//
//  ThresholdConfigurationView.swift
//  OralableApp
//
//  Threshold configuration for health metrics
//

import SwiftUI

struct ThresholdConfigurationView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    @State private var minValue: Double = 60
    @State private var maxValue: Double = 100
    @State private var sensitivity: ThresholdSensitivity = .medium
    @State private var showingResetAlert = false

    enum ThresholdSensitivity: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                    Text("Minimum Value")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Slider(value: $minValue, in: 0...200, step: 1)
                            .accentColor(designSystem.colors.accentBlue)

                        Text("\(Int(minValue))")
                            .font(designSystem.typography.bodyBold)
                            .foregroundColor(designSystem.colors.textPrimary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                    Text("Maximum Value")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Slider(value: $maxValue, in: 0...200, step: 1)
                            .accentColor(designSystem.colors.accentRed)

                        Text("\(Int(maxValue))")
                            .font(designSystem.typography.bodyBold)
                            .foregroundColor(designSystem.colors.textPrimary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            } header: {
                Text("Threshold Range")
            } footer: {
                Text("Values outside this range will trigger alerts.")
            }

            Section {
                Picker("Sensitivity", selection: $sensitivity) {
                    ForEach(ThresholdSensitivity.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Alert Sensitivity")
            } footer: {
                Text(sensitivityDescription)
            }

            Section {
                // Preview visualization
                VStack(spacing: designSystem.spacing.sm) {
                    Text("Threshold Preview")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(designSystem.colors.backgroundTertiary)
                            .frame(height: 60)

                        // Safe zone
                        RoundedRectangle(cornerRadius: 8)
                            .fill(designSystem.colors.accentGreen.opacity(0.3))
                            .frame(width: safeZoneWidth, height: 60)
                            .offset(x: safeZoneOffset)

                        // Min marker
                        Rectangle()
                            .fill(designSystem.colors.accentBlue)
                            .frame(width: 2, height: 60)
                            .offset(x: CGFloat(minValue / 200) * 300)

                        // Max marker
                        Rectangle()
                            .fill(designSystem.colors.accentRed)
                            .frame(width: 2, height: 60)
                            .offset(x: CGFloat(maxValue / 200) * 300)
                    }
                    .frame(width: 300, height: 60)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Section {
                Button(action: {
                    showingResetAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("Reset to Defaults")
                            .foregroundColor(designSystem.colors.error)
                        Spacer()
                    }
                }

                Button(action: {
                    // Save thresholds
                    dismiss()
                }) {
                    HStack {
                        Spacer()
                        Text("Save")
                            .foregroundColor(designSystem.colors.accentBlue)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Configure Thresholds")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Thresholds", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("This will reset all threshold values to their defaults.")
        }
    }

    // MARK: - Computed Properties

    private var sensitivityDescription: String {
        switch sensitivity {
        case .low:
            return "Fewer alerts, only for significant deviations"
        case .medium:
            return "Balanced alert frequency"
        case .high:
            return "More frequent alerts for early detection"
        }
    }

    private var safeZoneWidth: CGFloat {
        CGFloat((maxValue - minValue) / 200) * 300
    }

    private var safeZoneOffset: CGFloat {
        CGFloat(minValue / 200) * 300
    }

    // MARK: - Actions

    private func resetToDefaults() {
        minValue = 60
        maxValue = 100
        sensitivity = .medium
    }
}

// MARK: - Preview

struct ThresholdConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ThresholdConfigurationView()
                .environmentObject(DesignSystem.shared)
        }
    }
}
