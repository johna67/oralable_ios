//
//  DeveloperSettingsView.swift
//  OralableForProfessionals
//
//  Developer settings for feature flag control
//  Access via 7-tap on version number in Settings
//

import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject private var featureFlags = FeatureFlags.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            Section {
                Text("Control which features are visible. Pre-launch configuration hides advanced features for App Store approval.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Dashboard Features")) {
                Toggle("Movement Card", isOn: $featureFlags.showMovementCard)
                Toggle("Temperature Card", isOn: $featureFlags.showTemperatureCard)
                Toggle("Heart Rate Card", isOn: $featureFlags.showHeartRateCard)
                Toggle("Advanced Analytics", isOn: $featureFlags.showAdvancedAnalytics)
            }

            Section(header: Text("Research Features")) {
                Toggle("Multi-Participant", isOn: $featureFlags.showMultiParticipant)
                Toggle("Data Export", isOn: $featureFlags.showDataExport)
                Toggle("ANR Comparison", isOn: $featureFlags.showANRComparison)
                Toggle("CloudKit Sharing", isOn: $featureFlags.showCloudKitShare)
                    .tint(.blue)
            }

            Section(header: Text("Settings Features")) {
                Toggle("Subscription", isOn: $featureFlags.showSubscription)
            }

            Section(header: Text("Presets")) {
                Button {
                    featureFlags.applyAppStoreMinimalConfig()
                } label: {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.blue)
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
                        Text("Apply Pre-Launch Config")
                    }
                }

                Button {
                    featureFlags.applyWellnessConfig()
                } label: {
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundColor(.purple)
                        Text("Apply Wellness Config")
                    }
                }

                Button {
                    featureFlags.applyResearchConfig()
                } label: {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.blue)
                        Text("Apply Research Config")
                    }
                }

                Button {
                    featureFlags.applyFullConfig()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Apply Full Config")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    featureFlags.resetToDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
            }

            Section(header: Text("Current Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    configRow("Movement", featureFlags.showMovementCard)
                    configRow("Temperature", featureFlags.showTemperatureCard)
                    configRow("Heart Rate", featureFlags.showHeartRateCard)
                    configRow("Advanced Analytics", featureFlags.showAdvancedAnalytics)
                    configRow("Subscription", featureFlags.showSubscription)
                    configRow("Multi-Participant", featureFlags.showMultiParticipant)
                    configRow("Data Export", featureFlags.showDataExport)
                    configRow("ANR Comparison", featureFlags.showANRComparison)
                    configRow("CloudKit Share", featureFlags.showCloudKitShare)
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
