//
//  SessionHistoryView.swift
//  OralableApp
//
//  Created: December 6, 2025
//  Purpose: History view with segmented control to filter EMG (ANR M40) and IR (Oralable) sessions
//

import SwiftUI

/// Filter options for session history
enum SessionHistoryFilter: String, CaseIterable {
    case all = "All"
    case emg = "EMG"
    case ir = "IR"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .emg: return "bolt.horizontal.circle.fill"
        case .ir: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .all: return .primary
        case .emg: return .blue
        case .ir: return .purple
        }
    }

    var description: String {
        switch self {
        case .all: return "All Sessions"
        case .emg: return "ANR M40 (EMG)"
        case .ir: return "Oralable (IR)"
        }
    }
}

struct SessionHistoryView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @ObservedObject var sessionManager: RecordingSessionManager

    @State private var selectedFilter: SessionHistoryFilter = .all

    /// Filtered sessions based on selected filter
    private var filteredSessions: [RecordingSession] {
        switch selectedFilter {
        case .all:
            return sessionManager.sessions
        case .emg:
            return sessionManager.emgSessions
        case .ir:
            return sessionManager.irSessions
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented filter picker
                filterPicker
                    .padding()

                // Session count summary
                sessionSummary
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // Session list or empty state
                if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Subviews

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(SessionHistoryFilter.allCases, id: \.self) { filter in
                HStack {
                    Image(systemName: filter.icon)
                    Text(filter.rawValue)
                }
                .tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sessionSummary: some View {
        HStack {
            Text("\(filteredSessions.count) session\(filteredSessions.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // Show breakdown when "All" is selected
            if selectedFilter == .all && sessionManager.sessions.count > 0 {
                HStack(spacing: 12) {
                    if sessionManager.emgSessions.count > 0 {
                        Label("\(sessionManager.emgSessions.count)", systemImage: "bolt.horizontal.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    if sessionManager.irSessions.count > 0 {
                        Label("\(sessionManager.irSessions.count)", systemImage: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
    }

    private var sessionList: some View {
        List {
            ForEach(filteredSessions) { session in
                SessionRowView(session: session)
            }
            .onDelete(perform: deleteSession)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: selectedFilter.icon)
                .font(.system(size: 60))
                .foregroundColor(selectedFilter.color.opacity(0.5))

            Text("No \(selectedFilter.description) Found")
                .font(.headline)
                .foregroundColor(.primary)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Start a recording session to see your history here."
        case .emg:
            return "Connect an ANR M40 device and start recording to capture EMG data."
        case .ir:
            return "Connect an Oralable device and start recording to capture IR data."
        }
    }

    // MARK: - Actions

    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            sessionManager.deleteSession(session)
        }
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: RecordingSession

    private var dataTypeColor: Color {
        switch session.deviceType {
        case .anr: return .blue
        case .oralable: return .purple
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Data type indicator
            Image(systemName: session.dataTypeIcon)
                .font(.title2)
                .foregroundColor(dataTypeColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                // Device name and type badge
                HStack {
                    Text(session.deviceName ?? "Unknown Device")
                        .font(.headline)

                    Text(session.dataTypeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(dataTypeColor)
                        .cornerRadius(4)
                }

                // Date and duration
                HStack {
                    Text(session.startTime, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(session.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Data counts
                HStack(spacing: 8) {
                    if session.sensorDataCount > 0 {
                        Label("\(session.sensorDataCount)", systemImage: "waveform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if session.heartRateDataCount > 0 {
                        Label("\(session.heartRateDataCount)", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // Status indicator
            Image(systemName: session.status.icon)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .recording: return .red
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    SessionHistoryView(sessionManager: RecordingSessionManager())
        .environmentObject(DesignSystem())
}
