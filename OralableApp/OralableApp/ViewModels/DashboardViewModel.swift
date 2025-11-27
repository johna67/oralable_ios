//
//  DashboardViewModel.swift
//  OralableApp
//
//  Complete ViewModel with MAM state detection
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

    // Session Management
    @Published var isRecording: Bool = false
    @Published var sessionStartTime: Date?
    
    // MARK: - Private Properties
    private let bleManager: BLEManagerProtocol  // ✅ Now uses protocol for dependency injection
    private let appStateManager: AppStateManager
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?

    // MARK: - Initialization

    /// Initialize with injected dependencies (preferred)
    /// - Parameters:
    ///   - bleManager: BLE manager conforming to protocol (allows mocking for tests)
    ///   - appStateManager: App state manager
    init(bleManager: BLEManagerProtocol, appStateManager: AppStateManager) {
        self.bleManager = bleManager
        self.appStateManager = appStateManager
        setupBindings()
        Logger.shared.info("[DashboardViewModel] ✅ Initializing with protocol-based dependency injection")
    }

    // MARK: - Public Methods
    func startMonitoring() {
        setupBLESubscriptions()
        startSessionTimer()
        Logger.shared.info("[DashboardViewModel] ✅ Mock data DISABLED - waiting for real device data")
    }
    
    func stopMonitoring() {
        sessionTimer?.invalidate()
    }
    
    func startRecording() {
        isRecording = true
        sessionStartTime = Date()
        bleManager.startRecording()
    }
    
    func stopRecording() {
        isRecording = false
        sessionStartTime = nil
        bleManager.stopRecording()
    }

    func disconnect() {
        bleManager.disconnect()
    }

    func startScanning() {
        bleManager.startScanning()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // CRITICAL PERFORMANCE FIX: Throttle connection state updates
        // Using protocol publishers for better testability

        // Connection state (throttled to prevent excessive UI updates)
        bleManager.isConnectedPublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] connected in
                self?.isConnected = connected
                if !connected {
                    self?.resetMetrics()
                }
            }
            .store(in: &cancellables)

        // Device name (throttled)
        bleManager.deviceNamePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] name in
                self?.deviceName = name
            }
            .store(in: &cancellables)

        // Battery level (throttled)
        bleManager.batteryLevelPublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                self?.batteryLevel = level
            }
            .store(in: &cancellables)

        // Device state from DeviceStateDetector
        bleManager.deviceStatePublisher
            .sink { [weak self] stateResult in
                guard let self = self, let stateResult = stateResult else { return }
                self.updateMAMStates(from: stateResult)
            }
            .store(in: &cancellables)
    }
    
    private func setupBLESubscriptions() {
        // CRITICAL PERFORMANCE FIX: Throttle all subscriptions to prevent SwiftUI rendering storm
        // Sensor data arrives every 10-14ms, but UI only needs to update 1-2x per second
        // Without throttling: 60-100 view re-renders/sec = iPhone freeze
        // With throttling: 2 view re-renders/sec = smooth UI

        // Subscribe to Heart Rate (calculated from PPG) - using protocol publisher
        bleManager.heartRatePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] hr in
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        // Subscribe to SpO2 (calculated from PPG) - using protocol publisher
        bleManager.spO2Publisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] spo2 in
                self?.spO2 = spo2
            }
            .store(in: &cancellables)

        // Subscribe to PPG data for waveform
        bleManager.ppgRedValuePublisher
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] value in
                self?.processPPGData(value)
            }
            .store(in: &cancellables)

        // Subscribe to accelerometer data
        bleManager.accelXPublisher
            .combineLatest(bleManager.accelYPublisher, bleManager.accelZPublisher)
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] x, y, z in
                self?.processAccelerometerData(x: x, y: y, z: z)
            }
            .store(in: &cancellables)

        // Subscribe to temperature
        bleManager.temperaturePublisher
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] temp in
                self?.temperature = temp
            }
            .store(in: &cancellables)

        // Subscribe to HR quality for signal quality display
        bleManager.heartRateQualityPublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] quality in
                self?.signalQuality = Int(quality * 100)
            }
            .store(in: &cancellables)
    }
    
    private func processPPGData(_ value: Double) {
        // Update PPG waveform
        ppgData.append(value)
        if ppgData.count > 100 {
            ppgData.removeFirst()
        }

        // Update muscle activity (derived from PPG IR)
        muscleActivity = value
        muscleActivityHistory.append(value)
        if muscleActivityHistory.count > 20 {
            muscleActivityHistory.removeFirst()
        }
    }
    
    private func processAccelerometerData(x: Double, y: Double, z: Double) {
        // Calculate magnitude for movement detection
        let magnitude = sqrt(x*x + y*y + z*z)

        // Update accelerometer waveform
        accelerometerData.append(magnitude)
        if accelerometerData.count > 100 {
            accelerometerData.removeFirst()
        }
    }
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
    }
    
    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else {
            sessionDuration = "00:00"
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed) % 60
        sessionDuration = String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Maps DeviceStateResult to MAM indicator states
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
            // Position quality based on confidence
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
    // Convenience methods for UI (connection state now comes from throttled @Published properties)
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
