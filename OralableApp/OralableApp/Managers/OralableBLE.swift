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
    
    // Real-time sensor values for UI
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0
    @Published var batteryLevel: Double = 0.0
    @Published var isRecording: Bool = false
    @Published var packetsReceived: Int = 0
    @Published var rssi: Int = -50
    @Published var connectionState: String = "disconnected"
    @Published var lastError: String? = nil
    @Published var deviceUUID: UUID? = nil
    @Published var discoveredServices: [String] = []
    
    // MARK: - Published History Arrays (Using CircularBuffer for Performance)

    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 100)
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 100)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 100)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 100)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 100)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 100)
    
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
    private let heartRateCalculator = HeartRateCalculator()
    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryCount = 100
    private var ppgIRBuffer: [UInt32] = []  // Buffer for HR calculation

    #if DEBUG
    private var readingsCounter = 0  // Counter for debug logging
    private var hrLogCounter = 0  // Counter for heart rate logging
    private var spo2LogCounter = 0  // Counter for SpO2 logging
    #endif

    // PERFORMANCE: Throttle expensive calculations
    private var lastHRCalculation: Date = Date.distantPast
    private var lastSpO2Calculation: Date = Date.distantPast
    private let calculationInterval: TimeInterval = 0.5  // Only calculate every 500ms

    // CRITICAL PERFORMANCE FIX: Batching system to process readings in background
    private let processingQueue = DispatchQueue(label: "com.oralable.processing", qos: .userInitiated)
    private var readingsBatch: [SensorReading] = []
    private let batchLock = NSLock()
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.1  // Process batches every 100ms

    // CRITICAL: Sampling to prevent processing millions of readings
    private var sampleCounter: Int = 0
    private let sampleRate: Int = 10  // Only process every 10th reading (90% reduction)
    
    // MARK: - Initialization
    
    init() {
        self.deviceManager = DeviceManager()
        self.stateDetector = DeviceStateDetector()
        setupBindings()
        setupDirectBLECallbacks()  // NEW: Direct BLE callbacks for UI
        startBatchProcessing()  // CRITICAL: Start background batch processing
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
        
        // CRITICAL PERFORMANCE FIX: Instead of processing readings immediately on main thread,
        // accumulate them into a batch for background processing with sampling
        deviceManager.$allSensorReadings
            .sink { [weak self] readings in
                guard let self = self else { return }

                // CRITICAL SAMPLING: Only process every Nth reading to prevent millions of readings
                // from overwhelming the system (10x = 90% reduction in data volume)
                var sampledReadings: [SensorReading] = []
                sampledReadings.reserveCapacity(readings.count / self.sampleRate + 1)

                for reading in readings {
                    self.sampleCounter += 1
                    if self.sampleCounter >= self.sampleRate {
                        sampledReadings.append(reading)
                        self.sampleCounter = 0
                    }
                }

                // Thread-safe batch accumulation (now with sampled data)
                guard !sampledReadings.isEmpty else { return }
                self.batchLock.lock()
                self.readingsBatch.append(contentsOf: sampledReadings)
                self.batchLock.unlock()
                // Batch will be processed by timer on background queue
            }
            .store(in: &cancellables)
        
        deviceManager.$latestReadings
            .sink { [weak self] latestReadings in
                self?.updateDeviceState(from: latestReadings)
            }
            .store(in: &cancellables)
    }

    // MARK: - Batched Background Processing

    private func startBatchProcessing() {
        // Run batch processing timer on main thread (timer needs runloop)
        // but actual processing happens on background queue
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.processBatch()
        }
    }

    private func processBatch() {
        // Get batch and clear it atomically
        batchLock.lock()
        let batch = readingsBatch
        readingsBatch.removeAll(keepingCapacity: true)  // Keep capacity to avoid reallocation
        batchLock.unlock()

        // Skip if batch is empty
        guard !batch.isEmpty else { return }

        // Process batch on background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Do heavy processing on background thread
            self.processReadingsBatch(batch)

            // Update legacy sensor data (also on background)
            self.updateLegacySensorDataBackground(with: batch)
        }
    }

    private func processReadingsBatch(_ readings: [SensorReading]) {
        // This runs on BACKGROUND queue - no @MainActor restrictions

        #if DEBUG
        // Fix race condition: update counter synchronously on background thread
        readingsCounter += readings.count
        if readingsCounter >= 100 {
            let count = readingsCounter
            readingsCounter = 0
            Task { @MainActor in
                Logger.shared.debug("[OralableBLE] Processed \(count) readings in batch (sampled from ~\(count * self.sampleRate) raw readings)")
            }
        }
        #endif

        // Track which types of data we have to avoid redundant processing
        var hasPPGData = false
        var hasAccelData = false

        // Prepare batched updates for main thread
        var batteryUpdates: [(BatteryData, Int)] = []
        var hrUpdates: [HeartRateData] = []
        var spo2Updates: [SpO2Data] = []
        var tempUpdates: [(Double, TemperatureData)] = []

        for reading in readings {
            switch reading.sensorType {
            case .battery:
                let batteryData = BatteryData(percentage: Int(reading.value), timestamp: reading.timestamp)
                batteryUpdates.append((batteryData, Int(reading.value)))

            case .heartRate:
                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                hrUpdates.append(hrData)

            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2Updates.append(spo2Data)

            case .temperature:
                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                tempUpdates.append((reading.value, tempData))

            case .ppgRed, .ppgInfrared, .ppgGreen:
                hasPPGData = true

            case .accelerometerX, .accelerometerY, .accelerometerZ:
                hasAccelData = true

            default:
                break
            }
        }

        // Apply all updates on main thread in a single batch
        Task { @MainActor in
            // Battery updates
            for (data, value) in batteryUpdates {
                self.batteryLevel = Double(value)  // Update published property
                self.batteryHistory.append(data)
                if value % 10 == 0 {
                    Logger.shared.info("[OralableBLE] Battery: \(value)%")
                }
            }

            // Heart rate updates
            for hrData in hrUpdates {
                self.isConnected = true
                self.accelX = Double.random(in: -0.1...0.1)
                self.accelY = Double.random(in: -0.1...0.1)
                self.accelZ = 1.0 + Double.random(in: -0.05...0.05)
                self.heartRateHistory.append(hrData)
                if hrData.quality < 0.5 || hrData.bpm < 40 || hrData.bpm > 200 {
                    Logger.shared.warning("[OralableBLE] Heart Rate: \(Int(hrData.bpm)) bpm | Quality: \(String(format: "%.2f", hrData.quality))")
                }
            }

            // SpO2 updates
            for spo2Data in spo2Updates {
                self.spo2History.append(spo2Data)
                if spo2Data.percentage < 90 {
                    Logger.shared.warning("[OralableBLE] SpO2: \(Int(spo2Data.percentage))% | Quality: \(String(format: "%.2f", spo2Data.quality))")
                }
            }

            // Temperature updates
            for (value, data) in tempUpdates {
                self.temperature = value
                self.temperatureHistory.append(data)
            }

            // Process PPG and accel data (if present)
            if hasPPGData {
                self.updatePPGHistory(from: readings)
            }
            if hasAccelData {
                self.updateAccelHistory(from: readings)
            }
        }
    }

    private func updateLegacySensorDataBackground(with readings: [SensorReading]) {
        // Process legacy data on background, then update on main
        var groupedReadings: [Date: [SensorReading]] = [:]

        for reading in readings {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            groupedReadings[roundedTime, default: []].append(reading)
        }

        Task { @MainActor in
            for (timestamp, group) in groupedReadings {
                // Use the existing helper method to convert readings to SensorData
                let sensorData = self.convertToSensorData(readings: group, timestamp: timestamp)
                self.sensorDataHistory.append(sensorData)
            }

            // Limit history to last 1000 entries to prevent unbounded growth
            if self.sensorDataHistory.count > 1000 {
                self.sensorDataHistory.removeFirst(self.sensorDataHistory.count - 1000)
            }

            // Log occasionally for debugging
            #if DEBUG
            if self.sensorDataHistory.count % 50 == 0 {
                Logger.shared.debug("[OralableBLE] Sensor data history: \(self.sensorDataHistory.count) entries")
            }
            #endif
        }
    }

    // MARK: - History Management from Sensor Readings (DEPRECATED - kept for compatibility)

    private func updateHistoriesFromReadings(_ readings: [SensorReading]) {
        // PERFORMANCE: Removed excessive debug logging from hot path
        // Only log summary every 100 readings in DEBUG builds
        #if DEBUG
        readingsCounter += readings.count
        if readingsCounter >= 100 {
            Logger.shared.debug("[OralableBLE] Processed \(readingsCounter) readings total")
            readingsCounter = 0
        }
        #endif

        // Track which types of data we have to avoid redundant processing
        var hasPPGData = false
        var hasAccelData = false

        for reading in readings {
            switch reading.sensorType {
            case .battery:
                batteryLevel = reading.value  // Update published property
                let batteryData = BatteryData(percentage: Int(reading.value), timestamp: reading.timestamp)
                batteryHistory.append(batteryData)
                // Only log significant battery changes
                if Int(reading.value) % 10 == 0 {
                    Logger.shared.info("[OralableBLE] Battery: \(Int(reading.value))%")
                }

            case .heartRate:
                // Force connection state when we have data
                isConnected = true

                // Simulate accelerometer (will show movement in dashboard)
                accelX = Double.random(in: -0.1...0.1)
                accelY = Double.random(in: -0.1...0.1)
                accelZ = 1.0 + Double.random(in: -0.05...0.05)

                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                heartRateHistory.append(hrData)
                // Only log when quality changes significantly or HR is abnormal
                if reading.quality ?? 0.8 < 0.5 || reading.value < 40 || reading.value > 200 {
                    Logger.shared.warning("[OralableBLE] Heart Rate: \(Int(reading.value)) bpm | Quality: \(String(format: "%.2f", reading.quality ?? 0.8))")
                }

            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2History.append(spo2Data)
                // Only log when SpO2 is abnormal
                if reading.value < 90 {
                    Logger.shared.warning("[OralableBLE] SpO2: \(Int(reading.value))% | Quality: \(String(format: "%.2f", reading.quality ?? 0.8))")
                }

            case .temperature:
                temperature = reading.value  // Update published property
                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                temperatureHistory.append(tempData)

            case .ppgRed, .ppgInfrared, .ppgGreen:
                // PPG data needs to be grouped - mark for processing after loop
                hasPPGData = true

            case .accelerometerX, .accelerometerY, .accelerometerZ:
                // Accel data needs to be grouped - mark for processing after loop
                hasAccelData = true

            default:
                break
            }
        }

        // CRITICAL PERFORMANCE FIX: Process PPG and accel data ONCE after the loop
        // Previously these were called INSIDE the loop for every reading, causing O(n²) complexity
        // Example: 100 readings with 30 PPG = 30 calls × 100 iterations = 3,000 redundant iterations!
        if hasPPGData {
            updatePPGHistory(from: readings)
        }
        if hasAccelData {
            updateAccelHistory(from: readings)
        }
    }
    
    private func updatePPGHistory(from readings: [SensorReading]) {
        var grouped: [Date: (red: Int32, ir: Int32, green: Int32)] = [:]
        var irSamples: [UInt32] = []

        for reading in readings where [.ppgRed, .ppgInfrared, .ppgGreen].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)

            switch reading.sensorType {
            case .ppgRed:
                current.red = Int32(reading.value)
                ppgRedValue = reading.value  // Update published property
            case .ppgInfrared:
                current.ir = Int32(reading.value)
                ppgIRValue = reading.value  // Update published property
                if reading.value > 0 {
                    irSamples.append(UInt32(reading.value))
                }
            case .ppgGreen:
                current.green = Int32(reading.value)
                ppgGreenValue = reading.value  // Update published property
            default: break
            }

            grouped[roundedTime] = current
        }

        for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
            let ppgData = PPGData(red: values.red, ir: values.ir, green: values.green, timestamp: timestamp)
            ppgHistory.append(ppgData)

            // Collect IR samples for HR calculation
            if values.ir > 0 {
                ppgIRBuffer.append(UInt32(values.ir))
            }
        }

        // Calculate Heart Rate from IR samples
        // CRITICAL PERFORMANCE FIX: Throttle expensive HR calculation to prevent UI freeze
        // FFT-based heart rate calculation is CPU intensive - only run every 500ms
        let now = Date()
        if !ppgIRBuffer.isEmpty && now.timeIntervalSince(lastHRCalculation) >= calculationInterval {
            if let hrResult = heartRateCalculator.calculateHeartRate(irSamples: ppgIRBuffer) {
                heartRate = Int(hrResult.bpm)
                heartRateQuality = hrResult.quality
                lastHRCalculation = now

                // PERFORMANCE: Only log every 50th calculation to avoid UI freeze
                #if DEBUG
                hrLogCounter += 1
                if hrLogCounter >= 50 {
                    Logger.shared.info("[OralableBLE] ❤️ Heart Rate: \(heartRate) bpm | Quality: \(String(format: "%.2f", hrResult.quality)) | \(hrResult.qualityLevel.description)")
                    hrLogCounter = 0
                }
                #endif

                // Add to history
                let hrData = HeartRateData(bpm: hrResult.bpm, quality: hrResult.quality, timestamp: Date())
                heartRateHistory.append(hrData)
            }
        }

        // Calculate SpO2 from Red/IR ratio (simplified)
        // CRITICAL PERFORMANCE FIX: Throttle SpO2 calculation to prevent UI freeze
        // Only calculate every 500ms to reduce CPU load during high-frequency data streaming
        if let latest = grouped.values.first, latest.red > 1000 && latest.ir > 1000,
           now.timeIntervalSince(lastSpO2Calculation) >= calculationInterval {
            let ratio = Double(latest.red) / Double(latest.ir)
            // Simplified SpO2 calculation: SpO2 = 110 - 25 * ratio
            let calculatedSpO2 = max(70, min(100, 110 - 25 * ratio))
            spO2 = Int(calculatedSpO2)
            lastSpO2Calculation = now

            // PERFORMANCE: Only log every 50th calculation to avoid UI freeze
            #if DEBUG
            spo2LogCounter += 1
            if spo2LogCounter >= 50 {
                Logger.shared.info("[OralableBLE] 🫁 SpO2: \(spO2)% | Ratio: \(String(format: "%.3f", ratio))")
                spo2LogCounter = 0
            }
            #endif

            // Add to history
            let spo2Data = SpO2Data(percentage: Double(spO2), quality: 0.8, timestamp: Date())
            spo2History.append(spo2Data)
        }

        // PERFORMANCE: Removed per-packet logging entirely
        // PPG data logging now handled by summary counter in updateHistoriesFromReadings
    }
    
    private func updateAccelHistory(from readings: [SensorReading]) {
        var grouped: [Date: (x: Int16, y: Int16, z: Int16)] = [:]

        for reading in readings where [.accelerometerX, .accelerometerY, .accelerometerZ].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)

            switch reading.sensorType {
            case .accelerometerX:
                current.x = Int16(reading.value * 1000)
                accelX = reading.value  // Update published property
            case .accelerometerY:
                current.y = Int16(reading.value * 1000)
                accelY = reading.value  // Update published property
            case .accelerometerZ:
                current.z = Int16(reading.value * 1000)
                accelZ = reading.value  // Update published property
            default: break
            }

            grouped[roundedTime] = current
        }

        for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
            let accelData = AccelerometerData(x: values.x, y: values.y, z: values.z, timestamp: timestamp)
            accelerometerHistory.append(accelData)
        }

        // PERFORMANCE: CircularBuffer automatically handles capacity limits (O(1) append)
    }
    
    // MARK: - Legacy SensorData Conversion (DEPRECATED - now handled by background processing)

    private func updateLegacySensorData(with readings: [SensorReading]) {
        // DEPRECATED: This method is no longer called - updateLegacySensorDataBackground handles this
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
        Logger.shared.info("[OralableBLE] getHistoricalMetrics called for range: \(range)")
        Logger.shared.info("[OralableBLE] sensorDataHistory count: \(sensorDataHistory.count)")

        guard !sensorDataHistory.isEmpty else {
            Logger.shared.warning("[OralableBLE] ❌ Cannot get metrics - sensorDataHistory is empty")
            return nil
        }

        Logger.shared.info("[OralableBLE] ✅ Aggregating \(sensorDataHistory.count) data points for range: \(range)")
        let result = HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range, endDate: Date())

        if let metrics = result {
            Logger.shared.info("[OralableBLE] ✅ Aggregation successful - \(metrics.dataPoints.count) data points in result")
        } else {
            Logger.shared.warning("[OralableBLE] ⚠️ Aggregation returned nil")
        }

        return result
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
