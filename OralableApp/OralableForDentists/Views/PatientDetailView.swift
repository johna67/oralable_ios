import SwiftUI

struct PatientDetailView: View {
    let patient: DentistPatient
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DentistDataManager

    @State private var healthSummaries: [PatientHealthSummary] = []
    @State private var isLoading = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var errorMessage: String?

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                    // Patient Header
                    PatientHeader(patient: patient)

                    // Time Range Selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView("Loading data...")
                            .padding()
                    } else if healthSummaries.isEmpty {
                        EmptyDataView()
                    } else {
                        // Summary Cards
                        VStack(spacing: 16) {
                            SummaryCard(
                                title: "Total Sessions",
                                value: "\(healthSummaries.count)",
                                icon: "calendar",
                                color: .blue
                            )

                            SummaryCard(
                                title: "Avg. Bruxism Events",
                                value: String(format: "%.0f", averageBruxismEvents()),
                                icon: "waveform.path.ecg",
                                color: .red
                            )

                            SummaryCard(
                                title: "Avg. Session Duration",
                                value: averageSessionDuration(),
                                icon: "clock",
                                color: .green
                            )

                            SummaryCard(
                                title: "Peak Intensity",
                                value: String(format: "%.1f", maxIntensity()),
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                        }
                        .padding(.horizontal)

                        // Session List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.title3.bold())
                                .padding(.horizontal)

                            ForEach(healthSummaries.prefix(10), id: \.recordingDate) { summary in
                                SessionRow(summary: summary)
                            }
                        }
                    }

                    // Show error inline instead of alert
                    if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)

                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Patient Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await loadData()
                }
            }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate

        do {
            let data = try await dataManager.fetchPatientHealthData(
                for: patient,
                from: startDate,
                to: endDate
            )
            healthSummaries = data
        } catch {
            errorMessage = "Failed to load patient data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    private func averageBruxismEvents() -> Double {
        guard !healthSummaries.isEmpty else { return 0 }
        let total = healthSummaries.reduce(0) { $0 + $1.bruxismEvents }
        return Double(total) / Double(healthSummaries.count)
    }

    private func averageSessionDuration() -> String {
        guard !healthSummaries.isEmpty else { return "0h 0m" }
        let totalSeconds = healthSummaries.reduce(0.0) { $0 + $1.sessionDuration }
        let avgSeconds = totalSeconds / Double(healthSummaries.count)

        let hours = Int(avgSeconds) / 3600
        let minutes = Int(avgSeconds) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }

    private func maxIntensity() -> Double {
        return healthSummaries.map { $0.peakIntensity }.max() ?? 0.0
    }
}

// MARK: - Patient Header

struct PatientHeader: View {
    let patient: DentistPatient

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text(patient.displayName)
                .font(.title2.bold())

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formattedDate(patient.accessGrantedDate))
                        .font(.subheadline)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("Patient ID")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(patient.anonymizedID)
                        .font(.subheadline.monospaced())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title2.bold())
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let summary: PatientHealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(summary.recordingDate))
                        .font(.headline)

                    Text(summary.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(summary.bruxismEvents) events")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)

                    Text("Intensity: \(String(format: "%.1f", summary.peakIntensity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
        }
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty Data View

struct EmptyDataView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Data Available")
                .font(.title3.bold())

            Text("No health data has been recorded for this time period")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

#Preview {
    PatientDetailView(patient: DentistPatient(
        id: "1",
        patientID: "patient123",
        patientName: "John Doe",
        shareCode: "123456",
        accessGrantedDate: Date(),
        lastDataUpdate: Date(),
        recordID: "record1"
    ))
    .environmentObject(DentistDataManager.shared)
}
