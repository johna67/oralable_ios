//
//  AddPatientView.swift
//  OralableForProfessionals
//
//  Updated: December 10, 2025 - Added CSV import option
//

import SwiftUI
import UniformTypeIdentifiers

struct AddPatientView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: ProfessionalDataManager
    @EnvironmentObject var designSystem: DesignSystem

    // Add method selection
    @State private var addMethod: AddMethod = .shareCode

    // Share code states
    @State private var shareCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var isCodeFieldFocused: Bool

    // CSV import states
    @State private var participantName = ""
    @State private var showFilePicker = false
    @State private var importPreview: CSVImportPreview?
    @State private var showImportSuccess = false

    enum AddMethod: String, CaseIterable {
        case shareCode = "Share Code"
        case csvUpload = "CSV Import"

        var icon: String {
            switch self {
            case .shareCode: return "icloud"
            case .csvUpload: return "doc.text"
            }
        }

        var description: String {
            switch self {
            case .shareCode: return "Connect for live data sync"
            case .csvUpload: return "Import historical data from CSV file"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Method Picker
                        methodPicker
                            .padding(.top, 16)

                        // Content based on selected method
                        if addMethod == .shareCode {
                            shareCodeContent
                        } else {
                            csvUploadContent
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if addMethod == .shareCode {
                    isCodeFieldFocused = true
                }
            }
            .alert("Participant Added", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("You can now view this participant's oral wellness data.")
            }
            .alert("Import Successful", isPresented: $showImportSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                if let preview = importPreview {
                    Text("Imported \(preview.dataPoints.count) data points for \(participantName).")
                } else {
                    Text("Participant data has been imported.")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Method Picker

    private var methodPicker: some View {
        VStack(spacing: 16) {
            Picker("Add Method", selection: $addMethod) {
                ForEach(AddMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)

            // Method description
            HStack(spacing: 8) {
                Image(systemName: addMethod.icon)
                    .foregroundColor(.secondary)
                Text(addMethod.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Share Code Content

    private var shareCodeContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.black)

                Text("Enter Share Code")
                    .font(.title2.bold())

                Text("Ask your participant to generate a 6-digit share code in their Oralable app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Code field
            VStack(spacing: 16) {
                ShareCodeField(code: $shareCode)
                    .focused($isCodeFieldFocused)

                if let error = errorMessage, addMethod == .shareCode {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            // Connect button
            Button(action: addPatient) {
                HStack {
                    if isLoading && addMethod == .shareCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("Connect")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValidShareCode ? Color.black : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isValidShareCode || isLoading)

            // Instructions
            instructionsCard(
                title: "How to get a share code",
                steps: [
                    "Participant opens Oralable app",
                    "Goes to Share tab",
                    "Their 6-digit code is displayed",
                    "Code expires after 48 hours"
                ]
            )
        }
    }

    // MARK: - CSV Upload Content

    private var csvUploadContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.black)

                Text("Import CSV Data")
                    .font(.title2.bold())

                Text("Import historical data from a CSV file exported from the Oralable app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Participant name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Participant Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Enter name or identifier", text: $participantName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)
            }

            // File picker button
            Button(action: { showFilePicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text(importPreview == nil ? "Select CSV File" : "Change File")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(12)
            }

            // Import preview
            if let preview = importPreview {
                importPreviewCard(preview)
            }

            // Import button
            if importPreview != nil {
                Button(action: importCSVData) {
                    HStack {
                        if isLoading && addMethod == .csvUpload {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Participant")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canImport ? Color.black : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canImport || isLoading)
            }

            // Instructions
            instructionsCard(
                title: "How to export CSV from Oralable",
                steps: [
                    "Participant opens Oralable app",
                    "Goes to Share tab",
                    "Taps 'Export Data as CSV'",
                    "Sends CSV file to you"
                ]
            )
        }
    }

    // MARK: - Import Preview Card

    private func importPreviewCard(_ preview: CSVImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("File Ready")
                    .font(.headline)
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                previewRow(label: "File", value: preview.fileName)
                previewRow(label: "Data Points", value: "\(preview.dataPoints.count)")
                previewRow(label: "Date Range", value: preview.dateRange)
                previewRow(label: "Device", value: preview.deviceTypes.joined(separator: ", "))
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func previewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Instructions Card

    private func instructionsCard(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.gray)
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var isValidShareCode: Bool {
        shareCode.count == 6 && Int(shareCode) != nil
    }

    private var canImport: Bool {
        !participantName.isEmpty && importPreview != nil && !(importPreview?.dataPoints.isEmpty ?? true)
    }

    // MARK: - Actions

    private func addPatient() {
        guard isValidShareCode else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await dataManager.addPatientWithShareCode(shareCode)
                showSuccess = true
            } catch let error as ProfessionalDataError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Failed to add participant. Please try again."
            }
            isLoading = false
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            parseCSVFile(url)
        case .failure(let error):
            errorMessage = "Failed to access file: \(error.localizedDescription)"
        }
    }

    private func parseCSVFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access the selected file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let dataPoints = CSVParser.parse(content)

            if dataPoints.isEmpty {
                errorMessage = "No valid data found in CSV file"
                return
            }

            importPreview = CSVImportPreview(
                fileName: url.lastPathComponent,
                dataPoints: dataPoints
            )

            // Auto-fill name from filename if empty
            if participantName.isEmpty {
                let filename = url.deletingPathExtension().lastPathComponent
                if filename.hasPrefix("oralable_data_") {
                    // Extract timestamp portion for a cleaner name
                    let suffix = String(filename.dropFirst("oralable_data_".count))
                    participantName = "Import \(suffix.prefix(10))"
                } else {
                    participantName = filename
                }
            }

            Logger.shared.info("[AddPatientView] CSV parsed: \(dataPoints.count) data points")

        } catch {
            errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
        }
    }

    private func importCSVData() {
        guard let preview = importPreview, !participantName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await dataManager.importParticipantFromCSV(
                    name: participantName,
                    data: preview.dataPoints
                )
                showImportSuccess = true
            } catch {
                errorMessage = "Failed to import: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - Share Code Field (unchanged)

struct ShareCodeField: View {
    @Binding var code: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitBox(
                        digit: getDigit(at: index),
                        isActive: index == code.count
                    )
                }
            }

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: code) { _, newValue in
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                    code = newValue.filter { $0.isNumber }
                }
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    private func getDigit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }
}

struct CodeDigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.black : Color(UIColor.systemGray4), lineWidth: isActive ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                )

            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: 48, height: 56)
    }
}
