import Foundation
import SwiftUI
import Combine

/// Central dependency injection container for the dentist app
/// Manages all core services and provides factory methods for ViewModels
@MainActor
class DentistAppDependencies: ObservableObject {
    // MARK: - Singleton Prevention

    private static var initializationCount = 0
    private static let maxInitializations = 2  // Allow app + cached default only

    // MARK: - Core Services

    let subscriptionManager: DentistSubscriptionManager
    let dataManager: DentistDataManager
    let authenticationManager: DentistAuthenticationManager

    // Note: DesignSystem will be shared from patient app
    // let designSystem: DesignSystem

    // MARK: - Initialization

    init() {
        // CRITICAL: Prevent runaway initialization that causes memory crashes
        DentistAppDependencies.initializationCount += 1
        let count = DentistAppDependencies.initializationCount

        Logger.shared.info("[DentistAppDependencies] Initializing dependency container #\(count)")

        if count > DentistAppDependencies.maxInitializations {
            Logger.shared.error("[DentistAppDependencies] ⚠️ CRITICAL: Too many initializations (\(count))! This will cause memory crash. Aborting.")
            fatalError("[DentistAppDependencies] Runaway initialization detected - preventing memory leak crash")
        }

        // Initialize managers (no more singletons - using dependency injection)
        self.authenticationManager = DentistAuthenticationManager()
        self.subscriptionManager = DentistSubscriptionManager.shared  // TODO: Remove singleton
        self.dataManager = DentistDataManager.shared  // TODO: Remove singleton

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
        // Use a cached singleton to prevent repeated initialization
        // This prevents memory leaks from creating new instances on every access
        _cachedDefaultDependencies
    }

    // Cached instance to prevent repeated initialization
    @MainActor private static let _cachedDefaultDependencies = DentistAppDependencies()
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
