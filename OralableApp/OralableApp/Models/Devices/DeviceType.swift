//
//  DeviceType.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
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
