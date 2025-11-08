//
//  DeviceManager.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//  Updated: November 4, 2025
//  Manages multiple BLE devices and coordinates device operations
//

import Foundation
import CoreBluetooth
import Combine

/// Manager for coordinating multiple BLE devices
@MainActor
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()  // ADD THIS LINE

    
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
    
    // BLE Integration
    private var bleManager: BLECentralManager?
    
    // MARK: - Initialization
    
    init() {
        bleManager = BLECentralManager()
        setupBLECallbacks()
    }
    
    // MARK: - BLE Callbacks Setup
    
    private func setupBLECallbacks() {
        bleManager?.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            Task { @MainActor [weak self] in
                self?.handleDeviceDiscovered(peripheral: peripheral, name: name, rssi: rssi)
            }
        }
        
        bleManager?.onDeviceConnected = { [weak self] peripheral in
            Task { @MainActor [weak self] in
                self?.handleDeviceConnected(peripheral: peripheral)
            }
        }
        
        bleManager?.onDeviceDisconnected = { [weak self] peripheral, error in
            Task { @MainActor [weak self] in
                self?.handleDeviceDisconnected(peripheral: peripheral, error: error)
            }
        }
        
        bleManager?.onBluetoothStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                if state != .poweredOn && (self?.isScanning ?? false) {
                    self?.isScanning = false
                }
            }
        }
    }
    
    // MARK: - Device Discovery Handlers
    
    private func handleDeviceDiscovered(peripheral: CBPeripheral, name: String, rssi: Int) {
        // Check if already discovered
        if discoveredDevices.contains(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            // Update RSSI
            if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                discoveredDevices[index].signalStrength = rssi
            }
            return
        }
        
        // Determine device type
        let deviceType = detectDeviceType(from: name, peripheral: peripheral)
        
        guard deviceType != .unknown else {
            print("⚠️ Unknown device type: \(name)")
            return
        }
        
        // Create appropriate device instance
        let device: BLEDeviceProtocol
        switch deviceType {
        case .oralable:
            device = OralableDevice(peripheral: peripheral, name: name)
        case .anrMuscleSense:
            device = ANRMuscleSenseDevice(peripheral: peripheral, name: name)
        case .unknown:
            return
        }
        
        // Update signal strength
        var deviceInfo = device.deviceInfo
        deviceInfo.signalStrength = rssi
        
        // Add to discovered devices
        addDiscoveredDevice(device)
        
        print("✅ Discovered: \(name) (\(deviceType.displayName))")
    }
    
    private func handleDeviceConnected(peripheral: CBPeripheral) {
        print("✅ Device connected: \(peripheral.name ?? "Unknown")")
        
        // Find device by peripheral identifier
        guard let device = devices.values.first(where: { $0.peripheral?.identifier == peripheral.identifier }) else {
            print("⚠️ Connected device not found in devices dictionary")
            return
        }
        
        // Update device info
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            discoveredDevices[index].connectionState = .connected
            discoveredDevices[index].lastConnected = Date()
        }
        
        // Add to connected devices if not already there
        if !connectedDevices.contains(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            var connectedInfo = device.deviceInfo
            connectedInfo.connectionState = .connected
            connectedInfo.lastConnected = Date()
            connectedDevices.append(connectedInfo)
        }
        
        // Set as primary if first device
        if primaryDevice == nil {
            primaryDevice = device.deviceInfo
        }
        
        // Start data stream
        Task {
            do {
                try await device.startDataStream()
                print("✅ Data stream started for: \(device.name)")
            } catch {
                print("❌ Failed to start data stream: \(error.localizedDescription)")
                lastError = .unknownError(error.localizedDescription)
            }
        }
        
        isConnecting = false
    }
    
    private func handleDeviceDisconnected(peripheral: CBPeripheral, error: Error?) {
        print("📱 Device disconnected: \(peripheral.name ?? "Unknown")")
        
        // Find device by peripheral identifier
        if let deviceInfo = discoveredDevices.first(where: { $0.peripheralIdentifier == peripheral.identifier }) {
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
            
            if let error = error {
                print("❌ Disconnection error: \(error.localizedDescription)")
                lastError = .connectionFailed(error.localizedDescription)
            }
        }
        
        isConnecting = false
    }
    
    private func detectDeviceType(from name: String, peripheral: CBPeripheral) -> DeviceType {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("oralable") {
            return .oralable
        } else if lowercaseName.contains("anr") || lowercaseName.contains("muscle") {
            return .anrMuscleSense
        }
        
        return .unknown
    }
    
    // MARK: - Device Discovery
    
    /// Start scanning for devices
    func startScanning() async {
        print("🔍 Starting device scan...")
        isScanning = true
        bleManager?.startScanning()
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        print("⏹️ Stopping device scan")
        isScanning = false
        bleManager?.stopScanning()
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
        
        guard let peripheral = device.peripheral else {
            throw DeviceError.invalidPeripheral
        }
        
        isConnecting = true
        
        print("📱 Connecting to: \(deviceInfo.name)")
        
        // Update state
        if let index = discoveredDevices.firstIndex(where: { $0.id == deviceInfo.id }) {
            discoveredDevices[index].connectionState = .connecting
        }
        
        // Connect via BLE manager
        bleManager?.connect(to: peripheral)
        
        // Note: Actual connection completion handled by callback
        // The device will be moved to connected state in handleDeviceConnected
    }
    
    /// Disconnect from a device
    func disconnect(from deviceInfo: DeviceInfo) async {
        guard let device = devices[deviceInfo.id] else {
            return
        }
        
        guard let peripheral = device.peripheral else {
            return
        }
        
        print("📱 Disconnecting from: \(deviceInfo.name)")
        
        // Update state
        if let index = discoveredDevices.firstIndex(where: { $0.id == deviceInfo.id }) {
            discoveredDevices[index].connectionState = .disconnecting
        }
        
        await device.stopDataStream()
        bleManager?.disconnect(from: peripheral)
        await device.disconnect()
    }
    
    /// Disconnect all devices
    func disconnectAll() async {
        print("📱 Disconnecting all devices")
        
        bleManager?.disconnectAll()
        
        for deviceInfo in connectedDevices {
            if let device = devices[deviceInfo.id] {
                await device.stopDataStream()
                await device.disconnect()
            }
        }
        
        connectedDevices.removeAll()
        primaryDevice = nil
    }
    
    /// Set primary device
    func setPrimaryDevice(_ deviceInfo: DeviceInfo) {
        guard connectedDevices.contains(where: { $0.id == deviceInfo.id }) else {
            print("⚠️ Cannot set primary device - not connected")
            return
        }
        
        print("📱 Primary device set to: \(deviceInfo.name)")
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
        print("🗑️ Removing device: \(deviceInfo.name)")
        
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
        print("🗑️ Clearing all devices")
        
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
    
    /// Get all Oralable devices (discovered)
    var oralableDevices: [DeviceInfo] {
        discoveredDevices.filter { $0.type == .oralable }
    }
    
    /// Get all ANR devices (discovered)
    var anrDevices: [DeviceInfo] {
        discoveredDevices.filter { $0.type == .anrMuscleSense }
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
            .mock(sensorType: .heartRate, value: 72),
            .mock(sensorType: .spo2, value: 98),
            .mock(sensorType: .temperature, value: 36.5),
            .mock(sensorType: .emg, value: 450)
        ]
        
        manager.latestReadings = [
            .heartRate: .mock(sensorType: .heartRate, value: 72),
            .spo2: .mock(sensorType: .spo2, value: 98),
            .temperature: .mock(sensorType: .temperature, value: 36.5),
            .emg: .mock(sensorType: .emg, value: 450)
        ]
        
        // Set one device as connected
        manager.connectedDevices = [oralableDevice.deviceInfo]
        manager.primaryDevice = oralableDevice.deviceInfo
        
        return manager
    }
    
    /// Create manager with Oralable device connected
    static func mockWithOralable() -> DeviceManager {
        let manager = DeviceManager()
        
        let oralableDevice = MockBLEDevice(type: .oralable)
        manager.addDiscoveredDevice(oralableDevice)
        
        var connectedInfo = oralableDevice.deviceInfo
        connectedInfo.connectionState = .connected
        connectedInfo.batteryLevel = 85
        connectedInfo.firmwareVersion = "0.13.0"
        
        manager.connectedDevices = [connectedInfo]
        manager.primaryDevice = connectedInfo
        
        // Add realistic sensor data
        manager.latestReadings = [
            .heartRate: .mock(sensorType: .heartRate, value: 72),
            .spo2: .mock(sensorType: .spo2, value: 98),
            .temperature: .mock(sensorType: .temperature, value: 36.5),
            .battery: .mock(sensorType: .battery, value: 85),
            .ppgInfrared: .mock(sensorType: .ppgInfrared, value: 1856),
            .ppgRed: .mock(sensorType: .ppgRed, value: 2048)
        ]
        
        return manager
    }
    
    /// Create manager with ANR device connected
    static func mockWithANR() -> DeviceManager {
        let manager = DeviceManager()
        
        let anrDevice = MockBLEDevice(type: .anrMuscleSense)
        manager.addDiscoveredDevice(anrDevice)
        
        var connectedInfo = anrDevice.deviceInfo
        connectedInfo.connectionState = .connected
        connectedInfo.batteryLevel = 92
        connectedInfo.firmwareVersion = "1.0.0"
        
        manager.connectedDevices = [connectedInfo]
        manager.primaryDevice = connectedInfo
        
        // Add EMG data
        manager.latestReadings = [
            .emg: .mock(sensorType: .emg, value: 450),
            .battery: .mock(sensorType: .battery, value: 92),
            .muscleActivity: .mock(sensorType: .muscleActivity, value: 520)
        ]
        
        return manager
    }
}

#endif
