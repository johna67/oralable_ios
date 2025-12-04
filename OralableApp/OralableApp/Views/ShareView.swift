//
//  ShareView.swift
//  OralableApp
//
//  Share screen - Share code and connections management
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

    var body: some View {
        NavigationView {
            List {
                // Export section - ALWAYS SHOWN
                exportSection

                // Share with Dentist section - CONDITIONAL
                if featureFlags.showShareWithDentist {
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
            if featureFlags.showShareWithDentist {
                if shareCode.isEmpty {
                    await generateAndSaveShareCode()
                }
                // Refresh shared dentists list
                sharedDataManager.loadSharedDentists()

                // Sync current sensor data to CloudKit for dentist access
                await sharedDataManager.uploadCurrentDataForSharing()
            }
        }
    }

    // MARK: - Export Section
    private var exportSection: some View {
        Section {
            Button(action: exportCSV) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    Text("Export Data as CSV")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Export")
        } footer: {
            Text("Export your sensor data for use in other applications")
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

                Text("Give this code to your dentist to share your data")
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
            Text("Share with Dentist")
        } footer: {
            Text("Code expires in 48 hours")
        }
    }

    // MARK: - Shared With Section
    private var sharedWithSection: some View {
        Section {
            if sharedDataManager.sharedDentists.isEmpty {
                Text("No one has access to your data")
                    .foregroundColor(.secondary)
            } else {
                ForEach(sharedDataManager.sharedDentists) { dentist in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dentist.dentistName ?? dentist.dentistID)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)

                            Text("Has access")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Remove") {
                            removeConnection(dentist)
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

    private func removeConnection(_ dentist: SharedDentist) {
        Task {
            try? await sharedDataManager.revokeAccessForDentist(dentistID: dentist.dentistID)
        }
    }

    // MARK: - Export CSV
    private func exportCSV() {
        Task {
            if let url = await generateCSVFile() {
                await MainActor.run {
                    exportURL = url
                    showingExportSheet = true
                }
            }
        }
    }

    private func generateCSVFile() async -> URL? {
        let sensorData = sensorDataProcessor.sensorDataHistory
        var csvString = "Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temperature,Battery,Heart_Rate\n"

        let dateFormatter = ISO8601DateFormatter()

        for data in sensorData {
            let timestamp = dateFormatter.string(from: data.timestamp)
            let heartRate = data.heartRate?.bpm ?? 0
            let line = "\(timestamp),\(data.ppg.ir),\(data.ppg.red),\(data.ppg.green),\(data.accelerometer.x),\(data.accelerometer.y),\(data.accelerometer.z),\(data.temperature.celsius),\(data.battery.percentage),\(heartRate)\n"
            csvString.append(line)
        }

        let fileName = "oralable_data_\(Int(Date().timeIntervalSince1970)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            Logger.shared.info("[ShareView] CSV file created: \(fileName) with \(sensorData.count) records")
            return tempURL
        } catch {
            Logger.shared.error("[ShareView] Failed to create CSV: \(error.localizedDescription)")
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
