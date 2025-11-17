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

    /// PPG Channel Order configuration (for OralableBLE compatibility)
    @Published var ppgChannelOrder: PPGChannelOrder = .standard

    // MARK: - Convenience Published Properties (for OralableBLE compatibility)
    // These mirror the computed properties in the extension but as @Published for Combine bindings

    /// Connection state as Boolean
    @Published var isConnected: Bool = false

    /// Device name of primary device
    @Published var deviceName: String = "No Device"

    /// Battery level (0-100)
    @Published var batteryLevel: Double = 0.0

    /// Heart rate (bpm)
    @Published var heartRate: Int = 0

    /// SpO2 percentage
    @Published var spO2: Int = 0

    /// Temperature in Celsius
    @Published var temperature: Double = 0.0

    /// PPG Red channel value
    @Published var ppgRedValue: Double = 0.0

    /// PPG Infrared channel value
    @Published var ppgIRValue: Double = 0.0

    /// PPG Green channel value
    @Published var ppgGreenValue: Double = 0.0

    /// Accelerometer X (g)
    @Published var accelX: Double = 0.0

    /// Accelerometer Y (g)
    @Published var accelY: Double = 0.0

    /// Accelerometer Z (g)
    @Published var accelZ: Double = 1.0

    /// Heart rate quality (0.0-1.0)
    @Published var heartRateQuality: Double = 0.0

    // MARK: - Private Properties

    private var devices: [UUID: BLEDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxDevices: Int = AppConfiguration.BLE.maxConcurrentConnections

    // BLE Integration
    private(set) var bleManager: BLECentralManager?

    // Discovery tracking
    private var discoveryCount: Int = 0
    private var scanStartTime: Date?

    // Auto-Reconnect Management (Phase 1 Refactoring)
    private var reconnectAttempts: [UUID: Int] = [:]
    private var reconnectTasks: [UUID: Task<Void, Never>] = [:]
    private let autoReconnectEnabled = AppConfiguration.BLE.autoReconnectEnabled

    // Data Throttling (Phase 2 Refactoring)
    private let sensorDataThrottler = DataThrottler<SensorReading>(
        minimumInterval: AppConfiguration.UI.sensorDataThrottleInterval
    )
    
    // MARK: - Initialization
    
    init() {
        print("\n🏭 [DeviceManager] Initializing...")
        bleManager = BLECentralManager()
        setupBLECallbacks()
        setupConveniencePropertyBindings()
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

    // MARK: - Convenience Property Bindings Setup

    private func setupConveniencePropertyBindings() {
        // Update isConnected when connectedDevices changes
        $connectedDevices
            .map { !$0.isEmpty }
            .assign(to: &$isConnected)

        // Update deviceName when primaryDevice changes
        $primaryDevice
            .map { $0?.name ?? "No Device" }
            .assign(to: &$deviceName)

        // Update sensor values when latestReadings changes
        $latestReadings
            .sink { [weak self] readings in
                guard let self = self else { return }

                // Update all sensor value properties
                self.batteryLevel = readings[.battery]?.value ?? 0.0

                let newHeartRate = Int(readings[.heartRate]?.value ?? 0)
                if newHeartRate != self.heartRate && newHeartRate > 0 {
                    print("💓 [DeviceManager] Updating @Published heartRate: \(self.heartRate) → \(newHeartRate)")
                }
                self.heartRate = newHeartRate

                self.spO2 = Int(readings[.spo2]?.value ?? 0)
                self.temperature = readings[.temperature]?.value ?? 0.0
                self.ppgRedValue = readings[.ppgRed]?.value ?? 0.0
                self.ppgIRValue = readings[.ppgInfrared]?.value ?? 0.0
                self.ppgGreenValue = readings[.ppgGreen]?.value ?? 0.0
                self.accelX = readings[.accelerometerX]?.value ?? 0.0
                self.accelY = readings[.accelerometerY]?.value ?? 0.0
                self.accelZ = readings[.accelerometerZ]?.value ?? 1.0
                self.heartRateQuality = readings[.heartRate]?.quality ?? 0.0
            }
            .store(in: &cancellables)
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

        let peripheralId = peripheral.identifier

        if let error = error {
            print("🔌 [DeviceManager] Error: \(error.localizedDescription)")
            lastError = .connectionLost
        }

        isConnecting = false

        // Update device states
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheralId }) {
            print("🔌 [DeviceManager] Updating discoveredDevices[\(index)] to disconnected")
            discoveredDevices[index].connectionState = .disconnected
        }

        connectedDevices.removeAll { $0.peripheralIdentifier == peripheralId }
        print("🔌 [DeviceManager] Removed from connectedDevices, count: \(connectedDevices.count)")

        if primaryDevice?.peripheralIdentifier == peripheralId {
            print("🔌 [DeviceManager] Primary device disconnected, setting to nil")
            primaryDevice = connectedDevices.first
        }

        // Auto-Reconnect Logic (Phase 1 Refactoring)
        if autoReconnectEnabled, let deviceInfo = discoveredDevices.first(where: { $0.peripheralIdentifier == peripheralId }) {
            print("🔄 [DeviceManager] Auto-reconnect enabled for device: \(deviceInfo.name)")
            attemptReconnection(to: deviceInfo)
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

        // Scan for ALL BLE devices, then filter by name (more reliable)
        // Name filtering happens in detectDeviceType() which checks for "oralable", "tgm", "anr", "muscle"
        print("🔍 [DeviceManager] Starting scan for ALL BLE devices...")
        print("🔍 [DeviceManager] (Will filter by name: Oralable, TGM, ANR)")
        bleManager?.startScanning()

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
        print("📊 [DeviceManager] handleSensorReading - Type: \(reading.sensorType), Value: \(reading.value)")

        // Phase 2: Use DataThrottler to prevent UI freezes from high-frequency data
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Don't throttle calculated metrics (low-frequency, important for UI)
            // Only throttle raw high-frequency sensor data (PPG, accelerometer)
            let calculatedMetrics: Set<SensorType> = [.heartRate, .spo2, .temperature, .battery]
            let shouldBypassThrottle = calculatedMetrics.contains(reading.sensorType)

            if shouldBypassThrottle {
                // Bypass throttler for calculated metrics - these are already low-frequency
                print("📊 [DeviceManager] Calculated metric - bypassing throttler: \(reading.sensorType) = \(reading.value)")
                self.allSensorReadings.append(reading)
                self.latestReadings[reading.sensorType] = reading

                if reading.sensorType == .heartRate {
                    print("💓 [DeviceManager] latestReadings[.heartRate] = \(reading.value) (should trigger binding)")
                }
            } else {
                // Throttle raw high-frequency data (PPG, accelerometer)
                if let throttledReading = await self.sensorDataThrottler.throttle(reading) {
                    print("📊 [DeviceManager] Throttled reading passed: \(throttledReading.sensorType) = \(throttledReading.value)")
                    self.allSensorReadings.append(throttledReading)
                    self.latestReadings[throttledReading.sensorType] = throttledReading
                }
                // Note: Dropped readings are tracked by throttler statistics
            }

            // Trim history if needed (keep last 1000)
            if self.allSensorReadings.count > AppConfiguration.Sensors.historyBufferSize {
                self.allSensorReadings.removeFirst(100)
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

    // MARK: - Data Throttling (Phase 2 Refactoring)

    /// Get sensor data throttling statistics
    /// - Returns: Tuple of (received count, emitted count, drop rate percentage)
    func getThrottlingStatistics() async -> (received: Int, emitted: Int, dropRate: Double) {
        await sensorDataThrottler.statistics()
    }

    /// Reset data throttling statistics
    func resetThrottlingStatistics() async {
        await sensorDataThrottler.reset()
    }

    // MARK: - Auto-Reconnect (Phase 1 Refactoring)

    /// Attempt to reconnect to a disconnected device with exponential backoff
    /// - Parameter deviceInfo: The device to reconnect to
    private func attemptReconnection(to deviceInfo: DeviceInfo) {
        guard let peripheralId = deviceInfo.peripheralIdentifier else {
            print("🔄 [DeviceManager] Cannot reconnect - no peripheral identifier")
            return
        }

        // Cancel any existing reconnect task for this device
        reconnectTasks[peripheralId]?.cancel()
        reconnectTasks[peripheralId] = nil

        // Get current attempt count (default to 0 if not found)
        let currentAttempt = (reconnectAttempts[peripheralId] ?? 0) + 1
        reconnectAttempts[peripheralId] = currentAttempt

        print("🔄 [DeviceManager] Reconnect attempt #\(currentAttempt) for device: \(deviceInfo.name)")

        // Check if we've exceeded max attempts
        if currentAttempt > AppConfiguration.BLE.maxReconnectAttempts {
            print("🔄 [DeviceManager] Max reconnect attempts (\(AppConfiguration.BLE.maxReconnectAttempts)) reached for device: \(deviceInfo.name)")
            reconnectAttempts[peripheralId] = nil
            lastError = .connectionLost
            return
        }

        // Calculate delay using exponential backoff
        let delay = AppConfiguration.BLE.reconnectInitialDelay * pow(
            AppConfiguration.BLE.reconnectBackoffMultiplier,
            Double(currentAttempt - 1)
        )

        print("🔄 [DeviceManager] Waiting \(String(format: "%.1f", delay))s before reconnect attempt...")

        // Create reconnect task
        let task = Task { @MainActor [weak self] in
            do {
                // Wait for delay
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Check if task was cancelled
                if Task.isCancelled {
                    print("🔄 [DeviceManager] Reconnect task cancelled for device: \(deviceInfo.name)")
                    return
                }

                print("🔄 [DeviceManager] Executing reconnect attempt for device: \(deviceInfo.name)")

                // Attempt reconnection
                try await self?.connect(to: deviceInfo)

                // If successful, reset attempt counter
                print("🔄 [DeviceManager] ✅ Reconnection successful for device: \(deviceInfo.name)")
                self?.reconnectAttempts[peripheralId] = nil
                self?.reconnectTasks[peripheralId] = nil

            } catch {
                print("🔄 [DeviceManager] ❌ Reconnection failed: \(error.localizedDescription)")
                // Don't recurse here - let handleDeviceDisconnected call us again if needed
            }
        }

        reconnectTasks[peripheralId] = task
    }

    /// Cancel all pending reconnection attempts
    func cancelAllReconnectionAttempts() {
        print("\n🔄 [DeviceManager] Cancelling all reconnection attempts...")
        for (_, task) in reconnectTasks {
            task.cancel()
        }
        reconnectTasks.removeAll()
        reconnectAttempts.removeAll()
        print("🔄 [DeviceManager] All reconnection attempts cancelled")
    }

    /// Cancel reconnection attempts for a specific device
    /// - Parameter deviceInfo: The device to cancel reconnection for
    func cancelReconnection(for deviceInfo: DeviceInfo) {
        guard let peripheralId = deviceInfo.peripheralIdentifier else { return }

        print("\n🔄 [DeviceManager] Cancelling reconnection for device: \(deviceInfo.name)")
        reconnectTasks[peripheralId]?.cancel()
        reconnectTasks[peripheralId] = nil
        reconnectAttempts[peripheralId] = nil
        print("🔄 [DeviceManager] Reconnection cancelled")
    }
}

