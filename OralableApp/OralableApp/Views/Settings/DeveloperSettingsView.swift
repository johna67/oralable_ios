//
//  DeveloperSettingsView.swift
//  OralableApp
//
//  Created: December 4, 2025
//  Purpose: Hidden developer settings for enabling feature flags
//  Access: Tap "About" row 7 times in Settings
//

import SwiftUI

struct DeveloperSettingsView: View {
    @ObservedObject private var featureFlags = FeatureFlags.shared

    var body: some View {
        List {
            // Dashboard Features Section
            Section(header: Text("Dashboard Features")) {
                Toggle("Movement Card", isOn: $featureFlags.showMovementCard)
                Toggle("Temperature Card", isOn: $featureFlags.showTemperatureCard)
                Toggle("Heart Rate Card", isOn: $featureFlags.showHeartRateCard)
                Toggle("SpO2 Card", isOn: $featureFlags.showSpO2Card)
                Toggle("Battery Card", isOn: $featureFlags.showBatteryCard)
            }

            // Settings Features Section
            Section(header: Text("Settings Features")) {
                Toggle("Subscription", isOn: $featureFlags.showSubscription)
                Toggle("Health Integration", isOn: $featureFlags.showHealthIntegration)
                Toggle("Detection Settings", isOn: $featureFlags.showDetectionSettings)
            }
        }
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
