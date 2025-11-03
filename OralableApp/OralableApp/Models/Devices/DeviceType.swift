//
//  DeviceType.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//


//
//  DeviceInfo.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Device information model for multi-device support
//

import Foundation
import CoreBluetooth

/// Device type enumeration
enum DeviceType: String, Codable, CaseIterable {
    case oralable = "oralable"
    case anrMuscleSense = "anr_muscle_sense"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .oralable:
            return "Oralable"
        case .anrMuscleSense:
            return "ANR Muscle Sense"
        case .unknown:
            return "Unknown Device"
        }
    }
    
    var iconName: String {
        switch self {
        case .oralable:
            return "waveform.path.ecg"
        case .anrMuscleSense:
            return "bolt.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

/// Device connection state
enum DeviceConnectionState: String, Codable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error
    
    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .error:
            return "Error"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .connected, .connecting:
            return true
        default:
            return false
        }
    }
}

/// Complete device information
struct DeviceInfo: Identifiable, Codable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier
    let id: UUID
    
    /// Device type
    let type: DeviceType
    
    /// Device name
    let name: String
    
    /// Bluetooth peripheral identifier
    let peripheralIdentifier: UUID?
    
    /// Connection state
    var connectionState: DeviceConnectionState
    
    /// Battery level (0-100)
    var batteryLevel: Int?
    
    /// Signal strength (RSSI)
    var signalStrength: Int?
    
    /// Firmware version
    var firmwareVersion: String?
    
    /// Hardware version
    var hardwareVersion: String?
    
    /// Last connection timestamp
    var lastConnected: Date?
    
    /// Supported sensor types
    let supportedSensors: [SensorType]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: DeviceType,
        name: String,
        peripheralIdentifier: UUID? = nil,
        connectionState: DeviceConnectionState = .disconnected,
        batteryLevel: Int? = nil,
        signalStrength: Int? = nil,
        firmwareVersion: String? = nil,
        hardwareVersion: String? = nil,
        lastConnected: Date? = nil,
        supportedSensors: [SensorType]? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.peripheralIdentifier = peripheralIdentifier
        self.connectionState = connectionState
        self.batteryLevel = batteryLevel
        self.signalStrength = signalStrength
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.lastConnected = lastConnected
        self.supportedSensors = supportedSensors ?? type.defaultSensors
    }
    
    // MARK: - Computed Properties
    
    /// Display name with connection state
    var statusText: String {
        "\(name) - \(connectionState.displayName)"
    }
    
    /// Battery level text
    var batteryText: String? {
        guard let level = batteryLevel else { return nil }
        return "\(level)%"
    }
    
    /// Signal strength description
    var signalText: String? {
        guard let rssi = signalStrength else { return nil }
        switch rssi {
        case -50...0:
            return "Excellent"
        case -70 ..< -50:
            return "Good"
        case -85 ..< -70:
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    /// Whether device is currently connected
    var isConnected: Bool {
        connectionState == .connected
    }
    
    /// Whether device is connecting
    var isConnecting: Bool {
        connectionState == .connecting
    }
    
    // MARK: - Static Helpers
    
    /// Create a mock device for testing
    static func mock(type: DeviceType = .oralable) -> DeviceInfo {
        DeviceInfo(
            type: type,
            name: type == .oralable ? "Oralable-001" : "ANR-MS-001",
            peripheralIdentifier: UUID(),
            connectionState: .connected,
            batteryLevel: 85,
            signalStrength: -55,
            firmwareVersion: "1.2.3",
            hardwareVersion: "2.0",
            lastConnected: Date()
        )
    }
}

// MARK: - DeviceType Default Sensors

extension DeviceType {
    
    /// Default sensors supported by each device type
    var defaultSensors: [SensorType] {
        switch self {
        case .oralable:
            return [
                .ppgRed,
                .ppgInfrared,
                .ppgGreen,
                .accelerometerX,
                .accelerometerY,
                .accelerometerZ,
                .temperature,
                .battery,
                .heartRate,
                .spo2
            ]
            
        case .anrMuscleSense:
            return [
                .emg,
                .battery,
                .muscleActivity
            ]
            
        case .unknown:
            return []
        }
    }
    
    /// Service UUID for BLE discovery
    var serviceUUID: CBUUID? {
        switch self {
        case .oralable:
            return CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        case .anrMuscleSense:
            return CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB")
        case .unknown:
            return nil
        }
    }
}

// MARK: - Array Extension

extension Array where Element == DeviceInfo {
    
    /// Get connected devices
    var connected: [DeviceInfo] {
        self.filter { $0.isConnected }
    }
    
    /// Get devices by type
    func devices(ofType type: DeviceType) -> [DeviceInfo] {
        self.filter { $0.type == type }
    }
    
    /// Find device by peripheral identifier
    func device(withPeripheralId peripheralId: UUID) -> DeviceInfo? {
        self.first { $0.peripheralIdentifier == peripheralId }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct DeviceInfoPreview: View {
    
    let devices: [DeviceInfo] = [
        .mock(type: .oralable),
        DeviceInfo(
            type: .anrMuscleSense,
            name: "ANR-MS-001",
            connectionState: .connecting,
            batteryLevel: 72,
            signalStrength: -68
        ),
        DeviceInfo(
            type: .oralable,
            name: "Oralable-002",
            connectionState: .disconnected,
            lastConnected: Date().addingTimeInterval(-3600)
        )
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Connected Devices") {
                    ForEach(devices.filter { $0.isConnected }) { device in
                        DeviceRow(device: device)
                    }
                }
                
                Section("Available Devices") {
                    ForEach(devices.filter { !$0.isConnected }) { device in
                        DeviceRow(device: device)
                    }
                }
                
                Section("Device Types") {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(DesignSystem.Typography.bodyLarge)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text("\(type.defaultSensors.count) sensors")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .background(DesignSystem.Colors.backgroundPrimary)
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo
    
    var body: some View {
        HStack {
            Image(systemName: device.type.iconName)
                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(DesignSys