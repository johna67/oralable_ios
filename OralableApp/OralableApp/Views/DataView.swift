import SwiftUI
import Charts

struct DataView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false  // NEW: Flag to indicate Viewer Mode
    @State private var selectedDataType = "PPG"
    
    let dataTypes = ["PPG", "Accelerometer", "Temperature"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Data Type Selector
                Picker("Data Type", selection: $selectedDataType) {
                    ForEach(dataTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .disabled(isViewerMode && !ble.isConnected) // Disable if in viewer mode and no connection
                
                // Viewer Mode Notice (if not connected)
                if isViewerMode && !ble.isConnected {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Real-time data unavailable in Viewer Mode")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Switch to Subscription Mode to connect your device and view live sensor data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    // Data Visualization (works in both modes if device is connected)
                    ScrollView {
                        switch selectedDataType {
                        case "PPG":
                            PPGChartView(ppgData: ble.sensorData.ppg)
                        case "Accelerometer":
                            AccelerometerChartView(accData: ble.sensorData.accelerometer)
                        case "Temperature":
                            TemperatureView(temperature: ble.sensorData.temperature)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Sensor Data")
        }
    }
}

struct PPGChartView: View {
    let ppgData: PPGData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PPG Signals")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart(ppgData.samples.indices, id: \.self) { index in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("IR", ppgData.samples[index].ir)
                    )
                    .foregroundStyle(.red)
                    
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Red", ppgData.samples[index].red)
                    )
                    .foregroundStyle(.pink)
                    
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Green", ppgData.samples[index].green)
                    )
                    .foregroundStyle(.green)
                }
                .frame(height: 200)
                .padding()
            } else {
                // Fallback for iOS 15
                Text("Charts require iOS 16+")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            // Current Values
            VStack(spacing: 10) {
                DataRow(label: "IR", value: "\(ppgData.ir)", color: .red)
                DataRow(label: "Red", value: "\(ppgData.red)", color: .pink)
                DataRow(label: "Green", value: "\(ppgData.green)", color: .green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct AccelerometerChartView: View {
    let accData: AccelerometerData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Accelerometer Data")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 10) {
                DataRow(label: "X", value: "\(accData.x)", color: .red)
                DataRow(label: "Y", value: "\(accData.y)", color: .green)
                DataRow(label: "Z", value: "\(accData.z)", color: .blue)
                DataRow(label: "Magnitude",
                       value: String(format: "%.2f", accData.magnitude),
                       color: .purple)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct TemperatureView: View {
    let temperature: Double
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Temperature")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: min(temperature / 50.0, 1.0))
                    .stroke(
                        LinearGradient(colors: [.blue, .green, .red],
                                      startPoint: .leading,
                                      endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(String(format: "%.1f", temperature))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("°C")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding()
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .monospaced()
        }
    }
}
