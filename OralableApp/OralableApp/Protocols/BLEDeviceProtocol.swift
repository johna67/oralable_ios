//
//  BLEDeviceProtocol.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Protocol defining interface for all BLE devices
//

import Foundation
import CoreBluetooth
import Combine

/// Protocol that all BLE devices must implement
protocol BLEDeviceProtocol: AnyObject {
    
    // MARK: - Device Information
    
    /// Device information structure
    var deviceInfo: DeviceInfo { get }
    
    /// Device type
    var deviceType: DeviceType { get }
    
    /// Device name
    var name: String { get }
    
    /// BLE peripheral
    var peripheral: CBPeripheral? { get }
    
    // MARK: - Connection State
    
    /// Current connection state
    var connectionState: DeviceConnectionState { get }
    
    /// Whether device is currently connected
    var isConnected: Bool { get }
    
    /// Signal strength (RSSI)
    var signalStrength: Int? { get }
    
    // MARK: - Battery & System Info
    
    /// Current battery level (0-100)
    var batteryLevel: Int? { get }
    
    /// Firmware version
    var firmwareVersion: String? { get }
    
    /// Hardware version
    var hardwareVersion: String? { get }
    
    // MARK: - Sensor Data
    
    /// Publisher for sensor readings
    var sensorReadings: AnyPublisher<SensorReading, Never> { get }
    
    /// Latest readings by sensor type
    var latestReadings: [SensorType: SensorReading] { get }
    
    /// List of supported sensors
    var supportedSensors: [SensorType] { get }
    
    // MARK: - Connection Management
    
    /// Connect to the device
    func connect() async throws
    
    /// Disconnect from the device
    func disconnect() async
    
    /// Check if device is available
    func isAvailable() -> Bool
    
    // MARK: - Data Operations
    
    /// Start streaming sensor data
    func startDataStream() async throws
    
    /// Stop streaming sensor data
    func stopDataStream() async
    
    /// Request current sensor reading
    func requestReading(for sensorType: SensorType) async throws -> SensorReading?
    
    /// Parse raw BLE data into sensor readings
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading]
    
    // MARK: - Device Control
    
    /// Send command to device
    func sendCommand(_ command: DeviceCommand) async throws
    
    /// Update device configuration
    func updateConfiguration(_ config: DeviceConfiguration) async throws
    
    /// Request device information update
    func updateDeviceInfo() async throws
}

// MARK: - Device Command

/// Commands that can be sent to devices
enum DeviceCommand {
    case startSensors
    case stopSensors
    case reset
    case calibrate
    case setSamplingRate(Hz: Int)
    case enableSensor(SensorType)
    case disableSensor(SensorType)
    case requestBatteryLevel
    case requestFirmwareVersion
    
    var rawValue: String {
        switch self {
        case .startSensors:
            return "START"
        case .stopSensors:
            return "STOP"
        case .reset:
            return "RESET"
        case .calibrate:
            return "CALIBRATE"
        case .setSamplingRate(let hz):
            return "RATE:\(hz)"
        case .enableSensor(let type):
            return "ENABLE:\(type.rawValue)"
        case .disableSensor(let type):
            return "DISABLE:\(type.rawValue)"
        case .requestBatteryLevel:
            return "BATTERY?"
        case .requestFirmwareVersion:
            return "VERSION?"
        }
    }
}

// MARK: - Device Configuration

/// Configuration settings for devices
struct DeviceConfiguration {
    
    /// Sampling rate in Hz
    var samplingRate: Int
    
    /// Enabled sensors
    var enabledSensors: Set<SensorType>
    
    /// Auto-reconnect on disconnect
    var autoReconnect: Bool
    
    /// Notification preferences
    var notificationsEnabled: Bool
    
    /// Data buffer size
    var bufferSize: Int
    
    // MARK: - Default Configurations
    
    static let defaultOralable = DeviceConfiguration(
        samplingRate: 50,
        enabledSensors: [
            .ppgRed,
            .ppgInfrared,
            .ppgGreen,
            .accelerometerX,
            .accelerometerY,
            .accelerometerZ,
            .temperature,
            .battery
        ],
        autoReconnect: true,
        notificationsEnabled: true,
        bufferSize: 100
    )
    
    static let defaultANR = DeviceConfiguration(
        samplingRate: 100,
        enabledSensors: [
            .emg,
            .battery
        ],
        autoReconnect: true,
        notificationsEnabled: true,
        bufferSize: 200
    )
}

// MARK: - Device Error

/// Errors that can occur with BLE devices
enum DeviceError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case disconnected
    case invalidPeripheral
    case characteristicNotFound(String)
    case serviceNotFound(String)
    case writeCommandFailed(String)
    case readFailed(String)
    case dataParsingFailed(String)
    case unsupportedSensor(SensorType)
    case timeout
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Device is not connected"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .disconnected:
            return "Device disconnected unexpectedly"
        case .invalidPeripheral:
            return "Invalid BLE peripheral"
        case .characteristicNotFound(let uuid):
            return "Characteristic not found: \(uuid)"
        case .serviceNotFound(let uuid):
            return "Service not found: \(uuid)"
        case .writeCommandFailed(let message):
            return "Failed to write command: \(message)"
        case .readFailed(let message):
            return "Failed to read data: \(message)"
        case .dataParsingFailed(let message):
            return "Failed to parse data: \(message)"
        case .unsupportedSensor(let type):
            return "Sensor not supported: \(type.displayName)"
        case .timeout:
            return "Operation timed out"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Protocol Extension (Default Implementations)

extension BLEDeviceProtocol {
    
    /// Check if specific sensor is supported
    func supports(sensor: SensorType) -> Bool {
        supportedSensors.contains(sensor)
    }
    
    /// Get latest reading for sensor type
    func latestReading(for sensorType: SensorType) -> SensorReading? {
        latestReadings[sensorType]
    }
    
    /// Check if device is streaming data
    var isStreaming: Bool {
        isConnected && connectionState == .connected
    }
}

// MARK: - Preview Helper

#if DEBUG

/// Mock device for testing
class MockBLEDevice: BLEDeviceProtocol {
    
    var deviceInfo: DeviceInfo
    var deviceType: DeviceType
    var name: String
    var peripheral: CBPeripheral?
    var connectionState: DeviceConnectionState = .disconnected
    var signalStrength: Int? = -55
    var batteryLevel: Int? = 85
    var firmwareVersion: String? = "1.0.0"
    var hardwareVersion: String? = "2.0"
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    var latestReadings: [SensorType: SensorReading] = [:]
    var supportedSensors: [SensorType]
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    init(type: DeviceType) {
        self.deviceType = type
        self.name = type.displayName
        self.deviceInfo = DeviceInfo.mock(type: type)
        self.supportedSensors = type.defaultSensors
    }
    
    func connect() async throws {
        connectionState = .connecting
        try await Task.sleep(nanoseconds: 500_000_000)
        connectionState = .connected
    }
    
    func disconnect() async {
        connectionState = .disconnecting
        try? await Task.sleep(nanoseconds: 200_000_000)
        connectionState = .disconnected
    }
    
    func isAvailable() -> Bool {
        true
    }
    
    func startDataStream() async throws {
        guard isConnected else { throw DeviceError.notConnected }
        // Simulate data streaming
    }
    
    func stopDataStream() async {
        // Stop streaming
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        guard isConnected else { throw DeviceError.notConnected }
        return SensorReading.mock(sensorType: sensorType)
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        []
    }
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else { throw DeviceError.notConnected }
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else { throw DeviceError.notConnected }
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else { throw DeviceError.notConnected }
    }
}

#endif
