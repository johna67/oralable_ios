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

    // MARK: - Individual Sensor Value Published Properties (for ViewModel bindings)

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var heartRate: Int = 0
    @Published private(set) var spO2: Int = 0
    @Published private(set) var temperature: Double = 0.0
    @Published private(set) var batteryLevel: Double = 0.0
    @Published private(set) var accelX: Double = 0.0
    @Published private(set) var accelY: Double = 0.0
    @Published private(set) var accelZ: Double = 0.0
    @Published private(set) var ppgRedValue: Double = 0.0
    @Published private(set) var ppgIRValue: Double = 0.0
    @Published private(set) var ppgGreenValue: Double = 0.0
    @Published private(set) var heartRateQuality: Double = 0.0
    @Published private(set) var ppgChannelOrderValue: PPGChannelOrder = .standard
    
    // MARK: - Private Properties

    private var devices: [UUID: BLEDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxDevices: Int = 5

    // BLE Integration
    private(set) var bleManager: BLECentralManager?

    // Discovery tracking
    private var discoveryCount: Int = 0
    private var scanStartTime: Date?

    // Heart Rate & SpO2 Calculation
    private let heartRateCalculator = HeartRateCalculator()
    private var ppgIRBuffer: [UInt32] = []
    private var ppgRedBuffer: [UInt32] = []
    private let maxPPGBufferSize: Int = 300  // 6 seconds at 50Hz
    
    // MARK: - Initialization
    
    init() {
        print("\n🏭 [DeviceManager] Initializing...")
        
        // Load PPG channel order from UserDefaults
        if let rawValue = UserDefaults.standard.string(forKey: "ppgChannelOrder"),
           let order = PPGChannelOrder(rawValue: rawValue) {
            ppgChannelOrderValue = order
        }
        
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

                // Update isConnected published property
                isConnected = !connectedDevices.isEmpty
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

        var shouldReconnect = false

        if let error = error {
            print("🔌 [DeviceManager] Error: \(error.localizedDescription)")
            lastError = .connectionLost

            // Automatic reconnection for unexpected disconnections
            shouldReconnect = true
            print("🔌 [DeviceManager] Unexpected disconnection detected - will attempt reconnection")
        } else {
            print("🔌 [DeviceManager] Clean disconnection (user-initiated)")
        }

        isConnecting = false

        // Store device info before updating state (needed for reconnection)
        let deviceInfoForReconnect = discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier })

        // Update device states
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            print("🔌 [DeviceManager] Updating discoveredDevices[\(index)] to disconnected")
            discoveredDevices[index].connectionState = .disconnected
        }

        connectedDevices.removeAll { $0.peripheralIdentifier == peripheral.identifier }
        print("🔌 [DeviceManager] Removed from connectedDevices, count: \(connectedDevices.count)")

        // Update isConnected published property
        isConnected = !connectedDevices.isEmpty

        if primaryDevice?.peripheralIdentifier == peripheral.identifier {
            print("🔌 [DeviceManager] Primary device disconnected, setting to nil")
            primaryDevice = connectedDevices.first
        }

        // Attempt automatic reconnection for unexpected disconnections
        if shouldReconnect, let deviceInfo = deviceInfoForReconnect {
            print("🔌 [DeviceManager] Scheduling automatic reconnection in 2 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("🔌 [DeviceManager] Attempting automatic reconnection to \(deviceInfo.name)...")
                Task { @MainActor in
                    do {
                        try await self?.connect(to: deviceInfo)
                        print("✅ [DeviceManager] Automatic reconnection successful")
                    } catch {
                        print("❌ [DeviceManager] Automatic reconnection failed: \(error.localizedDescription)")
                    }
                }
            }
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

        // PRODUCTION: Only show known devices (Oralable/TGM or ANR)
        print("🔍 [DeviceManager] ❌ Unknown device type - name doesn't match known patterns")
        print("🔍 [DeviceManager] ❌ Device '\(name)' REJECTED - not an Oralable or ANR device")
        return nil
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

        // Update individual @Published properties for ViewModel bindings
        switch reading.sensorType {
        case .heartRate:
            heartRate = Int(reading.value)
            heartRateQuality = reading.quality ?? 0.0
        case .spo2:
            spO2 = Int(reading.value)
        case .temperature:
            temperature = reading.value
        case .battery:
            batteryLevel = reading.value
        case .accelerometerX:
            accelX = reading.value
        case .accelerometerY:
            accelY = reading.value
        case .accelerometerZ:
            accelZ = reading.value
        case .ppgRed:
            ppgRedValue = reading.value
            // Collect red samples for SpO2 calculation
            ppgRedBuffer.append(UInt32(reading.value))
            if ppgRedBuffer.count > maxPPGBufferSize {
                ppgRedBuffer.removeFirst(ppgRedBuffer.count - maxPPGBufferSize)
            }
        case .ppgInfrared:
            ppgIRValue = reading.value
            // Collect IR samples for HR calculation
            ppgIRBuffer.append(UInt32(reading.value))
            if ppgIRBuffer.count > maxPPGBufferSize {
                ppgIRBuffer.removeFirst(ppgIRBuffer.count - maxPPGBufferSize)
            }
            // Calculate heart rate when we have enough samples
            calculateHeartRateAndSpO2()
        case .ppgGreen:
            ppgGreenValue = reading.value
        default:
            break
        }

        // Trim history if needed (keep last 1000)
        if allSensorReadings.count > 1000 {
            allSensorReadings.removeFirst(100)
        }
    }

    private func calculateHeartRateAndSpO2() {
        // Calculate Heart Rate from IR samples
        if ppgIRBuffer.count >= 100 {  // Need at least 2 seconds of data
            if let hrResult = heartRateCalculator.calculateHeartRate(irSamples: ppgIRBuffer) {
                heartRate = Int(hrResult.bpm)
                heartRateQuality = hrResult.quality
            }
        }

        // Calculate SpO2 from Red/IR ratio
        if ppgRedBuffer.count >= 10 && ppgIRBuffer.count >= 10 {
            // Use recent samples for ratio calculation
            let recentRed = ppgRedBuffer.suffix(10)
            let recentIR = ppgIRBuffer.suffix(10)

            // Calculate average values
            let avgRed = Double(recentRed.reduce(0, +)) / Double(recentRed.count)
            let avgIR = Double(recentIR.reduce(0, +)) / Double(recentIR.count)

            // Only calculate if both values are valid (not saturated, not zero)
            if avgRed > 1000 && avgRed < 500000 && avgIR > 1000 && avgIR < 500000 {
                let ratio = avgRed / avgIR
                // Simplified SpO2 calculation: SpO2 = 110 - 25 * ratio
                let calculatedSpO2 = max(70, min(100, 110 - 25 * ratio))
                spO2 = Int(calculatedSpO2)
            }
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

// MARK: - BLEManagerProtocol Conformance

extension DeviceManager: BLEManagerProtocol {

    // MARK: - Connection State Properties
    // Note: isConnected is now a @Published property, not computed

    var deviceName: String {
        primaryDevice?.name ?? "No Device"
    }

    // Note: Recording functionality delegated to RecordingSessionManager
    var isRecording: Bool {
        RecordingSessionManager.shared.currentSession != nil
    }

    // Note: PPG channel order stored in UserDefaults
    var ppgChannelOrder: PPGChannelOrder {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "ppgChannelOrder"),
               let order = PPGChannelOrder(rawValue: rawValue) {
                return order
            }
            return .standard
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ppgChannelOrder")
            ppgChannelOrderValue = newValue
        }
    }

    // MARK: - Publisher Properties

    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    var isScanningPublisher: Published<Bool>.Publisher { $isScanning }
    var batteryLevelPublisher: Published<Double>.Publisher { $batteryLevel }
    var heartRatePublisher: Published<Int>.Publisher { $heartRate }
    var spO2Publisher: Published<Int>.Publisher { $spO2 }
    var ppgRedValuePublisher: Published<Double>.Publisher { $ppgRedValue }
    var accelXPublisher: Published<Double>.Publisher { $accelX }
    var accelYPublisher: Published<Double>.Publisher { $accelY }
    var accelZPublisher: Published<Double>.Publisher { $accelZ }
    var temperaturePublisher: Published<Double>.Publisher { $temperature }
    var heartRateQualityPublisher: Published<Double>.Publisher { $heartRateQuality }
    var ppgChannelOrderPublisher: Published<PPGChannelOrder>.Publisher { $ppgChannelOrderValue }

    // MARK: - BLEManagerProtocol Methods

    // Note: The class already has stopScanning() and async startScanning()
    // We provide sync wrappers where needed for protocol conformance

    /// Synchronous wrapper for async startScanning() - required by protocol
    func startScanning() {
        Task {
            // Call the async version defined in the main class (line 338)
            await (self as DeviceManager).startScanning()
        }
    }

    func connect(to peripheral: CBPeripheral) {
        Task {
            if let deviceInfo = discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                do {
                    try await connect(to: deviceInfo)
                    Logger.shared.info("[DeviceManager] ✅ Connected to \(deviceInfo.name)")

                    // Auto-start recording when connected (matching OralableBLE behavior)
                    await MainActor.run {
                        startRecording()
                    }
                } catch {
                    Logger.shared.error("[DeviceManager] ❌ Connection failed: \(error)")
                }
            }
        }
    }

    func disconnect() {
        guard let primary = primaryDevice else { return }

        // Auto-stop recording when disconnecting (matching OralableBLE behavior)
        if isRecording {
            stopRecording()
        }

        disconnect(from: primary)
    }

    func startRecording() {
        guard !isRecording else {
            Logger.shared.warning("[DeviceManager] Recording already in progress")
            return
        }

        do {
            let deviceID = primaryDevice?.peripheralIdentifier?.uuidString
            let deviceName = primaryDevice?.name ?? "Unknown"
            _ = try RecordingSessionManager.shared.startSession(
                deviceID: deviceID,
                deviceName: deviceName
            )
            Logger.shared.info("[DeviceManager] ✅ Started recording session")
        } catch {
            Logger.shared.error("[DeviceManager] ❌ Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else {
            Logger.shared.debug("[DeviceManager] No recording in progress")
            return
        }

        do {
            try RecordingSessionManager.shared.stopSession()
            Logger.shared.info("[DeviceManager] ✅ Stopped recording session")
        } catch {
            Logger.shared.error("[DeviceManager] ❌ Failed to stop recording: \(error)")
        }
    }

    func clearHistory() {
        clearReadings()
        Logger.shared.info("[DeviceManager] ✅ Cleared all history")
    }
}
