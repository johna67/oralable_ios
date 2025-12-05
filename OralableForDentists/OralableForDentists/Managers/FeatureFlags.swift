//
//  FeatureFlags.swift
//  OralableForDentists
//
//  Created: December 5, 2025
//  Purpose: Feature flags for controlling app functionality
//  Pre-launch release hides advanced features for simpler App Store approval
//

import Foundation
import Combine

/// Feature flags for controlling OralableForDentists functionality
/// Pre-launch release hides advanced features for simpler App Store approval
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let showMovementCard = "feature.dashboard.showMovement"
        static let showTemperatureCard = "feature.dashboard.showTemperature"
        static let showHeartRateCard = "feature.dashboard.showHeartRate"
        static let showAdvancedAnalytics = "feature.dashboard.showAdvancedAnalytics"
        static let showSubscription = "feature.settings.showSubscription"
        static let showMultiParticipant = "feature.showMultiParticipant"
        static let showDataExport = "feature.showDataExport"
        static let showANRComparison = "feature.showANRComparison"
    }

    // MARK: - Pre-Launch Defaults (all advanced features OFF)
    private enum Defaults {
        static let showMovementCard = false
        static let showTemperatureCard = false
        static let showHeartRateCard = false
        static let showAdvancedAnalytics = false
        static let showSubscription = false
        static let showMultiParticipant = true  // Basic participant list always on
        static let showDataExport = true        // Basic export always on
        static let showANRComparison = false
    }

    // MARK: - Dashboard Features
    @Published var showMovementCard: Bool {
        didSet { defaults.set(showMovementCard, forKey: Keys.showMovementCard) }
    }

    @Published var showTemperatureCard: Bool {
        didSet { defaults.set(showTemperatureCard, forKey: Keys.showTemperatureCard) }
    }

    @Published var showHeartRateCard: Bool {
        didSet { defaults.set(showHeartRateCard, forKey: Keys.showHeartRateCard) }
    }

    @Published var showAdvancedAnalytics: Bool {
        didSet { defaults.set(showAdvancedAnalytics, forKey: Keys.showAdvancedAnalytics) }
    }

    // MARK: - Settings Features
    @Published var showSubscription: Bool {
        didSet { defaults.set(showSubscription, forKey: Keys.showSubscription) }
    }

    // MARK: - Research Features
    @Published var showMultiParticipant: Bool {
        didSet { defaults.set(showMultiParticipant, forKey: Keys.showMultiParticipant) }
    }

    @Published var showDataExport: Bool {
        didSet { defaults.set(showDataExport, forKey: Keys.showDataExport) }
    }

    @Published var showANRComparison: Bool {
        didSet { defaults.set(showANRComparison, forKey: Keys.showANRComparison) }
    }

    // MARK: - Initialization
    init() {
        self.showMovementCard = defaults.object(forKey: Keys.showMovementCard) as? Bool ?? Defaults.showMovementCard
        self.showTemperatureCard = defaults.object(forKey: Keys.showTemperatureCard) as? Bool ?? Defaults.showTemperatureCard
        self.showHeartRateCard = defaults.object(forKey: Keys.showHeartRateCard) as? Bool ?? Defaults.showHeartRateCard
        self.showAdvancedAnalytics = defaults.object(forKey: Keys.showAdvancedAnalytics) as? Bool ?? Defaults.showAdvancedAnalytics
        self.showSubscription = defaults.object(forKey: Keys.showSubscription) as? Bool ?? Defaults.showSubscription
        self.showMultiParticipant = defaults.object(forKey: Keys.showMultiParticipant) as? Bool ?? Defaults.showMultiParticipant
        self.showDataExport = defaults.object(forKey: Keys.showDataExport) as? Bool ?? Defaults.showDataExport
        self.showANRComparison = defaults.object(forKey: Keys.showANRComparison) as? Bool ?? Defaults.showANRComparison

        Logger.shared.info("[FeatureFlags] Initialized with pre-launch configuration")
    }

    // MARK: - Presets

    /// Pre-launch configuration (minimal features for App Store approval)
    func applyPreLaunchConfig() {
        showMovementCard = false
        showTemperatureCard = false
        showHeartRateCard = false
        showAdvancedAnalytics = false
        showSubscription = false
        showMultiParticipant = true
        showDataExport = true
        showANRComparison = false
        Logger.shared.info("[FeatureFlags] Applied pre-launch config")
    }

    /// Wellness release configuration (consumer features)
    func applyWellnessConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = false
        showAdvancedAnalytics = true
        showSubscription = true
        showMultiParticipant = true
        showDataExport = true
        showANRComparison = false
        Logger.shared.info("[FeatureFlags] Applied wellness config")
    }

    /// Research release configuration
    func applyResearchConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = true
        showAdvancedAnalytics = true
        showSubscription = true
        showMultiParticipant = true
        showDataExport = true
        showANRComparison = true
        Logger.shared.info("[FeatureFlags] Applied research config")
    }

    /// Full feature configuration
    func applyFullConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = true
        showAdvancedAnalytics = true
        showSubscription = true
        showMultiParticipant = true
        showDataExport = true
        showANRComparison = true
        Logger.shared.info("[FeatureFlags] Applied full config")
    }

    /// Reset to defaults
    func resetToDefaults() {
        applyPreLaunchConfig()
    }

    // MARK: - Debug Description
    var currentConfigDescription: String {
        """
        FeatureFlags Configuration:
        - Movement Card: \(showMovementCard)
        - Temperature Card: \(showTemperatureCard)
        - Heart Rate Card: \(showHeartRateCard)
        - Advanced Analytics: \(showAdvancedAnalytics)
        - Subscription: \(showSubscription)
        - Multi-Participant: \(showMultiParticipant)
        - Data Export: \(showDataExport)
        - ANR Comparison: \(showANRComparison)
        """
    }
}
