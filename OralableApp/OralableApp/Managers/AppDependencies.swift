//
//  AppDependencies.swift
//  OralableApp
//
//  Created: Refactoring - Dependency Injection
//  Purpose: Central dependency injection container replacing singletons
//

import Foundation
import SwiftUI

/// Central dependency injection container for the entire app
/// Replaces singleton pattern with proper dependency management
@MainActor
class AppDependencies: ObservableObject {
    // MARK: - Core Services

    let deviceManager: DeviceManager
    let bleManager: OralableBLE
    let authenticationManager: AuthenticationManager
    let subscriptionManager: SubscriptionManager
    let appStateManager: AppStateManager
    let healthKitManager: HealthKitManager
    let historicalDataManager: HistoricalDataManager
    let designSystem: DesignSystem

    // MARK: - Data Provider

    let dataProvider: SensorDataProvider

    // MARK: - Initialization

    /// Initializes all dependencies with proper dependency graph
    init(appMode: AppMode = .subscription) {
        Logger.shared.info("[AppDependencies] Initializing dependency container for mode: \(appMode)")

        // Initialize managers in correct order
        self.appStateManager = AppStateManager.shared // Keep for now (transition)
        self.designSystem = DesignSystem.shared // Keep for now (transition)

        // Core BLE infrastructure
        // Note: With lazy CBCentralManager initialization, this won't trigger Bluetooth permission
        self.deviceManager = DeviceManager()

        // Authentication & Subscription
        self.authenticationManager = AuthenticationManager.shared // Keep for now
        self.subscriptionManager = SubscriptionManager.shared // Keep for now

        // Health integration - create new instance
        self.healthKitManager = HealthKitManager()

        // BLE Manager (wraps DeviceManager - to be refactored)
        // Note: BLE permission won't be requested until scan/connect is actually called
        self.bleManager = OralableBLE.shared // Keep for now

        // Historical data (depends on bleManager)
        self.historicalDataManager = HistoricalDataManager(bleManager: self.bleManager)

        // Data provider based on app mode
        // Note: Mock data provider removed - only real BLE data supported
        Logger.shared.info("[AppDependencies] Using RealBLEDataProvider for production mode")
        self.dataProvider = RealBLEDataProvider(deviceManager: deviceManager)

        Logger.shared.info("[AppDependencies] ✅ Dependency container initialized successfully")
    }

    // MARK: - Factory Methods

    /// Creates a DashboardViewModel with injected dependencies
    func makeDashboardViewModel() -> DashboardViewModel {
        return DashboardViewModel(
            bleManager: bleManager,
            appStateManager: appStateManager
        )
    }

    /// Creates a DevicesViewModel with injected dependencies
    func makeDevicesViewModel() -> DevicesViewModel {
        return DevicesViewModel(bleManager: bleManager)
    }

    /// Creates a HistoricalViewModel with injected dependencies
    func makeHistoricalViewModel() -> HistoricalViewModel {
        return HistoricalViewModel(historicalDataManager: historicalDataManager)
    }

    /// Creates a SettingsViewModel with injected dependencies
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(bleManager: bleManager)
    }

    /// Creates an AuthenticationViewModel with injected dependencies
    func makeAuthenticationViewModel() -> AuthenticationViewModel {
        return AuthenticationViewModel()
    }
}

// MARK: - Testing Support

#if DEBUG
extension AppDependencies {
    /// Creates a mock dependencies container for testing and previews
    static func mock() -> AppDependencies {
        let deps = AppDependencies(appMode: .viewer)
        return deps
    }

    /// Creates dependencies with a specific data provider for testing
    convenience init(dataProvider: SensorDataProvider) {
        self.init(appMode: .viewer)
        // Override with provided data provider
        // Note: This is a temporary workaround - will be improved when we fully remove singletons
    }
}
#endif

// MARK: - Environment Key

/// Environment key for accessing dependencies throughout the app
struct AppDependenciesKey: EnvironmentKey {
    @MainActor static var defaultValue: AppDependencies {
        // Use lazy initialization to avoid circular dependency issues
        // This creates a new instance each time, but defaultValue should rarely be used
        // The app should inject dependencies explicitly via .withDependencies()
        return AppDependencies()
    }
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Injects all app dependencies into the environment
    func withDependencies(_ dependencies: AppDependencies) -> some View {
        self
            .environment(\.dependencies, dependencies)
            .environmentObject(dependencies)
            .environmentObject(dependencies.bleManager)
            .environmentObject(dependencies.deviceManager)
            .environmentObject(dependencies.authenticationManager)
            .environmentObject(dependencies.subscriptionManager)
            .environmentObject(dependencies.appStateManager)
            .environmentObject(dependencies.healthKitManager)
            .environmentObject(dependencies.historicalDataManager)
            .environmentObject(dependencies.designSystem)
    }
}
