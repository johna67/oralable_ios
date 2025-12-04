//
//  SettingsView.swift
//  OralableApp
//
//  Settings - Subscription and Health Integration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager
    @ObservedObject private var featureFlags = FeatureFlags.shared

    @State private var showSubscriptionInfo = false
    @State private var developerTapCount = 0
    @State private var showDeveloperSettings = false

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                // Subscription Section - CONDITIONAL
                if featureFlags.showSubscription {
                    Section {
                        subscriptionRow
                    } header: {
                        Text("Subscription")
                    }
                }

                // Health Integration Section - CONDITIONAL
                if featureFlags.showHealthIntegration {
                    Section {
                        healthKitRow
                    } header: {
                        Text("Health Integration")
                    }
                }

                // Detection Settings Section - CONDITIONAL
                if featureFlags.showDetectionSettings {
                    Section {
                        thresholdsRow
                    } header: {
                        Text("Detection Settings")
                    }
                }

                // About Section - ALWAYS SHOWN (with hidden developer access)
                Section {
                    aboutRow
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSubscriptionInfo) {
                SubscriptionInfoView()
            }
            .sheet(isPresented: $showDeveloperSettings) {
                NavigationStack {
                    DeveloperSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showDeveloperSettings = false
                                }
                            }
                        }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - About Row (with hidden developer access)
    private var aboutRow: some View {
        Button(action: {
            developerTapCount += 1
            if developerTapCount >= 7 {
                showDeveloperSettings = true
                developerTapCount = 0
            }
            // Reset after 2 seconds of no taps
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if developerTapCount > 0 && developerTapCount < 7 {
                    developerTapCount = 0
                }
            }
        }) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("About")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)

                    Text("Version 1.0")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var subscriptionRow: some View {
        Button(action: { showSubscriptionInfo = true }) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Plan")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(dependencies.subscriptionManager.currentTier.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)

                        if dependencies.subscriptionManager.currentTier == .premium {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                if dependencies.subscriptionManager.currentTier == .basic {
                    Text("Upgrade")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var healthKitRow: some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundColor(.red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health")
                    .font(.system(size: 17))
                    .foregroundColor(.primary)

                Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                    .font(.system(size: 15))
                    .foregroundColor(healthKitManager.isAuthorized ? .green : .secondary)
            }

            Spacer()

            if !healthKitManager.isAuthorized {
                Button("Enable") {
                    Task {
                        try? await healthKitManager.requestAuthorization()
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var thresholdsRow: some View {
        NavigationLink {
            ThresholdsSettingsView()
        } label: {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Thresholds")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)

                    Text("Adjust movement sensitivity")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview("Settings View") {
    let designSystem = DesignSystem()

    let authManager = AuthenticationManager()
    let healthKitManager = HealthKitManager()
    let recordingSessionManager = RecordingSessionManager()
    let historicalDataManager = HistoricalDataManager(sensorDataProcessor: SensorDataProcessor.shared)
    let sensorDataStore = SensorDataStore()
    let subscriptionManager = SubscriptionManager()
    let deviceManager = DeviceManager()
    let appStateManager = AppStateManager()
    let sharedDataManager = SharedDataManager(
        authenticationManager: authManager,
        healthKitManager: healthKitManager,
        sensorDataProcessor: SensorDataProcessor.shared
    )

    let dependencies = AppDependencies(
        authenticationManager: authManager,
        healthKitManager: healthKitManager,
        recordingSessionManager: recordingSessionManager,
        historicalDataManager: historicalDataManager,
        sensorDataStore: sensorDataStore,
        subscriptionManager: subscriptionManager,
        deviceManager: deviceManager,
        sensorDataProcessor: SensorDataProcessor.shared,
        appStateManager: appStateManager,
        sharedDataManager: sharedDataManager,
        designSystem: designSystem
    )

    SettingsView(viewModel: dependencies.makeSettingsViewModel())
        .withDependencies(dependencies)
        .environmentObject(designSystem)
}
