import SwiftUI
import Foundation

// MARK: - MetricType Definition
enum MetricType: String, CaseIterable {
    case battery = "battery"
    case ppg = "ppg"
    case heartRate = "heartRate"
    case spo2 = "spo2"
    case temperature = "temperature"
    case accelerometer = "accelerometer"

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .ppg: return "PPG Signals"
        case .heartRate: return "Heart Rate"
        case .spo2: return "Blood Oxygen"
        case .temperature: return "Temperature"
        case .accelerometer: return "Accelerometer"
        }
    }

    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .ppg: return "waveform.path.ecg"
        case .heartRate: return "heart.fill"
        case .spo2: return "drop.fill"
        case .temperature: return "thermometer"
        case .accelerometer: return "gyroscope"
        }
    }

    var color: Color {
        switch self {
        case .battery: return .green
        case .ppg: return .red
        case .heartRate: return .pink
        case .spo2: return .blue
        case .temperature: return .orange
        case .accelerometer: return .purple
        }
    }

    func csvHeader() -> String {
        switch self {
        case .battery:
            return "Timestamp,Battery_Percentage"
        case .ppg:
            return "Timestamp,PPG_Red,PPG_IR,PPG_Green"
        case .heartRate:
            return "Timestamp,Heart_Rate_BPM,Quality"
        case .spo2:
            return "Timestamp,SpO2_Percentage,Quality"
        case .temperature:
            return "Timestamp,Temperature_Celsius"
        case .accelerometer:
            return "Timestamp,Accel_X,Accel_Y,Accel_Z,Magnitude"
        }
    }

    func csvRow(for data: SensorData) -> String {
        let timestamp = ISO8601DateFormatter().string(from: data.timestamp)
        switch self {
        case .battery:
            return "\(timestamp),\(data.battery.percentage)"
        case .ppg:
            return "\(timestamp),\(data.ppg.red),\(data.ppg.ir),\(data.ppg.green)"
        case .heartRate:
            if let hr = data.heartRate {
                return "\(timestamp),\(hr.bpm),\(hr.quality)"
            } else {
                return "\(timestamp),0,0"
            }
        case .spo2:
            if let spo2 = data.spo2 {
                return "\(timestamp),\(spo2.percentage),\(spo2.quality)"
            } else {
                return "\(timestamp),0,0"
            }
        case .temperature:
            return "\(timestamp),\(data.temperature.celsius)"
        case .accelerometer:
            return "\(timestamp),\(data.accelerometer.x),\(data.accelerometer.y),\(data.accelerometer.z),\(data.accelerometer.magnitude)"
        }
    }
}
