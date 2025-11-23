import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    // Note: Create a shared instance in your app's entry point
    // Example: let dependencies = AppDependencies(...)
    // Then inject it via .withDependencies(dependencies)
    
    let authenticationManager: AuthenticationManager
    let healthKitManager: HealthKitManager
    let recordingSessionManager: RecordingSessionManager
    let historicalDataManager: HistoricalDataManager
    let bleManager: OralableBLE
    let sensorDataStore: SensorDataStore
    let subscriptionManager: SubscriptionManager
    let deviceManager: DeviceManager
    let appStateManager: AppStateManager
    let sharedDataManager: SharedDataManager
    let designSystem: DesignSystem

    init(authenticationManager: AuthenticationManager,
         healthKitManager: HealthKitManager,
         recordingSessionManager: RecordingSessionManager,
         historicalDataManager: HistoricalDataManager,
         bleManager: OralableBLE,
         sensorDataStore: SensorDataStore,
         subscriptionManager: SubscriptionManager,
         deviceManager: DeviceManager,
         appStateManager: AppStateManager,
         sharedDataManager: SharedDataManager,
         designSystem: DesignSystem) {
        self.authenticationManager = authenticationManager
        self.healthKitManager = healthKitManager
        self.recordingSessionManager = recordingSessionManager
        self.historicalDataManager = historicalDataManager
        self.bleManager = bleManager
        self.sensorDataStore = sensorDataStore
        self.subscriptionManager = subscriptionManager
        self.deviceManager = deviceManager
        self.appStateManager = appStateManager
        self.sharedDataManager = sharedDataManager
        self.designSystem = designSystem
    }
    
    // MARK: - Factory Methods
    func makeDashboardViewModel() -> DashboardViewModel {
        return DashboardViewModel(
            bleManager: bleManager,
            appStateManager: appStateManager
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            bleManager: bleManager
        )
    }
}

struct DependenciesModifier: ViewModifier {
    @ObservedObject var dependencies: AppDependencies

    func body(content: Content) -> some View {
        content
            .environmentObject(dependencies)
            .environmentObject(dependencies.authenticationManager)
            .environmentObject(dependencies.healthKitManager)
            .environmentObject(dependencies.recordingSessionManager)
            .environmentObject(dependencies.historicalDataManager)
            .environmentObject(dependencies.bleManager)
            .environmentObject(dependencies.sensorDataStore)
            .environmentObject(dependencies.subscriptionManager)
            .environmentObject(dependencies.deviceManager)
            .environmentObject(dependencies.appStateManager)
            .environmentObject(dependencies.sharedDataManager)
            .environmentObject(dependencies.designSystem)
    }
}

extension View {
    func withDependencies(_ dependencies: AppDependencies) -> some View {
        self.modifier(DependenciesModifier(dependencies: dependencies))
    }
}
