//
//  DeviceManagerAdapter.swift
//  OralableApp
//
//  Created: November 24, 2025
//  Purpose: Adapts DeviceManager to BLEManagerProtocol for compatibility with existing ViewModels
//

import Foundation
import Combine
import CoreBluetooth

/// Adapter that wraps DeviceManager and conforms to BLEManagerProtocol
/// This allows existing ViewModels (like DashboardViewModel) to work with DeviceManager
@MainActor
final class DeviceManagerAdapter: ObservableObject, BLEManagerProtocol {

    // MARK: - Dependencies

    private let deviceManager: DeviceManager
    private let sensorDataProcessor: SensorDataProcessor
    private let bioMetricCalculator = BioMetricCalculator()
    private var cancellables = Set<AnyCancellable>()
    private let deviceStateDetector = DeviceStateDetector()
    private var sensorDataBuffer: [SensorData] = []
    private let sensorDataBufferLimit = 20

    // MARK: - Published Properties (conforming to BLEManagerProtocol)

    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "Unknown Device"
    @Published var connectionState: String = "Disconnected"
    @Published var deviceUUID: UUID?
    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var batteryLevel: Double = 0.0
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    @Published var isRecording: Bool = false
    @Published var deviceState: DeviceStateResult?

    // MARK: - Initialization

    init(deviceManager: DeviceManager, sensorDataProcessor: SensorDataProcessor) {
        self.deviceManager = deviceManager
        self.sensorDataProcessor = sensorDataProcessor
        setupBindings()
        Logger.shared.info("[DeviceManagerAdapter] Initialized with DeviceManager and SensorDataProcessor")
    }

    // MARK: - Setup Bindings

    private func setupBindings() {
        // Bind connection state
        deviceManager.$connectedDevices
            .map { !$0.isEmpty }
            .assign(to: &$isConnected)

        deviceManager.$isScanning
            .assign(to: &$isScanning)

        // Bind primary device info
        deviceManager.$primaryDevice
            .map { $0?.name ?? "Unknown Device" }
            .assign(to: &$deviceName)

        deviceManager.$primaryDevice
            .map { $0?.peripheralIdentifier }
            .assign(to: &$deviceUUID)

        // Bind connection state string
        deviceManager.$connectedDevices
            .map { $0.isEmpty ? "Disconnected" : "Connected" }
            .assign(to: &$connectionState)

        // Bind latest sensor readings to individual properties (real-time display)
        deviceManager.$latestReadings
            .sink { [weak self] readings in
                self?.updateSensorValues(from: readings)
            }
            .store(in: &cancellables)

        // Subscribe to BATCH publisher for history storage
        // Throttle to 1 update per second to prevent flooding from multiple subscribers
        deviceManager.readingsBatchPublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] readings in
                guard let self = self else { return }
                if !readings.isEmpty {
                    Task {
                        await self.sensorDataProcessor.processBatch(readings)
                        await self.sensorDataProcessor.updateAccelHistory(from: readings)
                    }
                    self.updateDeviceState(from: readings)
                }
            }
            .store(in: &cancellables)

        // Update legacy sensor data less frequently (every 3 seconds)
        deviceManager.readingsBatchPublisher
            .throttle(for: .seconds(3), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] readings in
                guard let self = self else { return }
                if !readings.isEmpty {
                    Task {
                        await self.sensorDataProcessor.updateLegacySensorData(with: readings)
                    }
                }
            }
            .store(in: &cancellables)

        Logger.shared.info("[DeviceManagerAdapter] Bindings configured with throttled batch publisher")
    }

    private func updateSensorValues(from readings: [SensorType: SensorReading]) {
        // Update heart rate
        if let reading = readings[.heartRate] {
            heartRate = Int(reading.value)
        }

        // Update SpO2
        if let reading = readings[.spo2] {
            spO2 = Int(reading.value)
        }

        // Update temperature
        if let reading = readings[.temperature] {
            temperature = reading.value
        }

        // Update battery
        if let reading = readings[.battery] {
            batteryLevel = reading.value
        }

        // Update PPG values
        if let reading = readings[.ppgRed] {
            ppgRedValue = reading.value
        }

        if let reading = readings[.ppgInfrared] {
            ppgIRValue = reading.value
            // Collect IR sample for heart rate calculation
            Task { @MainActor in
                let irSamples = self.sensorDataProcessor.getPPGIRBuffer()
                if irSamples.count >= 50 {  // Need ~1 second of data at 50Hz
                    if let result = self.bioMetricCalculator.calculateHeartRate(
                        irSamples: irSamples,
                        processor: self.sensorDataProcessor
                    ) {
                        self.heartRate = Int(result.bpm)
                    }
                    self.sensorDataProcessor.clearPPGIRBuffer()
                }
            }
        }

        if let reading = readings[.ppgGreen] {
            ppgGreenValue = reading.value
        }

        // Update accelerometer values
        if let reading = readings[.accelerometerX] {
            accelX = reading.value
        }

        if let reading = readings[.accelerometerY] {
            accelY = reading.value
        }

        if let reading = readings[.accelerometerZ] {
            accelZ = reading.value
        }
    }

    // MARK: - BLEManagerProtocol Methods

    func startScanning() {
        Task {
            await deviceManager.startScanning()
        }
    }

    func stopScanning() {
        deviceManager.stopScanning()
    }

    func connect(to peripheral: CBPeripheral) {
        // Find the DeviceInfo for this peripheral
        guard let deviceInfo = deviceManager.discoveredDevices.first(where: {
            $0.peripheralIdentifier == peripheral.identifier
        }) else {
            Logger.shared.error("[DeviceManagerAdapter] Cannot find DeviceInfo for peripheral: \(peripheral.identifier)")
            return
        }

        Task {
            do {
                try await deviceManager.connect(to: deviceInfo)
                Logger.shared.info("[DeviceManagerAdapter] Connected to device: \(deviceInfo.name)")
            } catch {
                Logger.shared.error("[DeviceManagerAdapter] Connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        if let primaryDevice = deviceManager.primaryDevice {
            deviceManager.disconnect(from: primaryDevice)
        } else {
            deviceManager.disconnectAll()
        }
        sensorDataBuffer.removeAll()
        deviceState = nil
    }

    func startRecording() {
        isRecording = true
        Logger.shared.info("[DeviceManagerAdapter] Recording started")
    }

    func stopRecording() {
        isRecording = false
        Logger.shared.info("[DeviceManagerAdapter] Recording stopped")
    }

    func clearHistory() {
        deviceManager.clearReadings()
        sensorDataProcessor.clearHistory()
        sensorDataBuffer.removeAll()
        deviceStateDetector.reset()
    }

    // MARK: - Publishers for Reactive UI

    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    var isScanningPublisher: Published<Bool>.Publisher { $isScanning }
    var deviceNamePublisher: Published<String>.Publisher { $deviceName }
    var heartRatePublisher: Published<Int>.Publisher { $heartRate }
    var spO2Publisher: Published<Int>.Publisher { $spO2 }
    var heartRateQualityPublisher: Published<Double>.Publisher { $heartRateQuality }
    var temperaturePublisher: Published<Double>.Publisher { $temperature }
    var batteryLevelPublisher: Published<Double>.Publisher { $batteryLevel }
    var ppgRedValuePublisher: Published<Double>.Publisher { $ppgRedValue }
    var ppgIRValuePublisher: Published<Double>.Publisher { $ppgIRValue }
    var ppgGreenValuePublisher: Published<Double>.Publisher { $ppgGreenValue }
    var accelXPublisher: Published<Double>.Publisher { $accelX }
    var accelYPublisher: Published<Double>.Publisher { $accelY }
    var accelZPublisher: Published<Double>.Publisher { $accelZ }
    var isRecordingPublisher: Published<Bool>.Publisher { $isRecording }
    var deviceStatePublisher: Published<DeviceStateResult?>.Publisher { $deviceState }

    // MARK: - Device State Detection

    /// Updates device state by converting sensor readings to SensorData and analyzing via DeviceStateDetector
    private func updateDeviceState(from readings: [SensorReading]) {
        guard let sensorData = convertToSensorData(from: readings) else { return }

        // Add to buffer
        sensorDataBuffer.append(sensorData)

        // Trim buffer to limit
        if sensorDataBuffer.count > sensorDataBufferLimit {
            sensorDataBuffer.removeFirst(sensorDataBuffer.count - sensorDataBufferLimit)
        }

        // Analyze device state
        if let result = deviceStateDetector.analyzeDeviceState(sensorData: sensorDataBuffer) {
            self.deviceState = result
        }
    }

    /// Converts an array of SensorReading to a single SensorData object
    private func convertToSensorData(from readings: [SensorReading]) -> SensorData? {
        let now = Date()

        // Extract PPG values
        let ppgRed = readings.first { $0.sensorType == .ppgRed }?.value ?? 0
        let ppgIR = readings.first { $0.sensorType == .ppgInfrared }?.value ?? 0
        let ppgGreen = readings.first { $0.sensorType == .ppgGreen }?.value ?? 0

        // Extract accelerometer values - convert from g to raw units if needed
        // If abs(value) > 100, use as-is (already raw units); otherwise multiply by 16384.0
        let accelXRaw = readings.first { $0.sensorType == .accelerometerX }?.value ?? 0
        let accelYRaw = readings.first { $0.sensorType == .accelerometerY }?.value ?? 0
        let accelZRaw = readings.first { $0.sensorType == .accelerometerZ }?.value ?? 0

        let accelX: Int16 = Int16(clamping: Int(abs(accelXRaw) > 100 ? accelXRaw : accelXRaw * 16384.0))
        let accelY: Int16 = Int16(clamping: Int(abs(accelYRaw) > 100 ? accelYRaw : accelYRaw * 16384.0))
        let accelZ: Int16 = Int16(clamping: Int(abs(accelZRaw) > 100 ? accelZRaw : accelZRaw * 16384.0))

        // Extract temperature
        let temp = readings.first { $0.sensorType == .temperature }?.value ?? 0

        // Extract battery
        let battery = readings.first { $0.sensorType == .battery }?.value ?? 0

        // Extract heart rate if available
        let hrReading = readings.first { $0.sensorType == .heartRate }
        var heartRateData: HeartRateData? = nil
        if let hr = hrReading {
            heartRateData = HeartRateData(
                bpm: hr.value,
                quality: hr.quality ?? 0.5,
                timestamp: hr.timestamp
            )
        }

        // Create SensorData
        let ppgData = PPGData(
            red: Int32(ppgRed),
            ir: Int32(ppgIR),
            green: Int32(ppgGreen),
            timestamp: now
        )

        let accelerometerData = AccelerometerData(
            x: accelX,
            y: accelY,
            z: accelZ,
            timestamp: now
        )

        let temperatureData = TemperatureData(
            celsius: temp,
            timestamp: now
        )

        let batteryData = BatteryData(
            percentage: Int(battery),
            timestamp: now
        )

        return SensorData(
            timestamp: now,
            ppg: ppgData,
            accelerometer: accelerometerData,
            temperature: temperatureData,
            battery: batteryData,
            heartRate: heartRateData
        )
    }
}
