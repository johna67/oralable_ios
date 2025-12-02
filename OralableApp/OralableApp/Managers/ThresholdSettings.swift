//
//  ThresholdSettings.swift
//  OralableApp
//
//  Created: December 2025
//  Purpose: User-adjustable threshold settings for movement detection
//

import Foundation
import Combine

/// Manages user-adjustable threshold settings with persistence
class ThresholdSettings: ObservableObject {
    static let shared = ThresholdSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let movementThreshold = "settings.threshold.movement"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let movementThreshold: Double = 1500.0
    }

    // MARK: - Range Constraints

    /// Valid range for movement threshold (500 = very sensitive, 5000 = very insensitive)
    static let movementThresholdRange: ClosedRange<Double> = 500...5000
    static let movementThresholdStep: Double = 100

    // MARK: - Published Properties

    /// Movement variability threshold for active/still detection
    /// Lower values = more sensitive (smaller movements detected as "Active")
    /// Higher values = less sensitive (requires more movement for "Active")
    @Published var movementThreshold: Double {
        didSet {
            defaults.set(movementThreshold, forKey: Keys.movementThreshold)
            Logger.shared.info("[ThresholdSettings] Movement threshold updated: \(movementThreshold)")
        }
    }

    // MARK: - Initialization

    private init() {
        // Load saved value or use default
        if defaults.object(forKey: Keys.movementThreshold) != nil {
            self.movementThreshold = defaults.double(forKey: Keys.movementThreshold)
        } else {
            self.movementThreshold = Defaults.movementThreshold
        }
        Logger.shared.info("[ThresholdSettings] Initialized with movement threshold: \(movementThreshold)")
    }

    // MARK: - Public Methods

    /// Reset all thresholds to default values
    func resetToDefaults() {
        movementThreshold = Defaults.movementThreshold
        Logger.shared.info("[ThresholdSettings] Reset to defaults")
    }

    /// Get default value for movement threshold
    static var defaultMovementThreshold: Double {
        Defaults.movementThreshold
    }
}
