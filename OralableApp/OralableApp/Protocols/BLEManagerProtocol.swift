//
//  BLEManagerProtocol.swift
//  OralableApp
//
//  Created: November 16, 2025
//  Protocol for BLE manager dependency injection to enable testing and eliminate dual managers
//

import Foundation
import Combine
import CoreBluetooth

/// Protocol defining the interface for BLE device management
/// This enables dependency injection and testing while eliminating the dual manager pattern
///
/// Note: Since protocols cannot use @Published, conforming types should publish changes via objectWillChange
@MainActor
protocol BLEManagerProtocol: AnyObject, ObservableObject {

    // MARK: - Connection State

    /// Whether any device is currently connected
    var isConnected: Bool { get }

    /// Whether scanning is in progress
    var isScanning: Bool { get }

    /// Name of the primary connected device
    var deviceName: String { get }

    /// Whether recording is in progress
    var isRecording: Bool { get }

    // MARK: - Real-time Sensor Values

    /// Current heart rate in BPM
    var heartRate: Int { get }

    /// Current SpO2 percentage
    var spO2: Int { get }

    /// Current temperature in Celsius
    var temperature: Double { get }

    /// Current battery level (0.0-100.0)
    var batteryLevel: Double { get }

    /// Accelerometer X-axis value
    var accelX: Double { get }

    /// Accelerometer Y-axis value
    var accelY: Double { get }

    /// Accelerometer Z-axis value
    var accelZ: Double { get }

    /// PPG Red channel value
    var ppgRedValue: Double { get }

    /// PPG Infrared channel value
    var ppgIRValue: Double { get }

    /// PPG Green channel value
    var ppgGreenValue: Double { get }

    /// Heart rate signal quality (0.0-1.0)
    var heartRateQuality: Double { get }

    /// PPG channel order configuration
    var ppgChannelOrder: PPGChannelOrder { get set }

    // MARK: - Publishers (for Combine bindings)
    // Note: These allow ViewModels to observe specific property changes

    var isConnectedPublisher: Published<Bool>.Publisher { get }
    var isScanningPublisher: Published<Bool>.Publisher { get }
    var batteryLevelPublisher: Published<Double>.Publisher { get }
    var heartRatePublisher: Published<Int>.Publisher { get }
    var spO2Publisher: Published<Int>.Publisher { get }
    var ppgRedValuePublisher: Published<Double>.Publisher { get }
    var accelXPublisher: Published<Double>.Publisher { get }
    var accelYPublisher: Published<Double>.Publisher { get }
    var accelZPublisher: Published<Double>.Publisher { get }
    var temperaturePublisher: Published<Double>.Publisher { get }
    var heartRateQualityPublisher: Published<Double>.Publisher { get }

    // Note: deviceName is computed from primaryDevice, so we observe primaryDevice changes via objectWillChange

    // MARK: - Device Discovery & Connection

    /// Start scanning for BLE devices
    func startScanning()

    /// Stop scanning for BLE devices
    func stopScanning()

    /// Connect to a specific peripheral
    func connect(to peripheral: CBPeripheral)

    /// Disconnect from the current device
    func disconnect()

    // MARK: - Recording

    /// Start recording sensor data
    func startRecording()

    /// Stop recording sensor data
    func stopRecording()

    // MARK: - Data Management

    /// Clear all historical data
    func clearHistory()
}
