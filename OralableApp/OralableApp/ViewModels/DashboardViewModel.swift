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

    // Waveform Data
    @Published var ppgData: [Double] = []
    @Published var accelerometerData: [Double] = []

    // Session Management
    @Published var isRecording: Bool = false
    @Published var sessionStartTime: Date?
    
    // MARK: - Private Properties
    private let bleManager = OralableBLE.shared
    private let appStateManager = AppStateManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var mockDataTimer: Timer?
    
    // Thresholds for MAM detection
    private let chargingVoltageThreshold: Double = 4.2  // Voltage above this = charging
    private let movementThreshold: Double = 0.1         // Accelerometer magnitude
    private let signalQualityThreshold: Double = 80.0   // Signal quality percentage
    
    // MARK: - Initialization
    init() {
        setupBindings()

        // Only use mock data in Demo mode
        let isDemoMode = appStateManager.selectedMode == .demo
        if isDemoMode {
            Logger.shared.info("[DashboardViewModel] 🎭 Initializing in DEMO MODE with MOCK DATA")
            generateMockWaveforms()
        } else {
            Logger.shared.info("[DashboardViewModel] ✅ Initializing in PRODUCTION MODE - REAL DATA only")
        }
    }

    // MARK: - Public Methods
    func startMonitoring() {
        setupBLESubscriptions()
        startSessionTimer()

        // Only use mock data in Demo mode
        let isDemoMode = appStateManager.selectedMode == .demo
        if isDemoMode {
            Logger.shared.info("[DashboardViewModel] 🎭 Starting mock data generation for DEMO MODE")
            startMockDataGeneration()
        } else {
            Logger.shared.info("[DashboardViewModel] ✅ Mock data DISABLED - waiting for real device data")
        }
    }
    
    func stopMonitoring() {
        sessionTimer?.invalidate()
        mockDataTimer?.invalidate()
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
    
    // MARK: - Private Methods
    private func setupBindings() {
        // CRITICAL PERFORMANCE FIX: Throttle connection state updates
        // Connection state (throttled to prevent excessive UI updates)
        bleManager.$isConnected
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] connected in
                self?.isConnected = connected
                if !connected {
                    self?.resetMetrics()
                }
            }
            .store(in: &cancellables)

        // Device name (throttled)
        bleManager.$deviceName
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] name in
                self?.deviceName = name
            }
            .store(in: &cancellables)

        // Battery level (throttled)
        bleManager.$batteryLevel
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                self?.batteryLevel = level
                self?.updateChargingState(batteryLevel: level)
            }
            .store(in: &cancellables)
    }
    
    private func setupBLESubscriptions() {
        // CRITICAL PERFORMANCE FIX: Throttle all subscriptions to prevent SwiftUI rendering storm
        // Sensor data arrives every 10-14ms, but UI only needs to update 1-2x per second
        // Without throttling: 60-100 view re-renders/sec = iPhone freeze
        // With throttling: 2 view re-renders/sec = smooth UI

        // Subscribe to Heart Rate (calculated from PPG)
        bleManager.$heartRate
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] hr in
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        // Subscribe to SpO2 (calculated from PPG)
        bleManager.$spO2
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] spo2 in
                self?.spO2 = spo2
            }
            .store(in: &cancellables)

        // Subscribe to PPG data for waveform
        bleManager.$ppgRedValue
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] value in
                self?.processPPGData(value)
            }
            .store(in: &cancellables)

        // Subscribe to accelerometer data
        bleManager.$accelX
            .combineLatest(bleManager.$accelY, bleManager.$accelZ)
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] x, y, z in
                self?.processAccelerometerData(x: x, y: y, z: z)
            }
            .store(in: &cancellables)

        // Subscribe to temperature
        bleManager.$temperature
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] temp in
                self?.temperature = temp
            }
            .store(in: &cancellables)

        // Subscribe to HR quality for signal quality display
        bleManager.$heartRateQuality
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
    // Convenience methods for UI (connection state now comes from throttled @Published properties)
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // BLE Manager methods (need direct access for connect/disconnect)
    var bleManagerRef: OralableBLE {
        bleManager
    }
}
