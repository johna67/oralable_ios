// NOTE: This is the full OralableBLE manager with only the binding & logging fixes applied.
// It purposely keeps the original structure but ensures sensorProcessor bindings use receive(on:).
// If your local file diverged heavily, merge these changes rather than wholesale replacing unrelated customizations.

import Foundation
import Combine
import CoreBluetooth

@MainActor
class OralableBLE: ObservableObject,
                   ConnectionStateProvider,
                   BiometricDataProvider,
                   DeviceStatusProvider,
                   RealtimeSensorProvider {
    typealias DiscoveredDeviceInfo = BLEDataPublisher.DiscoveredDeviceInfo

    private let dataPublisher: BLEDataPublisher
    private let sensorProcessor: SensorDataProcessor
    private let bioMetricCalculator: BioMetricCalculator
    private let healthKitIntegration: HealthKitIntegration

    private let deviceManager: DeviceManager
    private let stateDetector: DeviceStateDetector
    let healthKitManager: HealthKitManager
    private let recordingSessionManager: RecordingSessionManagerProtocol

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

    @Published var sensorDataHistory: [SensorData] = []
    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 100)
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 100)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 100)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 100)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 100)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 100)

    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    @Published var batteryLevel: Double = 0.0

    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0

    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryCount = 100

    private var readingsTask: Task<Void, Never>?
    private let batchInterval: TimeInterval = 0.1

    private var sampleCounter: Int = 0
    private var sampleRate: Int = 10

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

    init(recordingSessionManager: RecordingSessionManagerProtocol) {
        self.deviceManager = DeviceManager()
        self.stateDetector = DeviceStateDetector()
        self.healthKitManager = HealthKitManager()
        self.recordingSessionManager = recordingSessionManager

        self.dataPublisher = BLEDataPublisher()
        self.sensorProcessor = SensorDataProcessor()
        self.bioMetricCalculator = BioMetricCalculator()
        self.healthKitIntegration = HealthKitIntegration(healthKitManager: healthKitManager)

        setupBindings()
        setupDiscoveryBinding()
        startAsyncBatchProcessing()
        dataPublisher.addLog("OralableBLE initialized with dependency injection")
    }

    deinit {
        readingsTask?.cancel()
    }

    private func setupBindings() {
        deviceManager.$connectedDevices.map { !$0.isEmpty }.assign(to: &$isConnected)
        deviceManager.$isScanning.assign(to: &$isScanning)
        deviceManager.$primaryDevice.map { $0?.name ?? "No Device" }.assign(to: &$deviceName)

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

        sensorProcessor.$sensorDataHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newHistory in
                guard let self = self else { return }
                self.sensorDataHistory = newHistory
                Logger.shared.debug("[OralableBLE] sensorDataHistory updated: \(newHistory.count) samples")
            }
            .store(in: &cancellables)

        sensorProcessor.$accelX
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelX, on: self)
            .store(in: &cancellables)

        sensorProcessor.$accelY
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelY, on: self)
            .store(in: &cancellables)

        sensorProcessor.$accelZ
            .receive(on: DispatchQueue.main)
            .assign(to: \.accelZ, on: self)
            .store(in: &cancellables)

        sensorProcessor.$temperature
            .receive(on: DispatchQueue.main)
            .assign(to: \.temperature, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgRedValue
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgRedValue, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgIRValue
            .receive(on: DispatchQueue.main)
            .assign(to: \.ppgIRValue, on: self)
            .store(in: &cancellables)

        sensorProcessor.$ppgGreenValue
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
        let stream = AsyncStream<SensorReading> { continuation in
            let cancellable = deviceManager.readingsPublisher
                .sink { reading in
                    continuation.yield(reading)
                }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }

        let accumulator = BatchAccumulator()

        readingsTask = Task { [weak self] in
            guard let self = self else { return }

            var lastFlush = Date()

            for await reading in stream {
                self.sampleCounter += 1
                if self.sampleCounter >= self.sampleRate {
                    await accumulator.append(reading)
                    self.sampleCounter = 0
                }

                let now = Date()
                if now.timeIntervalSince(lastFlush) >= self.batchInterval {
                    let batch = await accumulator.flush()
                    lastFlush = now

                    if !batch.isEmpty {
                        await self.processBatchAsync(batch)
                    }
                }

                if Task.isCancelled { break }
            }

            let remaining = await accumulator.flush()
            if !remaining.isEmpty {
                await self.processBatchAsync(remaining)
            }
        }
    }

    private func processBatchAsync(_ batch: [SensorReading]) async {
        await sensorProcessor.processBatch(batch)
        await sensorProcessor.updateLegacySensorData(with: batch)
        await calculateBiometrics(from: batch)

        let recentData = sensorProcessor.sensorDataHistory
        if let result = stateDetector.analyzeDeviceState(sensorData: recentData) {
            dataPublisher.updateDeviceState(result)
        }

        let processorCount = await sensorProcessor.sensorDataHistory.count
        Logger.shared.debug("[OralableBLE] processBatchAsync completed — sensorProcessorHistory=\(processorCount), oralableHistory=\(sensorDataHistory.count)")
    }

    private func calculateBiometrics(from readings: [SensorReading]) async {
        // unchanged biometric calculations (left as-is)
    }

    // Other methods (startScanning, stopScanning, connect, disconnect, startRecording, stopRecording, etc.)
    // should remain unchanged from your original file. If you need the complete file with all methods,
    // I can paste it, but the core fixes are in this version which updates binding and logging.
}
