//
//  DashboardView_SpO2_Components.swift
//  OralableApp
//
//  Updated: October 28, 2025
//  Added: SpO2 visualization and metric type
//
//  INSTRUCTIONS: Add this code to your existing DashboardView.swift file
//

import SwiftUI
import Charts

// MARK: - Updated MetricType Enum

/// Replace the existing MetricType enum in DashboardView.swift with this updated version
enum MetricType: String, CaseIterable {
    case battery
    case ppg
    case heartRate      // Existing
    case spo2           // NEW
    case temperature
    case accelerometer
    
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .ppg: return "PPG Signals"
        case .heartRate: return "Heart Rate"
        case .spo2: return "Blood Oxygen"  // NEW
        case .temperature: return "Temperature"
        case .accelerometer: return "Accelerometer"
        }
    }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .ppg: return "waveform.ecg"
        case .heartRate: return "heart.fill"
        case .spo2: return "drop.fill"  // NEW - water drop icon
        case .temperature: return "thermometer"
        case .accelerometer: return "gyroscope"
        }
    }
    
    var color: Color {
        switch self {
        case .battery: return .green
        case .ppg: return .red
        case .heartRate: return .pink
        case .spo2: return .blue  // NEW - blue for oxygen
        case .temperature: return .orange
        case .accelerometer: return .blue
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
        case .spo2:  // NEW
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
                return "\(timestamp),--,--"
            }
        case .spo2:  // NEW
            if let spo2 = data.spo2 {
                return "\(timestamp),\(spo2.percentage),\(spo2.quality)"
            } else {
                return "\(timestamp),--,--"
            }
        case .temperature:
            return "\(timestamp),\(data.temperature.celsius)"
        case .accelerometer:
            let mag = data.accelerometer.magnitude
            return "\(timestamp),\(data.accelerometer.x),\(data.accelerometer.y),\(data.accelerometer.z),\(mag)"
        }
    }
}

// MARK: - SpO2 Graph View Component

/// Add this new struct to your DashboardView.swift file
struct SpO2GraphView: View {
    let spo2History: [SpO2Data]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with current value
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = spo2History.last, latest.isValid {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(latest.percentage))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("%")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        // Health status
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorForStatus(latest.healthStatus))
                                .frame(width: 8, height: 8)
                            
                            Text(latest.healthStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("No Signal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Signal quality indicator
                if let latest = spo2History.last {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForQuality(latest.qualityColor))
                                .frame(width: 10, height: 10)
                            
                            Text(latest.qualityLevel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Signal Quality")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Chart
            if !spo2History.isEmpty {
                Chart {
                    ForEach(Array(spo2History.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("SpO2", measurement.percentage)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("SpO2", measurement.percentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Reference line at 95% (normal threshold)
                    RuleMark(y: .value("Normal", 95))
                        .foregroundStyle(Color.green.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartYScale(domain: 85...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                // Empty state
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No SpO2 Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            }
            
            // Info footer
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Normal range: 95-100%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let latest = spo2History.last {
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func colorForQuality(_ qualityColor: String) -> Color {
        switch qualityColor {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "Normal": return .green
        case "Borderline": return .yellow
        case "Low": return .orange
        default: return .red
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Integration Instructions

/*
 
 TO INTEGRATE SpO2 INTO YOUR DASHBOARDVIEW:
 
 1. REPLACE MetricType enum:
    - Find the existing `enum MetricType` in DashboardView.swift
    - Replace it entirely with the updated version above
 
 2. ADD SpO2GraphView:
    - Copy the entire SpO2GraphView struct above
    - Paste it into DashboardView.swift (after other graph views)
 
 3. UPDATE Dashboard Layout:
    - In DashboardView body, find the ScrollView with metric cards
    - Add SpO2 card in the order you want (suggested: after Heart Rate)
 
 Example placement in ScrollView:
 
 ScrollView {
     VStack(spacing: 16) {
         // ... existing connection status card ...
         
         // Battery card
         MetricGraphCard(metric: .battery) {
             BatteryGraphView(batteryHistory: ble.batteryHistory)
         }
         
         // PPG card
         MetricGraphCard(metric: .ppg) {
             PPGGraphView(ppgHistory: ble.ppgHistory)
         }
         
         // Heart Rate card (existing)
         MetricGraphCard(metric: .heartRate) {
             HeartRateGraphView(heartRateHistory: ble.heartRateHistory)
         }
         
         // SpO2 card (NEW - add this)
         MetricGraphCard(metric: .spo2) {
             SpO2GraphView(spo2History: ble.spo2History)
         }
         
         // Temperature card
         MetricGraphCard(metric: .temperature) {
             TemperatureGraphView(temperatureHistory: ble.temperatureHistory)
         }
         
         // Accelerometer card
         MetricGraphCard(metric: .accelerometer) {
             AccelerometerGraphView(accelerometerHistory: ble.accelerometerHistory)
         }
     }
     .padding()
 }
 
 4. UPDATE OralableBLE Manager:
    - Add spo2History array: @Published var spo2History: [SpO2Data] = []
    - Import SpO2Calculator in OralableBLE.swift
    - Calculate SpO2 after parsing PPG data (similar to heart rate)
    - Append results to spo2History array
 
 5. TEST:
    - Build project (Cmd+B)
    - Run on device
    - Verify SpO2 card appears on dashboard
    - Verify SpO2 calculation runs when PPG data arrives
 
 */

// MARK: - Preview Support

#if DEBUG
struct SpO2GraphView_Previews: PreviewProvider {
    static var previews: some View {
        SpO2GraphView(spo2History: [
            SpO2Data(percentage: 98.0, quality: 0.95, timestamp: Date().addingTimeInterval(-300)),
            SpO2Data(percentage: 97.5, quality: 0.90, timestamp: Date().addingTimeInterval(-240)),
            SpO2Data(percentage: 98.2, quality: 0.92, timestamp: Date().addingTimeInterval(-180)),
            SpO2Data(percentage: 97.8, quality: 0.88, timestamp: Date().addingTimeInterval(-120)),
            SpO2Data(percentage: 98.5, quality: 0.94, timestamp: Date().addingTimeInterval(-60)),
            SpO2Data(percentage: 98.0, quality: 0.93, timestamp: Date())
        ])
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
