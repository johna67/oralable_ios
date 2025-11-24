import SwiftUI

@main
struct OralableApp: App {
    @MainActor @StateObject private var authenticationManager: AuthenticationManager
    @MainActor @StateObject private var healthKitManager: HealthKitManager
    @MainActor @StateObject private var sensorDataStore: SensorDataStore
    @MainActor @StateObject private var bleManager: OralableBLE
    @MainActor @StateObject private var recordingSessionManager: RecordingSessionManager
    @MainActor @StateObject private var historicalDataManager: HistoricalDataManager
    @MainActor @StateObject private var subscriptionManager: SubscriptionManager
    @MainActor @StateObject private var deviceManager: DeviceManager
    @MainActor @StateObject private var appStateManager: AppStateManager
    @MainActor @StateObject private var sharedDataManager: SharedDataManager
    @MainActor @StateObject private var designSystem: DesignSystem

    init() {
        let authenticationManager = AuthenticationManager()
        let healthKitManager = HealthKitManager()
        let sensorDataStore = SensorDataStore()
        let bleManager = OralableBLE()

        let recordingSessionManager = RecordingSessionManager()

        let historicalDataManager = HistoricalDataManager(
            bleManager: bleManager
        )

        let subscriptionManager = SubscriptionManager()
        let deviceManager = DeviceManager()
        let appStateManager = AppStateManager()
        let sharedDataManager = SharedDataManager(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            bleManager: bleManager
        )
        let designSystem = DesignSystem()

        _authenticationManager = StateObject(wrappedValue: authenticationManager)
        _healthKitManager = StateObject(wrappedValue: healthKitManager)
        _sensorDataStore = StateObject(wrappedValue: sensorDataStore)
        _bleManager = StateObject(wrappedValue: bleManager)
        _recordingSessionManager = StateObject(wrappedValue: recordingSessionManager)
        _historicalDataManager = StateObject(wrappedValue: historicalDataManager)
        _subscriptionManager = StateObject(wrappedValue: subscriptionManager)
        _deviceManager = StateObject(wrappedValue: deviceManager)
        _appStateManager = StateObject(wrappedValue: appStateManager)
        _sharedDataManager = StateObject(wrappedValue: sharedDataManager)
        _designSystem = StateObject(wrappedValue: designSystem)
    }

    var body: some Scene {
        let dependencies = AppDependencies(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            recordingSessionManager: recordingSessionManager,
            historicalDataManager: historicalDataManager,
            bleManager: bleManager,
            sensorDataStore: sensorDataStore,
            subscriptionManager: subscriptionManager,
            deviceManager: deviceManager,
            appStateManager: appStateManager,
            sharedDataManager: sharedDataManager,
            designSystem: designSystem
        )

        WindowGroup {
            LaunchCoordinator()
                .withDependencies(dependencies)
        }
    }
}
