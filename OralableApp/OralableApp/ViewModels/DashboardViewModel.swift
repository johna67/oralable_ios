//
//  DashboardViewModel.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


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
    
    // Historical data for charts
    @Published var batteryHistory: [BatteryData] = []
    @Published var heartRateHistory: [HeartRateData] = []
    @Published var spo2History: [SpO2Data] = []
    @Published var temperatureHistory: [TemperatureData] = []
    @Published var accelerometerHistory: [AccelerometerData] = []
    @Published var ppgHistory: [PPGData] = []
    
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
    
    // MARK: - Initialization
    
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
        
        // Subscribe to historical data
        bleManager.$batteryHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.batteryHistory = history
                self?.batteryLevel = history.last?.percentage ?? 0
            }
            .store(in: &cancellables)
        
        bleManager.$heartRateHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.heartRateHistory = history
                self?.currentHeartRate = history.last?.bpm
            }
            .store(in: &cancellables)
        
        bleManager.$spo2History
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.spo2History = history
                self?.currentSpO2 = history.last?.percentage
            }
            .store(in: &cancellables)
        
        bleManager.$temperatureHistory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] history in
                self?.temperatureHistory = history
                self?.currentTemperature = history.last?.celsius ?? 36.0
            }
            .store(in: &cancellables)
        
        bleManager.$accelerometerHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$accelerometerHistory)
        
        bleManager.$ppgHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$ppgHistory)
        
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
        bleManager.toggleScanning()
    }
    
    func refreshScan() {
        bleManager.refreshScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        bleManager.connect(to: peripheral)
    }
    
    func disconnect() {
        bleManager.disconnect()
    }
    
    func resetBLE() {
        bleManager.resetBLE()
    }
    
    // MARK: - Data Access
    
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics? {
        return bleManager.getHistoricalMetrics(for: range)
    }
    
    func getRecentDataPoints(count: Int) -> [SensorData] {
        let history = bleManager.sensorDataHistory
        return Array(history.suffix(count))
    }
    
    // MARK: - Convenience Accessors (for backward compatibility during transition)
    
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

// MARK: - Mock for Previews

extension DashboardViewModel {
    static func mock() -> DashboardViewModel {
        let mockBLE = OralableBLE.mock()
        return DashboardViewModel(bleManager: mockBLE)
    }
}
