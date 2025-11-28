import SwiftUI

@main
struct OralableApp: App {
    @StateObject private var authenticationManager: AuthenticationManager
    @StateObject private var healthKitManager: HealthKitManager
    @StateObject private var sensorDataStore: SensorDataStore
    @StateObject private var bleManager: OralableBLE
    @StateObject private var recordingSessionManager: RecordingSessionManager
    @StateObject private var historicalDataManager: HistoricalDataManager
    @StateObject private var subscriptionManager: SubscriptionManager
    @StateObject private var deviceManager: DeviceManager
    @StateObject private var sensorDataProcessor: SensorDataProcessor
    @StateObject private var appStateManager: AppStateManager
    @StateObject private var sharedDataManager: SharedDataManager
    @StateObject private var designSystem: DesignSystem
    @StateObject private var dependencies: AppDependencies  // ← ADD THIS
    
    init() {
        let authenticationManager = AuthenticationManager()
        let healthKitManager = HealthKitManager()
        let sensorDataStore = SensorDataStore()
        let bleManager = OralableBLE()
        let recordingSessionManager = RecordingSessionManager()
        let sensorDataProcessor = SensorDataProcessor.shared
        let historicalDataManager = HistoricalDataManager(
            sensorDataProcessor: sensorDataProcessor
        )
        let subscriptionManager = SubscriptionManager()
        let deviceManager = DeviceManager()
        let appStateManager = AppStateManager()
        let sharedDataManager = SharedDataManager(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            sensorDataProcessor: sensorDataProcessor
        )
        let designSystem = DesignSystem()
        
        // Create AppDependencies ONCE here
        let dependencies = AppDependencies(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            recordingSessionManager: recordingSessionManager,
            historicalDataManager: historicalDataManager,
            bleManager: bleManager,
            sensorDataStore: sensorDataStore,
            subscriptionManager: subscriptionManager,
            deviceManager: deviceManager,
            sensorDataProcessor: sensorDataProcessor,
            appStateManager: appStateManager,
            sharedDataManager: sharedDataManager,
            designSystem: designSystem
        )
        
        _authenticationManager = StateObject(wrappedValue: authenticationManager)
        _healthKitManager = StateObject(wrappedValue: healthKitManager)
        _sensorDataStore = StateObject(wrappedValue: sensorDataStore)
        _bleManager = StateObject(wrappedValue: bleManager)
        _recordingSessionManager = StateObject(wrappedValue: recordingSessionManager)
        _historicalDataManager = StateObject(wrappedValue: historicalDataManager)
        _subscriptionManager = StateObject(wrappedValue: subscriptionManager)
        _deviceManager = StateObject(wrappedValue: deviceManager)
        _sensorDataProcessor = StateObject(wrappedValue: sensorDataProcessor)
        _appStateManager = StateObject(wrappedValue: appStateManager)
        _sharedDataManager = StateObject(wrappedValue: sharedDataManager)
        _designSystem = StateObject(wrappedValue: designSystem)
        _dependencies = StateObject(wrappedValue: dependencies)  // ← ADD THIS
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            LaunchCoordinator()
                .withDependencies(dependencies)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        // Sync data when app goes to background
                        Task {
                            await sharedDataManager.uploadCurrentDataForSharing()
                        }
                    }
                }
        }
    }
}
