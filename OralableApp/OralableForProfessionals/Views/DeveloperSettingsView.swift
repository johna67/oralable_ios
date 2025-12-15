//
//  DeveloperSettingsView.swift
//  OralableForProfessionals
//
//  Developer settings for feature flag control
//  Access via 7-tap on version number in Settings
//  Updated: December 13, 2025 - Simplified for pre-launch
//

import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject private var featureFlags = FeatureFlags.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            // Dashboard Features Section
            Section("Dashboard Features") {
                Toggle("EMG Card", isOn: $featureFlags.showEMGCard)
                Toggle("Movement Card", isOn: $featureFlags.showMovementCard)
                Toggle("Temperature Card", isOn: $featureFlags.showTemperatureCard)
                Toggle("Heart Rate Card", isOn: $featureFlags.showHeartRateCard)
            }

            // Research Features Section
            Section("Research Features") {
                Toggle("Multi-Participant", isOn: $featureFlags.showMultiParticipant)
                Toggle("Data Export", isOn: $featureFlags.showDataExport)
                Toggle("CloudKit Sharing", isOn: $featureFlags.showCloudKitShare)
            }

            // Subscription Section
            Section("Subscription") {
                Toggle("Subscription UI", isOn: $featureFlags.showSubscription)
            }

            // Reset Section
            Section {
                Button("Reset to Defaults") {
                    featureFlags.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Developer Settings")
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
