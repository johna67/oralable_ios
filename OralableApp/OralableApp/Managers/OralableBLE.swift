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
    
    // MARK: - Discovered Device Info
    struct DiscoveredDeviceInfo: Identifiable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        var rssi: Int
    }
    
    
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "No Device"
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var discoveredDevicesInfo: [DiscoveredDeviceInfo] = []  // NEW: Detailed device info
    @Published var connectedDevice: CBPeripheral?
    @Published var sensorDataHistory: [SensorData] = []
    @Published var deviceState: DeviceStateResult?
    @Published var logMessages: [LogMessage] = []
    @Published var ppgChannelOrder: PPGChannelOrder = .standard
    
    // ADD THESE PROPERTIES
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 36.5
    @Published var ppgRedValue: Double = 0.0
    @Published var batteryLevel: Double = 85.0
    @Published var isRecording: Bool = false
    @Published var packetsReceived: Int = 0
    @Published var rssi: Int = -50
    @Published var connectionState: String = "disconnected"
    @Published var lastError: String? = nil
    @Published var deviceUUID: UUID? = nil
    @Published var discoveredServices: [String] = []
    
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

    // MARK: - Calculators and Buffers (Restored from a820411)
    private let heartRateCalculator = HeartRateCalculator()
    private let spo2Calculator = SpO2Calculator()

    // PPG data buffers for calculations
    private var ppgBufferRed: [Int32] = []
    private var ppgBufferIR: [Int32] = []
    private var ppgBufferGreen: [Int32] = []
    
    // MARK: - Initialization
    
    init() {
        self.deviceManager = DeviceManager.shared
        self.stateDetector = DeviceStateDetector()
        setupBindings()
        setupDirectBLECallbacks()  // NEW: Direct BLE callbacks for UI
        addLog("OralableBLE initialized")
    }
    
    // MARK: - Direct BLE Callbacks (for UI integration)
    
    private func setupDirectBLECallbacks() {
        // CRITICAL FIX: Set up our own discovery callback to track peripherals for UI
        guard let bleManager = deviceManager.bleManager else {
            print("[OralableBLE] Warning: BLE manager not available")
            return
        }
        
        // Store the original callback
        let originalCallback = bleManager.onDeviceDiscovered
        
        // Wrap the callback to also update our UI-friendly list
        bleManager.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            // Call the original callback first (for DeviceManager)
            originalCallback?(peripheral, name, rssi)
            
            // Update our UI-friendly discovered devices list
            Task { @MainActor [weak self] in
                self?.handleDeviceDiscovered(peripheral: peripheral, name: name, rssi: rssi)
            }
        }
        
        print("[OralableBLE] Direct BLE callbacks configured")
    }
    
    private func handleDeviceDiscovered(peripheral: CBPeripheral, name: String, rssi: Int) {
        // Check if we already have this device
        if let index = discoveredDevicesInfo.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update RSSI for existing device
            discoveredDevicesInfo[index].rssi = rssi
            print("[OralableBLE] Updated device: \(name) RSSI: \(rssi) dBm")
        } else {
            // Add new device
            let deviceInfo = DiscoveredDeviceInfo(
                id: peripheral.identifier,
                name: name,
                peripheral: peripheral,
                rssi: rssi
            )
            discoveredDevicesInfo.append(deviceInfo)
            print("[OralableBLE] Discovered new device: \(name) RSSI: \(rssi) dBm")
        }
        
        // Update legacy discoveredDevices array
        discoveredDevices = discoveredDevicesInfo.map { $0.peripheral }
        
        addLog("Found device: \(name) (\(rssi) dBm)")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        deviceManager.$connectedDevices.map { !$0.isEmpty }.assign(to: &$isConnected)
        deviceManager.$isScanning.assign(to: &$isScanning)
        deviceManager.$primaryDevice.map { $0?.name ?? "No Device" }.assign(to: &$deviceName)
        
        // CRITICAL FIX: Bind discovered devices with full info
     /*   deviceManager.$discoveredDevices
            .sink { [weak self] deviceInfos in
                guard let self = self else { return }
                
                // Update discoveredDevicesInfo with proper peripheral tracking
                self.discoveredDevicesInfo = deviceInfos.compactMap { deviceInfo in
                    guard let peripheralID = deviceInfo.peripheralIdentifier else { return nil }
                    
                    // Try to retrieve the peripheral from the central manager
                    // This is a workaround - ideally DeviceInfo should store the peripheral reference
                    if let existingInfo = self.discoveredDevicesInfo.first(where: { $0.id == deviceInfo.id }) {
                        // Update RSSI if we already have this device
                        var updated = existingInfo
                        updated.rssi = deviceInfo.signalStrength ?? existingInfo.rssi
                        return updated
                    }
                    
                    // For new devices, we need the peripheral reference
                    // This will be nil until we implement proper peripheral storage
                    // For now, log the discovery
                    print("[OralableBLE] Discovered device: \(deviceInfo.name) [\(deviceInfo.id)]")
                    return nil
                }
                
                // Also update the legacy discoveredDevices array
                self.discoveredDevices = self.discoveredDevicesInfo.map { $0.peripheral }
                
                if !deviceInfos.isEmpty {
                    print("[OralableBLE] Total discovered devices: \(deviceInfos.count)")
                }
            }
            .store(in: &cancellables) */
        
        // Throttle sensor reading updates to prevent UI thread saturation
        // Process at most 5 times per second instead of 100+ times per second
        deviceManager.$allSensorReadings
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] readings in
                self?.updateHistoriesFromReadings(readings)
                self?.updateLegacySensorData(with: readings)
            }
            .store(in: &cancellables)

        // Throttle device state updates to reduce processing load
        deviceManager.$latestReadings
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] latestReadings in
                self?.updateDeviceState(from: latestReadings)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - History Management from Sensor Readings

    private func updateHistoriesFromReadings(_ readings: [SensorReading]) {
        // Only log summary info, not every reading to reduce logging overhead
        var hrCount = 0, spo2Count = 0, batteryCount = 0, tempCount = 0

        for reading in readings {
            switch reading.sensorType {
            case .battery:
                // Update live battery value
                self.batteryLevel = reading.value

                let batteryData = BatteryData(percentage: Int(reading.value), timestamp: reading.timestamp)
                batteryHistory.append(batteryData)
                if batteryHistory.count > maxHistoryCount {
                    batteryHistory.removeFirst(batteryHistory.count - maxHistoryCount)
                }
                batteryCount += 1

            case .heartRate:
                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                heartRateHistory.append(hrData)
                if heartRateHistory.count > maxHistoryCount {
                    heartRateHistory.removeFirst(heartRateHistory.count - maxHistoryCount)
                }
                hrCount += 1

            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2History.append(spo2Data)
                if spo2History.count > maxHistoryCount {
                    spo2History.removeFirst(spo2History.count - maxHistoryCount)
                }
                spo2Count += 1

            case .temperature:
                // Update live temperature value
                self.temperature = reading.value

                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                temperatureHistory.append(tempData)
                if temperatureHistory.count > maxHistoryCount {
                    temperatureHistory.removeFirst(temperatureHistory.count - maxHistoryCount)
                }
                tempCount += 1

            case .ppgRed:
                // Update live PPG red value
                self.ppgRedValue = reading.value
                // PPG data needs to be grouped - handled separately
                updatePPGHistory(from: readings)

            case .ppgInfrared, .ppgGreen:
                // PPG data needs to be grouped - handled separately
                updatePPGHistory(from: readings)

            case .accelerometerX:
                // Update live accelerometer X value
                self.accelX = reading.value
                // Accel data needs to be grouped - handled separately
                updateAccelHistory(from: readings)

            case .accelerometerY:
                // Update live accelerometer Y value
                self.accelY = reading.value
                // Accel data needs to be grouped - handled separately
                updateAccelHistory(from: readings)

            case .accelerometerZ:
                // Update live accelerometer Z value
                self.accelZ = reading.value
                // Accel data needs to be grouped - handled separately
                updateAccelHistory(from: readings)

            default:
                break
            }
        }

        // Log batch summary instead of individual readings
        if hrCount > 0 || spo2Count > 0 || batteryCount > 0 || tempCount > 0 {
            Logger.shared.debug("[OralableBLE] Batch processed - HR: \(hrCount), SpO2: \(spo2Count), Battery: \(batteryCount), Temp: \(tempCount) | Total: \(readings.count) readings")
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

        // CRITICAL: Extract PPG samples and calculate HR/SpO2
        if !grouped.isEmpty {
            let sortedSamples = grouped.sorted(by: { $0.key < $1.key })
            let redSamples = sortedSamples.map { $0.value.red }
            let irSamples = sortedSamples.map { $0.value.ir }
            let greenSamples = sortedSamples.map { $0.value.green }

            // Process PPG data for heart rate and SpO2 calculation
            processPPGData(red: redSamples, ir: irSamples, green: greenSamples)
        }

        // Reduce logging frequency - only log if significant data processed
        if grouped.count >= 5 {
            Logger.shared.debug("[OralableBLE] PPG batch: \(grouped.count) samples | History: \(ppgHistory.count)")
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

        // Reduce logging frequency - only log if significant data processed
        if grouped.count >= 5 {
            Logger.shared.debug("[OralableBLE] Accel batch: \(grouped.count) samples | History: \(accelerometerHistory.count)")
        }
    }

    // MARK: - PPG Processing and Metric Calculation (Restored from a820411)

    /// Process PPG data and calculate heart rate and SpO2
    /// This accumulates PPG samples in buffers and runs calculations when enough data is available
    private func processPPGData(red: [Int32], ir: [Int32], green: [Int32]) {
        // Add new samples to buffers
        ppgBufferRed.append(contentsOf: red)
        ppgBufferIR.append(contentsOf: ir)
        ppgBufferGreen.append(contentsOf: green)

        // Limit buffer size to prevent memory growth
        let maxBufferSize = 300
        if ppgBufferRed.count > maxBufferSize {
            ppgBufferRed.removeFirst(ppgBufferRed.count - maxBufferSize)
            ppgBufferIR.removeFirst(ppgBufferIR.count - maxBufferSize)
            ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxBufferSize)
        }

        // Heart Rate Calculation (requires 20+ samples)
        if ppgBufferIR.count >= 20 {
            let irSamplesUInt32 = ppgBufferIR.map { UInt32(bitPattern: $0) }
            if let heartRateResult = heartRateCalculator.calculateHeartRate(irSamples: irSamplesUInt32) {
                let bpm = heartRateResult.bpm
                let quality = heartRateResult.quality

                Logger.shared.info("[OralableBLE] ❤️ Heart Rate Calculated: \(bpm) BPM (quality: \(String(format: "%.2f", quality)))")

                // Add to history for graphing
                let hrData = HeartRateData(bpm: bpm, quality: quality, timestamp: Date())
                heartRateHistory.append(hrData)
                if heartRateHistory.count > 1000 {
                    heartRateHistory.removeFirst(heartRateHistory.count - 1000)
                }
            } else {
                Logger.shared.debug("[OralableBLE] ⚠️ Heart Rate: Calculation failed (insufficient signal quality)")
            }
        }

        // SpO2 Calculation (requires 150+ samples for accuracy)
        if ppgBufferRed.count >= 150, ppgBufferIR.count >= 150 {
            if let result = spo2Calculator.calculateSpO2WithQuality(
                redSamples: ppgBufferRed,
                irSamples: ppgBufferIR
            ) {
                let spo2Value = result.spo2
                let quality = result.quality

                Logger.shared.info("[OralableBLE] 🫁 SpO2 Calculated: \(String(format: "%.1f", spo2Value))% (quality: \(String(format: "%.2f", quality)))")

                // Add to history for graphing
                let spo2Data = SpO2Data(percentage: spo2Value, quality: quality, timestamp: Date())
                spo2History.append(spo2Data)
                if spo2History.count > 1000 {
                    spo2History.removeFirst(spo2History.count - 1000)
                }

                Logger.shared.debug("[OralableBLE] 📊 SpO2 History: \(spo2History.count) readings")
            } else {
                Logger.shared.debug("[OralableBLE] ⚠️ SpO2: Calculation failed (poor signal quality)")
            }
        } else {
            // Only log occasionally to avoid spam
            if ppgBufferRed.count % 50 == 0 {
                Logger.shared.debug("[OralableBLE] ⏳ SpO2: Accumulating data (\(ppgBufferRed.count)/150 samples)")
            }
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
    }
    
    func startRecording() {
        guard !isRecording else {
            addLog("Recording already in progress")
            Logger.shared.warning("[OralableBLE] Recording already in progress, ignoring start request")
            return
        }

        do {
            let session = try RecordingSessionManager.shared.startSession(
                deviceID: deviceUUID?.uuidString,
                deviceName: deviceName
            )
            isRecording = true
            addLog("Recording session started: \(session.id)")
            Logger.shared.info("[OralableBLE] ✅ Started recording session | ID: \(session.id) | Device: \(deviceName)")
            print("📝 [OralableBLE] Started recording session: \(session.formattedDuration)")
        } catch {
            addLog("Failed to start recording: \(error.localizedDescription)")
            Logger.shared.error("[OralableBLE] ❌ Failed to start recording: \(error.localizedDescription)")
            print("❌ [OralableBLE] Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else {
            addLog("No recording in progress")
            Logger.shared.debug("[OralableBLE] No recording in progress, ignoring stop request")
            return
        }

        do {
            try RecordingSessionManager.shared.stopSession()
            isRecording = false
            addLog("Recording session stopped")
            Logger.shared.info("[OralableBLE] ✅ Stopped recording session | Duration: \(RecordingSessionManager.shared.currentSession?.formattedDuration ?? "unknown")")
            print("✅ [OralableBLE] Stopped recording session")
        } catch {
            addLog("Failed to stop recording: \(error.localizedDescription)")
            Logger.shared.error("[OralableBLE] ❌ Failed to stop recording: \(error.localizedDescription)")
            print("❌ [OralableBLE] Failed to stop recording: \(error)")
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
        Logger.shared.info("[OralableBLE] 🔌 Initiating connection to device: \(peripheral.name ?? "Unknown") | ID: \(peripheral.identifier)")
        connectedDevice = peripheral

        Task {
            if let deviceInfo = deviceManager.discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                do {
                    try await deviceManager.connect(to: deviceInfo)
                    addLog("Connected to \(deviceInfo.name)")
                    Logger.shared.info("[OralableBLE] ✅ Successfully connected to \(deviceInfo.name)")

                    // Automatically start recording when connected
                    await MainActor.run {
                        Logger.shared.info("[OralableBLE] 📝 Auto-starting recording session for device: \(deviceInfo.name)")
                        self.startRecording()
                    }
                } catch {
                    addLog("Connection failed: \(error.localizedDescription)")
                    Logger.shared.error("[OralableBLE] ❌ Connection failed: \(error.localizedDescription)")
                }
            } else {
                addLog("Device not found in discovered devices")
                Logger.shared.error("[OralableBLE] ❌ Device not found in discovered devices list")
            }
        }
    }

    func disconnect() {
        guard let primaryDevice = deviceManager.primaryDevice else {
            Logger.shared.warning("[OralableBLE] No primary device to disconnect from")
            return
        }
        addLog("Disconnecting from \(primaryDevice.name)...")
        Logger.shared.info("[OralableBLE] 🔌 Disconnecting from device: \(primaryDevice.name)")

        // Automatically stop recording when disconnecting
        if isRecording {
            Logger.shared.info("[OralableBLE] 📝 Auto-stopping recording session before disconnect")
            stopRecording()
        }

        Task {
            await deviceManager.disconnect(from: primaryDevice)
            connectedDevice = nil
            addLog("Disconnected")
            Logger.shared.info("[OralableBLE] ✅ Successfully disconnected")
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
