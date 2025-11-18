import Foundation
import SwiftUI

/// Central dependency injection container for the dentist app
/// Manages all core services and provides factory methods for ViewModels
@MainActor
class DentistAppDependencies: ObservableObject {
    // MARK: - Core Services

    let subscriptionManager: DentistSubscriptionManager
    let dataManager: DentistDataManager
    let authenticationManager: DentistAuthenticationManager

    // Note: DesignSystem will be shared from patient app
    // let designSystem: DesignSystem

    // MARK: - Initialization

    init() {
        Logger.shared.info("[DentistAppDependencies] Initializing dependency container")

        // Initialize managers
        self.subscriptionManager = DentistSubscriptionManager.shared
        self.dataManager = DentistDataManager.shared
        self.authenticationManager = DentistAuthenticationManager.shared

        Logger.shared.info("[DentistAppDependencies] ✅ Dependency container initialized successfully")
    }

    // MARK: - Factory Methods

    /// Creates a PatientListViewModel with injected dependencies
    func makePatientListViewModel() -> PatientListViewModel {
        return PatientListViewModel(
            dataManager: dataManager,
            subscriptionManager: subscriptionManager
        )
    }

    /// Creates an AddPatientViewModel with injected dependencies
    func makeAddPatientViewModel() -> AddPatientViewModel {
        return AddPatientViewModel(
            dataManager: dataManager,
            subscriptionManager: subscriptionManager
        )
    }

    /// Creates a DentistSettingsViewModel with injected dependencies
    func makeSettingsViewModel() -> DentistSettingsViewModel {
        return DentistSettingsViewModel(
            subscriptionManager: subscriptionManager,
            authenticationManager: authenticationManager
        )
    }
}

// MARK: - Testing Support

#if DEBUG
extension DentistAppDependencies {
    /// Creates a mock dependencies container for testing and previews
    static func mock() -> DentistAppDependencies {
        return DentistAppDependencies()
    }
}
#endif

// MARK: - Environment Key

/// Environment key for accessing dependencies throughout the app
struct DentistAppDependenciesKey: EnvironmentKey {
    @MainActor static var defaultValue: DentistAppDependencies {
        return DentistAppDependencies()
    }
}

extension EnvironmentValues {
    var dentistDependencies: DentistAppDependencies {
        get { self[DentistAppDependenciesKey.self] }
        set { self[DentistAppDependenciesKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects all dentist app dependencies into the environment
    func withDentistDependencies(_ dependencies: DentistAppDependencies) -> some View {
        self
            .environment(\.dentistDependencies, dependencies)
            .environmentObject(dependencies)
            .environmentObject(dependencies.subscriptionManager)
            .environmentObject(dependencies.dataManager)
            .environmentObject(dependencies.authenticationManager)
    }
}

// MARK: - Placeholder Logger (will use shared Logger from patient app)

class Logger {
    static let shared = Logger()

    func info(_ message: String) {
        print("[INFO] \(message)")
    }

    func error(_ message: String) {
        print("[ERROR] \(message)")
    }

    func warning(_ message: String) {
        print("[WARNING] \(message)")
    }
}
