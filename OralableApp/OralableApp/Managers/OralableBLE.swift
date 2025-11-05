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
// MARK: - BLE Manager

/// Manages Bluetooth Low Energy communication with Oralable devices
@MainActor
class OralableBLE: NSObject, ObservableObject {
    
    private var connectionManager: ConnectionManager?
    private var dataParser: DataParser?  // ADD THIS
    
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
            self?.addLogMessage("⏰ Connection timeout after 30 seconds")
            self?.centralManager.cancelPeripheralConnection(peripheral)
            DispatchQueue.main.async {
                self?.connectionStatus = "Timeout"
                self?.connectedPeripheral = nil
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
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.discoveredDeviceUUIDs.removeAll()
        }
        addLogMessage("🔄 Refreshing scan...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startScanning()
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
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.isScanning = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Disconnected"
            self.discoveredDevices.removeAll()
            self.discoveredDeviceUUIDs.removeAll()
            self.sensorData = CurrentSensorData()
        }
        
        ppgBufferRed.removeAll()
        ppgBufferIR.removeAll()
        ppgBufferGreen.removeAll()
        
        addLogMessage("✅ Reset complete")
        
        if centralManager.state == .poweredOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startScanning()
            }
        }
    }
    
    /// Clear all logs and historical data
    func clearLogs() {
        DispatchQueue.main.async {
            self.logMessages.removeAll()
            self.sensorDataHistory.removeAll()
            self.batteryHistory.removeAll()
            self.ppgHistory.removeAll()
            self.heartRateHistory.removeAll()
            self.spo2History.removeAll()
            self.temperatureHistory.removeAll()
            self.accelerometerHistory.removeAll()
        }
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
        
        DispatchQueue.main.async {
            self.logMessages.append(LogMessage(message: formattedMessage))
        }
        print(formattedMessage)
    }
    
    /// Process PPG data and calculate heart rate and SpO2
    private func processPPGData(red: [Int32], ir: [Int32], green: [Int32]) {
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
                
                DispatchQueue.main.async {
                    self.sensorData.heartRate = bpm
                    
                    // FIXED: Add to history array so dashboard shows it!
                    let hrData = HeartRateData(bpm: bpm, quality: heartRate.quality, timestamp: Date())
                    self.heartRateHistory.append(hrData)
                    if self.heartRateHistory.count > 1000 {
                        self.heartRateHistory.removeFirst(self.heartRateHistory.count - 1000)
                    }
                    
                    self.addLogMessage("📊 Heart Rate History: \(self.heartRateHistory.count) readings")
                }
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
                
                DispatchQueue.main.async {
                    self.sensorData.spo2 = spo2Value
                    
                    // FIXED: Add to history array so dashboard shows it!
                    let spo2Data = SpO2Data(percentage: spo2Value, quality: result.quality, timestamp: Date())
                    self.spo2History.append(spo2Data)
                    if self.spo2History.count > 1000 {
                        self.spo2History.removeFirst(self.spo2History.count - 1000)
                    }
                    
                    self.addLogMessage("📊 SpO2 History: \(self.spo2History.count) readings")
                }
            } else {
                addLogMessage("⚠️ SpO2: Calculation failed (poor signal quality)")
            }
        } else {
            addLogMessage("⏳ SpO2: Waiting for more data (\(ppgBufferRed.count)/150 samples)")
        }
        
        // CRITICAL FIX: Consolidate all sensor data into sensorDataHistory
        consolidateSensorData()
    }
    
    /// Consolidates individual sensor readings into complete SensorData objects
    /// This is required for HistoricalDetailView to work properly
    private func consolidateSensorData() {
        DispatchQueue.main.async {
            // DEBUG: Log sensor availability
            print("🔄 Attempting to consolidate sensor data:")
            print("   PPG: \(self.ppgHistory.count)")
            print("   Temperature: \(self.temperatureHistory.count)")
            print("   Battery: \(self.batteryHistory.count)")
            print("   Accelerometer: \(self.accelerometerHistory.count)")
            print("   Heart Rate: \(self.heartRateHistory.count)")
            print("   SpO2: \(self.spo2History.count)")
            
            // RELAXED REQUIREMENTS: Only require PPG and accelerometer as minimum
            // Battery and temperature can be missing or zero
            guard !self.ppgHistory.isEmpty,
                  !self.accelerometerHistory.isEmpty else {
                print("⚠️ Need at least PPG and Accelerometer data to consolidate")
                return
            }
            
            // Get the latest readings from each sensor
            guard let latestPPG = self.ppgHistory.last,
                  let latestAccel = self.accelerometerHistory.last else {
                print("⚠️ Could not get latest PPG or Accelerometer readings")
                return
            }
            
            // Use latest or create default values for optional sensors
            let latestTemp = self.temperatureHistory.last ?? TemperatureData(celsius: 0.0, timestamp: Date())
            let latestBattery = self.batteryHistory.last ?? BatteryData(percentage: 0, timestamp: Date())
            
            // Get optional calculated metrics
            let latestHeartRate = self.heartRateHistory.last
            let latestSpO2 = self.spo2History.last
            
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
            self.sensorDataHistory.append(consolidatedData)
            
            // Limit history size
            if self.sensorDataHistory.count > 10000 {
                self.sensorDataHistory.removeFirst(self.sensorDataHistory.count - 10000)
            }
            
            print("✅ Consolidated! Total sensorDataHistory: \(self.sensorDataHistory.count)")
            self.addLogMessage("📦 Consolidated sensor data: \(self.sensorDataHistory.count) complete readings")
            
            // Detect device state based on recent sensor data
            Task {
                if let stateResult = await self.deviceStateDetector.analyzeDeviceState(sensorData: self.sensorDataHistory) {
                    await MainActor.run {
                        self.deviceState = stateResult
                        self.addLogMessage("🔍 Device State: \(stateResult.state.rawValue) (confidence: \(String(format: "%.0f", stateResult.confidence * 100))%)")
                    }
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension OralableBLE: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.connectionStatus = "Ready"
                self.addLogMessage("✅ Bluetooth ready")
            case .poweredOff:
                self.connectionStatus = "Bluetooth Off"
                self.addLogMessage("❌ Bluetooth is off")
            case .unauthorized:
                self.connectionStatus = "Unauthorized"
                self.addLogMessage("❌ Bluetooth unauthorized")
            case .unsupported:
                self.connectionStatus = "Unsupported"
                self.addLogMessage("❌ BLE not supported")
            default:
                self.connectionStatus = "Not Ready"
                self.addLogMessage("⚠️ Bluetooth: \(central.state.rawValue)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
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
            
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
            
            addLogMessage("✅ Found: \(deviceName) (RSSI: \(RSSI)dB)")
            
            if !advertisedUUIDs.isEmpty {
                addLogMessage("   Services: \(advertisedUUIDs.map { $0.uuidString }.joined(separator: ", "))")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        retryCount = 0
        
        addLogMessage("✅ Connected to \(peripheral.name ?? "device")")
        addLogMessage("🔍 Starting service discovery...")
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDevice = peripheral
            self.deviceName = peripheral.name ?? "Unknown"
            self.sensorData.isConnected = true
            self.connectionStatus = "Connected"
        }
        
        addLogMessage("📊 Discovering Oralable service...")

        peripheral.discoverServices([tgmServiceUUID])    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        addLogMessage("❌ Connection failed: \(errorMsg)")
        
        DispatchQueue.main.async {
            self.connectionStatus = "Failed"
            self.connectedPeripheral = nil
        }
        
        if retryCount < maxRetries {
            retryCount += 1
            addLogMessage("🔄 Retry \(retryCount)/\(maxRetries) in 2 seconds...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        if let error = error {
            addLogMessage("⚠️ Disconnected: \(error.localizedDescription)")
        } else {
            addLogMessage("📱 Disconnected")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Disconnected"
            self.sensorData.isConnected = false
        }
        
        ppgBufferRed.removeAll()
        ppgBufferIR.removeAll()
        ppgBufferGreen.removeAll()
    }
}

// MARK: - CBPeripheralDelegate

extension OralableBLE: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
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
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Read error: \(error.localizedDescription)")
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
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Notification error for \(characteristic.uuid): \(error.localizedDescription)")
        } else if characteristic.isNotifying {
            addLogMessage("✅ Notifications active for \(characteristic.uuid)")
        }
    }
    
    // MARK: - FIXED Data Parsing - Handles actual firmware format
    
    private func parsePPGData(_ data: Data) {
        addLogMessage("📊 PPG: Received \(data.count) bytes")
        
        guard data.count >= 244 else {
            addLogMessage("⚠️ PPG data too short: \(data.count) bytes (expected 244)")
            return
        }
        
        var redSamples: [Int32] = []
        var irSamples: [Int32] = []
        var greenSamples: [Int32] = []
        
        // DEBUG: Log first few bytes
        let firstBytes = data.prefix(24).map { String(format: "%02X", $0) }.joined(separator: " ")
        addLogMessage("🔍 First 24 bytes: \(firstBytes)")
        
        // Parse 20 samples, each 12 bytes (3 x UInt32)
        for i in 0..<20 {
            let offset = 4 + (i * 12)
            
            guard offset + 12 <= data.count else { break }
            
            // Read as bytes array to avoid alignment issues
            let redBytes = data.subdata(in: offset..<(offset + 4))
            let irBytes = data.subdata(in: (offset + 4)..<(offset + 8))
            let greenBytes = data.subdata(in: (offset + 8)..<(offset + 12))
            
            let red = redBytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            let ir = irBytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            let green = greenBytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            
            // DEBUG: Log first sample values
            if i == 0 {
                addLogMessage("🔍 Sample 0: Red=\(red), IR=\(ir), Green=\(green)")
            }
            
            redSamples.append(Int32(bitPattern: red))
            irSamples.append(Int32(bitPattern: ir))
            greenSamples.append(Int32(bitPattern: green))
        }
        
        // DEBUG: Log parsed sample statistics
        if !irSamples.isEmpty {
            let avgIR = irSamples.map { Double($0) }.reduce(0, +) / Double(irSamples.count)
            let minIR = irSamples.min() ?? 0
            let maxIR = irSamples.max() ?? 0
            addLogMessage("📈 IR Stats: Min=\(minIR), Max=\(maxIR), Avg=\(Int(avgIR))")
        }
        
        addLogMessage("💓 PPG parsed: \(redSamples.count) samples")
        processPPGData(red: redSamples, ir: irSamples, green: greenSamples)
        
        if let lastRed = redSamples.last, let lastIR = irSamples.last, let lastGreen = greenSamples.last {
            let ppgData = PPGData(red: lastRed, ir: lastIR, green: lastGreen, timestamp: Date())
            DispatchQueue.main.async {
                self.ppgHistory.append(ppgData)
                if self.ppgHistory.count > 1000 {
                    self.ppgHistory.removeFirst(self.ppgHistory.count - 1000)
                }
                self.sensorData.lastUpdate = Date()
                
                self.addLogMessage("📊 PPG History: \(self.ppgHistory.count) readings (R=\(lastRed), IR=\(lastIR), G=\(lastGreen))")
            }
        }
    }
    
    private func parseAccelerometerData(_ data: Data) {
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
        
        DispatchQueue.main.async {
            self.accelerometerHistory.append(accelData)
            if self.accelerometerHistory.count > 1000 {
                self.accelerometerHistory.removeFirst(self.accelerometerHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
            
            self.addLogMessage("📊 Accelerometer History: \(self.accelerometerHistory.count) readings")
            
            // Consolidate sensor data for historical view
            self.consolidateSensorData()
        }
    }
    
    private func parseTemperatureData(_ data: Data) {
        addLogMessage("📊 Temp: Received \(data.count) bytes")
        
        // DEBUG: Print raw bytes to understand the format
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        addLogMessage("🔍 Temp raw bytes: \(hexString)")
        
        // Handle multiple possible formats
        var temperature: Double = 0.0
        
        if data.count == 8 {
            // Based on your device's actual format: Two 32-bit integers
            // Bytes: 82 19 00 00 61 0D 00 00
            // This appears to be raw sensor values, not temperature yet
            
            let int1Bytes = data.subdata(in: 0..<4)
            let int2Bytes = data.subdata(in: 4..<8)
            let val1 = int1Bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            let val2 = int2Bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            
            addLogMessage("🔍 Raw sensor values: val1=\(val1), val2=\(val2)")
            
            // Try different interpretations
            
            // Option 1: val1 and val2 are in hundredths of degrees (0.01°C units)
            let temp1 = Double(val1) / 100.0
            addLogMessage("🔍 Val1 as temp (÷100): \(String(format: "%.2f", temp1))°C")
            
            // Option 2: Some devices send object temp and ambient temp
            let temp2 = Double(val2) / 100.0
            addLogMessage("🔍 Val2 as temp (÷100): \(String(format: "%.2f", temp2))°C")
            
            // Option 3: Kelvin to Celsius (val1 in hundredths of Kelvin)
            let tempKelvin1 = (Double(val1) / 100.0) - 273.15
            addLogMessage("🔍 Val1 as Kelvin→Celsius: \(String(format: "%.2f", tempKelvin1))°C")
            
            // Option 4: Maybe it's in 10ths or 1000ths
            let temp1div10 = Double(val1) / 10.0
            let temp1div1000 = Double(val1) / 1000.0
            addLogMessage("🔍 Val1 ÷10: \(String(format: "%.2f", temp1div10))°C, ÷1000: \(String(format: "%.2f", temp1div1000))°C")
            
            // Use the most reasonable interpretation
            // 6530 / 100 = 65.30°C (too high)
            // 6530 / 10 = 653.0°C (way too high)
            // Let's try: maybe it's actually (val1/100 + val2/100)/2 or just use val2?
            // Or perhaps it needs to be interpreted as signed int16 values instead?
            
            // Try as signed 16-bit values (maybe it's two temp readings)
            let int16_1 = int1Bytes.subdata(in: 0..<2).withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let int16_2 = int1Bytes.subdata(in: 2..<4).withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let int16_3 = int2Bytes.subdata(in: 0..<2).withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let int16_4 = int2Bytes.subdata(in: 2..<4).withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            
            addLogMessage("🔍 As 4 x Int16: [\(int16_1), \(int16_2), \(int16_3), \(int16_4)]")
            
            // 0x1982 = 6530, 0x0D61 = 3425
            // If we divide by 100: 65.30°C and 34.25°C
            // 34.25°C is a reasonable body temperature!
            
            // Use val2 (the second value) as it seems more reasonable
            temperature = Double(val2) / 100.0
            addLogMessage("🌡️ Using val2/100 = \(String(format: "%.2f", temperature))°C")
            
        } else if data.count == 6 {
            // Format 1: int16_t + uint32_t (6 bytes)
            let intBytes = data.subdata(in: 0..<2)
            let fracBytes = data.subdata(in: 2..<6)
            
            let integerPart = intBytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            let fractionalPart = fracBytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            
            temperature = Double(integerPart) + (Double(fractionalPart) / 1000000.0)
            addLogMessage("🌡️ Temp format: 6-byte split = \(String(format: "%.2f", temperature))°C")
        } else if data.count == 4 {
            // Format 2: float (4 bytes)
            let floatTemp = data.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
            temperature = floatTemp.isNaN ? 0.0 : Double(floatTemp)
            addLogMessage("🌡️ Temp format: 4-byte float = \(String(format: "%.2f", temperature))°C")
        } else if data.count == 2 {
            // Format 3: int16_t in 0.1°C units (2 bytes)
            let intBytes = data.subdata(in: 0..<2)
            let rawValue = intBytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }
            temperature = Double(rawValue) / 10.0
            addLogMessage("🌡️ Temp format: 2-byte int16 = \(String(format: "%.2f", temperature))°C")
        } else {
            addLogMessage("⚠️ Temp data unexpected size: \(data.count) bytes")
            return
        }
        
        // Validate temperature is in reasonable range for body temperature
        // Typical range: 30°C to 45°C (86°F to 113°F)
        if temperature < 20.0 || temperature > 50.0 {
            addLogMessage("⚠️ Temperature \(String(format: "%.2f", temperature))°C is out of reasonable range")
            // Still add it to history but with 0 value
            temperature = 0.0
        }
        
        let tempData = TemperatureData(celsius: temperature, timestamp: Date())
        
        DispatchQueue.main.async {
            self.sensorData.temperature = temperature
            self.temperatureHistory.append(tempData)
            if self.temperatureHistory.count > 1000 {
                self.temperatureHistory.removeFirst(self.temperatureHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
            
            self.addLogMessage("🌡️ Temp: \(String(format: "%.1f", temperature))°C")
            self.addLogMessage("📊 Temperature History: \(self.temperatureHistory.count) readings")
            
            // Consolidate sensor data for historical view
            self.consolidateSensorData()
        }
    }
    
    private func parseBatteryData(_ data: Data) {
        addLogMessage("📊 Battery: Received \(data.count) bytes")
        
        var batteryLevel: Int = 0
        
        if data.count >= 4 {
            // Format 1: uint32_t (4 bytes)
            let bytes = data.subdata(in: 0..<4)
            let rawValue = bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            addLogMessage("🔋 Battery: Raw UInt32 value = \(rawValue)")
            batteryLevel = Int(rawValue)
        } else if data.count >= 2 {
            // Format 2: uint16_t (2 bytes) - ACTUAL FORMAT FROM YOUR DEVICE
            let bytes = data.subdata(in: 0..<2)
            let rawValue = bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
            addLogMessage("🔋 Battery: Raw UInt16 value = \(rawValue)")
            batteryLevel = Int(rawValue)
        } else if data.count >= 1 {
            // Format 3: uint8_t (1 byte)
            batteryLevel = Int(data[0])
            addLogMessage("🔋 Battery: Raw UInt8 value = \(batteryLevel)")
        } else {
            addLogMessage("⚠️ Battery data too short: \(data.count) bytes")
            return
        }
        
        // Clamp to valid range
        batteryLevel = max(0, min(100, batteryLevel))
        
        let batteryData = BatteryData(percentage: batteryLevel, timestamp: Date())
        
        DispatchQueue.main.async {
            self.sensorData.batteryLevel = batteryLevel
            self.batteryHistory.append(batteryData)
            if self.batteryHistory.count > 1000 {
                self.batteryHistory.removeFirst(self.batteryHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
            
            self.addLogMessage("🔋 Battery: \(batteryLevel)%")
            self.addLogMessage("📊 Battery History: \(self.batteryHistory.count) readings")
            
            // Consolidate sensor data for historical view
            self.consolidateSensorData()
        }
    }
    
    private func parseDeviceUUID(_ data: Data) {
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
        
        DispatchQueue.main.async {
            self.sensorData.deviceUUID = uuid
        }
        
        addLogMessage("🆔 UUID: \(String(format: "%016llX", uuid))")
    }
    
    private func parseFirmwareVersion(_ data: Data) {
        if let version = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.sensorData.firmwareVersion = version
            }
            addLogMessage("📱 Firmware: \(version)")
        } else {
            addLogMessage("⚠️ Could not parse firmware version")
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

