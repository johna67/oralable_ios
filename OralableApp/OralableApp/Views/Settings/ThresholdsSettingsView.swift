//
//  ThresholdsSettingsView.swift
//  OralableApp
//
//  Created: December 2025
//  Purpose: Settings screen for adjusting detection thresholds
//

import SwiftUI

struct ThresholdsSettingsView: View {
    @ObservedObject private var settings = ThresholdSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Movement Threshold Section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with current value
                    HStack {
                        Text("Movement Threshold")
                            .font(.headline)
                        Spacer()
                        Text(formatThreshold(settings.movementThreshold))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(thresholdColor)
                    }

                    // Slider
                    Slider(
                        value: $settings.movementThreshold,
                        in: ThresholdSettings.movementThresholdRange,
                        step: ThresholdSettings.movementThresholdStep
                    )
                    .tint(.blue)

                    // Labels
                    HStack {
                        VStack(alignment: .leading) {
                            Text("More Sensitive")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("500")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Less Sensitive")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("5K")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Visual indicator
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(isCurrentlyActive ? .green : .blue)
                        Text(isCurrentlyActive ? "More likely to show Active" : "More likely to show Still")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Movement Detection")
            } footer: {
                Text("Adjusts how much movement is required to change from 'Still' (blue) to 'Active' (green) on the dashboard. Default is 1.5K.")
            }

            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(
                        icon: "arrow.down.circle.fill",
                        color: .green,
                        title: "Lower values (500-1000)",
                        description: "Detect small movements. Good for sensitive monitoring."
                    )

                    Divider()

                    infoRow(
                        icon: "minus.circle.fill",
                        color: .blue,
                        title: "Default value (1500)",
                        description: "Balanced sensitivity for typical use."
                    )

                    Divider()

                    infoRow(
                        icon: "arrow.up.circle.fill",
                        color: .orange,
                        title: "Higher values (2000-5000)",
                        description: "Only detect significant movement. Reduces false positives."
                    )
                }
                .padding(.vertical, 4)
            } header: {
                Text("Guide")
            }

            // Reset Section
            Section {
                Button(action: {
                    withAnimation {
                        settings.resetToDefaults()
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Thresholds")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Views

    private func infoRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var thresholdColor: Color {
        if settings.movementThreshold < 1000 {
            return .green
        } else if settings.movementThreshold > 2500 {
            return .orange
        } else {
            return .blue
        }
    }

    private var isCurrentlyActive: Bool {
        settings.movementThreshold < ThresholdSettings.defaultMovementThreshold
    }

    // MARK: - Helper Functions

    private func formatThreshold(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThresholdsSettingsView()
    }
}
