import Foundation
import CoreBluetooth
import Combine

// MARK: - Simple Log Level Enum
enum LogLevel: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

class OralableBLE: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var sensorData = SensorData()
    @Published var deviceName = "Not Connected"
    @Published var lastUpdate = Date()
    @Published var logMessages: [String] = []
    @Published var historicalData: [SensorData] = []
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var cancellables = Set<AnyCancellable>()
    
    private var reconnectTimer: Timer?
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 3
    private let maxHistoricalDataPoints = 1000
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        
        addLog("🚀 Oralable BLE Manager initialized")
        
        if #available(iOS 13.1, *) {
            checkBluetoothPermissions()
        }
    }
    
    // MARK: - Permissions Check
    @available(iOS 13.1, *)
    private func checkBluetoothPermissions() {
        switch CBManager.authorization {
        case .notDetermined:
            addLog("Bluetooth permission not determined", level: .warning)
        case .restricted:
            addLog("Bluetooth permission restricted ⛔️", level: .error)
        case .denied:
            addLog("Bluetooth permission denied - Please enable in Settings", level: .error)
        case .allowedAlways:
            addLog("Bluetooth permission granted ✅", level: .success)
        @unknown default:
            addLog("Unknown Bluetooth permission state", level: .warning)
        }
    }
    
    // MARK: - Logging
    func addLog(_ message: String, level: LogLevel = .info) {
        let timestamp = Date().formatted(date: .omitted, time: .shortened)
        let logEntry = "\(timestamp) [\(level.rawValue)] \(message)"
        
        DispatchQueue.main.async {
            self.logMessages.append(logEntry)
            if self.logMessages.count > 500 {
                self.logMessages.removeFirst()
            }
        }
    }
    
    // MARK: - Public Methods
    func toggleScanning() {
        isScanning ? stopScanning() : startScanning()
    }
    
    func disconnect() {
        reconnectTimer?.invalidate()
        connectionAttempts = maxConnectionAttempts
        
        if let peripheral = peripheral {
            addLog("Disconnecting from \(peripheral.name ?? "device")...", level: .warning)
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func setMeasurementSite(_ site: UInt8) {
        guard let peripheral = peripheral,
              let service = peripheral.services?.first(where: {
                  $0.uuid.uuidString.uppercased() == BLEConstants.TGM_SERVICE.uppercased()
              }),
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid.uuidString.uppercased() == BLEConstants.MUSCLE_SITE_CHAR.uppercased()
              }) else {
            addLog("Cannot set measurement site - not connected", level: .error)
            return
        }
        
        let data = Data([site])
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        addLog("Setting measurement site to \(MeasurementSite(rawValue: site)?.name ?? "unknown")", level: .info)
    }
    
    func clearLogs() {
        logMessages.removeAll()
        historicalData.removeAll()
        addLog("Logs cleared", level: .info)
    }
    
    // MARK: - Private Methods
    private func startScanning() {
        guard centralManager.state == .poweredOn else {
            addLog("Cannot scan - Bluetooth state: \(centralManager.state.rawValue)", level: .error)
            return
        }
        
        centralManager.stopScan()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.centralManager.scanForPeripherals(
                withServices: nil,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: false,
                    CBCentralManagerScanOptionSolicitedServiceUUIDsKey: []
                ]
            )
            self?.isScanning = true
            self?.addLog("Started scanning for BLE devices...", level: .info)
        }
    }
    
    private func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        addLog("Stopped scanning", level: .info)
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
        addLog("Found Oralable device! Connecting...", level: .success)
        centralManager.connect(peripheral, options: nil)
    }
    
    private func handleDisconnection() {
        isConnected = false
        deviceName = "Not Connected"
        self.peripheral = nil
        
        reconnectTimer?.invalidate()
        
        if connectionAttempts < maxConnectionAttempts {
            connectionAttempts += 1
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.addLog("Auto-reconnecting (attempt \(self?.connectionAttempts ?? 0))...", level: .info)
                self?.startScanning()
            }
        }
    }
    
    private func storeSensorData() {
        var dataCopy = sensorData
        dataCopy.timestamp = Date()
        historicalData.append(dataCopy)
        
        if historicalData.count > maxHistoricalDataPoints {
            historicalData.removeFirst()
        }
    }
    
    // MARK: - Data Parsing Methods
    private func parseCharacteristicData(characteristic: CBCharacteristic, data: Data) {
        switch characteristic.uuid.uuidString.uppercased() {
        case BLEConstants.PPG_CHAR.uppercased():
            parsePPGData(data)
            storeSensorData()
            
        case BLEConstants.ACC_CHAR.uppercased():
            parseAccelerometerData(data)
            
        case BLEConstants.TEMPERATURE_CHAR.uppercased():
            parseTemperatureData(data)
            
        case BLEConstants.BATTERY_CHAR.uppercased():
            parseBatteryData(data)
            
        case BLEConstants.UUID_CHAR.uppercased():
            parseUUIDData(data)
            
        case BLEConstants.FW_VERSION_CHAR.uppercased():
            parseFirmwareVersion(data)
            
        default:
            addLog("Unknown characteristic: \(characteristic.uuid.uuidString)", level: .warning)
        }
    }
    
    private func parsePPGData(_ data: Data) {
        guard data.count >= 4 else { return }
        
        sensorData.ppg.frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        
        let sampleSize = 12
        let headerSize = 4
        let availableSamples = (data.count - headerSize) / sampleSize
        let samplesToRead = min(availableSamples, BLEConstants.PPG_SAMPLES_PER_FRAME)
        
        sensorData.ppg.samples.removeAll()
        
        for i in 0..<samplesToRead {
            let offset = headerSize + (i * sampleSize)
            if offset + sampleSize <= data.count {
                var sample = PPGSample()
                sample.red = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
                sample.ir = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) }
                sample.green = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: UInt32.self) }
                sample.timestamp = Date()
                sensorData.ppg.samples.append(sample)
            }
        }
        
        addLog("PPG: IR=\(sensorData.ppg.ir), R=\(sensorData.ppg.red), G=\(sensorData.ppg.green)")
    }
    
    private func parseAccelerometerData(_ data: Data) {
        guard data.count >= 4 else { return }
        
        sensorData.accelerometer.frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        
        let sampleSize = 6
        let headerSize = 4
        let availableSamples = (data.count - headerSize) / sampleSize
        let samplesToRead = min(availableSamples, BLEConstants.ACC_SAMPLES_PER_FRAME)
        
        sensorData.accelerometer.samples.removeAll()
        
        for i in 0..<samplesToRead {
            let offset = headerSize + (i * sampleSize)
            if offset + sampleSize <= data.count {
                var sample = AccSample()
                sample.x = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int16.self) }
                sample.y = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 2, as: Int16.self) }
                sample.z = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Int16.self) }
                sample.timestamp = Date()
                sensorData.accelerometer.samples.append(sample)
            }
        }
        
        let mag = sensorData.accelerometer.magnitude
        addLog("Accel: X=\(sensorData.accelerometer.x), Y=\(sensorData.accelerometer.y), Z=\(sensorData.accelerometer.z), Mag=\(String(format: "%.2f", mag))")
    }
    
    private func parseTemperatureData(_ data: Data) {
        guard data.count >= 4 else { return }
        
        let tempRaw = data.withUnsafeBytes { $0.load(as: Float.self) }
        sensorData.temperature = Double(tempRaw)
        
        addLog("Temperature: \(String(format: "%.2f", sensorData.temperature))°C")
    }
    
    private func parseBatteryData(_ data: Data) {
        guard data.count >= 4 else { return }
        
        sensorData.batteryVoltage = data.withUnsafeBytes { $0.load(as: Int32.self) }
        
        addLog("Battery: \(sensorData.batteryVoltage) mV (\(sensorData.batteryLevel)%)")
    }
    
    private func parseUUIDData(_ data: Data) {
        guard data.count >= 8 else { return }
        
        sensorData.deviceUUID = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        
        addLog("Device UUID: \(String(format: "%016llX", sensorData.deviceUUID))")
    }
    
    private func parseFirmwareVersion(_ data: Data) {
        if let version = String(data: data, encoding: .utf8) {
            sensorData.firmwareVersion = version
            addLog("Firmware: \(version)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension OralableBLE: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            addLog("Bluetooth powered on", level: .success)
        case .poweredOff:
            addLog("Bluetooth powered off", level: .error)
        case .unauthorized:
            addLog("Bluetooth unauthorized", level: .error)
        case .unsupported:
            addLog("Bluetooth not supported", level: .error)
        default:
            addLog("Bluetooth state: \(central.state.rawValue)", level: .warning)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        
        if name.contains(BLEConstants.DEVICE_NAME) {
            addLog("Found \(name) (RSSI: \(RSSI))", level: .info)
            stopScanning()
            connectToPeripheral(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        isConnected = true
        deviceName = peripheral.name ?? "Oralable"
        connectionAttempts = 0
        
        addLog("Connected to \(deviceName) ✅", level: .success)
        
        peripheral.discoverServices([CBUUID(string: BLEConstants.TGM_SERVICE)])
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        if let error = error {
            addLog("Disconnected: \(error.localizedDescription)", level: .error)
        } else {
            addLog("Disconnected", level: .warning)
        }
        
        handleDisconnection()
    }
    
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        addLog("Failed to connect: \(error?.localizedDescription ?? "Unknown error")", level: .error)
        handleDisconnection()
    }
}

// MARK: - CBPeripheralDelegate
extension OralableBLE: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addLog("Service discovery error: \(error.localizedDescription)", level: .error)
            return
        }
        
        guard let services = peripheral.services else { return }
        addLog("Discovered \(services.count) services", level: .info)
        
        for service in services {
            if service.uuid.uuidString.uppercased() == BLEConstants.TGM_SERVICE.uppercased() {
                let characteristicUUIDs = [
                    CBUUID(string: BLEConstants.PPG_CHAR),
                    CBUUID(string: BLEConstants.ACC_CHAR),
                    CBUUID(string: BLEConstants.TEMPERATURE_CHAR),
                    CBUUID(string: BLEConstants.BATTERY_CHAR),
                    CBUUID(string: BLEConstants.UUID_CHAR),
                    CBUUID(string: BLEConstants.FW_VERSION_CHAR),
                    CBUUID(string: BLEConstants.MUSCLE_SITE_CHAR)
                ]
                
                peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
                addLog("Discovering characteristics...", level: .info)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        if let error = error {
            addLog("Characteristic discovery error: \(error.localizedDescription)", level: .error)
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        addLog("Found \(characteristics.count) characteristics", level: .info)
        
        var delay: TimeInterval = 0.1
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                delay += 0.1
            }
            
            if characteristic.properties.contains(.read) {
                let readableChars = [
                    BLEConstants.BATTERY_CHAR,
                    BLEConstants.UUID_CHAR,
                    BLEConstants.FW_VERSION_CHAR
                ]
                if readableChars.contains(where: { $0.uppercased() == characteristic.uuid.uuidString.uppercased() }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        peripheral.readValue(for: characteristic)
                    }
                    delay += 0.1
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            addLog("Value update error: \(error.localizedDescription)", level: .error)
            return
        }
        
        guard let data = characteristic.value, !data.isEmpty else {
            addLog("Received empty data", level: .warning)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.parseCharacteristicData(characteristic: characteristic, data: data)
            self?.lastUpdate = Date()
        }
    }
}

// MARK: - Historical Data Extension
extension OralableBLE {
    
    /// Get aggregated historical metrics for a specific time range
    /// - Parameters:
    ///   - range: The time range to aggregate (day, week, month, year)
    ///   - endDate: Optional end date (defaults to now)
    /// - Returns: HistoricalMetrics containing aggregated data
    func getHistoricalMetrics(for range: TimeRange, endDate: Date = Date()) -> HistoricalMetrics {
        return HistoricalDataAggregator.aggregate(
            data: historicalData,
            for: range,
            endDate: endDate
        )
    }
    
    /// Get metrics for all time ranges at once
    /// - Returns: Dictionary mapping each TimeRange to its HistoricalMetrics
    func getAllHistoricalMetrics() -> [TimeRange: HistoricalMetrics] {
        var metrics: [TimeRange: HistoricalMetrics] = [:]
        
        for range in TimeRange.allCases {
            metrics[range] = getHistoricalMetrics(for: range)
        }
        
        return metrics
    }
    
    /// Check if historical data is available for a specific time range
    /// - Parameter range: The time range to check
    /// - Returns: True if data exists for the range
    func hasDataForRange(_ range: TimeRange) -> Bool {
        guard !historicalData.isEmpty else { return false }
        
        let oldestData = historicalData.first?.timestamp ?? Date()
        let timeSinceOldest = Date().timeIntervalSince(oldestData)
        
        return timeSinceOldest >= range.seconds
    }
    
    /// Get a summary of available data
    /// - Returns: String describing data availability
    func getDataAvailabilitySummary() -> String {
        guard !historicalData.isEmpty else {
            return "No historical data available"
        }
        
        let oldestData = historicalData.first?.timestamp ?? Date()
        let newestData = historicalData.last?.timestamp ?? Date()
        let totalDuration = newestData.timeIntervalSince(oldestData)
        
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        var summary = "Data available: "
        
        if hours > 0 {
            summary += "\(hours)h "
        }
        if minutes > 0 || hours == 0 {
            summary += "\(minutes)m"
        }
        
        summary += " (\(historicalData.count) samples)"
        
        return summary
    }
    
    /// Get the date range of available data
    /// - Returns: Tuple with start and end dates, or nil if no data
    func getDataDateRange() -> (start: Date, end: Date)? {
        guard !historicalData.isEmpty else { return nil }
        
        let start = historicalData.first?.timestamp ?? Date()
        let end = historicalData.last?.timestamp ?? Date()
        
        return (start, end)
    }
    
    /// Export historical metrics as JSON
    /// - Parameter range: The time range to export
    /// - Returns: JSON data or nil if encoding fails
    func exportHistoricalMetrics(for range: TimeRange) -> Data? {
        let metrics = getHistoricalMetrics(for: range)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(metrics)
    }
    
    /// Clear historical data (useful for testing or resetting)
    func clearHistoricalData() {
        historicalData.removeAll()
        addLog("Historical data cleared", level: .info)
    }
    
    /// Get recent data points (last N samples)
    /// - Parameter count: Number of recent samples to retrieve
    /// - Returns: Array of most recent SensorData
    func getRecentData(count: Int = 100) -> [SensorData] {
        let startIndex = max(0, historicalData.count - count)
        return Array(historicalData[startIndex...])
    }
    
    /// Calculate current rate of data collection (samples per minute)
    /// - Returns: Samples per minute or 0 if insufficient data
    func getDataCollectionRate() -> Double {
        guard historicalData.count > 1 else { return 0 }
        
        let recentData = getRecentData(count: 10)
        guard recentData.count > 1 else { return 0 }
        
        let firstTimestamp = recentData.first?.timestamp ?? Date()
        let lastTimestamp = recentData.last?.timestamp ?? Date()
        let duration = lastTimestamp.timeIntervalSince(firstTimestamp)
        
        guard duration > 0 else { return 0 }
        
        let samplesPerSecond = Double(recentData.count) / duration
        return samplesPerSecond * 60.0 // Convert to per minute
    }
}
