//
//  DeviceManager.swift
//  OralableApp
//
//  CORRECTED VERSION - November 11, 2025
//  Production UUID filter ENABLED
//
//  Changes: Enabled production TGM Service UUID filter to connect to Oralable device
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
            device = OralableDevice(peripheral: peripheral, bleManager: bleManager!)
            print("🔍 [DeviceManager] ✅ OralableDevice created")
        case .anr:
            print("🔍 [DeviceManager] Creating ANRMuscleSenseDevice instance...")
            device = ANRMuscleSenseDevice(peripheral: peripheral, bleManager: bleManager!)
            print("🔍 [DeviceManager] ✅ ANRMuscleSenseDevice created")
        case .demo:
            print("🔍 [DeviceManager] Creating OralableDevice instance (demo mode)...")
            device = OralableDevice(peripheral: peripheral, bleManager: bleManager!)
            print("🔍 [DeviceManager] ✅ OralableDevice created (demo)")
        }
        
        print("🔍 [DeviceManager] Storing device in devices dictionary...")
        devices[peripheral.identifier] = device
        print("🔍 [DeviceManager] ✅ Device stored, total devices: \(devices.count)")
        
        print("🔍 [DeviceManager] Setting up device callback...")
        setupDeviceCallback(device)
        print("🔍 [DeviceManager] ✅ Device callback configured")
        
        print(String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] END handleDeviceDiscovered (success)")
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    private func handleDeviceConnected(peripheral: CBPeripheral) {
        print("\n✅ [DeviceManager] handleDeviceConnected")
        print("✅ [DeviceManager] Peripheral: \(peripheral.identifier)")
        print("✅ [DeviceManager] Name: \(peripheral.name ?? "Unknown")")
        
        isConnecting = false
        
        // Update device states
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            print("✅ [DeviceManager] Updating discoveredDevices[\(index)] to connected")
            discoveredDevices[index].connectionState = .connected
            
            let deviceInfo = discoveredDevices[index]
            if !connectedDevices.contains(where: { $0.id == deviceInfo.id }) {
                print("✅ [DeviceManager] Adding to connectedDevices...")
                connectedDevices.append(deviceInfo)
                print("✅ [DeviceManager] connectedDevices count: \(connectedDevices.count)")
            }
            
            if primaryDevice == nil {
                print("✅ [DeviceManager] Setting as primary device")
                primaryDevice = deviceInfo
            }
        }
        
        // Start device operations
        if let device = devices[peripheral.identifier] {
            print("✅ [DeviceManager] Starting device data collection...")
            Task {
                try? await device.startDataCollection()
                print("✅ [DeviceManager] Data collection started")
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
        
        // PRODUCTION: Accept any device advertising TGM Service as Oralable
        print("🔍 [DeviceManager] ⚠️ Name doesn't match known patterns")
        print("🔍 [DeviceManager] ✅ Accepting as Oralable (has TGM Service)")
        return .oralable
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
        
        // ==========================================
        // PRODUCTION MODE - ENABLED
        // ==========================================
        // Scan ONLY for TGM Service devices
        print("🔍 [DeviceManager] Starting scan for TGM Service devices...")
        let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        print("🔍 [DeviceManager] Service filter: \(tgmServiceUUID.uuidString)")
        bleManager?.startScanning(services: [tgmServiceUUID])
        
        // ==========================================
        // DEBUG MODE - DISABLED
        // ==========================================
        // Uncomment below to scan for ALL BLE devices
        // print("🔍 [DeviceManager] Starting scan for ALL BLE devices...")
        // print("🔍 [DeviceManager] (No service filter applied)")
        // bleManager?.startScanning()
        
        print(String(repeating: "=", count: 80))
        print("🔍 [DeviceManager] Scan started - waiting for discoveries")
        print(String(repeating: "=", count: 80) + "\n")
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        print("\n🛑 [DeviceManager] stopScanning() called")
        print("🛑 [DeviceManager] isScanning before: \(isScanning)")
        
        bleManager?.stopScanning()
        isScanning = false
        
        if let scanStart = scanStartTime {
            let duration = Date().timeIntervalSince(scanStart)
            print("🛑 [DeviceManager] Scan duration: \(String(format: "%.1f", duration))s")
            print("🛑 [DeviceManager] Devices discovered: \(discoveryCount)")
            print("🛑 [DeviceManager] Devices in list: \(discoveredDevices.count)")
        }
        
        print("🛑 [DeviceManager] isScanning after: \(isScanning)")
        print("🛑 [DeviceManager] Scan stopped\n")
    }
    
    // MARK: - Device Connection
    
    /// Connect to a specific device
    func connect(to deviceInfo: DeviceInfo) async throws {
        print("\n📲 [DeviceManager] connect(to:) called")
        print("📲 [DeviceManager] Device: \(deviceInfo.name)")
        print("📲 [DeviceManager] Type: \(deviceInfo.type)")
        print("📲 [DeviceManager] UUID: \(deviceInfo.peripheralIdentifier?.uuidString ?? "nil")")
        
        guard let peripheralId = deviceInfo.peripheralIdentifier else {
            print("📲 [DeviceManager] ❌ No peripheral identifier")
            throw DeviceError.invalidPeripheral
        }
        
        print("📲 [DeviceManager] Setting isConnecting = true")
        isConnecting = true
        
        print("📲 [DeviceManager] Updating device state to connecting...")
        if let index = discoveredDevices.firstIndex(where: { $0.id == deviceInfo.id }) {
            discoveredDevices[index].connectionState = .connecting
            print("📲 [DeviceManager] ✅ State updated")
        }
        
        print("📲 [DeviceManager] Calling bleManager.connect()...")
        try await bleManager?.connect(to: peripheralId)
        print("📲 [DeviceManager] ✅ Connection initiated")
    }
    
    /// Disconnect from a specific device
    func disconnect(from deviceInfo: DeviceInfo) async {
        print("\n🔌 [DeviceManager] disconnect(from:) called")
        print("🔌 [DeviceManager] Device: \(deviceInfo.name)")
        
        guard let peripheralId = deviceInfo.peripheralIdentifier else {
            print("🔌 [DeviceManager] ❌ No peripheral identifier")
            return
        }
        
        print("🔌 [DeviceManager] Calling bleManager.disconnect()...")
        await bleManager?.disconnect(from: peripheralId)
        print("🔌 [DeviceManager] ✅ Disconnect requested")
    }
    
    /// Disconnect from all devices
    func disconnectAll() async {
        print("\n🔌 [DeviceManager] disconnectAll() called")
        print("🔌 [DeviceManager] Connected devices: \(connectedDevices.count)")
        
        for deviceInfo in connectedDevices {
            await disconnect(from: deviceInfo)
        }
        
        print("🔌 [DeviceManager] ✅ All devices disconnected")
    }
    
    // MARK: - Device Data Management
    
    private func setupDeviceCallback(_ device: BLEDeviceProtocol) {
        print("📊 [DeviceManager] Setting up device callback for \(device.info.name)")
        
        device.onDataReceived = { [weak self] reading in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Add to all readings
                self.allSensorReadings.append(reading)
                
                // Update latest reading for this sensor type
                self.latestReadings[reading.type] = reading
                
                // Limit history size
                if self.allSensorReadings.count > 1000 {
                    self.allSensorReadings.removeFirst()
                }
                
                print("📊 [DeviceManager] Data received: \(reading.type) = \(reading.value)")
            }
        }
        
        print("📊 [DeviceManager] ✅ Device callback configured")
    }
    
    /// Clear all sensor readings
    func clearReadings() {
        print("🗑️ [DeviceManager] Clearing all sensor readings")
        print("🗑️ [DeviceManager] Readings before: \(allSensorReadings.count)")
        
        allSensorReadings.removeAll()
        latestReadings.removeAll()
        
        print("🗑️ [DeviceManager] Readings after: \(allSensorReadings.count)")
        print("🗑️ [DeviceManager] ✅ All readings cleared")
    }
    
    /// Get readings for a specific sensor type
    func getReadings(for sensorType: SensorType) -> [SensorReading] {
        return allSensorReadings.filter { $0.type == sensorType }
    }
    
    /// Get latest reading for a specific sensor type
    func getLatestReading(for sensorType: SensorType) -> SensorReading? {
        return latestReadings[sensorType]
    }
}
