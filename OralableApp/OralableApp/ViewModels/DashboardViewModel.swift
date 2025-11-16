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
    
    // Waveform Data
    @Published var ppgData: [Double] = []
    @Published var accelerometerData: [Double] = []
    
    // Connection State
    @Published var isConnected: Bool = false
    @Published var deviceName: String = "Not Connected"
    @Published var batteryLevel: Int = 0
    
    // Mock Mode (for testing without hardware)
    @Published var isMockMode: Bool = false
    
    // MARK: - Private Properties
    
    private let bleManager: BLEManagerProtocol
    private let appStateManager = AppStateManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var mockDataTimer: Timer?
    
    // Session tracking
    private var sessionStartTime: Date?
    
    // MAM Thresholds
    private let movementThreshold: Double = 0.5 // g-force
    
    // MARK: - Initialization
    
    init(bleManager: BLEManagerProtocol = DeviceManager.shared) {
        self.bleManager = bleManager
        setupBindings()
        
        // Start session timer
        startSessionTimer()
    }
    
    deinit {
        sessionTimer?.invalidate()
        mockDataTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        setupBLESubscriptions()
        setupStateSubscriptions()
    }
    
    private func setupStateSubscriptions() {
        // Connection state - update local property and reset on disconnect
        bleManager.isConnectedPublisher
            .sink { [weak self] connected in
                self?.isConnected = connected
                self?.deviceName = self?.bleManager.deviceName ?? "Not Connected"
                if !connected {
                    self?.resetMetrics()
                }
            }
            .store(in: &cancellables)

        // Battery monitoring
        bleManager.batteryLevelPublisher
            .sink { [weak self] level in
                self?.batteryLevel = Int(level)
                self?.updateChargingState(batteryLevel: level)
            }
            .store(in: &cancellables)
    }

    private func setupBLESubscriptions() {
        // Subscribe to Heart Rate (calculated from PPG) - reduced throttle for responsiveness
        bleManager.heartRatePublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        // Subscribe to SpO2 (calculated from PPG)
        bleManager.spO2Publisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] spo2 in
                self?.spO2 = spo2
            }
            .store(in: &cancellables)

        // Subscribe to PPG data for waveform
        bleManager.ppgRedValuePublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.processPPGData(value)
            }
            .store(in: &cancellables)

        // Subscribe to accelerometer data
        bleManager.accelXPublisher
            .combineLatest(bleManager.accelYPublisher, bleManager.accelZPublisher)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] x, y, z in
                self?.processAccelerometerData(x: x, y: y, z: z)
            }
            .store(in: &cancellables)

        // Subscribe to temperature
        bleManager.temperaturePublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] temp in
                self?.temperature = temp
            }
            .store(in: &cancellables)

        // Subscribe to HR quality for signal quality display
        bleManager.heartRateQualityPublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
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

        // Update position quality from PPG amplitude
        updatePositionQuality(from: value)
    }
    
    private func processAccelerometerData(x: Double, y: Double, z: Double) {
        // Calculate magnitude for movement detection
        let magnitude = sqrt(x*x + y*y + z*z)
        
        // Update accelerometer waveform
        accelerometerData.append(magnitude)
        if accelerometerData.count > 100 {
            accelerometerData.removeFirst()
        }
        
        // Detect movement (MAM - Movement state)
        isMoving = magnitude > movementThreshold
    }
    
    private func updatePositionQuality(from ppgValue: Double) {
        // MAM - Adhesion/Position detection based on signal quality
        if signalQuality > 80 {
            positionQuality = "Good"
        } else if signalQuality > 50 {
            positionQuality = "Adjust"
        } else {
            positionQuality = "Off"
        }
    }
    
    private func updateChargingState(batteryLevel: Double) {
        // MAM - Monitoring state (charging detection)
        // Simple heuristic: if battery is at 100% or increasing rapidly, it's charging
        isCharging = batteryLevel >= 99.9
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
    
    private func resetMetrics() {
        heartRate = 0
        spO2 = 0
        temperature = 0.0
        signalQuality = 0
        ppgData = []
        accelerometerData = []
        isMoving = false
        positionQuality = "Off"
    }
    
    // MARK: - Mock Data Generation (ONLY for Demo Mode)
    private func generateMockWaveforms() {
        Logger.shared.debug("[DashboardViewModel] Generating initial mock waveforms")
        // Generate initial mock PPG waveform
        for i in 0..<100 {
            let value = sin(Double(i) * 0.1) * 1000 + 2000 + Double.random(in: -100...100)
            ppgData.append(value)
        }

        // Generate initial mock accelerometer waveform
        for i in 0..<100 {
            let value = sin(Double(i) * 0.05) * 0.5 + 1.0 + Double.random(in: -0.1...0.1)
            accelerometerData.append(value)
        }

        // Initialize mock metrics for demo mode
        heartRate = 72
        spO2 = 98
        temperature = 36.5
        signalQuality = 95
        Logger.shared.info("[DashboardViewModel] ✅ Mock data initialized | HR: 72 bpm | SpO2: 98% | Temp: 36.5°C")
    }

    private func startMockDataGeneration() {
        Logger.shared.info("[DashboardViewModel] Starting continuous mock data generation timer")
        mockDataTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Only generate mock data if NOT connected to real device
            guard !self.bleManager.isConnected else {
                Logger.shared.debug("[DashboardViewModel] Device connected - stopping mock data generation")
                self.mockDataTimer?.invalidate()
                self.mockDataTimer = nil
                return
            }

            // Update mock PPG data
            if !self.ppgData.isEmpty {
                self.ppgData.removeFirst()
            }
            let newPPGValue = sin(Double(self.ppgData.count) * 0.1) * 1000 + 2000 + Double.random(in: -100...100)
            self.ppgData.append(newPPGValue)

            // Update mock accelerometer data
            if !self.accelerometerData.isEmpty {
                self.accelerometerData.removeFirst()
            }
            let newAccelValue = sin(Double(self.accelerometerData.count) * 0.05) * 0.5 + 1.0 + Double.random(in: -0.1...0.1)
            self.accelerometerData.append(newAccelValue)

            // Update mock metrics
            self.heartRate = Int.random(in: 68...76)
            self.spO2 = Int.random(in: 96...99)
            self.temperature = 36.5 + Double.random(in: -0.3...0.3)

            // Mock MAM states
            self.isCharging = Bool.random()
            self.isMoving = Bool.random()
            self.positionQuality = ["Good", "Good", "Good", "Adjust"].randomElement()!
        }
    }
}

// MARK: - Extensions
extension DashboardViewModel {
    // Recording control methods
    func startRecording() {
        guard isConnected else {
            Logger.shared.warning("[DashboardViewModel] Cannot start recording - not connected to device")
            return
        }
        // TODO: Implement recording start via RecordingSessionManager
        Logger.shared.info("[DashboardViewModel] Recording started")
    }

    func stopRecording() {
        // TODO: Implement recording stop via RecordingSessionManager
        Logger.shared.info("[DashboardViewModel] Recording stopped")
    }
}
