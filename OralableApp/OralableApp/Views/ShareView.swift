import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Main Share View (Refactored to use components)
struct ShareView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var csvImportManager: CSVImportManager
    @ObservedObject var ble: OralableBLE

    @State private var showShareSheet = false
    @State private var showDocumentExporter = false
    @State private var exportURL: URL?
    @State private var exportDocument: CSVDocument?
    @State private var showClearConfirmation = false
    @State private var showImportPicker = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dismiss) private var dismiss

    private var columns: [GridItem] {
        let columnCount = DesignSystem.Layout.gridColumns(for: sizeClass)
        return Array(
            repeating: GridItem(.flexible(), spacing: DesignSystem.Layout.cardSpacing),
            count: columnCount
        )
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(navigationBarTitleDisplayMode)
                .background(designSystem.colors.backgroundSecondary.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Back")
                            }
                            .foregroundColor(designSystem.colors.primaryBlack)
                        }
                    }
                }
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheetContent
        }
            .fileExporter(
                isPresented: $showDocumentExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: defaultExportFilename
            ) { result in
                handleExportResult(result)
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .modifier(ShareAlertsModifier(
                showImportSuccess: $showImportSuccess,
                showImportError: $showImportError,
                showClearConfirmation: $showClearConfirmation,
                importedCount: importedCount,
                importErrorMessage: importErrorMessage,
                ble: ble
            ))
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        "Share Data"
    }

    private var navigationBarTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        DesignSystem.Layout.isIPad ? .inline : .large
    }

    private var defaultExportFilename: String {
        "oralable_data_\(Date().formatted(.iso8601.year().month().day()))"
    }

    @ViewBuilder
    private var shareSheetContent: some View {
        if let url = exportURL {
            ShareSheet(items: [url])
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: designSystem.spacing.lg) {
                mainContentStack
            }
            .padding(DesignSystem.Layout.edgePadding)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var mainContentStack: some View {
        // Share with Dentist Section
        ShareWithDentistSection()
            .frame(maxWidth: DesignSystem.Layout.isIPad ? DesignSystem.Layout.maxCardWidth * 2 : .infinity)

        // Export Button
        ShareExportButton(
            showShareSheet: $showShareSheet,
            showDocumentExporter: $showDocumentExporter,
            exportURL: $exportURL,
            exportDocument: $exportDocument,
            ble: ble
        )
        .frame(maxWidth: DesignSystem.Layout.isIPad ? DesignSystem.Layout.maxCardWidth * 2 : .infinity)
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Logger.shared.info(" File saved successfully to: \(url)")
            if let exportURL = exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
        case .failure(let error):
            Logger.shared.error(" File save failed: \(error.localizedDescription)")
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access the selected file. Please try again."
                showImportError = true
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }

                try FileManager.default.copyItem(at: url, to: tempURL)

                let validation = csvImportManager.validateCSVFile(at: tempURL)

                if !validation.isValid {
                    importErrorMessage = validation.errorMessage ?? "Invalid CSV format"
                    showImportError = true
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }

                if let imported = csvImportManager.importData(from: tempURL) {
                    guard let oldestTimestamp = imported.sensorData.first?.timestamp,
                          let newestTimestamp = imported.sensorData.last?.timestamp else {
                        importErrorMessage = "No valid sensor data in CSV file."
                        showImportError = true
                        try? FileManager.default.removeItem(at: tempURL)
                        return
                    }

                    let timeOffset = Date().timeIntervalSince(newestTimestamp)

                    ble.sensorDataHistory.append(contentsOf: imported.sensorData)

                    for sensorData in imported.sensorData {
                        let adjustedTimestamp = sensorData.timestamp.addingTimeInterval(timeOffset)

                        var adjustedPPG = sensorData.ppg
                        adjustedPPG = PPGData(
                            red: adjustedPPG.red,
                            ir: adjustedPPG.ir,
                            green: adjustedPPG.green,
                            timestamp: adjustedTimestamp
                        )
                        ble.ppgHistory.append(adjustedPPG)

                        var adjustedAccel = sensorData.accelerometer
                        adjustedAccel = AccelerometerData(
                            x: adjustedAccel.x,
                            y: adjustedAccel.y,
                            z: adjustedAccel.z,
                            timestamp: adjustedTimestamp
                        )
                        ble.accelerometerHistory.append(adjustedAccel)

                        var adjustedTemp = sensorData.temperature
                        adjustedTemp = TemperatureData(
                            celsius: adjustedTemp.celsius,
                            timestamp: adjustedTimestamp
                        )
                        ble.temperatureHistory.append(adjustedTemp)

                        var adjustedBattery = sensorData.battery
                        adjustedBattery = BatteryData(
                            percentage: adjustedBattery.percentage,
                            timestamp: adjustedTimestamp
                        )
                        ble.batteryHistory.append(adjustedBattery)

                        if let heartRate = sensorData.heartRate {
                            var adjustedHR = heartRate
                            adjustedHR = HeartRateData(
                                bpm: adjustedHR.bpm,
                                quality: adjustedHR.quality,
                                timestamp: adjustedTimestamp
                            )
                            ble.heartRateHistory.append(adjustedHR)
                        }

                        if let spo2 = sensorData.spo2 {
                            var adjustedSpO2 = spo2
                            adjustedSpO2 = SpO2Data(
                                percentage: adjustedSpO2.percentage,
                                quality: adjustedSpO2.quality,
                                timestamp: adjustedTimestamp
                            )
                            ble.spo2History.append(adjustedSpO2)
                        }
                    }

                    for logString in imported.logs {
                        ble.logMessages.append(LogMessage(message: logString))
                    }

                    ble.sensorDataHistory.sort { $0.timestamp < $1.timestamp }

                    importedCount = imported.sensorData.count

                    let timeAdjustmentMinutes = Int(timeOffset / 60)
                    ble.logMessages.append(LogMessage(
                        message: "✅ Successfully imported \(imported.sensorData.count) sensor data points and \(imported.logs.count) log entries (timestamps adjusted by \(timeAdjustmentMinutes) minutes to current time)"
                    ))

                    showImportSuccess = true
                } else {
                    importErrorMessage = "Failed to parse CSV file. Please ensure it's in the correct format."
                    showImportError = true
                }

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
    @EnvironmentObject var csvImportManager: CSVImportManager
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
                        Text(csvImportManager.expectedFormat)
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

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activityItems: [Any] = []

        for item in items {
            if let fileURL = item as? URL {
                let itemSource = FileActivityItemSource(fileURL: fileURL)
                activityItems.append(itemSource)
            } else {
                activityItems.append(item)
            }
        }

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                Logger.shared.error("[ShareView] Share sheet error: \(error.localizedDescription)")
            }

            for item in items {
                if let url = item as? URL {
                    if url.path.contains("/Caches/Exports/") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            try? FileManager.default.removeItem(at: url)
                            Logger.shared.debug("[ShareView] Cleaned up temporary export file: \(url.lastPathComponent)")
                        }
                    }
                }
            }
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            controller.popoverPresentationController?.sourceView = rootViewController.view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - File Activity Item Source
class FileActivityItemSource: NSObject, UIActivityItemSource {
    private let fileURL: URL
    private let fileName: String

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileName
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try? FileManager.default.removeItem(at: tempFile)
            }

            try FileManager.default.copyItem(at: fileURL, to: tempFile)

            if activityType == .saveToCameraRoll || activityType == .copyToPasteboard {
                return try? Data(contentsOf: tempFile)
            }

            return tempFile
        } catch {
            Logger.shared.error("[preparing file for sharing: \(error)")
            return try? Data(contentsOf: fileURL)
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "public.comma-separated-values-text"
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileURL.deletingPathExtension().lastPathComponent
    }
}

// MARK: - CSV Document
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .text] }

    var csvContent: String

    init(csvContent: String) {
        self.csvContent = csvContent
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        csvContent = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = csvContent.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Alerts Modifier
struct ShareAlertsModifier: ViewModifier {
    @Binding var showImportSuccess: Bool
    @Binding var showImportError: Bool
    @Binding var showClearConfirmation: Bool
    let importedCount: Int
    let importErrorMessage: String
    var ble: OralableBLE

    func body(content: Content) -> some View {
        content
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
                    ble.clearHistory()
                }
            } message: {
                Text("This will clear all logs and historical data. This action cannot be undone.")
            }
    }
}

// MARK: - Debug Connection Section (Temporary)
struct ShareDebugSection: View {
    @EnvironmentObject var designSystem: DesignSystem
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
                ShareInfoRow(label: "Status", value: ble.connectionStatus)
                ShareInfoRow(label: "Connected", value: ble.isConnected ? "Yes" : "No")
                ShareInfoRow(label: "Scanning", value: ble.isScanning ? "Yes" : "No")
                ShareInfoRow(label: "Devices Found", value: "\(ble.discoveredDevices.count)")

                if ble.isConnected, let device = ble.connectedDevice {
                    ShareInfoRow(label: "Connected Device", value: device.name ?? "Unknown")
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
                            if let device = ble.discoveredDevices.first(where: {
                                $0.name?.contains(testDeviceName) == true
                            }) {
                                ble.connect(to: device)
                            }
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
                LogsView()
                    .environmentObject(designSystem)
            }
        }
    }
}
