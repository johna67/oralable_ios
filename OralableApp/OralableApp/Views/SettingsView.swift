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

    @State private var showSubscriptionInfo = false

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                Section {
                    subscriptionRow
                } header: {
                    Text("Subscription")
                }

                // Health Integration Section
                Section {
                    healthKitRow
                } header: {
                    Text("Health Integration")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSubscriptionInfo) {
                SubscriptionInfoView()
            }
        }
        .navigationViewStyle(.stack)
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
