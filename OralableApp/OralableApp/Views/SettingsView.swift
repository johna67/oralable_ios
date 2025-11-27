//
//  SettingsView.swift
//  OralableApp
//
//  Simplified Settings - Health Integration only
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    healthKitRow
                } header: {
                    Text("Health Integration")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
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
    let bleManager = OralableBLE()
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
        bleManager: bleManager,
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
