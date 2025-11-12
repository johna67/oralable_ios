//
//  AppStateManager.swift
//  OralableApp
//
//  Created: November 12, 2025
//  Purpose: Manage app-wide state including mode selection and first launch
//

import Foundation
import SwiftUI
import Combine

/// Manages app-wide state including mode selection, onboarding status, and user preferences
@MainActor
class AppStateManager: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedMode: AppMode?
    @Published var hasCompletedOnboarding: Bool
    @Published var isFirstLaunch: Bool

    // MARK: - Singleton

    static let shared = AppStateManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedMode = "com.oralable.selectedMode"
        static let hasCompletedOnboarding = "com.oralable.hasCompletedOnboarding"
        static let isFirstLaunch = "com.oralable.isFirstLaunch"
        static let lastLaunchDate = "com.oralable.lastLaunchDate"
    }

    // MARK: - Initialization

    private init() {
        // Load saved mode
        if let savedModeRaw = UserDefaults.standard.string(forKey: Keys.selectedMode),
           let savedMode = AppMode(rawValue: savedModeRaw) {
            self.selectedMode = savedMode
        } else {
            self.selectedMode = nil
        }

        // Check if first launch
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: Keys.isFirstLaunch)

        // Load onboarding status
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)

        // Mark as launched
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: Keys.isFirstLaunch)
        }

        // Update last launch date
        UserDefaults.standard.set(Date(), forKey: Keys.lastLaunchDate)
    }

    // MARK: - Mode Management

    /// Set the selected app mode and persist it
    func setMode(_ mode: AppMode) {
        selectedMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.selectedMode)

        Logger.shared.info("App mode changed to: \(mode.rawValue)")
    }

    /// Clear the selected mode (forces mode selection on next launch)
    func clearMode() {
        selectedMode = nil
        UserDefaults.standard.removeObject(forKey: Keys.selectedMode)

        Logger.shared.info("App mode cleared")
    }

    /// Check if mode requires authentication
    func requiresAuthentication(for mode: AppMode) -> Bool {
        switch mode {
        case .subscription:
            return true
        case .viewer, .demo:
            return false
        }
    }

    /// Check if mode requires subscription
    func requiresSubscription(for mode: AppMode) -> Bool {
        switch mode {
        case .subscription:
            return true
        case .viewer, .demo:
            return false
        }
    }

    // MARK: - Onboarding Management

    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)

        Logger.shared.info("Onboarding completed")
    }

    /// Reset onboarding status (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Keys.hasCompletedOnboarding)

        Logger.shared.info("Onboarding reset")
    }

    // MARK: - First Launch

    var lastLaunchDate: Date? {
        UserDefaults.standard.object(forKey: Keys.lastLaunchDate) as? Date
    }

    var daysSinceLastLaunch: Int {
        guard let lastLaunch = lastLaunchDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: lastLaunch, to: Date()).day ?? 0
        return days
    }

    // MARK: - Convenience Properties

    /// Check if the app is in viewer mode
    var isViewerMode: Bool {
        selectedMode == .viewer
    }

    /// Check if the app is in subscription mode
    var isSubscriptionMode: Bool {
        selectedMode == .subscription
    }

    /// Check if the app is in demo mode
    var isDemoMode: Bool {
        selectedMode == .demo
    }

    /// Check if mode selection is needed
    var needsModeSelection: Bool {
        selectedMode == nil
    }

    /// Get display name for current mode
    var currentModeDisplayName: String {
        selectedMode?.displayName ?? "Not Selected"
    }

    // MARK: - Reset Methods

    /// Reset all app state (for testing/debugging)
    #if DEBUG
    func resetAllState() {
        clearMode()
        resetOnboarding()
        UserDefaults.standard.removeObject(forKey: Keys.isFirstLaunch)
        UserDefaults.standard.removeObject(forKey: Keys.lastLaunchDate)

        isFirstLaunch = true
        hasCompletedOnboarding = false

        Logger.shared.warning("All app state reset")
    }
    #endif
}

// MARK: - AppMode Extension

extension AppMode {
    var displayName: String {
        switch self {
        case .viewer:
            return "Viewer Mode"
        case .subscription:
            return "Full Access"
        case .demo:
            return "Demo Mode"
        }
    }

    var description: String {
        switch self {
        case .viewer:
            return "Import and view historical data without device connection"
        case .subscription:
            return "Full access to all features with device connection"
        case .demo:
            return "Explore the app with sample data"
        }
    }

    var icon: String {
        switch self {
        case .viewer:
            return "eye.fill"
        case .subscription:
            return "star.circle.fill"
        case .demo:
            return "play.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .viewer:
            return .blue
        case .subscription:
            return .orange
        case .demo:
            return .green
        }
    }
}
