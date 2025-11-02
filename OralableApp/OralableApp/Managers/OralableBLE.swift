//
//  OralableBLE.swift
//  OralableApp
//
//  Updated: November 2, 2025
//  FIXES: Enhanced service discovery - finds ALL services
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

// MARK: - BLE Manager

/// Manages Bluetooth Low Energy communication with Oralable devices
class OralableBLE: NSObject, ObservableObject {
    
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
    @Published var logMessages: [String] = []
    
    // Sensor data history
    @Published var sensorDataHistory: [SensorData] = []
    @Published var batteryHistory: [BatteryData] = []
    @Published var ppgHistory: [PPGData] = []
    @Published var heartRateHistory: [HeartRateData] = []
    @Published var spo2History: [SpO2Data] = []
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    
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
        setupCentralManager()
    }
    
    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        
        // Scan for all devices but don't allow duplicates
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
        
        // Set connection timeout
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
    
    /// Add a log message with timestamp
    private func addLogMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logMessages.append(logEntry)
            
            // Keep only last 200 log messages
            if self.logMessages.count > 200 {
                self.logMessages.removeFirst(self.logMessages.count - 200)
            }
        }
        
        print(logEntry)
    }
    
    /// Process PPG data and calculate heart rate and SpO2
    private func processPPGData(red: [Int32], ir: [Int32], green: [Int32]) {
        ppgBufferRed.append(contentsOf: red)
        ppgBufferIR.append(contentsOf: ir)
        ppgBufferGreen.append(contentsOf: green)
        
        let maxBufferSize = 300
        if ppgBufferRed.count > maxBufferSize {
            ppgBufferRed.removeFirst(ppgBufferRed.count - maxBufferSize)
            ppgBufferIR.removeFirst(ppgBufferIR.count - maxBufferSize)
            ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxBufferSize)
        }
        
        // Calculate heart rate (needs minimum 20 samples)
        // Convert Int32 to UInt32 for the calculator
        if ppgBufferIR.count >= 20 {
            let irSamplesUInt32 = ppgBufferIR.map { UInt32(bitPattern: $0) }
            if let heartRate = heartRateCalculator.calculateHeartRate(irSamples: irSamplesUInt32) {
                DispatchQueue.main.async {
                    self.sensorData.heartRate = heartRate.bpm
                }
            }
        }
        
        // Calculate SpO2 (needs minimum 150 samples = 3 seconds)
        if ppgBufferRed.count >= 150, ppgBufferIR.count >= 150 {
            if let result = spo2Calculator.calculateSpO2WithQuality(
                redSamples: ppgBufferRed,
                irSamples: ppgBufferIR
            ) {
                DispatchQueue.main.async {
                    self.sensorData.spo2 = result.spo2
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
        
        // Skip if already discovered
        guard !discoveredDeviceUUIDs.contains(peripheral.identifier) else {
            return
        }
        
        let deviceName = peripheral.name ?? ""
        
        // Skip unnamed devices
        guard !deviceName.isEmpty else {
            return
        }
        
        // Check for Oralable device patterns
        let deviceNameLower = deviceName.lowercased()
        let namePatterns = ["oralable", "tgm", "nrf", "tooth", "dental", "bruxism"]
        let matchesName = namePatterns.contains { deviceNameLower.contains($0) }
        
        // Check for TGM service
        let advertisedUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasTGMService = advertisedUUIDs.contains(tgmServiceUUID)
        
        // Accept device if it matches
        if matchesName || hasTGMService {
            discoveredDeviceUUIDs.insert(peripheral.identifier)
            
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
            
            addLogMessage("✅ Found: \(deviceName) (RSSI: \(RSSI)dB)")
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
        
        // CRITICAL FIX: Discover ALL services, not just TGM service
        // This is needed because the device might not advertise the TGM service UUID
        addLogMessage("📊 Discovering ALL services on device...")
        peripheral.discoverServices(nil)  // nil = discover ALL services
    }
    
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
        } else {
            addLogMessage("❌ Max retries reached")
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
        
        // Log all discovered services
        for service in services {
            addLogMessage("   • \(service.uuid.uuidString)")
        }
        
        // Look for TGM service
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
            
            // Try to discover characteristics on all services
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
    
    // MARK: - Data Parsing
    
    private func parsePPGData(_ data: Data) {
        guard data.count >= 244 else {
            addLogMessage("⚠️ PPG data too short: \(data.count) bytes (expected 244)")
            return
        }
        
        var redSamples: [Int32] = []
        var irSamples: [Int32] = []
        var greenSamples: [Int32] = []
        
        for i in 0..<20 {
            let offset = 4 + (i * 12)
            let red = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            let ir = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) }
            let green = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt32.self) }
            
            redSamples.append(Int32(bitPattern: red))
            irSamples.append(Int32(bitPattern: ir))
            greenSamples.append(Int32(bitPattern: green))
        }
        
        addLogMessage("💓 PPG data received")
        processPPGData(red: redSamples, ir: irSamples, green: greenSamples)
        
        if let lastRed = redSamples.last, let lastIR = irSamples.last, let lastGreen = greenSamples.last {
            let ppgData = PPGData(red: lastRed, ir: lastIR, green: lastGreen, timestamp: Date())
            DispatchQueue.main.async {
                self.ppgHistory.append(ppgData)
                if self.ppgHistory.count > 1000 {
                    self.ppgHistory.removeFirst(self.ppgHistory.count - 1000)
                }
                self.sensorData.lastUpdate = Date()
            }
        }
    }
    
    private func parseAccelerometerData(_ data: Data) {
        guard data.count >= 154 else {
            addLogMessage("⚠️ Accel data too short: \(data.count) bytes (expected 154)")
            return
        }
        
        let lastSampleOffset = 4 + (24 * 6)
        let x = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset, as: Int16.self) }
        let y = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset + 2, as: Int16.self) }
        let z = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset + 4, as: Int16.self) }
        
        addLogMessage("📐 Accel: X=\(x), Y=\(y), Z=\(z)")
        
        let accelData = AccelerometerData(x: x, y: y, z: z, timestamp: Date())
        
        DispatchQueue.main.async {
            self.accelerometerHistory.append(accelData)
            if self.accelerometerHistory.count > 1000 {
                self.accelerometerHistory.removeFirst(self.accelerometerHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
        }
    }
    
    private func parseTemperatureData(_ data: Data) {
        guard data.count >= 6 else {
            addLogMessage("⚠️ Temp data too short: \(data.count) bytes (expected 6)")
            return
        }
        
        let integerPart = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int16.self) }
        let fractionalPart = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt32.self) }
        let temperature = Double(integerPart) + (Double(fractionalPart) / 1000000.0)
        
        let tempData = TemperatureData(celsius: temperature, timestamp: Date())
        
        DispatchQueue.main.async {
            self.sensorData.temperature = temperature
            self.temperatureHistory.append(tempData)
            if self.temperatureHistory.count > 1000 {
                self.temperatureHistory.removeFirst(self.temperatureHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
        }
        
        addLogMessage("🌡️ Temp: \(String(format: "%.1f", temperature))°C")
    }
    
    private func parseBatteryData(_ data: Data) {
        guard data.count >= 4 else {
            addLogMessage("⚠️ Battery data too short: \(data.count) bytes (expected 4)")
            return
        }
        
        let batteryLevel = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let batteryData = BatteryData(percentage: Int(batteryLevel), timestamp: Date())
        
        DispatchQueue.main.async {
            self.sensorData.batteryLevel = Int(batteryLevel)
            self.batteryHistory.append(batteryData)
            if self.batteryHistory.count > 1000 {
                self.batteryHistory.removeFirst(self.batteryHistory.count - 1000)
            }
            self.sensorData.lastUpdate = Date()
        }
        
        addLogMessage("🔋 Battery: \(batteryLevel)%")
    }
    
    private func parseDeviceUUID(_ data: Data) {
        guard data.count >= 8 else {
            addLogMessage("⚠️ UUID data too short: \(data.count) bytes (expected 8)")
            return
        }
        
        let uuid = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt64.self) }
        
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
        }
    }
}
