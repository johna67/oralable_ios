//
//  OralableBLE.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Refactored: November 19, 2025
//  Responsibility: Coordinate BLE operations and delegate to specialized managers
//  - Device connection coordination
//  - Characteristic notification setup
//  - Delegate pattern to specialized processors
//  - Integration with BLECentralManager
//  - Facade pattern for backward compatibility
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
class OralableBLE: ObservableObject {
    // MARK: - Type Aliases for Backward Compatibility

    typealias DiscoveredDeviceInfo = BLEDataPublisher.DiscoveredDeviceInfo

    // MARK: - Specialized Components

    private let dataPublisher: BLEDataPublisher
    private let sensorProcessor: SensorDataProcessor
    private let bioMetricCalculator: BioMetricCalculator
    private let healthKitIntegration: HealthKitIntegration

    // MARK: - Core Managers

    private let deviceManager: DeviceManager
    private let stateDetector: DeviceStateDetector
    private let healthKitManager: HealthKitManager

    // MARK: - Published Properties (Forwarded from Components)

    // Connection state (from BLEDataPublisher)
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "No Device"
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var discoveredDevicesInfo: [BLEDataPublisher.DiscoveredDeviceInfo] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var deviceState: DeviceStateResult?
    @Published var logMessages: [LogMessage] = []
    @Published var ppgChannelOrder: PPGChannelOrder = .standard
    @Published var connectionState: String = "disconnected"
    @Published var lastError: String? = nil
    @Published var deviceUUID: UUID? = nil
    @Published var discoveredServices: [String] = []
    @Published var isRecording: Bool = false
    @Published var packetsReceived: Int = 0
    @Published var rssi: Int = -50

    // Sensor data history (from SensorDataProcessor)
    @Published var sensorDataHistory: [SensorData] = []
    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 100)
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 100)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 100)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 100)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 100)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 100)

    // Real-time sensor values (from SensorDataProcessor)
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    @Published var batteryLevel: Double = 0.0

    // Biometric calculations (from BioMetricCalculator)
    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryCount = 100

    // CRITICAL PERFORMANCE: Batching system to process readings in background
    private let processingQueue = DispatchQueue(label: "com.oralable.processing", qos: .userInitiated)
    private var readingsBatch: [SensorReading] = []
    private let batchLock = NSLock()
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.1  // Process batches every 100ms

    // CRITICAL: Sampling to prevent processing millions of readings
    private var sampleCounter: Int = 0
    private let sampleRate: Int = 10  // Only process every 10th reading (90% reduction)

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

    var manager: DeviceManager { return deviceManager }

    // MARK: - Initialization

    init() {
        self.deviceManager = DeviceManager()
        self.stateDetector = DeviceStateDetector()
        self.healthKitManager = HealthKitManager()

        // Initialize specialized components
        self.dataPublisher = BLEDataPublisher()
        self.sensorProcessor = SensorDataProcessor()
        self.bioMetricCalculator = BioMetricCalculator()
        self.healthKitIntegration = HealthKitIntegration(healthKitManager: healthKitManager)

        setupBindings()
        setupDirectBLECallbacks()
        startBatchProcessing()
        dataPublisher.addLog("OralableBLE initialized")
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind DeviceManager state to local published properties
        deviceManager.$connectedDevices.map { !$0.isEmpty }.assign(to: &$isConnected)
        deviceManager.$isScanning.assign(to: &$isScanning)
        deviceManager.$primaryDevice.map { $0?.name ?? "No Device" }.assign(to: &$deviceName)

        // Bind component properties to local published properties
        bindDataPublisher()
        bindSensorProcessor()
        bindBioMetricCalculator()

        // CRITICAL PERFORMANCE: Batch and sample sensor readings
        deviceManager.$allSensorReadings
            .sink { [weak self] readings in
                guard let self = self else { return }

                // Sample readings to reduce data volume
                var sampledReadings: [SensorReading] = []
                sampledReadings.reserveCapacity(readings.count / self.sampleRate + 1)

                for reading in readings {
                    self.sampleCounter += 1
                    if self.sampleCounter >= self.sampleRate {
                        sampledReadings.append(reading)
                        self.sampleCounter = 0
                    }
                }

                // Add to batch for background processing
                guard !sampledReadings.isEmpty else { return }
                self.batchLock.lock()
                self.readingsBatch.append(contentsOf: sampledReadings)
                self.batchLock.unlock()
            }
            .store(in: &cancellables)

        // Update device state
        deviceManager.$latestReadings
            .sink { [weak self] latestReadings in
                self?.updateDeviceState(from: latestReadings)
            }
            .store(in: &cancellables)
    }

    private func bindDataPublisher() {
        dataPublisher.$isConnected.assign(to: &$isConnected)
        dataPublisher.$isScanning.assign(to: &$isScanning)
        dataPublisher.$deviceName.assign(to: &$deviceName)
        dataPublisher.$discoveredDevices.assign(to: &$discoveredDevices)
        dataPublisher.$discoveredDevicesInfo.assign(to: &$discoveredDevicesInfo)
        dataPublisher.$connectedDevice.assign(to: &$connectedDevice)
        dataPublisher.$deviceState.assign(to: &$deviceState)
        dataPublisher.$logMessages.assign(to: &$logMessages)
        dataPublisher.$connectionState.assign(to: &$connectionState)
        dataPublisher.$lastError.assign(to: &$lastError)
        dataPublisher.$deviceUUID.assign(to: &$deviceUUID)
        dataPublisher.$isRecording.assign(to: &$isRecording)
        dataPublisher.$rssi.assign(to: &$rssi)
    }

    private func bindSensorProcessor() {
        sensorProcessor.$batteryHistory.assign(to: &$batteryHistory)
        sensorProcessor.$heartRateHistory.assign(to: &$heartRateHistory)
        sensorProcessor.$spo2History.assign(to: &$spo2History)
        sensorProcessor.$temperatureHistory.assign(to: &$temperatureHistory)
        sensorProcessor.$accelerometerHistory.assign(to: &$accelerometerHistory)
        sensorProcessor.$ppgHistory.assign(to: &$ppgHistory)
        sensorProcessor.$sensorDataHistory.assign(to: &$sensorDataHistory)
        sensorProcessor.$accelX.assign(to: &$accelX)
        sensorProcessor.$accelY.assign(to: &$accelY)
        sensorProcessor.$accelZ.assign(to: &$accelZ)
        sensorProcessor.$temperature.assign(to: &$temperature)
        sensorProcessor.$ppgRedValue.assign(to: &$ppgRedValue)
        sensorProcessor.$ppgIRValue.assign(to: &$ppgIRValue)
        sensorProcessor.$ppgGreenValue.assign(to: &$ppgGreenValue)
        sensorProcessor.$batteryLevel.assign(to: &$batteryLevel)
    }

    private func bindBioMetricCalculator() {
        bioMetricCalculator.$heartRate.assign(to: &$heartRate)
        bioMetricCalculator.$spO2.assign(to: &$spO2)
        bioMetricCalculator.$heartRateQuality.assign(to: &$heartRateQuality)
    }

    // MARK: - Direct BLE Callbacks

    private func setupDirectBLECallbacks() {
        guard let bleManager = deviceManager.bleManager else {
            Logger.shared.warning("[OralableBLE] BLE manager not available")
            return
        }

        let originalCallback = bleManager.onDeviceDiscovered

        bleManager.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            originalCallback?(peripheral, name, rssi)

            Task { @MainActor [weak self] in
                self?.dataPublisher.handleDeviceDiscovered(peripheral: peripheral, name: name, rssi: rssi)
            }
        }

        Logger.shared.info("[OralableBLE] Direct BLE callbacks configured")
    }

    // MARK: - Batch Processing

    private func startBatchProcessing() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.processBatch()
        }
    }

    private func processBatch() {
        // Get batch and clear it atomically
        batchLock.lock()
        let batch = readingsBatch
        readingsBatch.removeAll(keepingCapacity: true)
        batchLock.unlock()

        guard !batch.isEmpty else { return }

        // Process batch on background queue
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            Task {
                // Process sensor data
                await self.sensorProcessor.processBatch(batch)

                // Update legacy sensor data
                await self.sensorProcessor.updateLegacySensorData(with: batch)

                // Calculate biometrics from PPG data
                await self.calculateBiometrics(from: batch)
            }
        }
    }

    private func calculateBiometrics(from readings: [SensorReading]) async {
        // Check if we have PPG data
        let hasPPGData = readings.contains { [.ppgRed, .ppgInfrared, .ppgGreen].contains($0.sensorType) }
        guard hasPPGData else { return }

        // Get PPG IR buffer for heart rate calculation
        await MainActor.run {
            let irBuffer = self.sensorProcessor.getPPGIRBuffer()

            // Calculate heart rate
            if !irBuffer.isEmpty {
                let _ = self.bioMetricCalculator.calculateHeartRate(
                    irSamples: irBuffer,
                    processor: self.sensorProcessor,
                    healthKitWriter: { [weak self] bpm in
                        self?.healthKitIntegration.writeHeartRate(bpm: bpm)
                    }
                )
            }
        }

        // Calculate SpO2 from grouped PPG values
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

        await MainActor.run {
            let _ = self.bioMetricCalculator.calculateSpO2FromGrouped(
                groupedValues: grouped,
                processor: self.sensorProcessor,
                healthKitWriter: { [weak self] percentage in
                    self?.healthKitIntegration.writeSpO2(percentage: percentage)
                }
            )
        }
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

    // MARK: - Public Methods - Scanning

    func startScanning() {
        dataPublisher.addLog("Started scanning for devices")
        Task { await deviceManager.startScanning() }
    }

    func stopScanning() {
        dataPublisher.addLog("Stopped scanning")
        deviceManager.stopScanning()
    }

    func toggleScanning() {
        if isScanning { stopScanning() } else { startScanning() }
    }

    func refreshScan() {
        stopScanning()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startScanning()
        }
    }

    // MARK: - Public Methods - Connection

    func connect(to peripheral: CBPeripheral) {
        dataPublisher.addLog("Connecting to \(peripheral.name ?? "Unknown")...")
        Logger.shared.info("[OralableBLE] 🔌 Initiating connection to device: \(peripheral.name ?? "Unknown") | ID: \(peripheral.identifier)")
        connectedDevice = peripheral

        Task {
            var deviceInfo = deviceManager.discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier })

            if deviceInfo == nil {
                Logger.shared.info("[OralableBLE] Device not in discovered list, creating temporary DeviceInfo")
                let deviceType = DeviceType.from(peripheral: peripheral) ?? .oralable

                deviceInfo = DeviceInfo(
                    type: deviceType,
                    name: peripheral.name ?? "Unknown Device",
                    peripheralIdentifier: peripheral.identifier,
                    signalStrength: 0
                )
            }

            guard let finalDeviceInfo = deviceInfo else {
                dataPublisher.addLog("Failed to create device info")
                Logger.shared.error("[OralableBLE] ❌ Failed to create DeviceInfo")
                return
            }

            do {
                try await deviceManager.connect(to: finalDeviceInfo)
                dataPublisher.addLog("Connected to \(finalDeviceInfo.name)")
                Logger.shared.info("[OralableBLE] ✅ Successfully connected to \(finalDeviceInfo.name)")

                await MainActor.run {
                    Logger.shared.info("[OralableBLE] 📝 Auto-starting recording session for device: \(finalDeviceInfo.name)")
                    self.startRecording()
                }
            } catch {
                dataPublisher.addLog("Connection failed: \(error.localizedDescription)")
                Logger.shared.error("[OralableBLE] ❌ Connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        guard let primaryDevice = deviceManager.primaryDevice else {
            Logger.shared.warning("[OralableBLE] No primary device to disconnect from")
            return
        }
        dataPublisher.addLog("Disconnecting from \(primaryDevice.name)...")
        Logger.shared.info("[OralableBLE] 🔌 Disconnecting from device: \(primaryDevice.name)")

        if isRecording {
            Logger.shared.info("[OralableBLE] 📝 Auto-stopping recording session before disconnect")
            stopRecording()
        }

        Task {
            await deviceManager.disconnect(from: primaryDevice)
            connectedDevice = nil
            dataPublisher.addLog("Disconnected")
            Logger.shared.info("[OralableBLE] ✅ Successfully disconnected")
        }
    }

    func autoConnectToOralable() {
        if let oralable = discoveredDevices.first(where: {
            $0.name?.contains("Oralable") == true
        }) {
            Logger.shared.info("[OralableBLE] Found Oralable, connecting...")
            stopScanning()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.connect(to: oralable)
            }
        }
    }

    // MARK: - Public Methods - Recording

    func startRecording() {
        guard !isRecording else {
            dataPublisher.addLog("Recording already in progress")
            Logger.shared.warning("[OralableBLE] Recording already in progress, ignoring start request")
            return
        }

        do {
            let session = try RecordingSessionManager.shared.startSession(
                deviceID: deviceUUID?.uuidString,
                deviceName: deviceName
            )
            dataPublisher.updateRecordingState(isRecording: true)
            dataPublisher.addLog("Recording session started: \(session.id)")
            Logger.shared.info("[OralableBLE] Started recording session | ID: \(session.id) | Device: \(deviceName)")
        } catch {
            dataPublisher.addLog("Failed to start recording: \(error.localizedDescription)")
            Logger.shared.error("[OralableBLE] Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else {
            dataPublisher.addLog("No recording in progress")
            Logger.shared.debug("[OralableBLE] No recording in progress, ignoring stop request")
            return
        }

        do {
            try RecordingSessionManager.shared.stopSession()
            dataPublisher.updateRecordingState(isRecording: false)
            dataPublisher.addLog("Recording session stopped")
            Logger.shared.info("[OralableBLE] Stopped recording session")
        } catch {
            dataPublisher.addLog("Failed to stop recording: \(error.localizedDescription)")
            Logger.shared.error("[OralableBLE] Failed to stop recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods - Data Management

    func clearHistory() {
        sensorProcessor.clearHistory()
        dataPublisher.addLog("Cleared all history data")
    }

    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics? {
        Logger.shared.info("[OralableBLE] getHistoricalMetrics called for range: \(range)")
        Logger.shared.info("[OralableBLE] sensorDataHistory count: \(sensorDataHistory.count)")

        guard !sensorDataHistory.isEmpty else {
            Logger.shared.warning("[OralableBLE] ❌ Cannot get metrics - sensorDataHistory is empty")
            return nil
        }

        Logger.shared.info("[OralableBLE] ✅ Aggregating \(sensorDataHistory.count) data points for range: \(range)")
        let metrics = HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range, endDate: Date())

        Logger.shared.info("[OralableBLE] ✅ Aggregation successful - \(metrics.dataPoints.count) data points in result")
        return metrics
    }

    // MARK: - Public Methods - System

    func resetBLE() {
        stopScanning()
        if isConnected {
            disconnect()
        }
        dataPublisher.clearDiscoveredDevices()
        dataPublisher.addLog("BLE system reset")
    }

    // MARK: - Mock

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
