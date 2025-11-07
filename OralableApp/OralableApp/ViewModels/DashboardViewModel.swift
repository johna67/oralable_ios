//
//  DashboardViewModel.swift
//  OralableApp
//
//  Created: November 7, 2025
//  MVVM Architecture - Dashboard business logic
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
    
    // Convenience initializer that uses shared instance
    init() {
        self.bleManager = OralableBLE.shared
        setupBindings()
    }
    
    // Full initializer for testing/injection
    init(bleManager: OralableBLE) {
        self.bleManager = bleManager
        setupBindings()
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
                self?.batteryLevel = history.last?.percentage ?? 0
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
        
        // Subscribe to accelerometer data
        bleManager.$accelerometerHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$accelerometerHistory)
        
        // Subscribe to PPG data
        bleManager.$ppgHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$ppgHistory)
        
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
                        x: data.x,
                        y: data.y,
                        z: data.z
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
    
    // MARK: - Public Methods
    
    func startScanning() {
        bleManager.startScanning()
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
        // Implement recording logic if needed
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
        // This would create a CSV or JSON file and return its URL
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
    
    // MARK: - Formatting Helpers
    
    func formatHeartRate(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return String(format: "%.0f bpm", value)
    }
    
    func formatSpO2(_ value: Double?) -> String {
        guard let value = value else { return "--%" }
        return String(format: "%.0f%%", value)
    }
    
    func formatTemperature(_ value: Double) -> String {
        return String(format: "%.1f°C", value)
    }
    
    func formatBattery(_ percentage: Int) -> String {
        return "\(percentage)%"
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
