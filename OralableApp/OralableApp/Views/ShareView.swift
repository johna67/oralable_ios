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

    @State private var shareCode: String = ""
    @State private var isGeneratingCode = false
    @State private var showCopiedFeedback = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL? = nil

    var body: some View {
        NavigationView {
            List {
                shareCodeSection
                exportSection
                sharedWithSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if shareCode.isEmpty {
                shareCode = sharedDataManager.generateShareCode()
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
                    Text(shareCode.isEmpty ? "------" : shareCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: copyShareCode) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 20))
                            .foregroundColor(showCopiedFeedback ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("Give this code to your dentist to share your data")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Share with Dentist")
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

// MARK: - Preview
struct ShareView_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        let authManager = AuthenticationManager()
        let healthKitManager = HealthKitManager()
        let sensorDataProcessor = SensorDataProcessor.shared
        let deviceManager = DeviceManager()
        let sharedDataManager = SharedDataManager(
            authenticationManager: authManager,
            healthKitManager: healthKitManager,
            sensorDataProcessor: sensorDataProcessor
        )

        ShareView(sensorDataProcessor: sensorDataProcessor, deviceManager: deviceManager)
            .environmentObject(designSystem)
            .environmentObject(sharedDataManager)
    }
}
