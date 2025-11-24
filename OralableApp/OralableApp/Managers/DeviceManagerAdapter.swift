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
    private var cancellables = Set<AnyCancellable>()

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

    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        setupBindings()
        Logger.shared.info("[DeviceManagerAdapter] Initialized with DeviceManager")
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

        // Bind latest sensor readings to individual properties
        deviceManager.$latestReadings
            .sink { [weak self] readings in
                self?.updateSensorValues(from: readings)
            }
            .store(in: &cancellables)

        Logger.shared.info("[DeviceManagerAdapter] Bindings configured")
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
}
