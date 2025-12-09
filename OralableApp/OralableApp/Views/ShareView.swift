//
//  ShareView.swift
//  OralableApp
//
//  Share screen - Share code and connections management
//  Updated: December 8, 2025 - Optimized CSV export performance
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ShareView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var sharedDataManager: SharedDataManager
    @ObservedObject var sensorDataProcessor: SensorDataProcessor
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject private var featureFlags = FeatureFlags.shared

    @State private var shareCode: String = ""
    @State private var isGeneratingCode = false
    @State private var showCopiedFeedback = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isExporting = false
    @State private var exportProgress: String = ""

    var body: some View {
        NavigationView {
            List {
                // Export section - ALWAYS SHOWN
                exportSection

                // Share with Professional section - CONDITIONAL
                if featureFlags.showShareWithProfessional {
                    shareCodeSection
                    sharedWithSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
        .task {
            // Only generate share code if feature is enabled
            if featureFlags.showShareWithProfessional {
                if shareCode.isEmpty {
                    await generateAndSaveShareCode()
                }
                // Refresh shared professionals list
                sharedDataManager.loadSharedProfessionals()

                // Sync current sensor data to CloudKit for professional access
                await sharedDataManager.uploadCurrentDataForSharing()
            }
        }
    }

    // MARK: - Export Section
    private var exportSection: some View {
        Section {
            Button(action: exportCSV) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .frame(width: 20, height: 20)
                            .frame(width: 32)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isExporting ? "Exporting..." : "Export Data as CSV")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        if isExporting && !exportProgress.isEmpty {
                            Text(exportProgress)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !isExporting {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isExporting)
        } header: {
            Text("Export")
        } footer: {
            let recordCount = sensorDataProcessor.sensorDataHistory.count
            Text("Export your sensor data for use in other applications (\(recordCount) records)")
        }
    }

    // MARK: - Share Code Section
    private var shareCodeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Share Code")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                HStack {
                    if isGeneratingCode {
                        ProgressView()
                            .frame(height: 38)
                    } else {
                        Text(shareCode.isEmpty ? "------" : shareCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Button(action: copyShareCode) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 20))
                            .foregroundColor(showCopiedFeedback ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(shareCode.isEmpty)
                }

                Text("Give this code to your healthcare professional to share your data")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                // Regenerate button
                Button(action: {
                    Task { await generateAndSaveShareCode() }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Generate New Code")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                }
                .disabled(isGeneratingCode)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Share with Professional")
        } footer: {
            Text("Code expires in 48 hours")
        }
    }

    // MARK: - Shared With Section
    private var sharedWithSection: some View {
        Section {
            if sharedDataManager.sharedProfessionals.isEmpty {
                Text("No one has access to your data")
                    .foregroundColor(.secondary)
            } else {
                ForEach(sharedDataManager.sharedProfessionals) { professional in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(professional.professionalName ?? professional.professionalID)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)

                            Text("Has access")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Remove") {
                            removeConnection(professional)
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Shared With")
        }
    }

    // MARK: - Actions
    
    private func generateAndSaveShareCode() async {
        await MainActor.run { isGeneratingCode = true }
        
        do {
            let code = try await sharedDataManager.createShareInvitation()
            await MainActor.run {
                shareCode = code
                isGeneratingCode = false
            }
            Logger.shared.info("[ShareView] ✅ Share code created and saved to CloudKit: \(code)")
        } catch {
            Logger.shared.error("[ShareView] ❌ Failed to create share invitation: \(error)")
            await MainActor.run {
                isGeneratingCode = false
                errorMessage = "Failed to create share code: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func copyShareCode() {
        UIPasteboard.general.string = shareCode
        showCopiedFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedFeedback = false
        }
    }

    private func removeConnection(_ professional: SharedProfessional) {
        Task {
            try? await sharedDataManager.revokeAccessForProfessional(professionalID: professional.professionalID)
        }
    }

    // MARK: - Export CSV (Optimized)
    private func exportCSV() {
        Task {
            await MainActor.run {
                isExporting = true
                exportProgress = "Preparing..."
            }
            
            if let url = await generateCSVFileOptimized() {
                await MainActor.run {
                    isExporting = false
                    exportProgress = ""
                    exportURL = url
                    showingExportSheet = true
                }
            } else {
                await MainActor.run {
                    isExporting = false
                    exportProgress = ""
                }
            }
        }
    }

    /// Optimized CSV generation using array join instead of string concatenation
    /// This is O(n) instead of O(n²) for string operations
    private func generateCSVFileOptimized() async -> URL? {
        let sensorData = sensorDataProcessor.sensorDataHistory
        let totalCount = sensorData.count
        
        guard totalCount > 0 else {
            await MainActor.run {
                errorMessage = "No data to export"
                showError = true
            }
            return nil
        }
        
        Logger.shared.info("[ShareView] 📊 Starting optimized CSV export with \(totalCount) records")
        let startTime = Date()
        
        // Pre-allocate array capacity for performance
        var lines: [String] = []
        lines.reserveCapacity(totalCount + 1)
        
        // Header
        lines.append("Timestamp,Device_Type,EMG,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temperature,Battery,Heart_Rate")
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Process in batches for UI updates
        let batchSize = 1000
        var processedCount = 0
        
        for data in sensorData {
            let timestamp = dateFormatter.string(from: data.timestamp)
            let heartRate = data.heartRate?.bpm ?? 0

            // Device type determines which columns get data
            let deviceTypeName: String
            let emgValue: Int32
            let ppgIRValue: Int32

            switch data.deviceType {
            case .anr:
                deviceTypeName = "ANR M40"
                emgValue = data.ppg.ir
                ppgIRValue = 0
            case .oralable:
                deviceTypeName = "Oralable"
                emgValue = 0
                ppgIRValue = data.ppg.ir
            case .demo:
                deviceTypeName = "Demo"
                emgValue = 0
                ppgIRValue = data.ppg.ir
            }

            // Build line using string interpolation (faster than repeated concatenation)
            let line = "\(timestamp),\(deviceTypeName),\(emgValue),\(ppgIRValue),\(data.ppg.red),\(data.ppg.green),\(data.accelerometer.x),\(data.accelerometer.y),\(data.accelerometer.z),\(data.temperature.celsius),\(data.battery.percentage),\(heartRate)"
            lines.append(line)
            
            processedCount += 1
            
            // Update progress every batch
            if processedCount % batchSize == 0 {
                let progress = Double(processedCount) / Double(totalCount) * 100
                await MainActor.run {
                    exportProgress = "Processing \(processedCount)/\(totalCount) (\(Int(progress))%)"
                }
                // Yield to allow UI updates
                await Task.yield()
            }
        }
        
        await MainActor.run {
            exportProgress = "Writing file..."
        }
        
        // Join all lines at once (O(n) operation)
        let csvString = lines.joined(separator: "\n")
        
        let fileName = "oralable_data_\(Int(Date().timeIntervalSince1970)).csv"
        
        // Save to Documents directory (for History view to find)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let elapsed = Date().timeIntervalSince(startTime)
            Logger.shared.info("[ShareView] ✅ CSV export complete: \(fileName) | \(totalCount) records | \(String(format: "%.2f", elapsed))s")
            
            return fileURL
        } catch {
            Logger.shared.error("[ShareView] ❌ Failed to create CSV: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to save CSV: \(error.localizedDescription)"
                showError = true
            }
            return nil
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CSV Document for File Export
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csvContent: String

    init(csvContent: String) {
        self.csvContent = csvContent
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
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
