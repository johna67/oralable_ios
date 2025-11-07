//
//  OralableBLE.swift
//  OralableApp
//
//  Updated: November 2, 2025
//  Production version with robust data parsing and proper filtering
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Current Sensor Data Model

/// Contains the most recent sensor readings from the device
struct CurrentSensorData {
    var batteryLevel: Int = 0
    var firmwareVersion: String = "Unknown"
    var deviceUUID: UInt64 = 0
    var temperature: Double = 0.0
    var heartRate: Double = 0.0
    var spo2: Double = 0.0
    var isConnected: Bool = false
    var lastUpdate: Date = Date()
}


// MARK: - Log Message Model

struct LogMessage: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date = Date()
}

// MARK: - PPG Channel Order Configuration

enum PPGChannelOrder: String, CaseIterable {
    case redIrGreen = "Red, IR, Green (Firmware Docs)"
    case irRedGreen = "IR, Red, Green"
    case greenRedIr = "Green, Red, IR" 
    case redGreenIr = "Red, Green, IR"
    case irGreenRed = "IR, Green, Red"
    case greenIrRed = "Green, IR, Red"
    
    var description: String {
        rawValue
    }
}

// MARK: - BLE Manager

/// Manages Bluetooth Low Energy communication with Oralable devices
@MainActor
class OralableBLE: NSObject, ObservableObject {
    
    private var connectionManager: ConnectionManager?
    private var dataParser: DataParser?  // ADD THIS
    
    // MARK: - Configuration
    
    /// Configurable PPG channel order for debugging
    /// The firmware sends: Position 0, Position 1, Position 2
    /// We need to determine which position corresponds to which LED
    @Published var ppgChannelOrder: PPGChannelOrder = .redIrGreen {
        didSet {
            addLogMessage("🔧 PPG channel order changed to: \(ppgChannelOrder.rawValue)")
            // Clear buffers when changing order to avoid mixed data
            ppgBufferRed.removeAll()
            ppgBufferIR.removeAll()
            ppgBufferGreen.removeAll()
        }
    }
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var connectedDevice: CBPeripheral?
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionStatus: String = "Disconnected"
    
    // Current sensor data (most recent reading)
    @Published var sensorData: CurrentSensorData = CurrentSensorData()
    
    // Device information
    @Published var deviceName: String = "Unknown Device"
    
    // Logs for diagnostics
    @Published var logMessages: [LogMessage] = []
    
    // Sensor data history
    @Published var sensorDataHistory: [SensorData] = []
    @Published var batteryHistory: [BatteryData] = []
    @Published var ppgHistory: [PPGData] = []
    @Published var heartRateHistory: [HeartRateData] = []
    @Published var spo2History: [SpO2Data] = []
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    
    // Device state detection
    @Published var deviceState: DeviceStateResult?
    private let deviceStateDetector = DeviceStateDetector()
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var connectionTimeoutTimer: Timer?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    
    // Calculators
    private let heartRateCalculator = HeartRateCalculator()
    private let spo2Calculator = SpO2Calculator()
    
    // Data buffers for calculations
    private var ppgBufferRed: [Int32] = []
    private var ppgBufferIR: [Int32] = []
    private var ppgBufferGreen: [Int32] = []
    
    // Track discovered device UUIDs to reduce duplicate logging
    private var discoveredDeviceUUIDs: Set<UUID> = []
    
    // FIXED: Correct TGM Service and Characteristic UUIDs
    private let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    
    private let ppgDataUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
    private let accelerometerUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
    private let temperatureUUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
    private let batteryUUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
    private let deviceUUIDChar = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E")
    private let firmwareVersionUUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")
    private let ppgRegisterReadUUID = CBUUID(string: "3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E")
    private let ppgRegisterWriteUUID = CBUUID(string: "3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E")
    private let muscleSiteUUID = CBUUID(string: "3A0FF102-98C4-46B2-94AF-1AEE0FD4C48E")
    
    // Characteristic references
    private var ppgCharacteristic: CBCharacteristic?
    private var accelerometerCharacteristic: CBCharacteristic?
    private var temperatureCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var deviceUUIDCharacteristic: CBCharacteristic?
    private var firmwareVersionCharacteristic: CBCharacteristic?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        connectionManager = ConnectionManager()
        setupConnectionCallbacks()
        
        // ADD THIS:
        dataParser = DataParser()
        setupDataParserCallbacks()
        setupCentralManager()
    }
    
    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    // MARK: - Data Parser Setup

    private func setupDataParserCallbacks() {
        // Subscribe to parsed sensor readings
        dataParser?.sensorReadingSubject
            .sink { [weak self] reading in
                self?.handleParsedSensorReading(reading)
            }
            .store(in: &cancellables)
    }

    private func handleParsedSensorReading(_ reading: SensorReading) {
        // Add to your existing sensor data arrays
        // Update your @Published properties
        // This replaces the manual parsing you had before
        
        print("Parsed sensor reading: \(reading.sensorType) = \(reading.value)")
        
        // You'll connect this to your existing data storage logic
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Oralable devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            addLogMessage("❌ Bluetooth is not powered on")
            return
        }
        
        isScanning = true
        discoveredDevices.removeAll()
        discoveredDeviceUUIDs.removeAll()
        connectionStatus = "Scanning..."
        
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        addLogMessage("🔍 Scanning for Oralable devices...")
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionStatus = "Scan stopped"
        }
        addLogMessage("⏹️ Stopped scanning - Found \(discoveredDevices.count) device(s)")
    }
    
    /// Toggle scanning state
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    /// Connect to a specific device
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionStatus = "Connecting..."
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        addLogMessage("📱 Attempting connection to: \(peripheral.name ?? "Unknown")")
        addLogMessage("   Device ID: \(peripheral.identifier.uuidString)")
        
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.addLogMessage("⏰ Connection timeout after 30 seconds")
                self.centralManager.cancelPeripheralConnection(peripheral)
                self.connectionStatus = "Timeout"
                self.connectedPeripheral = nil
            }
        }
        
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Connect to first device with matching name (for debugging)
    func connectToDeviceWithName(_ name: String) {
        let matchingDevices = discoveredDevices.filter { device in
            device.name?.lowercased().contains(name.lowercased()) == true
        }
        
        if let device = matchingDevices.first {
            connect(to: device)
        } else {
            addLogMessage("❌ No device found with name: \(name)")
        }
    }
    
    /// Disconnect from current device
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        connectionStatus = "Disconnecting..."
        centralManager.cancelPeripheralConnection(peripheral)
        addLogMessage("📱 Disconnecting...")
    }
    
    /// Clear discovered devices and start fresh scan
    func refreshScan() {
        stopScanning()
        discoveredDevices.removeAll()
        discoveredDeviceUUIDs.removeAll()
        addLogMessage("🔄 Refreshing scan...")
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await startScanning()
        }
    }
    
    /// Force reset all BLE connections and state
    func resetBLE() {
        addLogMessage("🔄 Resetting BLE...")
        
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        isConnected = false
        isScanning = false
        connectedDevice = nil
        connectedPeripheral = nil
        connectionStatus = "Disconnected"
        discoveredDevices.removeAll()
        discoveredDeviceUUIDs.removeAll()
        sensorData = CurrentSensorData()
        
        ppgBufferRed.removeAll()
        ppgBufferIR.removeAll()
        ppgBufferGreen.removeAll()
        
        addLogMessage("✅ Reset complete")
        
        if centralManager.state == .poweredOn {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 seconds
                await startScanning()
            }
        }
    }
    
    /// Clear all logs and historical data
    func clearLogs() {
        logMessages.removeAll()
        sensorDataHistory.removeAll()
        batteryHistory.removeAll()
        ppgHistory.removeAll()
        heartRateHistory.removeAll()
        spo2History.removeAll()
        temperatureHistory.removeAll()
        accelerometerHistory.removeAll()
        addLogMessage("🗑️ Cleared all data")
    }
    
    // MARK: - Historical Data Methods
    
    /// Get historical metrics for a specific time range
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics {
        return HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range)
    }
    
    // MARK: - Private Helper Methods
    
    
    // MARK: - Connection Manager Setup
    
    private func setupConnectionCallbacks() {
        connectionManager?.onConnected = { [weak self] peripheral in
            Task { @MainActor [weak self] in
                self?.handleConnectionSuccess(peripheral: peripheral)
            }
        }
        
        connectionManager?.onDisconnected = { [weak self] peripheral, error in
            Task { @MainActor [weak self] in
                self?.handleDisconnection(peripheral: peripheral, error: error)
            }
        }
        
        connectionManager?.onConnectionFailed = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleConnectionFailure(error: error)
            }
        }
    }

    private func handleConnectionSuccess(peripheral: CBPeripheral) {
        // Find existing connection success code in OralableBLE
        // and call it here
        print("Connected via ConnectionManager")
    }

    private func handleDisconnection(peripheral: CBPeripheral, error: Error?) {
        // Find existing disconnection code in OralableBLE
        // and call it here
        print("Disconnected via ConnectionManager")
    }

    private func handleConnectionFailure(error: Error) {
        // Find existing connection failure code in OralableBLE
        // and call it here
        print("Connection failed via ConnectionManager")
    }
    /// Add a log message with timestamp
    private func addLogMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let formattedMessage = "[\(timestamp)] \(message)"
        
        logMessages.append(LogMessage(message: formattedMessage))
        print(formattedMessage)
    }
    
    /// Process PPG data and calculate heart rate and SpO2
    nonisolated private func processPPGData(red: [Int32], ir: [Int32], green: [Int32]) {
        Task { @MainActor in
            ppgBufferRed.append(contentsOf: red)
            ppgBufferIR.append(contentsOf: ir)
            ppgBufferGreen.append(contentsOf: green)
            
            addLogMessage("📈 PPG Buffer: Red=\(ppgBufferRed.count), IR=\(ppgBufferIR.count), Green=\(ppgBufferGreen.count) samples")
            
            let maxBufferSize = 300
            if ppgBufferRed.count > maxBufferSize {
                ppgBufferRed.removeFirst(ppgBufferRed.count - maxBufferSize)
                ppgBufferIR.removeFirst(ppgBufferIR.count - maxBufferSize)
                ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxBufferSize)
            }
            
            // Heart Rate Calculation
            if ppgBufferIR.count >= 20 {
                let irSamplesUInt32 = ppgBufferIR.map { UInt32(bitPattern: $0) }
                if let heartRate = heartRateCalculator.calculateHeartRate(irSamples: irSamplesUInt32) {
                    let bpm = heartRate.bpm
                    addLogMessage("❤️ Heart Rate Calculated: \(bpm) BPM (quality: \(String(format: "%.1f", heartRate.quality)))")
                    
                    sensorData.heartRate = bpm
                    
                    // FIXED: Add to history array so dashboard shows it!
                    let hrData = HeartRateData(bpm: bpm, quality: heartRate.quality, timestamp: Date())
                    heartRateHistory.append(hrData)
                    if heartRateHistory.count > 1000 {
                        heartRateHistory.removeFirst(heartRateHistory.count - 1000)
                    }
                    
                    addLogMessage("📊 Heart Rate History: \(heartRateHistory.count) readings")
                } else {
                    addLogMessage("⚠️ Heart Rate: Calculation failed (insufficient signal quality)")
                }
            } else {
                addLogMessage("⏳ Heart Rate: Waiting for more data (\(ppgBufferIR.count)/20 samples)")
            }
            
            // SpO2 Calculation
            if ppgBufferRed.count >= 150, ppgBufferIR.count >= 150 {
                if let result = spo2Calculator.calculateSpO2WithQuality(
                    redSamples: ppgBufferRed,
                    irSamples: ppgBufferIR
                ) {
                    let spo2Value = result.spo2
                    addLogMessage("🫁 SpO2 Calculated: \(String(format: "%.1f", spo2Value))% (quality: \(String(format: "%.1f", result.quality)))")
                    
                    sensorData.spo2 = spo2Value
                    
                    // FIXED: Add to history array so dashboard shows it!
                    let spo2Data = SpO2Data(percentage: spo2Value, quality: result.quality, timestamp: Date())
                    spo2History.append(spo2Data)
                    if spo2History.count > 1000 {
                        spo2History.removeFirst(spo2History.count - 1000)
                    }
                    
                    addLogMessage("📊 SpO2 History: \(spo2History.count) readings")
                } else {
                    addLogMessage("⚠️ SpO2: Calculation failed (poor signal quality)")
                }
            } else {
                addLogMessage("⏳ SpO2: Waiting for more data (\(ppgBufferRed.count)/150 samples)")
            }
            
            // CRITICAL FIX: Consolidate all sensor data into sensorDataHistory
            consolidateSensorData()
        }
    }
    
    /// Consolidates individual sensor readings into complete SensorData objects
    /// This is required for HistoricalDetailView to work properly
    private func consolidateSensorData() {
        // DEBUG: Log sensor availability
        print("🔄 Attempting to consolidate sensor data:")
        print("   PPG: \(ppgHistory.count)")
        print("   Temperature: \(temperatureHistory.count)")
        print("   Battery: \(batteryHistory.count)")
        print("   Accelerometer: \(accelerometerHistory.count)")
        print("   Heart Rate: \(heartRateHistory.count)")
        print("   SpO2: \(spo2History.count)")
        
        // RELAXED REQUIREMENTS: Battery and temperature should always be visible
        // Only require accelerometer as minimum for device state detection
        // PPG can be invalid (zeros) if device is not on tissue
        guard !accelerometerHistory.isEmpty else {
            print("⚠️ Need at least Accelerometer data to consolidate")
            return
        }
        
        // Get the latest readings from each sensor (use defaults if missing)
        let latestPPG = ppgHistory.last ?? PPGData(red: 0, ir: 0, green: 0, timestamp: Date())
        guard let latestAccel = accelerometerHistory.last else {
            print("⚠️ Could not get latest Accelerometer reading")
            return
        }
        
        // Use latest or create default values for optional sensors
        let latestTemp = temperatureHistory.last ?? TemperatureData(celsius: 0.0, timestamp: Date())
        let latestBattery = batteryHistory.last ?? BatteryData(percentage: 0, timestamp: Date())
        
        // Get optional calculated metrics
        let latestHeartRate = heartRateHistory.last
        let latestSpO2 = spo2History.last
        
        // Create consolidated sensor data
        let consolidatedData = SensorData(
            timestamp: Date(),
            ppg: latestPPG,
            accelerometer: latestAccel,
            temperature: latestTemp,
            battery: latestBattery,
            heartRate: latestHeartRate,
            spo2: latestSpO2
        )
        
        // Add to history
        sensorDataHistory.append(consolidatedData)
        
        // Limit history size
        if sensorDataHistory.count > 10000 {
            sensorDataHistory.removeFirst(sensorDataHistory.count - 10000)
        }
        
        print("✅ Consolidated! Total sensorDataHistory: \(sensorDataHistory.count)")
        addLogMessage("📦 Consolidated sensor data: \(sensorDataHistory.count) complete readings")
        
        // Detect device state based on recent sensor data
        Task {
            if let stateResult = await deviceStateDetector.analyzeDeviceState(sensorData: sensorDataHistory) {
                await MainActor.run {
                    deviceState = stateResult
                    addLogMessage("🔍 Device State: \(stateResult.state.rawValue) (confidence: \(String(format: "%.0f", stateResult.confidence * 100))%)")
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension OralableBLE: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                connectionStatus = "Ready"
                addLogMessage("✅ Bluetooth ready")
            case .poweredOff:
                connectionStatus = "Bluetooth Off"
                addLogMessage("❌ Bluetooth is off")
            case .unauthorized:
                connectionStatus = "Unauthorized"
                addLogMessage("❌ Bluetooth unauthorized")
            case .unsupported:
                connectionStatus = "Unsupported"
                addLogMessage("❌ BLE not supported")
            default:
                connectionStatus = "Not Ready"
                addLogMessage("⚠️ Bluetooth: \(central.state.rawValue)")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard !discoveredDeviceUUIDs.contains(peripheral.identifier) else {
                return
            }
            
            let deviceName = peripheral.name ?? ""
            
            // Skip devices with no name
            guard !deviceName.isEmpty else {
                return
            }
            
            let deviceNameLower = deviceName.lowercased()
            let namePatterns = ["oralable", "tgm", "nrf", "tooth", "dental", "bruxism"]
            let matchesName = namePatterns.contains { deviceNameLower.contains($0) }
            
            let advertisedUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            let hasTGMService = advertisedUUIDs.contains(tgmServiceUUID)
            
            // Only add devices that match our criteria
            if matchesName || hasTGMService {
                discoveredDeviceUUIDs.insert(peripheral.identifier)
                discoveredDevices.append(peripheral)
                
                addLogMessage("✅ Found: \(deviceName) (RSSI: \(RSSI)dB)")
                
                if !advertisedUUIDs.isEmpty {
                    addLogMessage("   Services: \(advertisedUUIDs.map { $0.uuidString }.joined(separator: ", "))")
                }
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            retryCount = 0
            
            addLogMessage("✅ Connected to \(peripheral.name ?? "device")")
            addLogMessage("🔍 Starting service discovery...")
            
            isConnected = true
            connectedDevice = peripheral
            deviceName = peripheral.name ?? "Unknown"
            sensorData.isConnected = true
            connectionStatus = "Connected"
            
            addLogMessage("📊 Discovering Oralable service...")

            peripheral.discoverServices([tgmServiceUUID])
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            
            let errorMsg = error?.localizedDescription ?? "Unknown error"
            addLogMessage("❌ Connection failed: \(errorMsg)")
            
            connectionStatus = "Failed"
            connectedPeripheral = nil
            
            if retryCount < maxRetries {
                retryCount += 1
                addLogMessage("🔄 Retry \(retryCount)/\(maxRetries) in 2 seconds...")
                
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await connect(to: peripheral)
                }
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            
            if let error = error {
                addLogMessage("⚠️ Disconnected: \(error.localizedDescription)")
            } else {
                addLogMessage("📱 Disconnected")
            }
            
            isConnected = false
            connectedDevice = nil
            connectedPeripheral = nil
            connectionStatus = "Disconnected"
            sensorData.isConnected = false
            
            ppgBufferRed.removeAll()
            ppgBufferIR.removeAll()
            ppgBufferGreen.removeAll()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OralableBLE: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                addLogMessage("❌ Service discovery error: \(error.localizedDescription)")
                return
            }
            
            guard let services = peripheral.services else {
                addLogMessage("⚠️ No services found on device")
                return
            }
            
            addLogMessage("📊 Found \(services.count) service(s):")
            
            for service in services {
                addLogMessage("   • \(service.uuid.uuidString)")
            }
            
            var tgmServiceFound = false
            for service in services {
                if service.uuid == tgmServiceUUID {
                    tgmServiceFound = true
                    addLogMessage("✅ TGM Service found!")
                    addLogMessage("🔍 Discovering characteristics...")
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
            
            if !tgmServiceFound {
                addLogMessage("⚠️ TGM Service NOT found")
                addLogMessage("   Expected: \(tgmServiceUUID.uuidString)")
                addLogMessage("   Trying to discover characteristics on all services...")
                
                for service in services {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                addLogMessage("❌ Characteristic error: \(error.localizedDescription)")
                return
            }
            
            guard let characteristics = service.characteristics else {
                addLogMessage("⚠️ No characteristics in service: \(service.uuid.uuidString)")
                return
            }
            
            addLogMessage("📊 Service \(service.uuid.uuidString): \(characteristics.count) characteristic(s)")
            
            var foundAnyKnownCharacteristic = false
            
            for characteristic in characteristics {
                addLogMessage("   • Char: \(characteristic.uuid.uuidString)")
                
                switch characteristic.uuid {
                case ppgDataUUID:
                    ppgCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    addLogMessage("   ✅ PPG Data - notifications enabled")
                    foundAnyKnownCharacteristic = true
                    
                case accelerometerUUID:
                    accelerometerCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    addLogMessage("   ✅ Accelerometer - notifications enabled")
                    foundAnyKnownCharacteristic = true
                    
                case temperatureUUID:
                    temperatureCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    addLogMessage("   ✅ Temperature - notifications enabled")
                    foundAnyKnownCharacteristic = true
                    
                case batteryUUID:
                    batteryCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                    addLogMessage("   ✅ Battery - notifications enabled")
                    foundAnyKnownCharacteristic = true
                    
                case deviceUUIDChar:
                    deviceUUIDCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                    addLogMessage("   ✅ Device UUID - reading")
                    foundAnyKnownCharacteristic = true
                    
                case firmwareVersionUUID:
                    firmwareVersionCharacteristic = characteristic
                    peripheral.readValue(for: characteristic)
                    addLogMessage("   ✅ Firmware Version - reading")
                    foundAnyKnownCharacteristic = true
                    
                default:
                    addLogMessage("   ⚪ Unknown characteristic")
                }
            }
            
            if !foundAnyKnownCharacteristic {
                addLogMessage("⚠️ No known TGM characteristics found in this service")
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Task { @MainActor in
                addLogMessage("❌ Read error: \(error.localizedDescription)")
            }
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
        
        switch characteristic.uuid {
        case ppgDataUUID:
            parsePPGData(data)
        case accelerometerUUID:
            parseAccelerometerData(data)
        case temperatureUUID:
            parseTemperatureData(data)
        case batteryUUID:
            parseBatteryData(data)
        case deviceUUIDChar:
            parseDeviceUUID(data)
        case firmwareVersionUUID:
            parseFirmwareVersion(data)
        default:
            break
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                addLogMessage("❌ Notification error for \(characteristic.uuid): \(error.localizedDescription)")
            } else if characteristic.isNotifying {
                addLogMessage("✅ Notifications active for \(characteristic.uuid)")
            }
        }
    }
    
    // MARK: - FIXED Data Parsing - Handles actual firmware format
    
    nonisolated private func parsePPGData(_ data: Data) {
        Task { @MainActor in
            addLogMessage("📊 PPG: Received \(data.count) bytes")
            
            // Firmware packet structure (from tgm_service.h):
            // Bytes 0-3: frame counter (uint32_t)
            // Then for each sample (20 samples, CONFIG_PPG_SAMPLES_PER_FRAME):
            //   Bytes 0-3: Red   (uint32_t)
            //   Bytes 4-7: IR    (uint32_t)
            //   Bytes 8-11: Green (uint32_t)
            // Total: 4 + (20 * 12) = 244 bytes
            
            guard data.count >= 244 else {
                addLogMessage("⚠️ PPG data too short: \(data.count) bytes (expected 244)")
                return
            }
            
            // Parse frame counter
            let frameCounterBytes = data.subdata(in: 0..<4)
            let frameCounter = frameCounterBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
            addLogMessage("🔢 Frame counter: \(frameCounter)")
            
            var redSamples: [Int32] = []
            var irSamples: [Int32] = []
            var greenSamples: [Int32] = []
            
            // DEBUG: Log first few bytes
            let firstBytes = data.prefix(28).map { String(format: "%02X", $0) }.joined(separator: " ")
            addLogMessage("🔍 First 28 bytes: \(firstBytes)")
            addLogMessage("🔧 Using channel order: \(ppgChannelOrder.rawValue)")
        
            // Parse 20 samples, each 12 bytes (3 x UInt32 in little-endian format)
            // FIRMWARE FORMAT: Red, IR, Green (confirmed from tgm_service.h)
            for i in 0..<20 {
                let offset = 4 + (i * 12)  // Skip 4-byte frame counter
                
                guard offset + 12 <= data.count else { break }
                
                // Read three 4-byte values
                let bytes0to3 = data.subdata(in: offset..<(offset + 4))       // Position 0
                let bytes4to7 = data.subdata(in: (offset + 4)..<(offset + 8))  // Position 1
                let bytes8to11 = data.subdata(in: (offset + 8)..<(offset + 12)) // Position 2
                
                // Parse as little-endian UInt32 (firmware standard)
                let val0 = UInt32(littleEndian: bytes0to3.withUnsafeBytes { $0.load(as: UInt32.self) })
                let val1 = UInt32(littleEndian: bytes4to7.withUnsafeBytes { $0.load(as: UInt32.self) })
                let val2 = UInt32(littleEndian: bytes8to11.withUnsafeBytes { $0.load(as: UInt32.self) })
                
                // Assign to channels based on configured order
                let (red, ir, green): (UInt32, UInt32, UInt32)
                switch ppgChannelOrder {
                case .redIrGreen:  // Firmware default
                    (red, ir, green) = (val0, val1, val2)
                case .irRedGreen:
                    (red, ir, green) = (val1, val0, val2)
                case .greenRedIr:
                    (red, ir, green) = (val1, val2, val0)
                case .redGreenIr:
                    (red, ir, green) = (val0, val2, val1)
                case .irGreenRed:
                    (red, ir, green) = (val2, val0, val1)
                case .greenIrRed:
                    (red, ir, green) = (val2, val1, val0)
                }
                
                // DEBUG: Log first 3 samples to show LED time-multiplexing pattern
                if i < 3 {
                    let hex0 = bytes0to3.map { String(format: "%02X", $0) }.joined(separator: " ")
                    let hex1 = bytes4to7.map { String(format: "%02X", $0) }.joined(separator: " ")
                    let hex2 = bytes8to11.map { String(format: "%02X", $0) }.joined(separator: " ")
                    addLogMessage("🔍 Sample \(i) raw (firmware order: Red, IR, Green):")
                    addLogMessage("   Pos 0 [\(hex0)] = \(val0)")
                    addLogMessage("   Pos 1 [\(hex1)] = \(val1)")
                    addLogMessage("   Pos 2 [\(hex2)] = \(val2)")
                    addLogMessage("   → Assigned: R=\(red), IR=\(ir), G=\(green)")
                }
                
                // Store in correct arrays
                redSamples.append(Int32(bitPattern: red))
                irSamples.append(Int32(bitPattern: ir))
                greenSamples.append(Int32(bitPattern: green))
            }
            
            // DEBUG: Log parsed sample statistics with validation
            if !irSamples.isEmpty {
                let avgIR = irSamples.map { Double($0) }.reduce(0, +) / Double(irSamples.count)
                let minIR = irSamples.min() ?? 0
                let maxIR = irSamples.max() ?? 0
                let avgRed = redSamples.map { Double($0) }.reduce(0, +) / Double(redSamples.count)
                let avgGreen = greenSamples.map { Double($0) }.reduce(0, +) / Double(greenSamples.count)
                
                addLogMessage("📈 IR    Stats: Min=\(minIR), Max=\(maxIR), Avg=\(Int(avgIR))")
                addLogMessage("📈 Red   Stats: Avg=\(Int(avgRed))")
                addLogMessage("📈 Green Stats: Avg=\(Int(avgGreen))")
                
                // Validation: PPG values should typically be in range 10k-500k
                let validRange = 10_000...500_000
                let irValid = validRange.contains(Int(avgIR))
                let redValid = validRange.contains(Int(avgRed))
                let greenValid = validRange.contains(Int(avgGreen))
                
                if !irValid || !redValid || !greenValid {
                    addLogMessage("⚠️ WARNING: PPG values outside expected range (10k-500k)")
                    addLogMessage("   This may indicate:")
                    addLogMessage("   1. Wrong channel order in parsing")
                    addLogMessage("   2. Sensor not in contact with tissue")
                    addLogMessage("   3. LED power settings incorrect")
                }
            }
            
            addLogMessage("💓 PPG parsed: \(redSamples.count) samples")
            
            // CRITICAL FIX: The firmware time-multiplexes LEDs - only one LED is on per sample
            // Pattern from logs:
            //   Sample 0: Red LED ON  → Red reads ~138k, IR=0, Green=524287 (max ADC)
            //   Sample 1: IR LED ON   → IR reads ~138k, Red=~138k, Green=0
            //   Sample 2: Green LED ON → Green reads ~138k, Red=0, IR=524287 (max ADC)
            //
            // The 524287 (0x7FFFF) is the ADC maximum when LED is off (ambient light/noise)
            // Valid tissue readings are in the range ~10k-300k
            
            // Extract valid samples for each channel (reasonable tissue absorption range)
            let validRedSamples = redSamples.filter { $0 > 10_000 && $0 < 300_000 }
            let validIRSamples = irSamples.filter { $0 > 10_000 && $0 < 300_000 }
            let validGreenSamples = greenSamples.filter { $0 > 10_000 && $0 < 300_000 }
            
            addLogMessage("🔍 Valid samples: Red=\(validRedSamples.count), IR=\(validIRSamples.count), Green=\(validGreenSamples.count)")
            
            // Check if we have enough valid readings from any channel
            // During time-multiplexing, we expect ~6-7 valid samples per LED (out of 20 total)
            let hasValidData = validRedSamples.count >= 3 || validIRSamples.count >= 3 || validGreenSamples.count >= 3
            
            if !hasValidData {
                addLogMessage("⚠️ No valid PPG readings - device not on tissue or LEDs off")
                addLogMessage("   Device may be in standby, charging, or not properly positioned")
                
                // Still add to history but mark as invalid
                let ppgData = PPGData(red: 0, ir: 0, green: 0, timestamp: Date())
                ppgHistory.append(ppgData)
                if ppgHistory.count > 1000 {
                    ppgHistory.removeFirst(ppgHistory.count - 1000)
                }
                
                return  // Don't process this data for HR/SpO2
            }
            
            // Use average of valid samples for history (more robust than last sample)
            if !validRedSamples.isEmpty || !validIRSamples.isEmpty || !validGreenSamples.isEmpty {
                let avgRed = validRedSamples.isEmpty ? 0 : Int32(validRedSamples.map { Double($0) }.reduce(0, +) / Double(validRedSamples.count))
                let avgIR = validIRSamples.isEmpty ? 0 : Int32(validIRSamples.map { Double($0) }.reduce(0, +) / Double(validIRSamples.count))
                let avgGreen = validGreenSamples.isEmpty ? 0 : Int32(validGreenSamples.map { Double($0) }.reduce(0, +) / Double(validGreenSamples.count))
                
                let ppgData = PPGData(red: avgRed, ir: avgIR, green: avgGreen, timestamp: Date())
                ppgHistory.append(ppgData)
                if ppgHistory.count > 1000 {
                    ppgHistory.removeFirst(ppgHistory.count - 1000)
                }
                sensorData.lastUpdate = Date()
                
                addLogMessage("📊 PPG History: \(ppgHistory.count) readings (R=\(avgRed), IR=\(avgIR), G=\(avgGreen))")
            }
            
            // Process ALL samples for heart rate/SpO2 calculation (they handle filtering internally)
            processPPGData(red: redSamples, ir: irSamples, green: greenSamples)
        }
    }
    
    nonisolated private func parseAccelerometerData(_ data: Data) {
        Task { @MainActor in
            addLogMessage("📊 Accel: Received \(data.count) bytes")
            
            guard data.count >= 154 else {
                addLogMessage("⚠️ Accel data too short: \(data.count) bytes (expected 154)")
                return
            }
            
            // Parse last sample (25th sample at offset 4 + 24*6)
            let lastSampleOffset = 4 + (24 * 6)
            
            guard lastSampleOffset + 6 <= data.count else {
                addLogMessage("⚠️ Accel offset out of range")
                return
            }
            
            let xBytes = data.subdata(in: lastSampleOffset..<(lastSampleOffset + 2))
            let yBytes = data.subdata(in: (lastSampleOffset + 2)..<(lastSampleOffset + 4))
            let zBytes = data.subdata(in: (lastSampleOffset + 4)..<(lastSampleOffset + 6))
            
            let x = xBytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let y = yBytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let z = zBytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            
            addLogMessage("📐 Accel: X=\(x), Y=\(y), Z=\(z)")
            
            let accelData = AccelerometerData(x: x, y: y, z: z, timestamp: Date())
            
            accelerometerHistory.append(accelData)
            if accelerometerHistory.count > 1000 {
                accelerometerHistory.removeFirst(accelerometerHistory.count - 1000)
            }
            sensorData.lastUpdate = Date()
            
            addLogMessage("📊 Accelerometer History: \(accelerometerHistory.count) readings")
            
            // Consolidate sensor data for historical view
            consolidateSensorData()
        }
    }
    
    nonisolated private func parseTemperatureData(_ data: Data) {
        Task { @MainActor in
            addLogMessage("📊 Temp: Received \(data.count) bytes")
            
            // DEBUG: Print raw bytes to understand the format
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            addLogMessage("🔍 Temp raw bytes: \(hexString)")
            
            // Firmware format (from documentation):
            // Bytes 0-3: frame counter (uint32_t)
            // Bytes 4-5: temperature as signed int16 in centidegrees Celsius (1/100°C)
            // Total: 8 bytes
            // Example: value 2137 = 21.37°C
            
            guard data.count >= 6 else {
                addLogMessage("⚠️ Temp data too short: \(data.count) bytes (expected 8)")
                return
            }
            
            var temperature: Double = 0.0
            
            if data.count == 8 {
                // Parse frame counter (first 4 bytes)
                let frameCounterBytes = data.subdata(in: 0..<4)
                let frameCounter = frameCounterBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
                
                // Parse temperature (bytes 4-5 as signed int16)
                let tempBytes = data.subdata(in: 4..<6)
                let tempRaw = Int16(littleEndian: tempBytes.withUnsafeBytes { $0.load(as: Int16.self) })
                
                // Convert from centidegrees to degrees Celsius
                temperature = Double(tempRaw) / 100.0
                
                addLogMessage("🔢 Frame counter: \(frameCounter)")
                addLogMessage("🔍 Raw temperature value: \(tempRaw) centidegrees")
                addLogMessage("🌡️ Temperature: \(String(format: "%.2f", temperature))°C")
                
            } else if data.count == 6 {
                // Alternative format without frame counter?
                // Bytes 0-3: Some value
                // Bytes 4-5: Temperature
                let tempBytes = data.subdata(in: 4..<6)
                let tempRaw = Int16(littleEndian: tempBytes.withUnsafeBytes { $0.load(as: Int16.self) })
                temperature = Double(tempRaw) / 100.0
                addLogMessage("🌡️ Temp (6-byte format): \(String(format: "%.2f", temperature))°C")
                
            } else if data.count == 2 {
                // Just temperature, no frame counter
                let tempRaw = Int16(littleEndian: data.withUnsafeBytes { $0.load(as: Int16.self) })
                temperature = Double(tempRaw) / 100.0
                addLogMessage("🌡️ Temp (2-byte format): \(String(format: "%.2f", temperature))°C")
                
            } else {
                addLogMessage("⚠️ Unexpected temperature data size: \(data.count) bytes")
                return
            }
            
            // Validate temperature is in reasonable range
            // BLE module temp can be higher than body temp (0°C to 60°C is reasonable)
            if temperature < -10.0 || temperature > 80.0 {
                addLogMessage("⚠️ Temperature \(String(format: "%.2f", temperature))°C is out of reasonable range")
                // Still add it to history but with 0 value
                temperature = 0.0
            }
            
            let tempData = TemperatureData(celsius: temperature, timestamp: Date())
            
            sensorData.temperature = temperature
            temperatureHistory.append(tempData)
            if temperatureHistory.count > 1000 {
                temperatureHistory.removeFirst(temperatureHistory.count - 1000)
            }
            sensorData.lastUpdate = Date()
            
            addLogMessage("🌡️ Temp: \(String(format: "%.1f", temperature))°C")
            addLogMessage("📊 Temperature History: \(temperatureHistory.count) readings")
            
            // Consolidate sensor data for historical view
            consolidateSensorData()
        }
    }
    
    nonisolated private func parseBatteryData(_ data: Data) {
        Task { @MainActor in
            addLogMessage("📊 Battery: Received \(data.count) bytes")
            
            // Firmware format (from documentation):
            // int32_t battery voltage in millivolts (mV)
            // 4 bytes total
            
            guard data.count >= 4 else {
                addLogMessage("⚠️ Battery data too short: \(data.count) bytes (expected 4)")
                return
            }
            
            // Parse as int32_t in millivolts
            let voltageBytes = data.subdata(in: 0..<4)
            let voltageMillivolts = Int32(littleEndian: voltageBytes.withUnsafeBytes { $0.load(as: Int32.self) })
            let voltageVolts = Double(voltageMillivolts) / 1000.0
            
            addLogMessage("🔋 Battery voltage: \(voltageMillivolts) mV (\(String(format: "%.2f", voltageVolts)) V)")
            
            // Convert voltage to percentage estimate
            // Typical Li-ion battery: 4.2V (100%) to 3.0V (0%)
            // Adjust these values based on your specific battery
            let maxVoltage: Double = 4200.0  // 4.2V in mV
            let minVoltage: Double = 3000.0  // 3.0V in mV
            
            let voltageRange = maxVoltage - minVoltage
            let currentVoltage = Double(voltageMillivolts)
            let percentage = ((currentVoltage - minVoltage) / voltageRange) * 100.0
            
            // Clamp to valid range
            let batteryLevel = max(0, min(100, Int(percentage)))
            
            addLogMessage("🔋 Battery level: \(batteryLevel)% (estimated from voltage)")
            
            let batteryData = BatteryData(percentage: batteryLevel, timestamp: Date())
            
            sensorData.batteryLevel = batteryLevel
            batteryHistory.append(batteryData)
            if batteryHistory.count > 1000 {
                batteryHistory.removeFirst(batteryHistory.count - 1000)
            }
            sensorData.lastUpdate = Date()
            
            addLogMessage("📊 Battery History: \(batteryHistory.count) readings")
            
            // Consolidate sensor data for historical view
            consolidateSensorData()
        }
    }
    
    nonisolated private func parseDeviceUUID(_ data: Data) {
        Task { @MainActor in
            addLogMessage("📊 UUID: Received \(data.count) bytes")
            
            guard data.count >= 8 else {
                addLogMessage("⚠️ UUID data too short: \(data.count) bytes (expected 8)")
                return
            }
            
            // Safe way to read UInt64 from Data
            let uuid = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> UInt64 in
                guard pointer.count >= 8 else { return 0 }
                return pointer.load(as: UInt64.self)
            }
            
            sensorData.deviceUUID = uuid
            
            addLogMessage("🆔 UUID: \(String(format: "%016llX", uuid))")
        }
    }
    
    nonisolated private func parseFirmwareVersion(_ data: Data) {
        Task { @MainActor in
            if let version = String(data: data, encoding: .utf8) {
                sensorData.firmwareVersion = version
                addLogMessage("📱 Firmware: \(version)")
            } else {
                addLogMessage("⚠️ Could not parse firmware version")
            }
        }
    }
}

// MARK: - Data Extension for Safe Loading
extension Data {
    /// Safely load a value from unaligned data
    func loadUnaligned<T>(fromByteOffset offset: Int = 0, as type: T.Type) -> T {
        var value: T!
        let size = MemoryLayout<T>.size
        withUnsafeBytes { buffer in
            let slice = buffer[offset..<(offset + size)]
            value = slice.withUnsafeBytes { $0.load(as: T.self) }
        }
        return value
    }
}

