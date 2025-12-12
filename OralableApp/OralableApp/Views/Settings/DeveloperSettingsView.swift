//
//  DeveloperSettingsView.swift
//  OralableApp
//
//  Created: December 4, 2025
//  Purpose: Hidden developer settings for enabling feature flags
//  Access: Tap "About" row 7 times in Settings
//  Updated: December 12, 2025 - Added CloudKit toggle and preset buttons
//

import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject private var featureFlags = FeatureFlags.shared

    var body: some View {
        List {
            // Info Section
            Section {
                Text("Control which features are visible. Pre-launch configuration hides advanced features for App Store approval.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Dashboard Features Section
            Section(header: Text("Dashboard Features")) {
                Toggle("EMG Card", isOn: $featureFlags.showEMGCard)
                Toggle("Movement Card", isOn: $featureFlags.showMovementCard)
                Toggle("Temperature Card", isOn: $featureFlags.showTemperatureCard)
                Toggle("Heart Rate Card", isOn: $featureFlags.showHeartRateCard)
                Toggle("SpO2 Card", isOn: $featureFlags.showSpO2Card)
                Toggle("Battery Card", isOn: $featureFlags.showBatteryCard)
                Toggle("Advanced Metrics", isOn: $featureFlags.showAdvancedMetrics)
            }

            // Share Features Section
            Section {
                Toggle("Share with Professional", isOn: $featureFlags.showShareWithProfessional)
                Toggle("Share with Researcher", isOn: $featureFlags.showShareWithResearcher)
                Toggle("CloudKit Sharing", isOn: $featureFlags.showCloudKitShare)
                    .tint(.blue)
            } header: {
                Text("Share Features")
            } footer: {
                Text("CloudKit Sharing enables share codes. Disable for CSV-only mode.")
                    .font(.caption2)
            }

            // Settings Features Section
            Section(header: Text("Settings Features")) {
                Toggle("Subscription", isOn: $featureFlags.showSubscription)
                Toggle("Health Integration", isOn: $featureFlags.showHealthIntegration)
                Toggle("Detection Settings", isOn: $featureFlags.showDetectionSettings)
            }

            // Presets Section
            Section(header: Text("Configuration Presets")) {
                Button {
                    featureFlags.applyAppStoreMinimalConfig()
                } label: {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Apply App Store Minimal")
                        Spacer()
                        Text("CSV Only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    featureFlags.applyPreLaunchConfig()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Apply Pre-Launch Config")
                    }
                }

                Button {
                    featureFlags.applyWellnessConfig()
                } label: {
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Apply Wellness Config")
                    }
                }

                Button {
                    featureFlags.applyResearchConfig()
                } label: {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.teal)
                            .frame(width: 24)
                        Text("Apply Research Config")
                    }
                }

                Button {
                    featureFlags.applyFullConfig()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("Apply Full Config")
                    }
                }
            }

            // Reset Section
            Section {
                Button(role: .destructive) {
                    featureFlags.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 24)
                        Text("Reset to Defaults")
                    }
                }
            }

            // Current Configuration Summary
            Section(header: Text("Current Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    configRow("EMG", featureFlags.showEMGCard)
                    configRow("Movement", featureFlags.showMovementCard)
                    configRow("Temperature", featureFlags.showTemperatureCard)
                    configRow("Heart Rate", featureFlags.showHeartRateCard)
                    configRow("SpO2", featureFlags.showSpO2Card)
                    configRow("Battery", featureFlags.showBatteryCard)
                    configRow("CloudKit Share", featureFlags.showCloudKitShare)
                    configRow("Subscription", featureFlags.showSubscription)
                    configRow("Health Integration", featureFlags.showHealthIntegration)
                }
                .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func configRow(_ name: String, _ enabled: Bool) -> some View {
        HStack {
            Text(name)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .gray)
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
