import SwiftUI
import UniformTypeIdentifiers

struct ShareView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false
    
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showClearConfirmation = false
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Debug Section (temporary for troubleshooting)
                    DebugConnectionSection(ble: ble)
                    
                    // Viewer Mode Import Section
                    if isViewerMode {
                        ImportSection(
                            showImportPicker: $showImportPicker,
                            ble: ble,
                            showImportSuccess: $showImportSuccess,
                            importedCount: $importedCount,
                            showImportError: $showImportError,
                            importErrorMessage: $importErrorMessage
                        )
                    }
                    
                    // Device Info Card
                    DeviceInfoCard(isViewerMode: isViewerMode)
                    
                    // Data Summary Card
                    DataSummaryCard(ble: ble)
                    
                    // Export Button
                    ExportButton(
                        showShareSheet: $showShareSheet,
                        exportURL: $exportURL,
                        ble: ble
                    )
                    
                    // Recent Logs Preview
                    RecentLogsPreview(ble: ble)
                    
                    // Clear Data Button
                    ClearDataButton(showClearConfirmation: $showClearConfirmation, ble: ble)
                }
                .padding()
            }
            .navigationTitle(isViewerMode ? "Import & Export" : "Share Data")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Data Imported Successfully", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Imported \(importedCount) data points. View them in the Dashboard and History tabs.")
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    ble.clearLogs()
                }
            } message: {
                Text("This will clear all logs and historical data. This action cannot be undone.")
            }
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if let imported = CSVImportManager.shared.importCSV(from: url) {
                // Add imported data to BLE manager
                ble.sensorDataHistory.append(contentsOf: imported.data)
                ble.logMessages.append(contentsOf: imported.logs)
                
                // Sort by timestamp
                ble.sensorDataHistory.sort { $0.timestamp < $1.timestamp }
                
                importedCount = imported.data.count
                showImportSuccess = true
            } else {
                importErrorMessage = "Failed to parse CSV file. Please ensure it's in the correct format."
                showImportError = true
            }
            
        case .failure(let error):
            importErrorMessage = "Failed to import file: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

// MARK: - Import Section (Viewer Mode Only)
struct ImportSection: View {
    @Binding var showImportPicker: Bool
    @ObservedObject var ble: OralableBLE
    @Binding var showImportSuccess: Bool
    @Binding var importedCount: Int
    @Binding var showImportError: Bool
    @Binding var importErrorMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Import Data")
                    .font(.headline)
            }
            
            Text("Load previously exported CSV files to view historical data without connecting a device.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showImportPicker = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                    Text("Choose CSV File")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            // Format info
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Accepts CSV files exported from this app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Data will be viewable in Dashboard and History")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Device Info Card
struct DeviceInfoCard: View {
    let isViewerMode: Bool
    
    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    private var deviceModel: String {
        UIDevice.current.model
    }
    
    private var systemVersion: String {
        UIDevice.current.systemVersion
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)
            
            Divider()
            
            InfoRow(label: "Device ID", value: String(deviceID.prefix(12)) + "...")
            InfoRow(label: "Model", value: deviceModel)
            InfoRow(label: "iOS Version", value: systemVersion)
            InfoRow(label: "App Version", value: appVersion)
            
            if isViewerMode {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Viewer Mode - Import CSV files to view data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Data Summary Card
struct DataSummaryCard: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Summary")
                .font(.headline)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.blue)
                        Text("Log Entries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("\(ble.logMessages.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.green)
                        Text("Data Points")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("\(ble.sensorDataHistory.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !ble.sensorDataHistory.isEmpty {
                Divider()
                
                if let first = ble.sensorDataHistory.first, let last = ble.sensorDataHistory.last {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(first.timestamp, style: .date) to \(last.timestamp, style: .date)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Export Button
struct ExportButton: View {
    @Binding var showShareSheet: Bool
    @Binding var exportURL: URL?
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        Button(action: {
            exportCSV()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                Text("Export as CSV")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(ble.logMessages.isEmpty && ble.sensorDataHistory.isEmpty)
        .opacity((ble.logMessages.isEmpty && ble.sensorDataHistory.isEmpty) ? 0.5 : 1.0)
    }
    
    private func exportCSV() {
        let manager = LogExportManager.shared
        
        if let url = manager.exportLogsAsCSV(
            logs: ble.logMessages,
            historicalData: ble.sensorDataHistory
        ) {
            exportURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Recent Logs Preview
struct RecentLogsPreview: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentLogs: [String] {
        Array(ble.logMessages.suffix(10).reversed())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Text("Last \(min(10, ble.logMessages.count)) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if ble.logMessages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No activity logged yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentLogs, id: \.self) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(logColor(for: log))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            
                            Text(log)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("ERROR") || log.contains("Failed") {
            return .red
        } else if log.contains("WARNING") || log.contains("Disconnected") {
            return .orange
        } else if log.contains("Connected") || log.contains("SUCCESS") {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Clear Data Button
struct ClearDataButton: View {
    @Binding var showClearConfirmation: Bool
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        Button(action: {
            showClearConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash")
                Text("Clear All Data")
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .disabled(ble.logMessages.isEmpty && ble.sensorDataHistory.isEmpty)
        .opacity((ble.logMessages.isEmpty && ble.sensorDataHistory.isEmpty) ? 0.5 : 1.0)
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Debug Connection Section (Temporary)
struct DebugConnectionSection: View {
    @ObservedObject var ble: OralableBLE
    @State private var showFullLogs = false
    @State private var testDeviceName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Debug Connection")
                    .font(.headline)
                Spacer()
                Button("View Full Logs") {
                    showFullLogs = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Connection Status
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Status", value: ble.connectionStatus)
                InfoRow(label: "Connected", value: ble.isConnected ? "Yes" : "No")
                InfoRow(label: "Scanning", value: ble.isScanning ? "Yes" : "No")
                InfoRow(label: "Devices Found", value: "\(ble.discoveredDevices.count)")
                
                if ble.isConnected, let device = ble.connectedDevice {
                    InfoRow(label: "Connected Device", value: device.name ?? "Unknown")
                }
            }
            
            Divider()
            
            // Quick Actions
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Refresh Scan") {
                        ble.refreshScan()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset BLE") {
                        ble.resetBLE()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Force Disconnect") {
                        ble.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Test connect by device name
                HStack {
                    TextField("Device name to connect", text: $testDeviceName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Connect") {
                        if !testDeviceName.isEmpty {
                            ble.connectToDeviceWithName(testDeviceName)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(testDeviceName.isEmpty)
                }
                .font(.caption)
            }
            
            // Show discovered devices
            if !ble.discoveredDevices.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discovered Devices:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(ble.discoveredDevices, id: \.identifier) { device in
                        HStack {
                            Text(device.name ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("Connect") {
                                ble.connect(to: device)
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Recent logs preview
            if !ble.logMessages.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Logs (last 5):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(ble.logMessages.suffix(5).reversed()), id: \.self) { log in
                        Text(log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showFullLogs) {
            LogsView(logs: ble.logMessages)
        }
    }
}
