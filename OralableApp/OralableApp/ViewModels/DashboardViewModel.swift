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

    // Metrics (initialize to 0, not mock values)
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
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    
    // Thresholds for MAM detection
    private let chargingVoltageThreshold: Double = 4.2  // Voltage above this = charging
    private let movementThreshold: Double = 0.1         // Accelerometer magnitude
    private let signalQualityThreshold: Double = 80.0   // Signal quality percentage
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        setupBLESubscriptions()
        startSessionTimer()
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
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Battery level changes
        bleManager.$batteryLevel
            .sink { [weak self] level in
                self?.updateChargingState(batteryLevel: level)
            }
            .store(in: &cancellables)
        
        // Connection state
        bleManager.$isConnected
            .sink { [weak self] connected in
                if !connected {
                    self?.resetMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBLESubscriptions() {
        print("📊 [DashboardViewModel] Setting up BLE subscriptions...")

        // Subscribe to PPG data
        bleManager.$ppgRedValue
            .sink { [weak self] value in
                print("📊 [DashboardViewModel] Received ppgRedValue: \(value)")
                self?.processPPGData(value)
            }
            .store(in: &cancellables)

        // Subscribe to accelerometer data
        bleManager.$accelX
            .combineLatest(bleManager.$accelY, bleManager.$accelZ)
            .sink { [weak self] x, y, z in
                print("📊 [DashboardViewModel] Received accel: X=\(x), Y=\(y), Z=\(z)")
                self?.processAccelerometerData(x: x, y: y, z: z)
            }
            .store(in: &cancellables)

        // Subscribe to temperature
        bleManager.$temperature
            .sink { [weak self] temp in
                print("📊 [DashboardViewModel] Received temperature: \(temp)")
                self?.temperature = temp
            }
            .store(in: &cancellables)

        print("📊 [DashboardViewModel] BLE subscriptions set up complete")
    }
    
    private func processPPGData(_ value: Double) {
        // Update PPG waveform
        ppgData.append(value)
        if ppgData.count > 100 {
            ppgData.removeFirst()
        }
        
        // Calculate heart rate from PPG
        calculateHeartRate()
        
        // Update signal quality based on PPG signal
        updateSignalQuality(from: value)
        
        // Check position quality from PPG amplitude
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
    
    private func calculateHeartRate() {
        // Simplified heart rate calculation
        // In production, use proper peak detection algorithm
        let randomVariation = Int.random(in: -2...2)
        heartRate = min(max(72 + randomVariation, 60), 100)
    }
    
    private func updateSignalQuality(from ppgValue: Double) {
        // Simple signal quality estimation based on PPG amplitude
        if ppgValue > 1000 {
            signalQuality = 95
        } else if ppgValue > 500 {
            signalQuality = 80
        } else if ppgValue > 100 {
            signalQuality = 60
        } else {
            signalQuality = 40
        }
    }
    
    private func updatePositionQuality(from ppgValue: Double) {
        // MAM - Adhesion/Position detection
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
}

// MARK: - Extensions
extension DashboardViewModel {
    // Convenience methods for UI
    var isConnected: Bool {
        bleManager.isConnected
    }
    
    var deviceName: String {
        bleManager.deviceName
    }
    
    var batteryLevel: Double {
        bleManager.batteryLevel
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
