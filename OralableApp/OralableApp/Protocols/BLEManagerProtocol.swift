//
//  BLEManagerProtocol.swift
//  OralableApp
//
//  Created: Refactoring Phase 1
//  Purpose: Protocol abstraction for BLE manager to enable dependency injection and testing
//

import Foundation
import Combine
import CoreBluetooth

/// Protocol defining the BLE manager interface
/// Enables dependency injection, mocking, and testing
@MainActor
protocol BLEManagerProtocol: AnyObject {
    // MARK: - Connection State
    var isConnected: Bool { get }
    var isScanning: Bool { get }
    var deviceName: String { get }
    var connectionState: String { get }
    var deviceUUID: UUID? { get }

    // MARK: - Sensor Readings (Current Values)
    var heartRate: Int { get }
    var spO2: Int { get }
    var heartRateQuality: Double { get }
    var temperature: Double { get }
    var batteryLevel: Double { get }
    var accelX: Double { get }
    var accelY: Double { get }
    var accelZ: Double { get }

    // MARK: - PPG Data (Current Values)
    var ppgRedValue: Double { get }
    var ppgIRValue: Double { get }
    var ppgGreenValue: Double { get }

    // MARK: - Recording State
    var isRecording: Bool { get }

    // MARK: - Device State
    var deviceState: DeviceStateResult? { get }

    // MARK: - Actions
    func startScanning()
    func stopScanning()
    func connect(to peripheral: CoreBluetooth.CBPeripheral)
    func disconnect()
    func startRecording()
    func stopRecording()
    func clearHistory()

    // MARK: - Publishers for Reactive UI
    var isConnectedPublisher: Published<Bool>.Publisher { get }
    var isScanningPublisher: Published<Bool>.Publisher { get }
    var deviceNamePublisher: Published<String>.Publisher { get }
    var heartRatePublisher: Published<Int>.Publisher { get }
    var spO2Publisher: Published<Int>.Publisher { get }
    var heartRateQualityPublisher: Published<Double>.Publisher { get }
    var temperaturePublisher: Published<Double>.Publisher { get }
    var batteryLevelPublisher: Published<Double>.Publisher { get }
    var ppgRedValuePublisher: Published<Double>.Publisher { get }
    var ppgIRValuePublisher: Published<Double>.Publisher { get }
    var ppgGreenValuePublisher: Published<Double>.Publisher { get }
    var accelXPublisher: Published<Double>.Publisher { get }
    var accelYPublisher: Published<Double>.Publisher { get }
    var accelZPublisher: Published<Double>.Publisher { get }
    var isRecordingPublisher: Published<Bool>.Publisher { get }
    var deviceStatePublisher: Published<DeviceStateResult?>.Publisher { get }
}

// MARK: - OralableBLE Conformance

extension OralableBLE: BLEManagerProtocol {
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    var isScanningPublisher: Published<Bool>.Publisher { $isScanning }
    var deviceNamePublisher: Published<String>.Publisher { $deviceName }
    var heartRatePublisher: Published<Int>.Publisher { $heartRate }
    var spO2Publisher: Published<Int>.Publisher { $spO2 }
    var heartRateQualityPublisher: Published<Double>.Publisher { $heartRateQuality }
    var temperaturePublisher: Published<Double>.Publisher { $temperature }
    var batteryLevelPublisher: Published<Double>.Publisher { $batteryLevel }
    var ppgRedValuePublisher: Published<Double>.Publisher { $ppgRedValue }
    var ppgIRValuePublisher: Published<Double>.Publisher { $ppgIRValue }
    var ppgGreenValuePublisher: Published<Double>.Publisher { $ppgGreenValue }
    var accelXPublisher: Published<Double>.Publisher { $accelX }
    var accelYPublisher: Published<Double>.Publisher { $accelY }
    var accelZPublisher: Published<Double>.Publisher { $accelZ }
    var isRecordingPublisher: Published<Bool>.Publisher { $isRecording }
    var deviceStatePublisher: Published<DeviceStateResult?>.Publisher { $deviceState }
}
