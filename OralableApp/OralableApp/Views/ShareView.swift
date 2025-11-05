import SwiftUI
import SwiftUI
import Foundation
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
                VStack(spacing: DesignSystem.Spacing.lg) {
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
                    
                    // Device Info Card (collapsed/minimal)
                    DeviceInfoCard(isViewerMode: isViewerMode)
                    
                    // Clear Data Button
                    ClearDataButton(showClearConfirmation: $showClearConfirmation, ble: ble)
                    
                    // Debug Section (only in debug builds)
                    #if DEBUG
                    DebugConnectionSection(ble: ble)
                    #endif
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle(isViewerMode ? "Import & Export" : "Share Data")
            .navigationBarTitleDisplayMode(.large)
            .background(DesignSystem.Colors.backgroundSecondary.ignoresSafeArea())
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
            
            // Request access to security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file. Please try again."
                showImportError = true
                return
            }
            
            // Ensure we stop accessing the resource when done
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Copy file to temporary location to avoid permission issues
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // Copy to temporary directory
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Validate before importing
                let validation = CSVImportManager.shared.validateCSVFile(at: tempURL)
                
                if !validation.isValid {
                    importErrorMessage = validation.errorMessage ?? "Invalid CSV format"
                    showImportError = true
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }
                
                // Now import from the copied file
                if let imported = CSVImportManager.shared.importData(from: tempURL) {
                    // Add imported data to BLE manager
                    ble.sensorDataHistory.append(contentsOf: imported.sensorData)
                    
                    // Convert imported string logs to LogMessage objects
                    for logString in imported.logs {
                        ble.logMessages.append(LogMessage(message: logString))
                    }
                    
                    // Sort by timestamp
                    ble.sensorDataHistory.sort { $0.timestamp < $1.timestamp }
                    
                    importedCount = imported.sensorData.count
                    
                    // Log success
                    ble.logMessages.append(LogMessage(
                        message: "✅ Successfully imported \(imported.sensorData.count) sensor data points and \(imported.logs.count) log entries"
                    ))
                    
                    showImportSuccess = true
                } else {
                    importErrorMessage = "Failed to parse CSV file. Please ensure it's in the correct format."
                    showImportError = true
                }
                
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempURL)
                
            } catch {
                importErrorMessage = "Failed to access file: \(error.localizedDescription)"
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
    @State private var showFormatInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Import Data")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showFormatInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
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
        .sheet(isPresented: $showFormatInfo) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(CSVImportManager.shared.expectedFormat)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Common Issues")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TroubleshootItem(
                                    icon: "exclamationmark.triangle",
                                    color: .orange,
                                    title: "File Permission Error",
                                    description: "After exporting, save the file to Files app or iCloud Drive, then import from there."
                                )
                                
                                TroubleshootItem(
                                    icon: "doc.text",
                                    color: .blue,
                                    title: "Wrong Format",
                                    description: "Ensure your CSV has the exact header row shown above."
                                )
                                
                                TroubleshootItem(
                                    icon: "calendar",
                                    color: .purple,
                                    title: "Timestamp Format",
                                    description: "Dates must be in yyyy-MM-dd HH:mm:ss.SSS format."
                                )
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
                .navigationTitle("CSV Format")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showFormatInfo = false
                        }
                    }
                }
            }
        }
    }
}

struct TroubleshootItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Device Info Card
struct DeviceInfoCard: View {
    let isViewerMode: Bool
    @State private var isExpanded = false
    
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("Device Information", systemImage: "info.circle")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: DesignSystem.Sizing.Icon.xs))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    InfoRow(label: "Device", value: deviceModel)
                    InfoRow(label: "iOS", value: systemVersion)
                    InfoRow(label: "App Version", value: appVersion)
                    InfoRow(label: "Device ID", value: String(deviceID.prefix(12)) + "...")
                    
                    if isViewerMode {
                        HStack {
                            Image(systemName: "eye")
                                .font(.system(size: DesignSystem.Sizing.Icon.xs))
                                .foregroundColor(DesignSystem.Colors.info)
                            
                            Text("Viewing mode - no device connected")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
    }
}

// MARK: - Data Summary Card
struct DataSummaryCard: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Data Summary")
                .font(DesignSystem.Typography.h3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Divider()
            
            // Metrics Grid
            HStack(spacing: DesignSystem.Spacing.lg) {
                MetricBox(
                    title: "Sensor Data",
                    value: "\(ble.sensorDataHistory.count)",
                    subtitle: "points",
                    icon: "waveform.path.ecg",
                    color: .blue
                )
                
                MetricBox(
                    title: "Log Entries",
                    value: "\(ble.logMessages.count)",
                    subtitle: "messages",
                    icon: "doc.text",
                    color: .green
                )
            }
            
            if !ble.sensorDataHistory.isEmpty, 
               let first = ble.sensorDataHistory.first, 
               let last = ble.sensorDataHistory.last {
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Label("Recording Period", systemImage: "clock")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    HStack {
                        Text(first.timestamp, style: .date)
                        Image(systemName: "arrow.right")
                        Text(last.timestamp, style: .date)
                    }
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                    .foregroundColor(color)
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(DesignSystem.Typography.displaySmall)
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Export Button
struct ExportButton: View {
    @Binding var showShareSheet: Bool
    @Binding var exportURL: URL?
    @ObservedObject var ble: OralableBLE
    @State private var isExporting = false
    
    private var hasData: Bool {
        !ble.logMessages.isEmpty || !ble.sensorDataHistory.isEmpty
    }
    
    var body: some View {
        Button(action: exportData) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: DesignSystem.Sizing.Icon.md))
                }
                
                Text(isExporting ? "Exporting..." : "Export Data as CSV")
                    .font(DesignSystem.Typography.buttonMedium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                hasData ? 
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .designShadow(hasData ? DesignSystem.Shadow.md : DesignSystem.Shadow.sm)
        }
        .disabled(!hasData || isExporting)
        .animation(.easeInOut(duration: DesignSystem.Animation.fast), value: isExporting)
    }
    
    private func exportData() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let exportResult = CSVExportManager.shared.exportData(
                sensorData: ble.sensorDataHistory,
                logs: ble.logMessages.map { $0.message }
            )
            
            DispatchQueue.main.async {
                isExporting = false
                exportURL = exportResult
                showShareSheet = true
            }
        }
    }
}

// MARK: - Clear Data Button
struct ClearDataButton: View {
    @Binding var showClearConfirmation: Bool
    @ObservedObject var ble: OralableBLE
    
    private var hasData: Bool {
        !ble.logMessages.isEmpty || !ble.sensorDataHistory.isEmpty
    }
    
    var body: some View {
        Button(action: { showClearConfirmation = true }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "trash")
                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                
                Text("Clear All Data")
                    .font(DesignSystem.Typography.buttonMedium)
            }
            .foregroundColor(hasData ? .red : DesignSystem.Colors.textDisabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(hasData ? Color.red.opacity(0.1) : DesignSystem.Colors.backgroundTertiary)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(hasData ? Color.red.opacity(0.3) : DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .disabled(!hasData)
    }
}

// MARK: - Recent Logs Preview
struct RecentLogsPreview: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentLogs: [LogMessage] {
        Array(ble.logMessages.suffix(10).reversed())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Label("Recent Activity", systemImage: "clock")
                    .font(DesignSystem.Typography.h3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("Last \(min(10, ble.logMessages.count))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            
            Divider()
            
            if ble.logMessages.isEmpty {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.Colors.textDisabled)
                    
                    Text("No activity yet")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xl)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(recentLogs) { log in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Circle()
                                .fill(logColor(for: log.message))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            
                            Text(log.message)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("ERROR") || log.contains("Failed") || log.contains("❌") {
            return .red
        } else if log.contains("WARNING") || log.contains("Disconnected") || log.contains("⚠️") {
            return .orange
        } else if log.contains("Connected") || log.contains("SUCCESS") || log.contains("✅") {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
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
            
            // Recent logs preview - ✅ FIXED: Use LogMessage.id
            if !ble.logMessages.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Logs (last 5):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(ble.logMessages.suffix(5).reversed())) { log in
                        Text(log.message)
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
            NavigationView {
                LogsView(logs: ble.logMessages)
            }
        }
    }
}
