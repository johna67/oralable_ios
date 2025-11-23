import SwiftUI
import SessionKit

@main
struct OralableApp: App {
    @MainActor @StateObject private var authenticationManager: AuthenticationManager
    @MainActor @StateObject private var healthKitManager: HealthKitManager
    @MainActor @StateObject private var sensorDataStore: SensorDataStore
    @MainActor @StateObject private var bleManager: OralableBLE
    @MainActor @StateObject private var recordingSessionManager: RecordingSessionManager
    @MainActor @StateObject private var historicalDataManager: HistoricalDataManager

    init() {
        let authenticationManager = AuthenticationManager()
        let healthKitManager = HealthKitManager()
        let sensorDataStore = SensorDataStore()
        let bleManager = OralableBLE()

        let recordingSessionManager = RecordingSessionManager(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            bleManager: bleManager,
            sensorDataStore: sensorDataStore
        )

        let historicalDataManager = HistoricalDataManager(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager
        )

        _authenticationManager = StateObject(wrappedValue: authenticationManager)
        _healthKitManager = StateObject(wrappedValue: healthKitManager)
        _sensorDataStore = StateObject(wrappedValue: sensorDataStore)
        _bleManager = StateObject(wrappedValue: bleManager)
        _recordingSessionManager = StateObject(wrappedValue: recordingSessionManager)
        _historicalDataManager = StateObject(wrappedValue: historicalDataManager)
    }

    var body: some Scene {
        let dependencies = AppDependencies(
            authenticationManager: authenticationManager,
            healthKitManager: healthKitManager,
            recordingSessionManager: recordingSessionManager,
            historicalDataManager: historicalDataManager,
            bleManager: bleManager,
            sensorDataStore: sensorDataStore
        )

        WindowGroup {
            RootView()
                .withDependencies(dependencies)
        }
    }
}
