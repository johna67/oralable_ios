//
//  FeatureFlags.swift
//  OralableApp
//
//  Created: December 4, 2025
//  Purpose: Feature flags for controlling app functionality
//  Pre-launch release hides advanced features for simpler App Store approval
//

import Foundation
import Combine

/// Feature flags for controlling app functionality
/// Pre-launch release hides advanced features for simpler App Store approval
class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let showMovementCard = "feature.dashboard.showMovement"
        static let showTemperatureCard = "feature.dashboard.showTemperature"
        static let showHeartRateCard = "feature.dashboard.showHeartRate"
        static let showSpO2Card = "feature.dashboard.showSpO2"
        static let showAccelerometerCard = "feature.dashboard.showAccelerometer"
        static let showBatteryCard = "feature.dashboard.showBattery"
        static let showShareWithDentist = "feature.share.showDentist"
        static let showShareWithResearcher = "feature.share.showResearcher"
        static let showSubscription = "feature.settings.showSubscription"
        static let showHealthIntegration = "feature.settings.showHealthIntegration"
        static let showAdvancedMetrics = "feature.dashboard.showAdvancedMetrics"
        static let showDetectionSettings = "feature.settings.showDetectionSettings"
    }

    // MARK: - Pre-Launch Defaults (all advanced features OFF)
    private enum Defaults {
        static let showMovementCard = false
        static let showTemperatureCard = false
        static let showHeartRateCard = false
        static let showSpO2Card = false
        static let showAccelerometerCard = false
        static let showBatteryCard = false  // Hidden for pre-launch
        static let showShareWithDentist = false
        static let showShareWithResearcher = false
        static let showSubscription = false
        static let showHealthIntegration = false
        static let showAdvancedMetrics = false
        static let showDetectionSettings = false  // Hidden for pre-launch
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

    @Published var showSpO2Card: Bool {
        didSet { defaults.set(showSpO2Card, forKey: Keys.showSpO2Card) }
    }

    @Published var showAccelerometerCard: Bool {
        didSet { defaults.set(showAccelerometerCard, forKey: Keys.showAccelerometerCard) }
    }

    @Published var showBatteryCard: Bool {
        didSet { defaults.set(showBatteryCard, forKey: Keys.showBatteryCard) }
    }

    @Published var showAdvancedMetrics: Bool {
        didSet { defaults.set(showAdvancedMetrics, forKey: Keys.showAdvancedMetrics) }
    }

    // MARK: - Share Features
    @Published var showShareWithDentist: Bool {
        didSet { defaults.set(showShareWithDentist, forKey: Keys.showShareWithDentist) }
    }

    @Published var showShareWithResearcher: Bool {
        didSet { defaults.set(showShareWithResearcher, forKey: Keys.showShareWithResearcher) }
    }

    // MARK: - Settings Features
    @Published var showSubscription: Bool {
        didSet { defaults.set(showSubscription, forKey: Keys.showSubscription) }
    }

    @Published var showHealthIntegration: Bool {
        didSet { defaults.set(showHealthIntegration, forKey: Keys.showHealthIntegration) }
    }

    @Published var showDetectionSettings: Bool {
        didSet { defaults.set(showDetectionSettings, forKey: Keys.showDetectionSettings) }
    }

    // MARK: - Initialization
    init() {
        // Load saved values or use pre-launch defaults
        self.showMovementCard = defaults.object(forKey: Keys.showMovementCard) as? Bool ?? Defaults.showMovementCard
        self.showTemperatureCard = defaults.object(forKey: Keys.showTemperatureCard) as? Bool ?? Defaults.showTemperatureCard
        self.showHeartRateCard = defaults.object(forKey: Keys.showHeartRateCard) as? Bool ?? Defaults.showHeartRateCard
        self.showSpO2Card = defaults.object(forKey: Keys.showSpO2Card) as? Bool ?? Defaults.showSpO2Card
        self.showAccelerometerCard = defaults.object(forKey: Keys.showAccelerometerCard) as? Bool ?? Defaults.showAccelerometerCard
        self.showBatteryCard = defaults.object(forKey: Keys.showBatteryCard) as? Bool ?? Defaults.showBatteryCard
        self.showAdvancedMetrics = defaults.object(forKey: Keys.showAdvancedMetrics) as? Bool ?? Defaults.showAdvancedMetrics
        self.showShareWithDentist = defaults.object(forKey: Keys.showShareWithDentist) as? Bool ?? Defaults.showShareWithDentist
        self.showShareWithResearcher = defaults.object(forKey: Keys.showShareWithResearcher) as? Bool ?? Defaults.showShareWithResearcher
        self.showSubscription = defaults.object(forKey: Keys.showSubscription) as? Bool ?? Defaults.showSubscription
        self.showHealthIntegration = defaults.object(forKey: Keys.showHealthIntegration) as? Bool ?? Defaults.showHealthIntegration
        self.showDetectionSettings = defaults.object(forKey: Keys.showDetectionSettings) as? Bool ?? Defaults.showDetectionSettings

        Logger.shared.info("[FeatureFlags] Initialized with pre-launch configuration")
    }

    // MARK: - Presets

    /// Pre-launch configuration (minimal features for App Store approval)
    func applyPreLaunchConfig() {
        showMovementCard = false
        showTemperatureCard = false
        showHeartRateCard = false
        showSpO2Card = false
        showAccelerometerCard = false
        showBatteryCard = false
        showAdvancedMetrics = false
        showShareWithDentist = false
        showShareWithResearcher = false
        showSubscription = false
        showHealthIntegration = false
        showDetectionSettings = false
        Logger.shared.info("[FeatureFlags] Applied pre-launch config")
    }

    /// Full feature configuration (all features enabled)
    func applyFullConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = true
        showSpO2Card = true
        showAccelerometerCard = true
        showBatteryCard = true
        showAdvancedMetrics = true
        showShareWithDentist = true
        showShareWithResearcher = true
        showSubscription = true
        showHealthIntegration = true
        showDetectionSettings = true
        Logger.shared.info("[FeatureFlags] Applied full config")
    }

    /// Wellness release configuration (consumer features)
    func applyWellnessConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = false
        showSpO2Card = false
        showAccelerometerCard = true
        showBatteryCard = true
        showAdvancedMetrics = true
        showShareWithDentist = false
        showShareWithResearcher = false
        showSubscription = true
        showHealthIntegration = true
        showDetectionSettings = true
        Logger.shared.info("[FeatureFlags] Applied wellness config")
    }

    /// Research release configuration
    func applyResearchConfig() {
        showMovementCard = true
        showTemperatureCard = true
        showHeartRateCard = true
        showSpO2Card = true
        showAccelerometerCard = true
        showBatteryCard = true
        showAdvancedMetrics = true
        showShareWithDentist = false
        showShareWithResearcher = true
        showSubscription = true
        showHealthIntegration = true
        showDetectionSettings = true
        Logger.shared.info("[FeatureFlags] Applied research config")
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
        - SpO2 Card: \(showSpO2Card)
        - Accelerometer Card: \(showAccelerometerCard)
        - Battery Card: \(showBatteryCard)
        - ANR M40 Device Support: \(showAdvancedMetrics)
        - Share with Dentist: \(showShareWithDentist)
        - Share with Researcher: \(showShareWithResearcher)
        - Subscription: \(showSubscription)
        - Health Integration: \(showHealthIntegration)
        - Detection Settings: \(showDetectionSettings)
        """
    }
}
