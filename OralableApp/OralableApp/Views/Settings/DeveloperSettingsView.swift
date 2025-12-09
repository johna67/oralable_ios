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
            // Info Section
            Section {
                Text("These settings control which features are visible in the app. Pre-launch configuration hides advanced features for simpler App Store approval.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Dashboard Features Section
            Section(header: Text("Dashboard Features")) {
                Toggle("Movement Card", isOn: $featureFlags.showMovementCard)
                Toggle("Temperature Card", isOn: $featureFlags.showTemperatureCard)
                Toggle("Heart Rate Card", isOn: $featureFlags.showHeartRateCard)
                Toggle("SpO2 Card", isOn: $featureFlags.showSpO2Card)
                Toggle("Battery Card", isOn: $featureFlags.showBatteryCard)
                Toggle("ANR M40 Device Support", isOn: $featureFlags.showAdvancedMetrics)
            }

            // Share Features Section
            Section(header: Text("Share Features")) {
                Toggle("Share with Professional", isOn: $featureFlags.showShareWithProfessional)
                Toggle("Share for Research Studies", isOn: $featureFlags.showShareWithResearcher)
            }

            // Settings Features Section
            Section(header: Text("Settings Features")) {
                Toggle("Subscription", isOn: $featureFlags.showSubscription)
                Toggle("Health Integration", isOn: $featureFlags.showHealthIntegration)
                Toggle("Detection Settings", isOn: $featureFlags.showDetectionSettings)
            }

            // Presets Section
            Section(header: Text("Presets")) {
                Button(action: {
                    featureFlags.applyPreLaunchConfig()
                }) {
                    HStack {
                        Image(systemName: "app.badge.checkmark")
                            .foregroundColor(.orange)
                        Text("Apply Pre-Launch Config")
                        Spacer()
                        Text("Minimal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    featureFlags.applyWellnessConfig()
                }) {
                    HStack {
                        Image(systemName: "heart.circle")
                            .foregroundColor(.pink)
                        Text("Apply Wellness Config")
                        Spacer()
                        Text("Consumer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    featureFlags.applyResearchConfig()
                }) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundColor(.purple)
                        Text("Apply Research Config")
                        Spacer()
                        Text("Research")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    featureFlags.applyFullConfig()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Apply Full Config")
                        Spacer()
                        Text("All Features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Reset Section
            Section {
                Button(action: {
                    featureFlags.resetToDefaults()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                    }
                }
            } footer: {
                Text("Resets all feature flags to pre-launch defaults.")
            }

            // Current Configuration Debug
            Section(header: Text("Current Configuration")) {
                Text(featureFlags.currentConfigDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
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
