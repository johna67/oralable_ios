//
//  SharingView.swift
//  OralableApp
//
//  CRITICAL: This screen implements mode-specific functionality
//  Viewer Mode: Import ENABLED, Export DISABLED, HealthKit DISABLED
//  Subscription Mode: Import DISABLED, Export ENABLED, HealthKit ENABLED
//

import SwiftUI
import UniformTypeIdentifiers

struct SharingView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var designSystem: DesignSystem
    @StateObject private var bleManager = OralableBLE.shared

    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var exportDocument: CSVDocument?
    @State private var showHealthKitSheet = false

    var isViewerMode: Bool {
        appStateManager.selectedMode == .viewer
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // IMPORT SECTION - VIEWER MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("Import Data")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "arrow.down.doc.fill",
                            title: "Import CSV File",
                            description: isViewerMode ?
                                "Load historical data from exported files" :
                                "Import available in Viewer Mode only",
                            buttonText: "Select File",
                            isEnabled: isViewerMode,  // ← ENABLED IN VIEWER ONLY
                            accentColor: designSystem.colors.accentGreen
                        ) {
                            if isViewerMode {
                                showingImportPicker = true
                            }
                        }
                    }

                    // EXPORT SECTION - SUBSCRIPTION MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("Export Data")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "arrow.up.doc.fill",
                            title: "Export as CSV",
                            description: isViewerMode ?
                                "Export available in Subscription Mode" :
                                "Share your data for analysis",
                            buttonText: "Export Data",
                            isEnabled: !isViewerMode,  // ← ENABLED IN SUBSCRIPTION ONLY
                            accentColor: designSystem.colors.accentBlue
                        ) {
                            if !isViewerMode {
                                performExport()
                            }
                        }
                    }

                    // HEALTHKIT SECTION - SUBSCRIPTION MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("HealthKit")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "heart.fill",
                            title: "Connect HealthKit",
                            description: isViewerMode ?
                                "HealthKit available in Subscription Mode" :
                                "Sync with Apple Health",
                            buttonText: "Connect HealthKit",
                            isEnabled: !isViewerMode,  // ← ENABLED IN SUBSCRIPTION ONLY
                            buttonStyle: .secondary,
                            accentColor: designSystem.colors.accentRed
                        ) {
                            if !isViewerMode {
                                showHealthKitSheet = true
                            }
                        }
                    }

                    // Mode Indicator at bottom
                    HStack {
                        Image(systemName: isViewerMode ? "eye" : "crown")
                            .foregroundColor(isViewerMode ? designSystem.colors.accentBlue : designSystem.colors.accentGreen)
                        Text("Current Mode: \(isViewerMode ? "Viewer" : "Subscription")")
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .padding(.top, designSystem.spacing.md)
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.large)
            .background(designSystem.colors.backgroundPrimary)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText, .text]
        ) { (result: Result<[URL], Error>) in
            handleImport(result: result)
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: defaultExportFilename
        ) { (result: Result<URL, Error>) in
            switch result {
            case .success(let url):
                print("✅ File saved successfully to: \(url)")
            case .failure(let error):
                print("❌ File save failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showHealthKitSheet) {
            HealthKitConnectionView()
        }
        .alert("Data Imported Successfully", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Imported \(importedCount) data points. View them in the Home and History tabs.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Export Functionality

    private var defaultExportFilename: String {
        "oralable_data_\(Date().formatted(.iso8601.year().month().day()))"
    }

    private func performExport() {
        // Perform the export
        let exportResult = CSVExportManager.shared.exportData(
            sensorData: bleManager.sensorDataHistory,
            logs: bleManager.logMessages.map { $0.message }
        )

        if let url = exportResult,
           let csvContent = try? String(contentsOf: url, encoding: .utf8) {
            exportDocument = CSVDocument(csvContent: csvContent)
            showingExportSheet = true
        }
    }

    // MARK: - Import Functionality

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

            // Copy file to temporary location
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

                // Import the data
                if let imported = CSVImportManager.shared.importData(from: tempURL) {
                    // Add imported data to BLE manager
                    bleManager.sensorDataHistory.append(contentsOf: imported.sensorData)

                    // Import individual sensor histories
                    for sensorData in imported.sensorData {
                        bleManager.ppgHistory.append(sensorData.ppg)
                        bleManager.accelerometerHistory.append(sensorData.accelerometer)
                        bleManager.temperatureHistory.append(sensorData.temperature)
                        bleManager.batteryHistory.append(sensorData.battery)

                        if let heartRate = sensorData.heartRate {
                            bleManager.heartRateHistory.append(heartRate)
                        }
                        if let spo2 = sensorData.spo2 {
                            bleManager.spo2History.append(spo2)
                        }
                    }

                    // Convert imported string logs to LogMessage objects
                    for logString in imported.logs {
                        bleManager.logMessages.append(LogMessage(message: logString))
                    }

                    // Sort by timestamp
                    bleManager.sensorDataHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.ppgHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.accelerometerHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.temperatureHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.batteryHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.heartRateHistory.sort { $0.timestamp < $1.timestamp }
                    bleManager.spo2History.sort { $0.timestamp < $1.timestamp }

                    importedCount = imported.sensorData.count
                    showImportSuccess = true

                    bleManager.logMessages.append(LogMessage(
                        message: "✅ Successfully imported \(imported.sensorData.count) sensor data points"
                    ))
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

// MARK: - Action Card Component

struct ActionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let isEnabled: Bool
    var buttonStyle: ActionCardButtonStyle = .primary
    var accentColor: Color
    let action: () -> Void

    @EnvironmentObject var designSystem: DesignSystem

    enum ActionCardButtonStyle {
        case primary, secondary
    }

    var body: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(isEnabled ? accentColor : designSystem.colors.textDisabled)

            // Title
            Text(title)
                .font(designSystem.typography.title3)
                .foregroundColor(designSystem.colors.textPrimary)

            // Description
            Text(description)
                .font(designSystem.typography.callout)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Button
            Button(action: action) {
                Text(buttonText)
                    .font(designSystem.typography.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(
                        buttonStyle == .primary ?
                            (isEnabled ? accentColor : designSystem.colors.borderMedium) :
                            Color.clear
                    )
                    .foregroundColor(
                        buttonStyle == .primary ?
                            designSystem.colors.primaryWhite :
                            (isEnabled ? accentColor : designSystem.colors.textDisabled)
                    )
                    .cornerRadius(designSystem.cornerRadius.md)
                    .overlay(
                        buttonStyle == .secondary ?
                            RoundedRectangle(cornerRadius: designSystem.cornerRadius.md)
                                .stroke(isEnabled ? accentColor : designSystem.colors.borderMedium, lineWidth: 2) :
                            nil
                    )
            }
            .disabled(!isEnabled)
        }
        .padding(designSystem.spacing.lg)
        .frame(maxWidth: .infinity)
        .background(designSystem.colors.backgroundPrimary)
        .cornerRadius(designSystem.cornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: designSystem.cornerRadius.lg)
                .stroke(designSystem.colors.borderLight, lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
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

// MARK: - HealthKit Connection View (Placeholder)

struct HealthKitConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)

                Text("Connect to HealthKit")
                    .font(designSystem.typography.largeTitle)

                Text("Sync your Oralable data with Apple Health for comprehensive health tracking.")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    // TODO: Implement HealthKit connection
                    dismiss()
                }) {
                    Text("Connect")
                        .font(designSystem.typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("HealthKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct SharingView_Previews: PreviewProvider {
    static var previews: some View {
        SharingView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(AppStateManager.shared)
    }
}
