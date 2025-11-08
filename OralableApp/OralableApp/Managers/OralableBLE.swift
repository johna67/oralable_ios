//
//  OralableBLE.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Compatibility wrapper around DeviceManager to maintain existing view interfaces
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
class OralableBLE: ObservableObject {
    static let shared = OralableBLE() 
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "No Device"
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var sensorDataHistory: [SensorData] = []
    @Published var deviceState: DeviceStateResult?
    @Published var logMessages: [LogMessage] = []
    @Published var ppgChannelOrder: PPGChannelOrder = .standard
    
    // MARK: - Published History Arrays (Legacy Format - Mutable for Import)
    
    @Published var batteryHistory: [BatteryData] = []
    @Published var heartRateHistory: [HeartRateData] = []
    @Published var spo2History: [SpO2Data] = []
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    @Published var ppgHistory: [PPGData] = []
    
    // MARK: - Computed Properties
    
    var sensorData: (batteryLevel: Int, firmwareVersion: String, deviceUUID: UInt64) {
        let battery = batteryHistory.last?.percentage ?? 0
        let uuid: UInt64 = UInt64(connectedDevice?.identifier.uuidString.hash.magnitude ?? 0)
        return (battery, "1.0.0", uuid)
    }
    
    var connectionStatus: String {
        if isConnected {
            return "Connected"
        } else if isScanning {
            return "Scanning..."
        } else {
            return "Disconnected"
        }
    }
    
    // MARK: - Private Properties
    
    private let deviceManager: DeviceManager
    private let stateDetector: DeviceStateDetector
    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryCount = 100
    
    // MARK: - Initialization
    
    init() {
        self.deviceManager = DeviceManager()
        self.stateDetector = DeviceStateDetector()
        setupBindings()
        addLog("OralableBLE initialized")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        deviceManager.$connectedDevices.map { !$0.isEmpty }.assign(to: &$isConnected)
        deviceManager.$isScanning.assign(to: &$isScanning)
        deviceManager.$primaryDevice.map { $0?.name ?? "No Device" }.assign(to: &$deviceName)
        
        deviceManager.$allSensorReadings
            .sink { [weak self] readings in
                self?.updateHistoriesFromReadings(readings)
                self?.updateLegacySensorData(with: readings)
            }
            .store(in: &cancellables)
        
        deviceManager.$latestReadings
            .sink { [weak self] latestReadings in
                self?.updateDeviceState(from: latestReadings)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - History Management from Sensor Readings
    
    private func updateHistoriesFromReadings(_ readings: [SensorReading]) {
        for reading in readings {
            switch reading.sensorType {
            case .battery:
                let batteryData = BatteryData(percentage: Int(reading.value), timestamp: reading.timestamp)
                batteryHistory.append(batteryData)
                if batteryHistory.count > maxHistoryCount {
                    batteryHistory.removeFirst(batteryHistory.count - maxHistoryCount)
                }
                
            case .heartRate:
                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                heartRateHistory.append(hrData)
                if heartRateHistory.count > maxHistoryCount {
                    heartRateHistory.removeFirst(heartRateHistory.count - maxHistoryCount)
                }
                
            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2History.append(spo2Data)
                if spo2History.count > maxHistoryCount {
                    spo2History.removeFirst(spo2History.count - maxHistoryCount)
                }
                
            case .temperature:
                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                temperatureHistory.append(tempData)
                if temperatureHistory.count > maxHistoryCount {
                    temperatureHistory.removeFirst(temperatureHistory.count - maxHistoryCount)
                }
                
            case .ppgRed, .ppgInfrared, .ppgGreen:
                // PPG data needs to be grouped - handled separately
                updatePPGHistory(from: readings)
                
            case .accelerometerX, .accelerometerY, .accelerometerZ:
                // Accel data needs to be grouped - handled separately
                updateAccelHistory(from: readings)
                
            default:
                break
            }
        }
    }
    
    private func updatePPGHistory(from readings: [SensorReading]) {
        var grouped: [Date: (red: Int32, ir: Int32, green: Int32)] = [:]
        
        for reading in readings where [.ppgRed, .ppgInfrared, .ppgGreen].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)
            
            switch reading.sensorType {
            case .ppgRed: current.red = Int32(reading.value)
            case .ppgInfrared: current.ir = Int32(reading.value)
            case .ppgGreen: current.green = Int32(reading.value)
            default: break
            }
            
            grouped[roundedTime] = current
        }
        
        for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
            let ppgData = PPGData(red: values.red, ir: values.ir, green: values.green, timestamp: timestamp)
            ppgHistory.append(ppgData)
        }
        
        if ppgHistory.count > maxHistoryCount {
            ppgHistory.removeFirst(ppgHistory.count - maxHistoryCount)
        }
    }
    
    private func updateAccelHistory(from readings: [SensorReading]) {
        var grouped: [Date: (x: Int16, y: Int16, z: Int16)] = [:]
        
        for reading in readings where [.accelerometerX, .accelerometerY, .accelerometerZ].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)
            
            switch reading.sensorType {
            case .accelerometerX: current.x = Int16(reading.value * 1000)
            case .accelerometerY: current.y = Int16(reading.value * 1000)
            case .accelerometerZ: current.z = Int16(reading.value * 1000)
            default: break
            }
            
            grouped[roundedTime] = current
        }
        
        for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
            let accelData = AccelerometerData(x: values.x, y: values.y, z: values.z, timestamp: timestamp)
            accelerometerHistory.append(accelData)
        }
        
        if accelerometerHistory.count > maxHistoryCount {
            accelerometerHistory.removeFirst(accelerometerHistory.count - maxHistoryCount)
        }
    }
    
    // MARK: - Legacy SensorData Conversion
    
    private func updateLegacySensorData(with readings: [SensorReading]) {
        var groupedReadings: [Date: [SensorReading]] = [:]
        
        for reading in readings {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            groupedReadings[roundedTime, default: []].append(reading)
        }
        
        for (timestamp, group) in groupedReadings {
            let sensorData = convertToSensorData(readings: group, timestamp: timestamp)
            sensorDataHistory.append(sensorData)
            
            if sensorDataHistory.count > 1000 {
                sensorDataHistory.removeFirst(sensorDataHistory.count - 1000)
            }
        }
    }
    
    private func convertToSensorData(readings: [SensorReading], timestamp: Date) -> SensorData {
        var ppgRed: Int32 = 0, ppgIR: Int32 = 0, ppgGreen: Int32 = 0
        var accelX: Int16 = 0, accelY: Int16 = 0, accelZ: Int16 = 0
        var temperature: Double = 36.0, battery: Int = 0
        var heartRate: Double? = nil, heartRateQuality: Double? = nil
        var spo2: Double? = nil, spo2Quality: Double? = nil
        
        for reading in readings {
            switch reading.sensorType {
            case .ppgRed: ppgRed = Int32(reading.value)
            case .ppgInfrared: ppgIR = Int32(reading.value)
            case .ppgGreen: ppgGreen = Int32(reading.value)
            case .accelerometerX: accelX = Int16(reading.value * 1000)
            case .accelerometerY: accelY = Int16(reading.value * 1000)
            case .accelerometerZ: accelZ = Int16(reading.value * 1000)
            case .temperature: temperature = reading.value
            case .battery: battery = Int(reading.value)
            case .heartRate: heartRate = reading.value; heartRateQuality = reading.quality ?? 0.8
            case .spo2: spo2 = reading.value; spo2Quality = reading.quality ?? 0.8
            default: break
            }
        }
        
        let ppgData = PPGData(red: ppgRed, ir: ppgIR, green: ppgGreen, timestamp: timestamp)
        let accelData = AccelerometerData(x: accelX, y: accelY, z: accelZ, timestamp: timestamp)
        let tempData = TemperatureData(celsius: temperature, timestamp: timestamp)
        let batteryData = BatteryData(percentage: battery, timestamp: timestamp)
        let heartRateData = heartRate.map { HeartRateData(bpm: $0, quality: heartRateQuality ?? 0.8, timestamp: timestamp) }
        let spo2Data = spo2.map { SpO2Data(percentage: $0, quality: spo2Quality ?? 0.8, timestamp: timestamp) }
        
        return SensorData(timestamp: timestamp, ppg: ppgData, accelerometer: accelData, temperature: tempData, battery: batteryData, heartRate: heartRateData, spo2: spo2Data)
    }
    
    // MARK: - Historical Metrics
    
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics? {
        guard !sensorDataHistory.isEmpty else { return nil }
        return HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range, endDate: Date())
    }
    
    // MARK: - Device State Detection
    
    private func updateDeviceState(from latestReadings: [SensorType: SensorReading]) {
        let ppgReading = latestReadings[.ppgInfrared]
        let accelX = latestReadings[.accelerometerX]
        let accelY = latestReadings[.accelerometerY]
        let accelZ = latestReadings[.accelerometerZ]
        let battery = latestReadings[.battery]
        
        if let ppg = ppgReading, let ax = accelX, let ay = accelY, let az = accelZ {
            let ppgValue = ppg.value
            let motion = sqrt(ax.value * ax.value + ay.value * ay.value + az.value * az.value)
            
            if motion > 2.0 {
                deviceState = DeviceStateResult(state: .inMotion, confidence: 0.9, timestamp: Date(), details: ["motion": motion])
            } else if ppgValue > 1000 {
                deviceState = DeviceStateResult(state: .onMuscle, confidence: 0.85, timestamp: Date(), details: ["ppg": ppgValue])
            } else if let bat = battery, bat.value > 95 {
                deviceState = DeviceStateResult(state: .onChargerIdle, confidence: 0.8, timestamp: Date(), details: ["battery": bat.value])
            } else {
                deviceState = DeviceStateResult(state: .offChargerIdle, confidence: 0.7, timestamp: Date(), details: [:])
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        addLog("Started scanning for devices")
        Task { await deviceManager.startScanning() }
    }
    
    func stopScanning() {
        addLog("Stopped scanning")
        deviceManager.stopScanning()
    }
    
    func toggleScanning() {
        if isScanning { stopScanning() } else { startScanning() }
    }
    
    func refreshScan() {
        stopScanning()
        // Small delay before restarting scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startScanning()
            
       
        }
        
        func startRecording() {
            // TODO: Implement recording session start
            print("Recording started")
        }

        func stopRecording() {
            // TODO: Implement recording session stop
            print("Recording stopped")
        }
    }
    
    func resetBLE() {
        // Full BLE reset for debugging
        stopScanning()
        if isConnected {
            disconnect()
        }
        discoveredDevices.removeAll()
        addLog("BLE system reset")
    }
    
    // Add this method
    func autoConnectToOralable() {
        if let oralable = discoveredDevices.first(where: {
            $0.name?.contains("Oralable") == true
        }) {
            print("🔷 Found Oralable, connecting...")
            stopScanning()  // Important: stop scanning first
            
            // Small delay then connect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connect(to: oralable)
            }
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        addLog("Connecting to \(peripheral.name ?? "Unknown")...")
        connectedDevice = peripheral
        
        Task {
            if let deviceInfo = deviceManager.discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                do {
                    try await deviceManager.connect(to: deviceInfo)
                    addLog("Connected to \(deviceInfo.name)")
                } catch {
                    addLog("Connection failed: \(error.localizedDescription)")
                }
            } else {
                addLog("Device not found in discovered devices")
            }
        }
    }
    
    func disconnect() {
        guard let primaryDevice = deviceManager.primaryDevice else { return }
        addLog("Disconnecting from \(primaryDevice.name)...")
        
        Task {
            await deviceManager.disconnect(from: primaryDevice)
            connectedDevice = nil
            addLog("Disconnected")
        }
    }
    
    func clearHistory() {
        batteryHistory.removeAll()
        heartRateHistory.removeAll()
        spo2History.removeAll()
        temperatureHistory.removeAll()
        accelerometerHistory.removeAll()
        ppgHistory.removeAll()
        sensorDataHistory.removeAll()
        addLog("Cleared all history data")
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = LogMessage(message: "[\(timestamp)] \(message)")
        logMessages.append(logMessage)
        if logMessages.count > 100 { logMessages.removeFirst(logMessages.count - 100) }
    }
    
    var manager: DeviceManager { return deviceManager }
}

extension OralableBLE {
    static func mock() -> OralableBLE {
        let ble = OralableBLE()
        for i in 0..<50 {
            let timestamp = Date().addingTimeInterval(TimeInterval(-i * 10))
            ble.batteryHistory.append(BatteryData(percentage: 85 + i % 15, timestamp: timestamp))
            ble.heartRateHistory.append(HeartRateData(bpm: Double(60 + i % 40), quality: 0.9, timestamp: timestamp))
            ble.spo2History.append(SpO2Data(percentage: Double(95 + i % 5), quality: 0.9, timestamp: timestamp))
            ble.temperatureHistory.append(TemperatureData(celsius: 36.0 + Double(i % 10) * 0.1, timestamp: timestamp))
        }
        ble.isConnected = true
        ble.deviceName = "Oralable-Mock"
        return ble
    }
}
