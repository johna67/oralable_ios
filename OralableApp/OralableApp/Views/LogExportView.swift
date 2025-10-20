import SwiftUI
import UIKit

struct LogExportView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false  // NEW: Flag to indicate Viewer Mode
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var exportFormat = "CSV"
    @State private var isExporting = false
    @State private var appleID: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Device Info (Apple ID disabled in Viewer Mode)
                    DeviceInfoCard(appleID: isViewerMode ? nil : appleID, isViewerMode: isViewerMode)
                    
                    // Export Options
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Export Format")
                            .font(.headline)
                        
                        Picker("Format", selection: $exportFormat) {
                            Text("CSV").tag("CSV")
                            Text("JSON").tag("JSON")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        HStack {
                            Text("Log Count:")
                                .foregroundColor(.secondary)
                            Text("\(ble.logMessages.count)")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("Data Points:")
                                .foregroundColor(.secondary)
                            Text("\(ble.historicalData.count)")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Export Buttons
                    VStack(spacing: 10) {
                        Button(action: exportLogs) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Logs")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(ble.logMessages.isEmpty || isExporting)
                        
                        Button(action: { ble.clearLogs() }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Logs")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                        }
                        .disabled(ble.logMessages.isEmpty)
                    }
                    
                    if isExporting {
                        ProgressView("Exporting...")
                            .padding()
                    }
                    
                    // Viewer Mode Notice
                    if isViewerMode {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Viewer Mode - Apple ID not included in exports")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Recent Logs Preview
                    LogPreviewSection(logs: Array(ble.logMessages.suffix(10)))
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
        .onAppear {
            // Only fetch Apple ID in Subscription Mode
            if !isViewerMode {
                LogExportManager.shared.fetchAppleUserID { id in
                    self.appleID = id
                }
            }
        }
    }
    
    private func exportLogs() {
        isExporting = true
        
        DispatchQueue.global(qos: .background).async {
            let manager = LogExportManager.shared
            let url: URL?
            
            if exportFormat == "CSV" {
                url = manager.exportLogsAsCSV(
                    logs: ble.logMessages,
                    historicalData: ble.historicalData
                )
            } else {
                url = manager.exportLogsAsJSON(
                    logs: ble.logMessages,
                    historicalData: ble.historicalData
                )
            }
            
            DispatchQueue.main.async {
                self.exportURL = url
                self.isExporting = false
                if url != nil {
                    self.showShareSheet = true
                }
            }
        }
    }
}

struct DeviceInfoCard: View {
    let appleID: String?
    var isViewerMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Device Information")
                .font(.headline)
            
            HStack {
                Label("Device ID", systemImage: "iphone")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Spacer()
                
                Text(String(LogExportManager.shared.deviceID.prefix(8)) + "...")
                    .font(.caption)
                    .monospaced()
            }
            
            HStack {
                Label("Apple ID", systemImage: "person.circle")
                    .foregroundColor(isViewerMode ? .gray : .secondary)
                    .font(.caption)
                
                Spacer()
                
                if isViewerMode {
                    Text("Disabled in Viewer Mode")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                } else if let id = appleID {
                    Text(String(id.prefix(8)) + "...")
                        .font(.caption)
                        .monospaced()
                } else {
                    Text("Not signed in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .opacity(isViewerMode ? 0.6 : 1.0)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct LogPreviewSection: View {
    let logs: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Logs")
                .font(.headline)
            
            if logs.isEmpty {
                Text("No logs available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(logs.reversed(), id: \.self) { log in
                    Text(log)
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(5)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = [.assignToContact, .addToReadingList]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
