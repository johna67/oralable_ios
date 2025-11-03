//
//  DeviceManager.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//


//
//  DeviceManager.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Manages multiple BLE devices and coordinates device operations
//

import Foundation
import CoreBluetooth
import Combine

/// Manager for coordinating multiple BLE devices
@MainActor
class DeviceManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All discovered devices
    @Published var discoveredDevices: [DeviceInfo] = []
    
    /// Currently connected devices
    @Published var connectedDevices: [DeviceInfo] = []
    
    /// Primary active device
    @Published var primaryDevice: DeviceInfo?
    
    /// All sensor readings from all devices
    @Published var allSensorReadings: [SensorReading] = []
    
    /// Latest readings by sensor type (aggregated from all devices)
    @Published var latestReadings: [SensorType: SensorReading] = [:]
    
    /// Connection state
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    
    /// Errors
    @Published var lastError: DeviceError?
    
    // MARK: - Private Properties
    
    private var devices: [UUID: BLEDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxDevices: Int = 5
    
    // MARK: - Initialization
    
    init() {
        // Setup will be completed when actual device implementations are ready
    }
    
    // MARK: - Device Discovery
    
    /// Start scanning for devices
    func startScanning() async {
        isScanning = true
        
        // TODO: Implement actual BLE scanning when device classes are ready
        // For now, this is a skeleton
        
        await Task.sleep(1_000_000_000) // 1 second simulation
        isScanning = false
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        isScanning = false
        
        // TODO: Stop BLE scanning
    }
    
    /// Add discovered device
    func addDiscoveredDevice(_ device: BLEDeviceProtocol) {
        let deviceInfo = device.deviceInfo
        
        // Check if already discovered
        guard !discoveredDevices.contains(where: { $0.id == deviceInfo.id }) else {
            return
        }
        
        // Check max devices limit
        guard discoveredDevices.count < maxDevices else {
            lastError = .unknownError("Maximum device limit reached")
            return
        }
        
        discoveredDevices.append(deviceInfo)
        devices[deviceInfo.id] = device
        
        // Subscribe to device sensor readings
        subscribeToDevice(device)
    }
    
    // MARK: - Connection Management
    
    /// Connect to a device
    func connect(to deviceInfo: DeviceInfo) async throws {
        guard let device = devices[deviceInfo.id] else {
            throw DeviceError.invalidPeripheral
        }
        
        isConnecting = true
        
        do {
            try await device.connect()
            
            // Update device info
            if let index = discoveredDevices.firstIndex(where: { $0.id == deviceInfo.id }) {
                discoveredDevices[index].connectionState = .connected
            }
            
            // Add to connected devices
            if !connectedDevices.contains(where: { $0.id == deviceInfo.id }) {
                connectedDevices.append(device.deviceInfo)
            }
            
            // Set as primary if first device
            if primaryDevice == nil {
                primaryDevice = device.deviceInfo
            }
            
            // Start data stream
            try await device.startDataStream()
            
            isConnecting = false
            
        } catch {
            isConnecting = false
            lastError = .connectionFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Disconnect from a device
    func disconnect(from deviceInfo: DeviceInfo) async {
        guard let device = devices[deviceInfo.id] else {
            return
        }
        
        await device.stopDataStream()
        await device.disconnect()
        
        // Update device info
        if let index = discoveredDevices.firstIndex(where: { $0.id == deviceInfo.id }) {
            discoveredDevices[index].connectionState = .disconnected
        }
        
        // Remove from connected devices
        connectedDevices.removeAll { $0.id == deviceInfo.id }
        
        // Clear primary if it was the primary device
        if primaryDevice?.id == deviceInfo.id {
            primaryDevice = connectedDevices.first
        }
    }
    
    /// Disconnect all devices
    func disconnectAll() async {
        for deviceInfo in connectedDevices {
            await disconnect(from: deviceInfo)
        }
    }
    
    /// Set primary device
    func setPrimaryDevice(_ deviceInfo: DeviceInfo) {
        guard connectedDevices.contains(where: { $0.id == deviceInfo.id }) else {
            return
        }
        
        primaryDevice = deviceInfo
    }
    
    // MARK: - Data Management
    
    /// Subscribe to device sensor readings
    private func subscribeToDevice(_ device: BLEDeviceProtocol) {
        device.sensorReadings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reading in
                self?.handleSensorReading(reading, from: device.deviceInfo)
            }
            .store(in: &cancellables)
    }
    
    /// Handle incoming sensor reading
    private func handleSensorReading(_ reading: SensorReading, from deviceInfo: DeviceInfo) {
        // Add to all readings
        allSensorReadings.append(reading)
        
        // Update latest reading for this sensor type
        latestReadings[reading.sensorType] = reading
        
        // Keep only last 1000 readings to prevent memory issues
        if allSensorReadings.count > 1000 {
            allSensorReadings.removeFirst(allSensorReadings.count - 1000)
        }
    }
    
    /// Get readings for specific device
    func readings(for deviceInfo: DeviceInfo) -> [SensorReading] {
        allSensorReadings.filter { $0.deviceId == deviceInfo.id.uuidString }
    }
    
    /// Get readings for specific sensor type
    func readings(for sensorType: SensorType) -> [SensorReading] {
        allSensorReadings.filter { $0.sensorType == sensorType }
    }
    
    /// Get latest reading for sensor type
    func latestReading(for sensorType: SensorType) -> SensorReading? {
        latestReadings[sensorType]
    }
    
    /// Clear all readings
    func clearReadings() {
        allSensorReadings.removeAll()
        latestReadings.removeAll()
    }
    
    // MARK: - Device Control
    
    /// Send command to device
    func sendCommand(_ command: DeviceCommand, to deviceInfo: DeviceInfo) async throws {
        guard let device = devices[deviceInfo.id] else {
            throw DeviceError.invalidPeripheral
        }
        
        try await device.sendCommand(command)
    }
    
    /// Send command to all connected devices
    func sendCommandToAll(_ command: DeviceCommand) async throws {
        for deviceInfo in connectedDevices {
            try await sendCommand(command, to: deviceInfo)
        }
    }
    
    /// Update device configuration
    func updateConfiguration(_ config: DeviceConfiguration, for deviceInfo: DeviceInfo) async throws {
        guard let device = devices[deviceInfo.id] else {
            throw DeviceError.invalidPeripheral
        }
        
        try await device.updateConfiguration(config)
    }
    
    // MARK: - Device Information
    
    /// Get device by ID
    func device(withId id: UUID) -> DeviceInfo? {
        discoveredDevices.first { $0.id == id }
    }
    
    /// Get connected device by type
    func connectedDevice(ofType type: DeviceType) -> DeviceInfo? {
        connectedDevices.first { $0.type == type }
    }
    
    /// Check if device is connected
    func isConnected(_ deviceInfo: DeviceInfo) -> Bool {
        connectedDevices.contains { $0.id == deviceInfo.id }
    }
    
    /// Get device count by type
    func deviceCount(ofType type: DeviceType) -> Int {
        discoveredDevices.filter { $0.type == type }.count
    }
    
    // MARK: - Cleanup
    
    /// Remove device
    func removeDevice(_ deviceInfo: DeviceInfo) async {
        // Disconnect if connected
        if isConnected(deviceInfo) {
            await disconnect(from: deviceInfo)
        }
        
        // Remove from discovered
        discoveredDevices.removeAll { $0.id == deviceInfo.id }
        
        // Remove from devices dictionary
        devices.removeValue(forKey: deviceInfo.id)
    }
    
    /// Clear all devices
    func clearAllDevices() async {
        await disconnectAll()
        discoveredDevices.removeAll()
        connectedDevices.removeAll()
        devices.removeAll()
        primaryDevice = nil
        clearReadings()
    }
}

// MARK: - Convenience Extensions

extension DeviceManager {
    
    /// Get Oralable device if connected
    var oralableDevice: DeviceInfo? {
        connectedDevice(ofType: .oralable)
    }
    
    /// Get ANR device if connected
    var anrDevice: DeviceInfo? {
        connectedDevice(ofType: .anrMuscleSense)
    }
    
    /// Check if any device is connected
    var hasConnectedDevice: Bool {
        !connectedDevices.isEmpty
    }
    
    /// Check if Oralable device is connected
    var hasOralableConnected: Bool {
        oralableDevice != nil
    }
    
    /// Check if ANR device is connected
    var hasANRConnected: Bool {
        anrDevice != nil
    }
}

// MARK: - Preview Helper

#if DEBUG

extension DeviceManager {
    
    /// Create manager with mock devices for testing
    static func mock() -> DeviceManager {
        let manager = DeviceManager()
        
        // Add mock Oralable device
        let oralableDevice = MockBLEDevice(type: .oralable)
        manager.addDiscoveredDevice(oralableDevice)
        
        // Add mock ANR device
        let anrDevice = MockBLEDevice(type: .anrMuscleSense)
        manager.addDiscoveredDevice(anrDevice)
        
        // Simulate some sensor readings
        manager.allSensorReadings = [
            .mock(sensorType: .heartRate),
            .mock(sensorType: .spo2),
            .mock(sensorType: .temperature),
            .mock(sensorType: .emg)
        ]
        
        manager.latestReadings = [
            .heartRate: .mock(sensorType: .heartRate),
            .spo2: .mock(sensorType: .spo2),
            .temperature: .mock(sensorType: .temperature),
            .emg: .mock(sensorType: .emg)
        ]
        
        return manager
    }
}

#endif