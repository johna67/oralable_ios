//
//  HealthKitIntegration.swift
//  OralableApp
//
//  Created: November 19, 2025
//  Responsibility: Manage HealthKit write operations for BLE sensor data
//  - Background task management for HealthKit writes
//  - Write heart rate to HealthKit
//  - Write SpO2 to HealthKit
//  - Error handling for HealthKit operations
//

import Foundation
import HealthKit

/// Manages HealthKit integration for writing biometric data from BLE devices
@MainActor
class HealthKitIntegration {

    // MARK: - Private Properties

    private let healthKitManager: HealthKitManager

    // MARK: - Initialization

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        Logger.shared.info("[HealthKitIntegration] Initialized")
    }

    // MARK: - Public Methods

    /// Write heart rate to HealthKit if authorized
    /// - Parameter bpm: Heart rate in beats per minute
    func writeHeartRate(bpm: Double) {
        guard healthKitManager.isAuthorized else {
            Logger.shared.debug("[HealthKitIntegration] HealthKit not authorized, skipping heart rate write")
            return
        }

        Task {
            do {
                try await healthKitManager.writeHeartRate(bpm: bpm)
                Logger.shared.debug("[HealthKitIntegration] ✅ Heart rate written to HealthKit: \(Int(bpm)) bpm")
            } catch {
                Logger.shared.error("[HealthKitIntegration] ❌ Failed to write heart rate to HealthKit: \(error)")
            }
        }
    }

    /// Write SpO2 to HealthKit if authorized
    /// - Parameter percentage: SpO2 percentage (0-100)
    func writeSpO2(percentage: Double) {
        guard healthKitManager.isAuthorized else {
            Logger.shared.debug("[HealthKitIntegration] HealthKit not authorized, skipping SpO2 write")
            return
        }

        Task {
            do {
                try await healthKitManager.writeBloodOxygen(percentage: percentage)
                Logger.shared.debug("[HealthKitIntegration] ✅ SpO2 written to HealthKit: \(Int(percentage))%")
            } catch {
                Logger.shared.error("[HealthKitIntegration] ❌ Failed to write SpO2 to HealthKit: \(error)")
            }
        }
    }

    /// Check if HealthKit is authorized
    var isAuthorized: Bool {
        return healthKitManager.isAuthorized
    }

    /// Request HealthKit authorization
    func requestAuthorization() async throws {
        try await healthKitManager.requestAuthorization()
        Logger.shared.info("[HealthKitIntegration] HealthKit authorization requested")
    }
}
