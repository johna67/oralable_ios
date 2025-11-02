//
//  OralableBLE.swift
//  OralableApp
//
//  Updated: October 28, 2025
//  BLE Manager for Oralable device communication
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
    @Published var spo2History: [SpO2Data] = []  // NEW: SpO2 data history
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private var connectionTimeoutTimer: Timer?
    private var retryCount: Int = 0
    private var maxRetries: Int = 3
    
    // BLE Service and Characteristic UUIDs (update with actual Oralable UUIDs)
    private let serviceUUID = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB") // Battery Service
    private let dataCharacteristicUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB") // Battery Level
    
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
        
        // Scan for devices (update with actual Oralable service UUID)
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
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
    
    /// Connect to a specific device
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionStatus = "Connecting..."
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        // Set connection timeout
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            self.addLogMessage("⏰ Connection timeout - cancelling connection attempt")
            self.centralManager.cancelPeripheralConnection(peripheral)
            DispatchQueue.main.async {
                self.connectionStatus = "Connection timeout"
                self.connectedPeripheral = nil
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
    
    /// Toggle scanning state
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
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
        
        // Cancel any existing timers
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        // Disconnect from any connected device
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // Stop scanning
        if isScanning {
            stopScanning()
        }
        
        // Reset all state
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Reset"
            self.deviceName = "Unknown Device"
            self.discoveredDevices.removeAll()
            self.dataCharacteristic = nil
            self.sensorData.isConnected = false
        }
        
        addLogMessage("✅ BLE state reset complete")
    }
    
    /// Add a log message for diagnostics
    private func addLogMessage(_ message: String) {
        let timestampedMessage = "[\(DateFormatter.logFormatter.string(from: Date()))] \(message)"
        DispatchQueue.main.async {
            self.logMessages.append(timestampedMessage)
            // Keep only last 1000 log messages to prevent memory issues
            if self.logMessages.count > 1000 {
                self.logMessages.removeFirst()
            }
        }
        print(message)
    }
    
    // MARK: - Data Processing
    
    /// Process incoming sensor data and update histories
    private func processSensorData(_ data: Data) {
        // Parse raw BLE data into sensor readings
        // This is a placeholder - implement actual parsing based on Oralable protocol
        
        guard data.count >= 20 else { return } // Ensure minimum data length
        
        let timestamp = Date()
        
        // Example parsing (update with actual Oralable data format)
        let ppgRed = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }
        let ppgIR = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
        let ppgGreen = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) }
        
        let accelX = data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: Int16.self) }
        let accelY = data.withUnsafeBytes { $0.load(fromByteOffset: 14, as: Int16.self) }
        let accelZ = data.withUnsafeBytes { $0.load(fromByteOffset: 16, as: Int16.self) }
        
        let temperature = data.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt8.self) }
        let battery = data.withUnsafeBytes { $0.load(fromByteOffset: 19, as: UInt8.self) }
        
        // Create sensor data objects
        let ppgData = PPGData(red: ppgRed, ir: ppgIR, green: ppgGreen, timestamp: timestamp)
        let accelData = AccelerometerData(x: accelX, y: accelY, z: accelZ, timestamp: timestamp)
        let tempData = TemperatureData(celsius: Double(temperature) / 10.0, timestamp: timestamp) // Assuming 0.1°C resolution
        let batteryData = BatteryData(percentage: Int(battery), timestamp: timestamp)
        
        // Calculate heart rate from PPG data
        var heartRateData: HeartRateData?
        if let hr = calculateHeartRate(from: ppgData) {
            heartRateData = hr
            DispatchQueue.main.async {
                self.heartRateHistory.append(hr)
                if self.heartRateHistory.count > 1000 {
                    self.heartRateHistory.removeFirst()
                }
            }
        }
        
        // Calculate SpO2 from PPG data
        var spo2Data: SpO2Data?
        if let spo2 = calculateSpO2(from: ppgData) {
            spo2Data = spo2
            DispatchQueue.main.async {
                self.spo2History.append(spo2)
                if self.spo2History.count > 1000 {
                    self.spo2History.removeFirst()
                }
            }
        }
        
        // Create complete sensor data record
        let sensorData = SensorData(
            timestamp: timestamp,
            ppg: ppgData,
            accelerometer: accelData,
            temperature: tempData,
            battery: batteryData,
            heartRate: heartRateData,
            spo2: spo2Data
        )
        
        // Update UI on main thread
        DispatchQueue.main.async {
            // Update current sensor data
            self.sensorData.batteryLevel = Int(battery)
            self.sensorData.temperature = Double(temperature) / 10.0
            self.sensorData.heartRate = heartRateData?.bpm ?? 0.0
            self.sensorData.spo2 = spo2Data?.percentage ?? 0.0
            self.sensorData.isConnected = self.isConnected
            self.sensorData.lastUpdate = timestamp
            
            // Update individual histories
            self.ppgHistory.append(ppgData)
            self.accelerometerHistory.append(accelData)
            self.temperatureHistory.append(tempData)
            self.batteryHistory.append(batteryData)
            self.sensorDataHistory.append(sensorData)
            
            // Limit history size
            if self.ppgHistory.count > 1000 { self.ppgHistory.removeFirst() }
            if self.accelerometerHistory.count > 1000 { self.accelerometerHistory.removeFirst() }
            if self.temperatureHistory.count > 1000 { self.temperatureHistory.removeFirst() }
            if self.batteryHistory.count > 1000 { self.batteryHistory.removeFirst() }
            if self.sensorDataHistory.count > 1000 { self.sensorDataHistory.removeFirst() }
        }
    }
    
    /// Calculate heart rate from PPG data
    private func calculateHeartRate(from ppg: PPGData) -> HeartRateData? {
        // This is a placeholder - implement actual heart rate calculation
        // You would typically need a buffer of PPG samples and signal processing
        
        // For now, return a simulated heart rate
        let bpm = Double.random(in: 60...100)
        let quality = ppg.signalQuality
        
        guard quality > 0.6 else { return nil }
        
        return HeartRateData(bpm: bpm, quality: quality, timestamp: ppg.timestamp)
    }
    
    /// Calculate SpO2 from PPG data
    private func calculateSpO2(from ppg: PPGData) -> SpO2Data? {
        // This is a placeholder - implement actual SpO2 calculation
        // SpO2 calculation requires complex signal processing of red and IR PPG signals
        
        // For now, return a simulated SpO2 value
        let percentage = Double.random(in: 95...100)
        let quality = ppg.signalQuality
        
        guard quality > 0.6 else { return nil }
        
        return SpO2Data(percentage: percentage, quality: quality, timestamp: ppg.timestamp)
    }
    
    // MARK: - Historical Data Methods
    
    /// Get historical metrics for a specific time range
    /// - Parameter range: The time range to analyze
    /// - Returns: HistoricalMetrics containing aggregated data
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics {
        return HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range)
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
}

// MARK: - CBCentralManagerDelegate

extension OralableBLE: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            connectionStatus = "Unknown"
        case .resetting:
            connectionStatus = "Resetting"
        case .unsupported:
            connectionStatus = "BLE Unsupported"
        case .unauthorized:
            connectionStatus = "Unauthorized"
        case .poweredOff:
            connectionStatus = "Bluetooth Off"
        case .poweredOn:
            connectionStatus = "Ready"
            addLogMessage("✅ Bluetooth is powered on and ready")
        @unknown default:
            connectionStatus = "Unknown State"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Log all discovered devices for debugging
        addLogMessage("🔍 Discovered device: \(peripheral.name ?? "Unknown") - ID: \(peripheral.identifier)")
        
        // Filter for Oralable devices (update with actual device name pattern)
        // Temporarily allow all devices with names for debugging - you should update this filter
        guard let deviceName = peripheral.name, !deviceName.isEmpty else {
            // Also log devices without names
            addLogMessage("📱 Found device without name: \(peripheral.identifier)")
            return
        }
        
        // More flexible filtering - you can customize this based on your actual device name
        let isOralableDevice = deviceName.lowercased().contains("oralable") || 
                              deviceName.lowercased().contains("oral") ||
                              deviceName.lowercased().contains("esp32") ||  // Common for ESP32-based devices
                              deviceName.lowercased().contains("ble") ||    // Generic BLE devices
                              advertisementData[CBAdvertisementDataServiceUUIDsKey] != nil // Has service UUIDs
        
        if isOralableDevice {
            // Add to discovered devices if not already present
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredDevices.append(peripheral)
                }
                addLogMessage("📱 Added Oralable-compatible device: \(deviceName)")
            }
        } else {
            addLogMessage("⚠️ Device filtered out: \(deviceName)")
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
            
            // Generate a mock device UUID for demonstration (replace with actual implementation)
            self.sensorData.deviceUUID = UInt64(peripheral.identifier.hashValue)
            
            // Set default firmware version (this should be read from the device)
            self.sensorData.firmwareVersion = "1.0.0"
        }
        
        // Start discovering services
        // Try to discover all services first, then filter for the ones we need
        peripheral.discoverServices(nil) // Discover all services initially
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        retryCount += 1
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        
        if retryCount <= maxRetries {
            addLogMessage("❌ Connection failed (attempt \(retryCount)/\(maxRetries)): \(errorMessage)")
            addLogMessage("🔄 Retrying connection in 2 seconds...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.connect(to: peripheral)
            }
        } else {
            addLogMessage("❌ Connection failed after \(maxRetries) attempts: \(errorMessage)")
            
            DispatchQueue.main.async {
                self.connectionStatus = "Connection failed after \(self.maxRetries) attempts"
                self.connectedPeripheral = nil
                self.retryCount = 0  // Reset for next connection attempt
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Clear connection timeout if still active
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        addLogMessage("📱 Disconnected from: \(peripheral.name ?? "Unknown Device")")
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedDevice = nil
            self.connectedPeripheral = nil
            self.connectionStatus = "Disconnected"
            self.deviceName = "Unknown Device"
            
            // Reset sensor data connection status
            self.sensorData.isConnected = false
            
            // Clear data characteristic
            self.dataCharacteristic = nil
        }
        
        if let error = error {
            addLogMessage("❌ Disconnection error: \(error.localizedDescription)")
        }
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
            addLogMessage("⚠️ No services found on device")
            return 
        }
        
        addLogMessage("🔍 Found \(services.count) services on device")
        
        for service in services {
            addLogMessage("🔍 Discovered service: \(service.uuid)")
            
            // Try to discover all characteristics for each service
            peripheral.discoverCharacteristics(nil, for: service)
            
            // Also specifically look for our expected service
            if service.uuid == serviceUUID {
                addLogMessage("✅ Found expected service: \(service.uuid)")
                peripheral.discoverCharacteristics([dataCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { 
            addLogMessage("⚠️ No characteristics found for service \(service.uuid)")
            return 
        }
        
        addLogMessage("🔍 Found \(characteristics.count) characteristics for service \(service.uuid)")
        
        for characteristic in characteristics {
            addLogMessage("🔍 Discovered characteristic: \(characteristic.uuid) - Properties: \(characteristic.properties)")
            
            // Check if this is our expected data characteristic
            if characteristic.uuid == dataCharacteristicUUID {
                dataCharacteristic = characteristic
                addLogMessage("✅ Found expected data characteristic: \(characteristic.uuid)")
                
                // Subscribe to notifications if supported
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    addLogMessage("📡 Subscribing to notifications for \(characteristic.uuid)")
                }
                
                // Read current value if supported
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    addLogMessage("📖 Reading value from \(characteristic.uuid)")
                }
            } else {
                // For debugging, try to read from other characteristics too
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    addLogMessage("📖 Reading value from characteristic \(characteristic.uuid)")
                }
                
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    addLogMessage("📡 Subscribing to notifications for characteristic \(characteristic.uuid)")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == dataCharacteristicUUID {
            processSensorData(data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addLogMessage("❌ Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            addLogMessage("✅ Notifications enabled for \(characteristic.uuid)")
        } else {
            addLogMessage("⏹️ Notifications disabled for \(characteristic.uuid)")
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
