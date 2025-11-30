//
//  DashboardViewModel.swift
//  OralableApp
//
//  Complete ViewModel with MAM state detection
//  Updated: November 29, 2025 - Refactored for RecordingStateCoordinator
//  Fixed: Timer memory leak, uses single source of truth for recording state
//

import SwiftUI
import Combine
import CoreBluetooth

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties

    // Connection State (throttled from BLE manager)
    @Published var isConnected: Bool = false
    @Published var deviceName: String = ""
    @Published var batteryLevel: Double = 0.0

    // Metrics
    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var temperature: Double = 0.0
    @Published var signalQuality: Int = 0
    @Published var sessionDuration: String = "00:00"

    // MAM States (Movement, Adhesion, Monitoring)
    @Published var isCharging: Bool = false
    @Published var isMoving: Bool = false
    @Published var positionQuality: String = "Good" // "Good", "Adjust", "Off"

    // Device State Detection
    @Published var deviceStateDescription: String = "Unknown"
    @Published var deviceStateConfidence: Double = 0.0

    // Waveform Data
    @Published var ppgData: [Double] = []
    @Published var accelerometerData: [Double] = []

    // Muscle Activity (derived from PPG IR)
    @Published var muscleActivity: Double = 0.0
    @Published var muscleActivityHistory: [Double] = []

    // Recording state from coordinator (read-only binding)
    @Published private(set) var isRecording: Bool = false

    // MARK: - Private Properties
    private let deviceManagerAdapter: DeviceManagerAdapter
    private let deviceManager: DeviceManager
    private let appStateManager: AppStateManager
    private let recordingStateCoordinator: RecordingStateCoordinator
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(deviceManagerAdapter: DeviceManagerAdapter,
         deviceManager: DeviceManager,
         appStateManager: AppStateManager,
         recordingStateCoordinator: RecordingStateCoordinator) {
        self.deviceManagerAdapter = deviceManagerAdapter
        self.deviceManager = deviceManager
        self.appStateManager = appStateManager
        self.recordingStateCoordinator = recordingStateCoordinator
        setupBindings()
        Logger.shared.info("[DashboardViewModel] ✅ Initialized with RecordingStateCoordinator")
    }

    deinit {
        // Cancellables will be cleaned up automatically
        Logger.shared.info("[DashboardViewModel] deinit - cleaning up subscriptions")
    }

    // MARK: - Public Methods
    func startMonitoring() {
        setupBLESubscriptions()
        Logger.shared.info("[DashboardViewModel] ✅ Monitoring started - waiting for real device data")
    }

    func stopMonitoring() {
        // Subscriptions cleaned up via cancellables
    }

    func startRecording() {
        recordingStateCoordinator.startRecording()
    }

    func stopRecording() {
        recordingStateCoordinator.stopRecording()
    }

    func disconnect() {
        Task {
            if let device = deviceManager.primaryDevice,
               let peripheralId = device.peripheralIdentifier {
                await deviceManager.disconnect(from: DeviceInfo(
                    type: device.type,
                    name: device.name,
                    peripheralIdentifier: peripheralId,
                    connectionState: .connected
                ))
            }
        }
    }

    func startScanning() {
        Task {
            await deviceManager.startScanning()
        }
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Bind recording state from coordinator (single source of truth)
        recordingStateCoordinator.$isRecording
            .assign(to: &$isRecording)

        // Bind session duration from coordinator
        recordingStateCoordinator.$sessionDuration
            .map { duration -> String in
                let minutes = Int(duration / 60)
                let seconds = Int(duration) % 60
                return String(format: "%02d:%02d", minutes, seconds)
            }
            .assign(to: &$sessionDuration)

        // Connection state from DeviceManager (readiness-aware) - reduced throttle
        deviceManager.$connectedDevices
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] devices in
                guard let self = self else { return }
                self.isConnected = !devices.isEmpty && self.deviceManager.primaryDeviceReadiness == .ready
                if !self.isConnected {
                    self.resetMetrics()
                }
            }
            .store(in: &cancellables)

        // Also watch readiness state changes - reduced throttle
        deviceManager.$deviceReadiness
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isConnected = !self.deviceManager.connectedDevices.isEmpty &&
                                  self.deviceManager.primaryDeviceReadiness == .ready
            }
            .store(in: &cancellables)

        // Device name from primary device
        deviceManager.$primaryDevice
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] device in
                self?.deviceName = device?.name ?? ""
            }
            .store(in: &cancellables)

        // Battery level (throttled)
        deviceManagerAdapter.batteryLevelPublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                self?.batteryLevel = level
            }
            .store(in: &cancellables)

        // Device state from DeviceStateDetector
        deviceManagerAdapter.deviceStatePublisher
            .sink { [weak self] stateResult in
                guard let self = self, let stateResult = stateResult else { return }
                self.updateMAMStates(from: stateResult)
            }
            .store(in: &cancellables)
    }

    private func setupBLESubscriptions() {
        // Subscribe to Heart Rate
        deviceManagerAdapter.heartRatePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] hr in
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        // Subscribe to SpO2
        deviceManagerAdapter.spO2Publisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] spo2 in
                self?.spO2 = spo2
            }
            .store(in: &cancellables)

        // Subscribe to PPG data for waveform
        deviceManagerAdapter.ppgRedValuePublisher
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] value in
                self?.processPPGData(value)
            }
            .store(in: &cancellables)

        // Subscribe to accelerometer data
        deviceManagerAdapter.accelXPublisher
            .combineLatest(deviceManagerAdapter.accelYPublisher, deviceManagerAdapter.accelZPublisher)
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] x, y, z in
                self?.processAccelerometerData(x: x, y: y, z: z)
            }
            .store(in: &cancellables)

        // Subscribe to temperature
        deviceManagerAdapter.temperaturePublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] temp in
                self?.temperature = temp
            }
            .store(in: &cancellables)

        // Subscribe to HR quality for signal quality display
        deviceManagerAdapter.heartRateQualityPublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] quality in
                self?.signalQuality = Int(quality * 100)
            }
            .store(in: &cancellables)
    }

    private func processPPGData(_ value: Double) {
        ppgData.append(value)
        if ppgData.count > 100 {
            ppgData.removeFirst()
        }

        muscleActivity = value
        muscleActivityHistory.append(value)
        if muscleActivityHistory.count > 20 {
            muscleActivityHistory.removeFirst()
        }
    }

    private func processAccelerometerData(x: Double, y: Double, z: Double) {
        let magnitude = sqrt(x*x + y*y + z*z)

        accelerometerData.append(magnitude)
        if accelerometerData.count > 100 {
            accelerometerData.removeFirst()
        }
    }

    private func updateMAMStates(from stateResult: DeviceStateResult) {
        deviceStateDescription = stateResult.state.rawValue
        deviceStateConfidence = stateResult.confidence

        switch stateResult.state {
        case .onChargerStatic:
            isCharging = true
            isMoving = false
            positionQuality = "Off"

        case .offChargerStatic:
            isCharging = false
            isMoving = false
            positionQuality = "Off"

        case .inMotion:
            isCharging = false
            isMoving = true
            positionQuality = "Adjust"

        case .onCheek:
            isCharging = false
            isMoving = false
            if stateResult.confidence >= 0.8 {
                positionQuality = "Good"
            } else if stateResult.confidence >= 0.6 {
                positionQuality = "Adjust"
            } else {
                positionQuality = "Off"
            }

        case .unknown:
            isCharging = false
            isMoving = false
            positionQuality = "Off"
        }
    }

    private func resetMetrics() {
        heartRate = 0
        spO2 = 0
        temperature = 0.0
        signalQuality = 0
        ppgData = []
        accelerometerData = []
        muscleActivity = 0.0
        muscleActivityHistory = []
        isMoving = false
        positionQuality = "Off"
        deviceStateDescription = "Unknown"
        deviceStateConfidence = 0.0
    }
}

// MARK: - Extensions
extension DashboardViewModel {
    func toggleRecording() {
        recordingStateCoordinator.toggleRecording()
    }
}
