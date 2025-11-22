//
//  OralableBLE.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Refactored: November 19, 2025
//  Responsibility: Coordinate BLE operations and delegate to specialized managers
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
class OralableBLE: ObservableObject,
                   BLEManagerProtocol,
                   ConnectionStateProvider,
                   BiometricDataProvider,
                   DeviceStatusProvider,
                   RealtimeSensorProvider {
    // MARK: - Dependency Injection (Phase 4: Singleton Removed)
    // Note: Use AppDependencies.shared.bleManager instead

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
    let healthKitManager: HealthKitManager  // Public for backward compatibility
    private let recordingSessionManager: RecordingSessionManagerProtocol  // Injected dependency

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

    // NOTE: Publisher forwarders are defined in Managers/OralableBLE+Publishers.swift
    // Do not add them here to avoid duplicates

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryCount = 100

    // Async/await batching
    private var readingsTask: Task<Void, Never>?
    private let batchInterval: TimeInterval = 0.2  // 200 ms windows (reduced from 100ms for better performance)
    private var sampleCounter: Int = 0
    private let sampleRate: Int = 20  // process every 20th reading (reduced from 10 for better performance)

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

    /// Initialize with injected dependencies
    /// - Parameter recordingSessionManager: Recording session manager conforming to protocol
    init(recordingSessionManager: RecordingSessionManagerProtocol) {
        self.deviceManager = DeviceManager()
        self.stateDetector = DeviceStateDetector()
        self.healthKitManager = HealthKitManager()
        self.recordingSessionManager = recordingSessionManager

        // Initialize specialized components
        self.dataPublisher = BLEDataPublisher()
        self.sensorProcessor = SensorDataProcessor()
        self.bioMetricCalculator = BioMetricCalculator()
        self.healthKitIntegration = HealthKitIntegration(healthKitManager: healthKitManager)

        setupBindings()
        setupDiscoveryBinding()
        startAsyncBatchProcessing()
        dataPublisher.addLog("OralableBLE initialized")
    }

    deinit {
        readingsTask?.cancel()
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
        // IMPORTANT: ensure main-thread delivery for UI bound properties
        sensorProcessor.$batteryHistory
            .receive(on: DispatchQueue.main)
            .assign(to: \.batteryHistory, on: self)
            .store(in: &cancellables)

        sensorProcessor.$heartRateHistory
            .receive(on: DispatchQueue.main)
            .assign(to: \.heartRateHistory, on: self)
            .store(in: &cancellables)

        sensorProcessor.$spo2History
            .receive(on: DispatchQueue.main)
            .assign(to: \.spo2History, on: self)
            .store(in: &cancellables)

        sensorProcessor.$temperatureHistory
            .receive(on: DispatchQueue.main)
            .assign(to: \.temperatureHistory, on: self)
            .store(in: &cancellables)

        sensorProcessor.$accelerometerHistory
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelerometerHistory, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgHistory
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgHistory, on: self)
            .store(in: &cancellables)

        // Ensure sensorDataHistory arrives on main thread and log updates for debugging
        sensorProcessor.$sensorDataHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newHistory in
                guard let self = self else { return }
                self.sensorDataHistory = newHistory
                Logger.shared.debug("[OralableBLE] sensorDataHistory updated: \(newHistory.count) samples")
            }
            .store(in: &cancellables)

        sensorProcessor.$accelX
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelX, on: self)
            .store(in: &cancellables)

        sensorProcessor.$accelY
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelY, on: self)
            .store(in: &cancellables)

        sensorProcessor.$accelZ
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelZ, on: self)
            .store(in: &cancellables)

        sensorProcessor.$temperature
            .receive(on: DispatchQueue.main)
            .assign(to: \.temperature, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgRedValue
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(150), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgRedValue, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgIRValue
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(150), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgIRValue, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgGreenValue
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .removeDuplicates()
            .throttle(for: .milliseconds(150), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgGreenValue, on: self)
            .store(in: &cancellables)

        sensorProcessor.$batteryLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.batteryLevel, on: self)
            .store(in: &cancellables)
    }

    private func bindBioMetricCalculator() {
        bioMetricCalculator.$heartRate.assign(to: &$heartRate)
        bioMetricCalculator.$spO2.assign(to: &$spO2)
        bioMetricCalculator.$heartRateQuality.assign(to: &$heartRateQuality)
    }

    private func setupDiscoveryBinding() {
        deviceManager.$discoveredDevices
            .sink { [weak self] deviceInfos in
                guard let self = self else { return }
                var infos: [BLEDataPublisher.DiscoveredDeviceInfo] = []
                var peripherals: [CBPeripheral] = []

                for info in deviceInfos {
                    if let pid = info.peripheralIdentifier,
                       let peripheral = self.deviceManager.peripheral(for: pid) {
                        let d = BLEDataPublisher.DiscoveredDeviceInfo(
                            id: peripheral.identifier,
                            name: info.name,
                            peripheral: peripheral,
                            rssi: info.signalStrength ?? -50
                        )
                        infos.append(d)
                        peripherals.append(peripheral)
                    }
                }

                self.dataPublisher.discoveredDevicesInfo = infos
                self.dataPublisher.discoveredDevices = peripherals
            }
            .store(in: &cancellables)
    }

    // MARK: - Async/await Batching

    // Actor to accumulate readings safely off the main thread
    private actor BatchAccumulator {
        private var buffer: [SensorReading] = []

        func append(_ reading: SensorReading) {
            buffer.append(reading)
        }

        func append(contentsOf readings: [SensorReading]) {
            buffer.append(contentsOf: readings)
        }

        func flush() -> [SensorReading] {
            let batch = buffer
            buffer.removeAll(keepingCapacity: true)
            return batch
        }

        var isEmpty: Bool { buffer.isEmpty }
    }

    private func startAsyncBatchProcessing() {
        // Bridge DeviceManager.readingsBatchPublisher into AsyncStream<[SensorReading]>
        let stream = AsyncStream<[SensorReading]> { continuation in
            let cancellable = deviceManager.readingsBatchPublisher
                .sink { batch in
                    continuation.yield(batch)
                }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }

        // Create accumulator actor
        let accumulator = BatchAccumulator()

        // Spawn a Task to consume the batch stream and process batches periodically
        readingsTask = Task { [weak self] in
            guard let self = self else { return }

            var lastFlush = Date()

            for await readingsBatch in stream {
                // Sampling: only keep every Nth reading from the batch
                for reading in readingsBatch {
                    self.sampleCounter += 1
                    if self.sampleCounter >= self.sampleRate {
                        await accumulator.append(reading)
                        self.sampleCounter = 0
                    }
                }

                // Time-based flush every 200 ms
                let now = Date()
                if now.timeIntervalSince(lastFlush) >= self.batchInterval {
                    let batch = await accumulator.flush()
                    lastFlush = now

                    if !batch.isEmpty {
                        await self.processBatchAsync(batch)
                    }
                }

                // Cooperative cancellation
                if Task.isCancelled { break }
            }

            // Final flush on cancellation
            let remaining = await accumulator.flush()
            if !remaining.isEmpty {
                await self.processBatchAsync(remaining)
            }
        }
    }

    private func processBatchAsync(_ batch: [SensorReading]) async {
        // Process sensor data (MainActor mutations are inside processor methods)
        await sensorProcessor.processBatch(batch)

        // Update legacy sensor data
        await sensorProcessor.updateLegacySensorData(with: batch)

        // Calculate biometrics from PPG data
        await calculateBiometrics(from: batch)

        // Device state: use DeviceStateDetector exclusively
        let recentData = sensorProcessor.sensorDataHistory
        if let result = stateDetector.analyzeDeviceState(sensorData: recentData) {
            dataPublisher.updateDeviceState(result)
        }

        // Debug: report counts after processing to help trace pipeline
        let processorCount = await sensorProcessor.sensorDataHistory.count
        Logger.shared.debug("[OralableBLE] processBatchAsync completed — sensorProcessorHistory=\(processorCount), oralableHistory=\(sensorDataHistory.count)")
    }

    private func calculateBiometrics(from readings: [SensorReading]) async {
        // Check if we have PPG or EMG data (EMG treated as IR-equivalent at higher layers if needed)
        let hasPPGData = readings.contains { [.ppgRed, .ppgInfrared, .ppgGreen, .emg].contains($0.sensorType) }
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
                // Clear the buffer after calculation to prevent stale data accumulation
                self.sensorProcessor.clearPPGIRBuffer()
            }
        }

        // Calculate SpO2 from grouped PPG values
        // IMPORTANT: Use exact timestamps to preserve 20ms sample offsets from parseSensorData
        var grouped: [Date: (red: Int32, ir: Int32, green: Int32)] = [:]
        for reading in readings where [.ppgRed, .ppgInfrared, .ppgGreen].contains(reading.sensorType) {
            let timestamp = reading.timestamp  // Use exact timestamp, DO NOT ROUND
            var current = grouped[timestamp] ?? (0, 0, 0)

            switch reading.sensorType {
            case .ppgRed: current.red = Int32(reading.value)
            case .ppgInfrared: current.ir = Int32(reading.value)
            case .ppgGreen: current.green = Int32(reading.value)
            default: break
            }

            grouped[timestamp] = current
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
            let session = try recordingSessionManager.startSession(
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
            try recordingSessionManager.stopSession()
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
        // Reduced logging for performance
        guard !sensorDataHistory.isEmpty else {
            return nil
        }

        let metrics = HistoricalDataAggregator.aggregate(data: sensorDataHistory, for: range, endDate: Date())
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
        let mockRecorder = MockRecordingSessionManager()
        let ble = OralableBLE(recordingSessionManager: mockRecorder)
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

// MARK: - Mock Recording Session Manager

/// Mock implementation of RecordingSessionManagerProtocol for testing/previews
@MainActor
class MockRecordingSessionManager: RecordingSessionManagerProtocol, ObservableObject {
    @Published var currentSession: RecordingSession?
    @Published var sessions: [RecordingSession] = []

    var currentSessionPublisher: Published<RecordingSession?>.Publisher { $currentSession }
    var sessionsPublisher: Published<[RecordingSession]>.Publisher { $sessions }

    func startSession(deviceID: String?, deviceName: String?) throws -> RecordingSession {
        let session = RecordingSession(deviceID: deviceID, deviceName: deviceName)
        currentSession = session
        sessions.insert(session, at: 0)
        return session
    }

    func stopSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }
        session.endTime = Date()
        session.status = .completed
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = nil
    }

    func pauseSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }
        session.status = .paused
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    func resumeSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }
        session.status = .recording
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    func recordSensorData(_ data: String) {
        // Mock implementation - do nothing
    }

    func deleteSession(_ session: RecordingSession) {
        sessions.removeAll { $0.id == session.id }
    }
}
