import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    let authenticationManager: AuthenticationManager
    let healthKitManager: HealthKitManager
    let recordingSessionManager: RecordingSessionManager
    let historicalDataManager: HistoricalDataManager
    let bleManager: OralableBLE
    let sensorDataStore: SensorDataStore

    init(authenticationManager: AuthenticationManager,
         healthKitManager: HealthKitManager,
         recordingSessionManager: RecordingSessionManager,
         historicalDataManager: HistoricalDataManager,
         bleManager: OralableBLE,
         sensorDataStore: SensorDataStore) {
        self.authenticationManager = authenticationManager
        self.healthKitManager = healthKitManager
        self.recordingSessionManager = recordingSessionManager
        self.historicalDataManager = historicalDataManager
        self.bleManager = bleManager
        self.sensorDataStore = sensorDataStore
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
    }
}

extension View {
    func withDependencies(_ dependencies: AppDependencies) -> some View {
        self.modifier(DependenciesModifier(dependencies: dependencies))
    }
}
