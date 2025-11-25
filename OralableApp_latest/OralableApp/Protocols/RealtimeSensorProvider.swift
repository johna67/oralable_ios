//
//  RealtimeSensorProvider.swift
//  OralableApp
//
//  Created: Refactoring Phase 3 - Breaking Down God Objects
//  Purpose: Protocol for real-time sensor values, reducing OralableBLE's responsibilities
//

import Foundation
import Combine

/// Protocol for providing real-time sensor readings
/// Extracts raw sensor data responsibilities from OralableBLE
/// Note: These are HIGH FREQUENCY updates (up to 100Hz)
@MainActor
protocol RealtimeSensorProvider: AnyObject {
    // MARK: - Accelerometer (High Frequency)

    /// X-axis acceleration in g
    var accelX: Double { get }

    /// Y-axis acceleration in g
    var accelY: Double { get }

    /// Z-axis acceleration in g
    var accelZ: Double { get }

    // MARK: - PPG Sensors (High Frequency)

    /// Red LED PPG value
    var ppgRedValue: Double { get }

    /// Infrared LED PPG value
    var ppgIRValue: Double { get }

    /// Green LED PPG value
    var ppgGreenValue: Double { get }

    // MARK: - Environmental Sensors

    /// Temperature in Celsius
    var temperature: Double { get }

    /// Battery level percentage (0-100)
    var batteryLevel: Double { get }

    // MARK: - Publishers for Reactive UI
    // Note: Consider throttling these in ViewModels to avoid 100Hz UI updates

    var accelXPublisher: Published<Double>.Publisher { get }
    var accelYPublisher: Published<Double>.Publisher { get }
    var accelZPublisher: Published<Double>.Publisher { get }
    var ppgRedValuePublisher: Published<Double>.Publisher { get }
    var ppgIRValuePublisher: Published<Double>.Publisher { get }
    var ppgGreenValuePublisher: Published<Double>.Publisher { get }
    var temperaturePublisher: Published<Double>.Publisher { get }
    var batteryLevelPublisher: Published<Double>.Publisher { get }
}

// MARK: - Throttled Access Helper

extension RealtimeSensorProvider {
    /// Creates a throttled publisher for high-frequency sensor data
    /// - Parameter interval: Throttling interval in seconds (default: 0.1s = 10Hz)
    /// - Returns: Combined publisher with throttled sensor values
    func throttledSensorPublisher(interval: TimeInterval = 0.1) -> AnyPublisher<RealtimeSensorSnapshot, Never> {
        Publishers.CombineLatest4(
            accelXPublisher,
            accelYPublisher,
            accelZPublisher,
            temperaturePublisher
        )
        .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
        .map { accelX, accelY, accelZ, temperature in
            RealtimeSensorSnapshot(
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                temperature: temperature
            )
        }
        .eraseToAnyPublisher()
    }

    /// Creates a throttled publisher for PPG data
    /// - Parameter interval: Throttling interval in seconds (default: 0.05s = 20Hz)
    /// - Returns: Combined publisher with throttled PPG values
    func throttledPPGPublisher(interval: TimeInterval = 0.05) -> AnyPublisher<PPGSnapshot, Never> {
        Publishers.CombineLatest3(
            ppgRedValuePublisher,
            ppgIRValuePublisher,
            ppgGreenValuePublisher
        )
        .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
        .map { red, ir, green in
            PPGSnapshot(red: red, infrared: ir, green: green)
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

/// Snapshot of real-time sensor values
struct RealtimeSensorSnapshot {
    let accelX: Double
    let accelY: Double
    let accelZ: Double
    let temperature: Double
}

/// Snapshot of PPG sensor values
struct PPGSnapshot {
    let red: Double
    let infrared: Double
    let green: Double
}
