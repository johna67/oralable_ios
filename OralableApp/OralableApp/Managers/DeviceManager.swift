//
//  DeviceManager.swift
//  OralableApp
//
//  CORRECTED: November 11, 2025
//  Fixed: connect() method now uses correct UUID key
//

import Foundation
import CoreBluetooth
import Combine

/// Manager for coordinating multiple BLE devices
@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()
    
    // MARK: - Published Properties
    
    /// All discovered devices
    @Published var discoveredDevices: [DeviceInfo] = []
    
    /// Currently connected devices
    @Published var connectedDevices: [DeviceInfo] = []
    
    /// Primary active device
    @Published var primaryDevice: DeviceInfo?
    
    /// All sensor readings from all devices
    @Published var allSensorReadings: [SensorReading] = []
    
    /// Latest readings by sensor type (aggregated from all devices)
    @Published var latestReadings: [SensorType: SensorReading] = [:]
    
    /// Connection state
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    
    /// Errors
    @Published var lastError: DeviceError?
    
    // MARK: - Private Properties
    
    private var devices: [UUID: BLEDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxDevices: Int = 5
    
    // BLE Integration
    private(set) var bleManager: BLECentralManager?
    
    // Discovery tracking
    private var discoveryCount: Int = 0
    private var scanStartTime: Date?
    
    // MARK: - Initialization
    
    init() {
        print("\n🏭 [DeviceManager] Initializing...")
        bleManager = BLECentralManager()
        setupBLECallbacks()
        print("🏭 [DeviceManager] Initialization complete")
    }
    
    // MARK: - BLE Callbacks Setup
    
    private func setupBLECallbacks() {
        print("\n🔗 [DeviceManager] Setting up BLE callbacks...")
        
        bleManager?.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            print("\n📨 [DeviceManager] onDeviceDiscovered callback received")
            print("📨 [DeviceManager] Peripheral: \(peripheral.identifier)")
            print("📨 [DeviceManager] Name: \(name)")
            print("📨 [DeviceManager] RSSI: \(rssi)")
            
            Task { @MainActor [weak self] in
                print("📨 [DeviceManager] Dispatching to main actor...")
                self?.handleDeviceDiscovered(peripheral: peripheral, name: name, rssi: rssi)
            }
        }
        
        bleManager?.onDeviceConnected = { [weak self] peripheral in
            print("\n📨 [DeviceManager] onDeviceConnected callback received")
            print("📨 [DeviceManager] Peripheral: \(peripheral.identifier)")
            
            Task { @MainActor [weak self] in
                print("📨 [DeviceManager] Dispatching to main actor...")
                self?.handleDeviceConnected(peripheral: peripheral)
            }
        }
        
        bleManager?.onDeviceDisconnected = { [weak self] peripheral, error in
            print("\n📨 [DeviceManager] onDeviceDisconnected callback received")
            print("📨 [DeviceManager] Peripheral: \(peripheral.identifier)")
            if let error = error {
                print("📨 [DeviceManager] Error: \(error.localizedDescription)")
            }
            
            Task { @MainActor [weak self] in
                print("📨 [DeviceManager] Dispatching to main actor...")
                self?.handleDeviceDisconnected(peripheral: peripheral, error: error)
            }
        }
        
        bleManager?.onBluetoothStateChanged = { [weak self] state in
            print("\n📨 [DeviceManager] onBluetoothStateChanged callback received")
            print("📨 [DeviceManager] State: \(state.rawValue)")
            
            Task { @MainActor [weak self] in
                if state != .poweredOn && (self?.isScanning ?? false) {
                    print("⚠️ [DeviceManager] Bluetooth not powered on, stopping scan")
                    self?.isScanning = false
                }
            }
        }
        
        print("🔗 [DeviceManager] BLE callbacks configured successfully")
    }
    
    // MARK: - Device Discovery Handlers
    
    private func handleDeviceDiscovered(peripheral: CBPeripheral, name: String, rssi: Int) {
        discoveryCount += 1
        
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] handleDeviceDiscovered - DEVICE #\(discoveryCount)")
        print(String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] Peripheral UUID: \(peripheral.identifier)")
        print("🔍 [DeviceManager] Name: \(name)")
        print("🔍 [DeviceManager] RSSI: \(rssi) dBm")
        
        if let scanStart = scanStartTime {
            let elapsed = Date().timeIntervalSince(scanStart)
            print("🔍 [DeviceManager] Time since scan start: \(String(format: "%.1f", elapsed))s")
        }
        
        // Check if already discovered
        print("🔍 [DeviceManager] Checking if already discovered...")
        print("🔍 [DeviceManager] Current discovered devices count: \(discoveredDevices.count)")
        
        if discoveredDevices.contains(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            print("🔍 [DeviceManager] ⚠️ Device ALREADY in list - updating RSSI")
            
            if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                print("🔍 [DeviceManager] Found at index \(index), updating...")
                discoveredDevices[index].signalStrength = rssi
                print("🔍 [DeviceManager] ✅ RSSI updated to \(rssi)")
            }
            
            print(String(repeating: "=", count: 80))
            print("🔍 [DeviceManager] END handleDeviceDiscovered (duplicate)")
            print(String(repeating: "=", count: 80) + "\n")
            return
        }
        
        print("🔍 [DeviceManager] ✅ New device - creating DeviceInfo...")
        
        // Detect device type
        print("🔍 [DeviceManager] Detecting device type...")
        guard let deviceType = detectDeviceType(from: name, peripheral: peripheral) else {
            print("🔍 [DeviceManager] ❌ Could not detect device type for '\(name)'")
            print("🔍 [DeviceManager] ❌ Device REJECTED - unknown type")
            print(String(repeating: "=", count: 80))
            print("🔍 [DeviceManager] END handleDeviceDiscovered (rejected)")
            print(String(repeating: "=", count: 80) + "\n")
            return
        }
        
        print("🔍 [DeviceManager] ✅ Device type detected: \(deviceType)")
        
        // Create device info
        print("🔍 [DeviceManager] Creating DeviceInfo object...")
        let deviceInfo = DeviceInfo(
            type: deviceType,
            name: name,
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected,
            signalStrength: rssi
        )
        print("🔍 [DeviceManager] ✅ DeviceInfo created")
        
        // Add to discovered list
        print("🔍 [DeviceManager] Adding to discoveredDevices array...")
        discoveredDevices.append(deviceInfo)
        print("🔍 [DeviceManager] ✅ Added to discovered devices")
        print("🔍 [DeviceManager] New discoveredDevices count: \(discoveredDevices.count)")
        
        // Create device instance
        print("🔍 [DeviceManager] Creating device instance...")
        let device: BLEDeviceProtocol
        
        switch deviceType {
        case .oralable:
            print("🔍 [DeviceManager] Creating OralableDevice instance...")
            device = OralableDevice(peripheral: peripheral)
        case .anr:
            print("🔍 [DeviceManager] Creating ANRMuscleSenseDevice instance...")
            device = ANRMuscleSenseDevice(peripheral: peripheral, name: name)
        case .demo:
            print("🔍 [DeviceManager] Creating Demo device (using MockBLEDevice)...")
            #if DEBUG
            device = MockBLEDevice(type: .demo)
            #else
            device = OralableDevice(peripheral: peripheral)
            #endif
        }
        
        print("🔍 [DeviceManager] ✅ Device instance created")
        
        // Store device - KEY POINT: Using peripheral.identifier as the key
        print("🔍 [DeviceManager] Storing device in devices dictionary...")
        print("🔍 [DeviceManager] Dictionary key: \(peripheral.identifier)")
        devices[peripheral.identifier] = device
        print("🔍 [DeviceManager] ✅ Device stored")
        print("🔍 [DeviceManager] Total devices in dictionary: \(devices.count)")
        
        // Subscribe to device sensor readings
        print("🔍 [DeviceManager] Subscribing to device sensor readings...")
        subscribeToDevice(device)
        print("🔍 [DeviceManager] ✅ Subscribed to device")
        
        print(String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] END handleDeviceDiscovered (SUCCESS)")
        print("🔍 [DeviceManager] Summary: \(discoveredDevices.count) device(s) discovered so far")
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    private func handleDeviceConnected(peripheral: CBPeripheral) {
        print("\n✅ [DeviceManager] handleDeviceConnected")
        print("✅ [DeviceManager] Peripheral: \(peripheral.identifier)")
        print("✅ [DeviceManager] Name: \(peripheral.name ?? "Unknown")")
        
        isConnecting = false
        
        // Update device info
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            print("✅ [DeviceManager] Found device in discoveredDevices at index \(index)")
            discoveredDevices[index].connectionState = .connected
            
            // Add to connected devices if not already there
            if !connectedDevices.contains(where: { $0.id == discoveredDevices[index].id }) {
                print("✅ [DeviceManager] Adding to connectedDevices array")
                connectedDevices.append(discoveredDevices[index])
                print("✅ [DeviceManager] connectedDevices count: \(connectedDevices.count)")
            }
            
            // Set as primary if none set
            if primaryDevice == nil {
                print("✅ [DeviceManager] Setting as primary device (first connection)")
                primaryDevice = discoveredDevices[index]
            }
        } else {
            print("⚠️ [DeviceManager] Device not found in discoveredDevices!")
        }
        
        // Start device operations
        if let device = devices[peripheral.identifier] {
            print("✅ [DeviceManager] Calling device.connect() to discover services...")
            Task {
                do {
                    // First, let the device discover its services
                    try await device.connect()
                    print("✅ [DeviceManager] Device services discovered")
                    
                    // Then start data collection
                    try await device.startDataCollection()
                    print("✅ [DeviceManager] Data collection started")
                } catch {
                    print("❌ [DeviceManager] Error during device setup: \(error)")
                }
            }
        } else {
            print("⚠️ [DeviceManager] Device not found in devices dictionary!")
        }
    }
    
    private func handleDeviceDisconnected(peripheral: CBPeripheral, error: Error?) {
        print("\n🔌 [DeviceManager] handleDeviceDisconnected")
        print("🔌 [DeviceManager] Peripheral: \(peripheral.identifier)")
        print("🔌 [DeviceManager] Name: \(peripheral.name ?? "Unknown")")
        
        if let error = error {
            print("🔌 [DeviceManager] Error: \(error.localizedDescription)")
            lastError = .connectionLost
        }
        
        isConnecting = false
        
        // Update device states
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            print("🔌 [DeviceManager] Updating discoveredDevices[\(index)] to disconnected")
            discoveredDevices[index].connectionState = .disconnected
        }
        
        connectedDevices.removeAll { $0.peripheralIdentifier == peripheral.identifier }
        print("🔌 [DeviceManager] Removed from connectedDevices, count: \(connectedDevices.count)")
        
        if primaryDevice?.peripheralIdentifier == peripheral.identifier {
            print("🔌 [DeviceManager] Primary device disconnected, setting to nil")
            primaryDevice = connectedDevices.first
        }
    }
    
    private func detectDeviceType(from name: String, peripheral: CBPeripheral) -> DeviceType? {
        print("🔍 [DeviceManager] detectDeviceType")
        print("🔍 [DeviceManager] Input name: '\(name)'")
        print("🔍 [DeviceManager] Peripheral.name: '\(peripheral.name ?? "nil")'")
        
        let lowercaseName = name.lowercased()
        print("🔍 [DeviceManager] Lowercase name: '\(lowercaseName)'")
        
        // Check for Oralable
        if lowercaseName.contains("oralable") {
            print("🔍 [DeviceManager] ✅ Detected as: Oralable (name contains 'oralable')")
            return .oralable
        }
        
        // Check for TGM
        if lowercaseName.contains("tgm") {
            print("🔍 [DeviceManager] ✅ Detected as: Oralable (name contains 'tgm')")
            return .oralable
        }
        
        // Check for ANR
        if lowercaseName.contains("anr") || lowercaseName.contains("muscle") {
            print("🔍 [DeviceManager] ✅ Detected as: ANR MuscleSense")
            return .anr
        }
        
        // TEMPORARY: Accept all devices as Oralable for testing
        print("🔍 [DeviceManager] ⚠️ Name doesn't match known patterns")
        print("🔍 [DeviceManager] ⚠️ TEMPORARY: Accepting as Oralable for testing")
        return .oralable
        
        // PRODUCTION: Return nil for unknown devices
        // print("🔍 [DeviceManager] ❌ Unknown device type")
        // return nil
    }
    
    // MARK: - Device Discovery
    
    /// Start scanning for devices
    func startScanning() async {
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] startScanning() called")
        print(String(repeating: "=", count: 80))
        
        scanStartTime = Date()
        discoveryCount = 0
        
        print("🔍 [DeviceManager] Clearing previous discovered devices...")
        discoveredDevices.removeAll()
        print("🔍 [DeviceManager] discoveredDevices cleared")
        
        print("🔍 [DeviceManager] Setting isScanning = true...")
        isScanning = true
        print("🔍 [DeviceManager] isScanning = \(isScanning)")
        
        // OPTION 1: Scan for ALL BLE devices (for debugging)
        print("🔍 [DeviceManager] Starting scan for ALL BLE devices...")
        print("🔍 [DeviceManager] (No service filter applied)")
        bleManager?.startScanning()
        
        // OPTION 2: Scan ONLY for TGM Service devices (production)
        // print("🔍 [DeviceManager] Starting scan for TGM Service devices...")
        // let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        // print("🔍 [DeviceManager] Service filter: \(tgmServiceUUID.uuidString)")
        // bleManager?.startScanning(services: [tgmServiceUUID])
        
        print(String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] Scan started - waiting for discoveries...")
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        print("\n⏹️ [DeviceManager] stopScanning() called")
        
        if let scanStart = scanStartTime {
            let elapsed = Date().timeIntervalSince(scanStart)
            print("⏹️ [DeviceManager] Total scan duration: \(String(format: "%.1f", elapsed))s")
        }
        
        print("⏹️ [DeviceManager] Total devices discovered: \(discoveryCount)")
        print("⏹️ [DeviceManager] Devices in list: \(discoveredDevices.count)")
        
        print("⏹️ [DeviceManager] Setting isScanning = false...")
        isScanning = false
        
        print("⏹️ [DeviceManager] Calling bleManager.stopScanning()...")
        bleManager?.stopScanning()
        
        scanStartTime = nil
        print("⏹️ [DeviceManager] Scan stopped\n")
    }
    
    // MARK: - Connection Management
    
    // ✅ CORRECTED METHOD - Using peripheralIdentifier as dictionary key
    func connect(to deviceInfo: DeviceInfo) async throws {
        print("\n🔌 [DeviceManager] connect() called")
        print("🔌 [DeviceManager] Device: \(deviceInfo.name)")
        print("🔌 [DeviceManager] DeviceInfo.id: \(deviceInfo.id)")
        print("🔌 [DeviceManager] DeviceInfo.peripheralIdentifier: \(deviceInfo.peripheralIdentifier?.uuidString ?? "nil")")
        
        // ✅ CRITICAL FIX: Use peripheralIdentifier, not deviceInfo.id
        guard let peripheralId = deviceInfo.peripheralIdentifier else {
            print("❌ [DeviceManager] No peripheral identifier!")
            throw DeviceError.invalidPeripheral
        }
        
        print("🔌 [DeviceManager] Looking up device in dictionary with key: \(peripheralId)")
        print("🔌 [DeviceManager] Available dictionary keys: \(devices.keys.map { $0.uuidString })")
        
        guard let device = devices[peripheralId] else {
            print("❌ [DeviceManager] Device not found in devices dictionary!")
            print("❌ [DeviceManager] Searched for: \(peripheralId)")
            throw DeviceError.invalidPeripheral
        }
        
        print("🔌 [DeviceManager] ✅ Device found in dictionary")
        
        guard let peripheral = device.peripheral else {
            print("❌ [DeviceManager] Device has no peripheral!")
            throw DeviceError.invalidPeripheral
        }
        
        print("🔌 [DeviceManager] ✅ Peripheral available: \(peripheral.identifier)")
        
        isConnecting = true
        print("🔌 [DeviceManager] isConnecting = true")
        
        // Update state
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheralId }) {
            print("🔌 [DeviceManager] Updating state to .connecting")
            discoveredDevices[index].connectionState = .connecting
        }
        
        // Connect via BLE manager
        print("🔌 [DeviceManager] Calling bleManager.connect()...")
        bleManager?.connect(to: peripheral)
        print("🔌 [DeviceManager] Connection request sent")
    }
    
    func disconnect(from deviceInfo: DeviceInfo) {
        print("\n🔌 [DeviceManager] disconnect() called")
        print("🔌 [DeviceManager] Device: \(deviceInfo.name)")
        
        guard let peripheralId = deviceInfo.peripheralIdentifier,
              let device = devices[peripheralId],
              let peripheral = device.peripheral else {
            print("❌ [DeviceManager] Device or peripheral not found!")
            return
        }
        
        print("🔌 [DeviceManager] Calling bleManager.disconnect()...")
        bleManager?.disconnect(from: peripheral)
        
        // Stop data collection
        print("🔌 [DeviceManager] Stopping data collection...")
        Task {
            try? await device.stopDataCollection()
            print("🔌 [DeviceManager] Data collection stopped")
        }
    }
    
    func disconnectAll() {
        print("\n🔌 [DeviceManager] disconnectAll() called")
        print("🔌 [DeviceManager] Connected devices count: \(connectedDevices.count)")
        
        for deviceInfo in connectedDevices {
            print("🔌 [DeviceManager] Disconnecting: \(deviceInfo.name)")
            disconnect(from: deviceInfo)
        }
        
        print("🔌 [DeviceManager] All disconnections requested")
    }
    
    // MARK: - Sensor Data Management
    
    private func subscribeToDevice(_ device: BLEDeviceProtocol) {
        print("📊 [DeviceManager] subscribeToDevice")
        print("📊 [DeviceManager] Device: \(device.deviceInfo.name)")
        
        device.sensorReadingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.handleSensorReading(reading, from: device)
            }
            .store(in: &cancellables)
        
        print("📊 [DeviceManager] Subscription created")
    }
    
    private func handleSensorReading(_ reading: SensorReading, from device: BLEDeviceProtocol) {
        // Add to all readings
        allSensorReadings.append(reading)
        
        // Update latest readings
        latestReadings[reading.sensorType] = reading
        
        // Trim history if needed (keep last 1000)
        if allSensorReadings.count > 1000 {
            allSensorReadings.removeFirst(100)
        }
    }
    
    // MARK: - Device Info Access
    
    func device(withId id: UUID) -> DeviceInfo? {
        return discoveredDevices.first { $0.id == id }
    }
    
    // MARK: - Data Management
    
    /// Clear all sensor readings
    func clearReadings() {
        print("\n🗑️ [DeviceManager] clearReadings() called")
        allSensorReadings.removeAll()
        latestReadings.removeAll()
        print("🗑️ [DeviceManager] All readings cleared")
    }
    
    /// Set a device as the primary device
    func setPrimaryDevice(_ deviceInfo: DeviceInfo?) {
        print("\n📌 [DeviceManager] setPrimaryDevice() called")
        if let device = deviceInfo {
            print("📌 [DeviceManager] Setting primary device to: \(device.name)")
        } else {
            print("📌 [DeviceManager] Clearing primary device")
        }
        primaryDevice = deviceInfo
    }
}
