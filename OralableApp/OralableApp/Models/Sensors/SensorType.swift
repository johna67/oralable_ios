//
//  SensorType.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//


//
//  SensorType.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Defines all sensor types across multiple devices
//

import Foundation

/// Enumeration of all supported sensor types
enum SensorType: String, Codable, CaseIterable {
    
    // MARK: - Optical Sensors
    
    /// Photoplethysmography Red channel (Oralable)
    case ppgRed = "ppg_red"
    
    /// Photoplethysmography Infrared channel (Oralable)
    /// CRITICAL: EMG data from ANR is equivalent to this
    case ppgInfrared = "ppg_infrared"
    
    /// Photoplethysmography Green channel (Oralable)
    case ppgGreen = "ppg_green"
    
    /// Electromyography (ANR Muscle Sense)
    /// CRITICAL: Processed identically to ppgInfrared
    case emg = "emg"
    
    // MARK: - Motion Sensors
    
    /// Accelerometer X-axis
    case accelerometerX = "accel_x"
    
    /// Accelerometer Y-axis
    case accelerometerY = "accel_y"
    
    /// Accelerometer Z-axis
    case accelerometerZ = "accel_z"
    
    // MARK: - Environmental Sensors
    
    /// Temperature in Celsius
    case temperature = "temperature"
    
    // MARK: - System Sensors
    
    /// Battery level percentage (0-100)
    case battery = "battery"
    
    // MARK: - Computed Metrics
    
    /// Heart rate in beats per minute
    case heartRate = "heart_rate"
    
    /// Blood oxygen saturation percentage
    case spo2 = "spo2"
    
    /// Muscle activity level (computed from EMG)
    case muscleActivity = "muscle_activity"
    
    // MARK: - Properties
    
    /// Human-readable name
    var displayName: String {
        switch self {
        case .ppgRed: return "PPG Red"
        case .ppgInfrared: return "PPG Infrared"
        case .ppgGreen: return "PPG Green"
        case .emg: return "EMG"
        case .accelerometerX: return "Accel X"
        case .accelerometerY: return "Accel Y"
        case .accelerometerZ: return "Accel Z"
        case .temperature: return "Temperature"
        case .battery: return "Battery"
        case .heartRate: return "Heart Rate"
        case .spo2: return "SpO2"
        case .muscleActivity: return "Muscle Activity"
        }
    }
    
    /// Unit of measurement
    var unit: String {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return "ADC"
        case .emg:
            return "µV"
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return "g"
        case .temperature:
            return "°C"
        case .battery:
            return "%"
        case .heartRate:
            return "bpm"
        case .spo2:
            return "%"
        case .muscleActivity:
            return "µV"
        }
    }
    
    /// Whether this is an optical signal (PPG or EMG)
    var isOpticalSignal: Bool {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return true
        default:
            return false
        }
    }
    
    /// Whether this sensor type requires special processing
    var requiresProcessing: Bool {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return true
        default:
            return false
        }
    }
    
    /// Icon name for UI display
    var iconName: String {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return "waveform.path.ecg"
        case .emg:
            return "waveform.path.ecg"
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return "gyroscope"
        case .temperature:
            return "thermometer"
        case .battery:
            return "battery.100"
        case .heartRate:
            return "heart.fill"
        case .spo2:
            return "lungs.fill"
        case .muscleActivity:
            return "bolt.fill"
        }
    }
}

// MARK: - Sensor Grouping

extension SensorType {
    
    /// Groups sensors by category for UI organization
    static var opticalSensors: [SensorType] {
        [.ppgRed, .ppgInfrared, .ppgGreen, .emg]
    }
    
    static var motionSensors: [SensorType] {
        [.accelerometerX, .accelerometerY, .accelerometerZ]
    }
    
    static var environmentalSensors: [SensorType] {
        [.temperature]
    }
    
    static var systemSensors: [SensorType] {
        [.battery]
    }
    
    static var computedMetrics: [SensorType] {
        [.heartRate, .spo2, .muscleActivity]
    }
}