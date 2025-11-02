//
//  OralableBLE.swift
//  OralableApp
//
//  Updated: November 2, 2025
//  BLE Manager for Oralable device communication
//  FIXES: Device filtering, correct service UUIDs, complete implementation
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
        connectionStatus = "Scanning..."
        
        // OPTION 1: Scan for specific TGM service (recommended)
        centralManager.scanForPeripherals(
            withServices: [tgmServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // OPTION 2: Scan for all devices and filter (use if OPTION 1 doesn't find device)
        // centralManager.scanForPeripherals(
        //     withServices: nil,
        //     options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        // )
        
        addLogMessage("🔍 Started scanning for Oralable devices...")
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionStatus = "Scan stopped"
        }
        addLogMessage("⏹️ Stopped scanning")
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
        
        // Set connection timeout
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.addLogMessage("⏰ Connection timeout - cancelling connection attempt")
            self?.centralManager.cancelPeripheralConnection(peripheral)
            DispatchQueue.main.async {
                self?.connectionStatus = "Connection timeout"
                self?.connectedPeripheral = nil
            }
        }
        
        centralManager.connect(peripheral, options: nil)
        addLogMessage("📱 Attempting to connect to: \(peripheral.name ?? "Unknown Device")")
    }
    
    /// Connect to first device with matching name (for debugging)
    func connectToDeviceWithName(_ name: String) {
        let matchingDevices = discoveredDevices.filter { device in
            device.name?.lowercased().contains(name.lowercased()) == true
        }
        
        if let device = matchingDevices.first {
            connect(to: device)
        } else {
            addLogMessage("❌ No device found with name containing: \(name)")
        }
    }
    
    /// Disconnect from current device
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        connectionStatus = "Disconnecting..."
        centralManager.cancelPeripheralConnection(peripheral)
        addLogMessage("📱 Disconnecting from device...")
    }
    
    /// Clear discovered devices and start fresh scan
    func refreshScan() {
        stopScanning()
        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
        }
        addLogMessage("🔄 Cleared device list")
        
        // Start scanning after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startScanning()
        }
    }
    
    /// Force reset all BLE connections and state
    func resetBLE() {
        addLogMessage("🔄 Resetting BLE state...")
        
        // Cancel any existing timer
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        // Disconnect if connected
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // Clear all state
        DispatchQueue.main.async {
            self.isConnected = false
            self.isScanning = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Disconnected"
            self.discoveredDevices.removeAll()
            
            // Reset sensor data
            self.sensorData = CurrentSensorData()
        }
        
        // Clear data buffers
        ppgBufferRed.removeAll()
        ppgBufferIR.removeAll()
        ppgBufferGreen.removeAll()
        
        addLogMessage("✅ BLE state reset complete")
        
        // Restart scanning if Bluetooth is powered on
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
        addLogMessage("🗑️ All logs and historical data cleared")
    }
    
    // MARK: - Private Helper Methods
    
    /// Add a log message with timestamp
    private func addLogMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logMessages.append(message)
            
            // Keep only last 500 log messages
            if self.logMessages.count > 500 {
                self.logMessages.removeFirst(self.logMessages.count - 500)
            }
        }
        
        print(logEntry)
    }
    
    /// Process PPG data and calculate heart rate and SpO2
    private func processPPGData(red: [Int32], ir: [Int32], green: [Int32]) {
        // Accumulate samples
        ppgBufferRed.append(contentsOf: red)
        ppgBufferIR.append(contentsOf: ir)
        ppgBufferGreen.append(contentsOf: green)
        
        // Keep only recent samples (max 300 = 6 seconds @ 50Hz)
        let maxBufferSize = 300
        if ppgBufferRed.count > maxBufferSize {
            ppgBufferRed.removeFirst(ppgBufferRed.count - maxBufferSize)
            ppgBufferIR.removeFirst(ppgBufferIR.count - maxBufferSize)
            ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxBufferSize)
        }
        
        // Calculate heart rate (needs minimum 20 samples)
        if ppgBufferIR.count >= 20 {
            if let heartRate = heartRateCalculator.calculateHeartRate(irSamples: ppgBufferIR) {
                DispatchQueue.main.async {
                    self.sensorData.heartRate = heartRate
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
                    // Could also store quality: result.quality
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
            case .unknown:
                self.connectionStatus = "Unknown"
                self.addLogMessage("⚠️ Bluetooth state: Unknown")
            case .resetting:
                self.connectionStatus = "Resetting"
                self.addLogMessage("⚠️ Bluetooth state: Resetting")
            case .unsupported:
                self.connectionStatus = "BLE Unsupported"
                self.addLogMessage("❌ Bluetooth Low Energy is not supported on this device")
            case .unauthorized:
                self.connectionStatus = "Unauthorized"
                self.addLogMessage("❌ App is not authorized to use Bluetooth")
            case .poweredOff:
                self.connectionStatus = "Bluetooth Off"
                self.addLogMessage("❌ Bluetooth is powered off")
            case .poweredOn:
                self.connectionStatus = "Ready"
                self.addLogMessage("✅ Bluetooth is powered on and ready")
            @unknown default:
                self.connectionStatus = "Unknown State"
                self.addLogMessage("⚠️ Bluetooth state: Unknown default")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        addLogMessage("🔍 Discovered device: \(peripheral.name ?? "Unknown") - ID: \(peripheral.identifier)")
        
        // FIXED: Restrictive device filtering
        guard let deviceName = peripheral.name, !deviceName.isEmpty else {
            addLogMessage("📱 Found device without name: \(peripheral.identifier)")
            return
        }
        
        // Only accept devices that:
        // 1. Have "Oralable" in the name, OR
        // 2. Advertise the TGM Service UUID
        let advertisedUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        
        let hasOralableName = deviceName.lowercased().contains("oralable")
        let hasTGMService = advertisedUUIDs.contains(tgmServiceUUID)
        
        let isOralableDevice = hasOralableName || hasTGMService
        
        if isOralableDevice {
            // Add to discovered devices if not already present
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredDevices.append(peripheral)
                }
                addLogMessage("✅ Added Oralable device: \(deviceName)")
            }
        } else {
            // Only log filtered devices if there are very few (reduce noise)
            // Uncomment for debugging:
            // addLogMessage("⚠️ Device filtered out: \(deviceName)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Clear connection timeout and reset retry counter
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        retryCount = 0
        
        addLogMessage("✅ Connected to: \(peripheral.name ?? "Unknown Device")")
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectedDevice = peripheral
            self.connectionStatus = "Connected"
            self.deviceName = peripheral.name ?? "Unknown Device"
            
            // Update sensor data connection status
            self.sensorData.isConnected = true
        }
        
        // Start discovering services
        peripheral.discoverServices([tgmServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        addLogMessage("❌ Failed to connect: \(errorMessage)")
        
        DispatchQueue.main.async {
            self.connectionStatus = "Connection failed"
            self.connectedPeripheral = nil
        }
        
        // Retry connection if under max retries
        if retryCount < maxRetries {
            retryCount += 1
            addLogMessage("🔄 Retry attempt \(retryCount)/\(maxRetries)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.connect(to: peripheral)
            }
        } else {
            addLogMessage("❌ Max retry attempts reached. Please try again manually.")
            retryCount = 0
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        if let error = error {
            addLogMessage("⚠️ Disconnected with error: \(error.localizedDescription)")
        } else {
            addLogMessage("📱 Disconnected from device")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Disconnected"
            
            // Update sensor data connection status
            self.sensorData.isConnected = false
        }
        
        // Clear data buffers
        ppgBufferRed.removeAll()
        ppgBufferIR.removeAll()
        ppgBufferGreen.removeAll()
    }
}

// MARK: - CBPeripheralDelegate

extension OralableBLE: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addLogMessage("❌ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            addLogMessage("⚠️ No services found")
            return
        }
        
        addLogMessage("📡 Found \(services.count) service(s)")
        
        // Discover characteristics for TGM service
        for service in services {
            if service.uuid == tgmServiceUUID {
                addLogMessage("✅ Found TGM Service")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            addLogMessage("⚠️ No characteristics found")
            return
        }
        
        addLogMessage("📊 Found \(characteristics.count) characteristic(s)")
        
        // Store characteristic references and enable notifications
        for characteristic in characteristics {
            switch characteristic.uuid {
            case ppgDataUUID:
                ppgCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                addLogMessage("✅ Enabled PPG Data notifications")
                
            case accelerometerUUID:
                accelerometerCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                addLogMessage("✅ Enabled Accelerometer notifications")
                
            case temperatureUUID:
                temperatureCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                addLogMessage("✅ Enabled Temperature notifications")
                
            case batteryUUID:
                batteryCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                // Also read initial value
                peripheral.readValue(for: characteristic)
                addLogMessage("✅ Enabled Battery notifications")
                
            case deviceUUIDChar:
                deviceUUIDCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                addLogMessage("📱 Reading Device UUID")
                
            case firmwareVersionUUID:
                firmwareVersionCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                addLogMessage("📱 Reading Firmware Version")
                
            default:
                addLogMessage("📊 Found characteristic: \(characteristic.uuid)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            addLogMessage("⚠️ No data received from characteristic: \(characteristic.uuid)")
            return
        }
        
        // Parse data based on characteristic UUID
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
            addLogMessage("📊 Received data from unknown characteristic: \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            addLogMessage("✅ Notifications enabled for: \(characteristic.uuid)")
        } else {
            addLogMessage("⚠️ Notifications disabled for: \(characteristic.uuid)")
        }
    }
    
    // MARK: - Data Parsing Methods
    
    private func parsePPGData(_ data: Data) {
        // PPG Data Frame: 244 bytes
        // Bytes 0-3: Frame counter (uint32_t)
        // Bytes 4+: 20 samples × 12 bytes each (red, ir, green as uint32_t)
        
        guard data.count >= 244 else {
            addLogMessage("⚠️ PPG data too short: \(data.count) bytes")
            return
        }
        
        var redSamples: [Int32] = []
        var irSamples: [Int32] = []
        var greenSamples: [Int32] = []
        
        // Parse 20 samples
        for i in 0..<20 {
            let offset = 4 + (i * 12)
            
            let red = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            let ir = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) }
            let green = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt32.self) }
            
            redSamples.append(Int32(red))
            irSamples.append(Int32(ir))
            greenSamples.append(Int32(green))
        }
        
        // Process PPG data for heart rate and SpO2
        processPPGData(red: redSamples, ir: irSamples, green: greenSamples)
        
        // Store last sample in history
        if let lastRed = redSamples.last, let lastIR = irSamples.last, let lastGreen = greenSamples.last {
            let ppgData = PPGData(
                red: lastRed,
                ir: lastIR,
                green: lastGreen,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                self.ppgHistory.append(ppgData)
                
                // Keep only last 1000 samples
                if self.ppgHistory.count > 1000 {
                    self.ppgHistory.removeFirst(self.ppgHistory.count - 1000)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.sensorData.lastUpdate = Date()
        }
    }
    
    private func parseAccelerometerData(_ data: Data) {
        // Accelerometer Data Frame: 154 bytes
        // Bytes 0-3: Frame counter (uint32_t)
        // Bytes 4+: 25 samples × 6 bytes each (x, y, z as int16_t)
        
        guard data.count >= 154 else {
            addLogMessage("⚠️ Accelerometer data too short: \(data.count) bytes")
            return
        }
        
        // Parse last sample for display
        let lastSampleOffset = 4 + (24 * 6)
        let x = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset, as: Int16.self) }
        let y = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset + 2, as: Int16.self) }
        let z = data.withUnsafeBytes { $0.load(fromByteOffset: lastSampleOffset + 4, as: Int16.self) }
        
        let accelData = AccelerometerData(
            x: x,
            y: y,
            z: z,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.accelerometerHistory.append(accelData)
            
            // Keep only last 1000 samples
            if self.accelerometerHistory.count > 1000 {
                self.accelerometerHistory.removeFirst(self.accelerometerHistory.count - 1000)
            }
            
            self.sensorData.lastUpdate = Date()
        }
    }
    
    private func parseTemperatureData(_ data: Data) {
        // Temperature Data: 6 bytes
        // Bytes 0-1: Integer part (int16_t)
        // Bytes 2-5: Fractional part (uint32_t)
        
        guard data.count >= 6 else {
            addLogMessage("⚠️ Temperature data too short: \(data.count) bytes")
            return
        }
        
        let integerPart = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int16.self) }
        let fractionalPart = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt32.self) }
        
        let temperature = Double(integerPart) + (Double(fractionalPart) / 1000000.0)
        
        let tempData = TemperatureData(
            celsius: temperature,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.sensorData.temperature = temperature
            self.temperatureHistory.append(tempData)
            
            // Keep only last 1000 samples
            if self.temperatureHistory.count > 1000 {
                self.temperatureHistory.removeFirst(self.temperatureHistory.count - 1000)
            }
            
            self.sensorData.lastUpdate = Date()
        }
        
        addLogMessage("🌡️ Temperature: \(String(format: "%.2f", temperature))°C")
    }
    
    private func parseBatteryData(_ data: Data) {
        // Battery Data: 4 bytes (uint32_t percentage)
        
        guard data.count >= 4 else {
            addLogMessage("⚠️ Battery data too short: \(data.count) bytes")
            return
        }
        
        let batteryLevel = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        
        let batteryData = BatteryData(
            percentage: Int(batteryLevel),
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.sensorData.batteryLevel = Int(batteryLevel)
            self.batteryHistory.append(batteryData)
            
            // Keep only last 1000 samples
            if self.batteryHistory.count > 1000 {
                self.batteryHistory.removeFirst(self.batteryHistory.count - 1000)
            }
            
            self.sensorData.lastUpdate = Date()
        }
        
        addLogMessage("🔋 Battery: \(batteryLevel)%")
    }
    
    private func parseDeviceUUID(_ data: Data) {
        // Device UUID: 16 bytes
        
        guard data.count >= 8 else {
            addLogMessage("⚠️ Device UUID data too short: \(data.count) bytes")
            return
        }
        
        let uuid = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt64.self) }
        
        DispatchQueue.main.async {
            self.sensorData.deviceUUID = uuid
        }
        
        addLogMessage("🆔 Device UUID: \(String(format: "%016llX", uuid))")
    }
    
    private func parseFirmwareVersion(_ data: Data) {
        // Firmware Version: String
        
        if let versionString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.sensorData.firmwareVersion = versionString
            }
            
            addLogMessage("📱 Firmware Version: \(versionString)")
        }
    }
}
