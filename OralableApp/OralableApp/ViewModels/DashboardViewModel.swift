//
//  DashboardViewModel.swift
//  OralableApp
//
//  Updated: November 8, 2025
//  Added: MAM state properties and position detection logic
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable by View)
    
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "No Device"
    @Published var deviceState: DeviceStateResult?
    @Published var batteryLevel: Int = 0
    @Published var currentHeartRate: Double?
    @Published var currentSpO2: Double?
    @Published var currentTemperature: Double = 36.0
    @Published var connectionStatus: String = "Disconnected"
    @Published var isRecording: Bool = false
    
    // MAM State Properties (NEW)
    @Published var isCharging: Bool = false
    @Published var isMoving: Bool = false
    @Published var positionQuality: String = "Unknown"  // "Good", "Adjust", "Off"
    @Published var ppgQuality: String = "--"
    @Published var movementIntensity: String = "Low"
    
    // Historical data for charts
    @Published var batteryHistory: [BatteryData] = []
    @Published var heartRateHistory: [HeartRateData] = []
    @Published var spo2History: [SpO2Data] = []
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    @Published var ppgHistory: [PPGData] = []
    
    // For real-time waveform display
    @Published var ppgData: [PPGDataPoint] = []
    @Published var accelerometerData: [AccelerometerDataPoint] = []
    
    // MARK: - Private Properties
    
    private let bleManager: OralableBLE
    private var cancellables = Set<AnyCancellable>()
    private var movementThreshold: Double = 0.1  // G-force threshold for movement
    private var ppgSignalThreshold: Double = 100.0  // Minimum amplitude for good signal
    
    // MARK: - Computed Properties
    
    var showSensorData: Bool {
        isConnected
    }
    
    var batteryPercentageText: String {
        "\(batteryLevel)%"
    }
    
    var heartRateText: String {
        guard let hr = currentHeartRate else { return "--" }
        return String(format: "%.0f", hr)
    }
    
    var spo2Text: String {
        guard let spo2 = currentSpO2 else { return "--" }
        return String(format: "%.0f", spo2)
    }
    
    var temperatureText: String {
        String(format: "%.1f°C", currentTemperature)
    }
    
    var connectionStatusText: String {
        if isConnected {
            return "Connected to \(deviceName)"
        } else if isScanning {
            return "Scanning for devices..."
        } else {
            return "Tap to connect"
        }
    }
    
    var scanButtonText: String {
        if isConnected {
            return "Disconnect"
        } else if isScanning {
            return "Stop Scanning"
        } else {
            return "Start Scanning"
        }
    }
    
    // MARK: - Initialization
    
    init() {
        self.bleManager = OralableBLE.shared
        setupBindings()
        setupMAMStateDetection()
    }
    
    init(bleManager: OralableBLE) {
        self.bleManager = bleManager
        setupBindings()
        setupMAMStateDetection()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to BLE manager's published properties
        bleManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        bleManager.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
        
        bleManager.$deviceName
            .receive(on: DispatchQueue.main)
            .assign(to: &$deviceName)
        
        bleManager.$deviceState
            .receive(on: DispatchQueue.main)
            .assign(to: &$deviceState)
        
        // Subscribe to battery data
        bleManager.$batteryHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.batteryHistory = history
                if let lastBattery = history.last {
                    self?.batteryLevel = lastBattery.percentage
                    // Detect charging state from battery trend
                    self?.detectChargingState(history: history)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to heart rate data
        bleManager.$heartRateHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.heartRateHistory = history
                self?.currentHeartRate = history.last?.bpm
            }
            .store(in: &cancellables)
        
        // Subscribe to SpO2 data
        bleManager.$spo2History
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.spo2History = history
                self?.currentSpO2 = history.last?.percentage
            }
            .store(in: &cancellables)
        
        // Subscribe to temperature data
        bleManager.$temperatureHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.temperatureHistory = history
                self?.currentTemperature = history.last?.celsius ?? 36.0
            }
            .store(in: &cancellables)
        
        // Subscribe to accelerometer data for movement detection
        bleManager.$accelerometerHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.accelerometerHistory = history
                self?.detectMovement(history: history)
            }
            .store(in: &cancellables)
        
        // Subscribe to PPG data for signal quality
        bleManager.$ppgHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.ppgHistory = history
                self?.detectPPGSignalQuality(history: history)
            }
            .store(in: &cancellables)
        
        // For real-time waveform display - convert PPG history to display points
        bleManager.$ppgHistory
            .receive(on: DispatchQueue.main)
            .map { history in
                history.suffix(200).map { data in
                    PPGDataPoint(
                        timestamp: data.timestamp,
                        red: Double(data.red),
                        ir: Double(data.ir),
                        green: Double(data.green)
                    )
                }
            }
            .assign(to: &$ppgData)
        
        // For real-time accelerometer display
        bleManager.$accelerometerHistory
            .receive(on: DispatchQueue.main)
            .map { history in
                history.suffix(100).map { data in
                    AccelerometerDataPoint(
                        timestamp: data.timestamp,
                        x: Double(data.x),
                        y: Double(data.y),
                        z: Double(data.z)
                    )
                }
            }
            .assign(to: &$accelerometerData)
        
        // Update connection status text
        Publishers.CombineLatest(bleManager.$isConnected, bleManager.$isScanning)
            .receive(on: DispatchQueue.main)
            .map { isConnected, isScanning in
                if isConnected {
                    return "Connected"
                } else if isScanning {
                    return "Scanning..."
                } else {
                    return "Disconnected"
                }
            }
            .assign(to: &$connectionStatus)
    }
    
    // MARK: - MAM State Detection (NEW)
    
    private func setupMAMStateDetection() {
        // Device state detection from DeviceStateResult
        bleManager.$deviceState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stateResult in
                guard let stateResult = stateResult else { return }
                
                // Update MAM indicators based on device state
                switch stateResult.state {
                case .onChargerIdle:
                    self?.isCharging = true
                    self?.isMoving = false
                    self?.positionQuality = "Off"
                    
                case .offChargerIdle:
                    self?.isCharging = false
                    self?.isMoving = false
                    self?.positionQuality = "Off"
                    
                case .onMuscle:
                    self?.isCharging = false
                    self?.isMoving = false
                    self?.positionQuality = "Good"
                    
                case .inMotion:
                    self?.isCharging = false
                    self?.isMoving = true
                    self?.positionQuality = stateResult.confidence > 0.7 ? "Good" : "Adjust"
                    
                case .unknown:
                    self?.positionQuality = "Unknown"
                }
                
                // Check details dictionary for additional info if available
                if let details = stateResult.details as? [String: Any] {
                    if let charging = details["charging"] as? Bool {
                        self?.isCharging = charging
                    }
                    if let moving = details["moving"] as? Bool {
                        self?.isMoving = moving
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func detectChargingState(history: [BatteryData]) {
        guard history.count > 5 else { return }
        
        // Check if battery is increasing over last 5 readings
        let recent = Array(history.suffix(5))
        let isIncreasing = recent.enumerated().allSatisfy { index, data in
            index == 0 || data.percentage >= recent[index - 1].percentage
        }
        
        // If battery is at 100% or increasing, likely charging
        isCharging = batteryLevel == 100 || isIncreasing
    }
    
    private func detectMovement(history: [AccelerometerData]) {
        guard let lastData = history.last else {
            isMoving = false
            movementIntensity = "Low"
            return
        }
        
        // Calculate magnitude of acceleration - convert to Double explicitly
        let x = Double(lastData.x)
        let y = Double(lastData.y)
        let z = Double(lastData.z)
        let magnitude = sqrt(x * x + y * y + z * z)
        
        // Subtract gravity (approximately 1.0 G when still)
        let movement = abs(magnitude - 1.0)
        
        // Determine movement state
        isMoving = movement > movementThreshold
        
        // Classify movement intensity
        switch movement {
        case 0..<0.1:
            movementIntensity = "None"
        case 0.1..<0.3:
            movementIntensity = "Low"
        case 0.3..<0.6:
            movementIntensity = "Medium"
        default:
            movementIntensity = "High"
        }
    }
    
    private func detectPPGSignalQuality(history: [PPGData]) {
        guard let lastData = history.last else {
            ppgQuality = "--"
            positionQuality = "Unknown"
            return
        }
        
        // Calculate signal amplitude
        let redAmplitude = Double(lastData.red)
        let irAmplitude = Double(lastData.ir)
        
        // Simple signal quality assessment
        if redAmplitude < 10 || irAmplitude < 10 {
            ppgQuality = "No Signal"
            positionQuality = "Off"
        } else if redAmplitude < ppgSignalThreshold || irAmplitude < ppgSignalThreshold {
            ppgQuality = "Poor"
            positionQuality = "Adjust"
        } else {
            ppgQuality = "Good"
            positionQuality = "Good"
        }
        
        // Additional check: if HR or SpO2 are being calculated successfully
        if currentHeartRate != nil && currentSpO2 != nil {
            positionQuality = "Good"
        } else if currentHeartRate != nil || currentSpO2 != nil {
            positionQuality = "Adjust"
        }
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        bleManager.startScanning()
        
        // Auto-connect after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.bleManager.autoConnectToOralable()
        }
    }
    
    func stopScanning() {
        bleManager.stopScanning()
    }
    
    func toggleScanning() {
        if isConnected {
            disconnect()
        } else if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func refreshScan() {
        bleManager.refreshScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        bleManager.connect(to: peripheral)
    }
    
    func connectToFirstAvailable() {
        if let firstDevice = bleManager.discoveredDevices.first {
            connect(to: firstDevice)
        }
    }
    
    func disconnect() {
        bleManager.disconnect()
    }
    
    func resetBLE() {
        bleManager.resetBLE()
    }
    
    func toggleRecording() {
        isRecording.toggle()
        // TODO: Implement actual recording logic
        // For now, just toggle the state for UI purposes
        if isRecording {
            print("Recording started")
            // When BLE recording is implemented:
            // bleManager.startRecording()
        } else {
            print("Recording stopped")
            // When BLE recording is implemented:
            // bleManager.stopRecording()
        }
    }
    
    // MARK: - Data Access
    
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics? {
        return bleManager.getHistoricalMetrics(for: range)
    }
    
    func getRecentDataPoints(count: Int) -> [SensorData] {
        let history = bleManager.sensorDataHistory
        return Array(history.suffix(count))
    }
    
    func exportData(range: TimeRange) -> URL? {
        // Implement data export
        return nil
    }
    
    // MARK: - Convenience Accessors
    
    var sensorDataHistory: [SensorData] {
        bleManager.sensorDataHistory
    }
    
    var discoveredDevices: [CBPeripheral] {
        bleManager.discoveredDevices
    }
    
    var connectedDevice: CBPeripheral? {
        bleManager.connectedDevice
    }
}

// MARK: - Data Models for Display

struct PPGDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let red: Double
    let ir: Double
    let green: Double
}

struct AccelerometerDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let x: Double
    let y: Double
    let z: Double
}

// MARK: - Mock for Previews

extension DashboardViewModel {
    static func mock() -> DashboardViewModel {
        let viewModel = DashboardViewModel()
        
        // Set mock data
        viewModel.isConnected = true
        viewModel.deviceName = "Oralable Device"
        viewModel.batteryLevel = 85
        viewModel.currentHeartRate = 72
        viewModel.currentSpO2 = 98
        viewModel.currentTemperature = 36.5
        viewModel.connectionStatus = "Connected"
        
        // Set MAM states
        viewModel.isCharging = false
        viewModel.isMoving = false
        viewModel.positionQuality = "Good"
        viewModel.ppgQuality = "Good"
        viewModel.movementIntensity = "Low"
        
        // Generate mock PPG data
        let now = Date()
        viewModel.ppgData = (0..<100).map { i in
            PPGDataPoint(
                timestamp: now.addingTimeInterval(Double(i) * 0.1),
                red: 1000 + Double.random(in: -50...50),
                ir: 1500 + Double.random(in: -75...75),
                green: 800 + Double.random(in: -40...40)
            )
        }
        
        // Generate mock accelerometer data
        viewModel.accelerometerData = (0..<50).map { i in
            AccelerometerDataPoint(
                timestamp: now.addingTimeInterval(Double(i) * 0.2),
                x: sin(Double(i) * 0.1) * 0.5,
                y: cos(Double(i) * 0.1) * 0.3,
                z: sin(Double(i) * 0.05) * 0.4
            )
        }
        
        return viewModel
    }
}
