//
//  MetricType.swift
//  OralableApp
//
//  Created by John A Cogan on 22/11/2025.
//


import Foundation
import SwiftUI

/// Central MetricType used across history UI and processors.
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

    func csvRow(for sample: SensorData) -> String {
        let timestamp = ISO8601DateFormatter().string(from: sample.timestamp)

        switch self {
        case .battery:
            return "\(timestamp),\(sample.battery.percentage)"
        case .ppg:
            return "\(timestamp),\(sample.ppg.red),\(sample.ppg.ir),\(sample.ppg.green)"
        case .heartRate:
            let bpm = sample.heartRate?.bpm ?? 0.0
            let quality = sample.heartRate?.quality ?? 0.0
            return "\(timestamp),\(bpm),\(quality)"
        case .spo2:
            let percentage = sample.spo2?.percentage ?? 0.0
            let quality = sample.spo2?.quality ?? 0.0
            return "\(timestamp),\(percentage),\(quality)"
        case .temperature:
            return "\(timestamp),\(sample.temperature.celsius)"
        case .accelerometer:
            let x = sample.accelerometer.x
            let y = sample.accelerometer.y
            let z = sample.accelerometer.z
            let magnitude = sample.accelerometer.magnitude
            return "\(timestamp),\(x),\(y),\(z),\(magnitude)"
        }
    }
}