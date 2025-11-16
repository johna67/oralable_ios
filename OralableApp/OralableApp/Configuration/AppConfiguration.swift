//
//  AppConfiguration.swift
//  OralableApp
//
//  Created: Phase 1 Refactoring
//  Centralized configuration and constants
//

import Foundation
import CoreBluetooth

/// Centralized application configuration
enum AppConfiguration {

    // MARK: - App Information

    enum App {
        static let version = "1.0.0"
        static let buildNumber = "2025.11.07"
        static let minimumOSVersion = "15.0"
        static let bundleIdentifier = "com.oralable.mam"
        static let appName = "Oralable MAM"
    }

    // MARK: - BLE Configuration

    enum BLE {
        // TGM Service UUIDs (Oralable Device)
        static let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        static let sensorDataCharacteristicUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
        static let ppgWaveformCharacteristicUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic003UUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic004UUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic005UUID = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic006UUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic007UUID = CBUUID(string: "3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic008UUID = CBUUID(string: "3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E")

        // Standard BLE Services
        static let batteryServiceUUID = CBUUID(string: "180F")
        static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
        static let deviceInfoServiceUUID = CBUUID(string: "180A")
        static let firmwareVersionCharacteristicUUID = CBUUID(string: "2A26")
        static let hardwareVersionCharacteristicUUID = CBUUID(string: "2A27")

        // Timing & Limits
        static let scanTimeout: TimeInterval = 30.0
        static let connectionTimeout: TimeInterval = 10.0
        static let maxConcurrentConnections = 5

        // Reconnection Policy
        static let maxReconnectAttempts = 3
        static let reconnectInitialDelay: TimeInterval = 1.0
        static let reconnectBackoffMultiplier = 2.0
        static let autoReconnectEnabled = true
    }

    // MARK: - Sensor Configuration

    enum Sensors {
        // Sampling Rates
        static let defaultSamplingRate = 50 // Hz
        static let highSpeedSamplingRate = 100 // Hz
        static let lowPowerSamplingRate = 25 // Hz

        // Data Buffer Sizes
        static let defaultBufferSize = 100
        static let waveformBufferSize = 100
        static let historyBufferSize = 1000

        // Thresholds
        static let movementThreshold = 0.1 // g-force
        static let signalQualityThreshold = 80.0 // percentage
        static let chargingVoltageThreshold = 4.2 // volts

        // Heart Rate
        static let minValidHeartRate = 40 // bpm
        static let maxValidHeartRate = 200 // bpm

        // SpO2
        static let minValidSpO2 = 70 // percentage
        static let maxValidSpO2 = 100 // percentage

        // Temperature
        static let minValidTemperature = 30.0 // Celsius
        static let maxValidTemperature = 45.0 // Celsius

        // Battery
        static let lowBatteryThreshold = 20 // percentage
        static let criticalBatteryThreshold = 10 // percentage
    }

    // MARK: - UI Configuration

    enum UI {
        // Waveform Display
        static let maxWaveformPoints = 100
        static let waveformUpdateInterval: TimeInterval = 0.1 // seconds

        // Session Timer
        static let sessionTimerInterval: TimeInterval = 1.0 // seconds

        // Animations
        static let defaultAnimationDuration: TimeInterval = 0.3
        static let fastAnimationDuration: TimeInterval = 0.15
        static let slowAnimationDuration: TimeInterval = 0.5

        // Refresh Rates
        static let dashboardRefreshRate: TimeInterval = 0.1
        static let metricsRefreshRate: TimeInterval = 1.0

        // Data Throttling
        static let sensorDataThrottleInterval: TimeInterval = 0.1
        static let uiUpdateThrottleInterval: TimeInterval = 0.05
    }

    // MARK: - Data Management

    enum Data {
        // CSV Export
        static let csvExportDateFormat = "yyyy-MM-dd_HH-mm-ss"
        static let csvFileName = "oralable_data"
        static let csvDelimiter = ","

        // Historical Data
        static let maxHistoricalSessions = 100
        static let maxSessionDuration: TimeInterval = 3600 * 8 // 8 hours

        // Cloud Sync
        static let iCloudContainerIdentifier = "iCloud.jacdentalsolutions.OralableApp"
        static let cloudSyncInterval: TimeInterval = 300 // 5 minutes

        // Data Retention
        static let dataRetentionDays = 90 // days
        static let autoDeleteOldData = false
    }

    // MARK: - Subscription

    enum Subscription {
        // Product IDs
        static let monthlySubscriptionID = "com.oralable.mam.subscription.monthly"
        static let yearlySubscriptionID = "com.oralable.mam.subscription.yearly"
        static let lifetimePurchaseID = "com.oralable.mam.lifetime"

        // Expiry Warnings
        static let expiryWarningDays = 7 // days
        static let showExpiryReminders = true
    }

    // MARK: - Logging

    enum Logging {
        static let defaultLogLevel: LogLevel = .info
        static let enableFileLogging = true
        static let maxLogFileSize = 5_000_000 // 5 MB
        static let maxLogFiles = 3
        static let logDateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Throttling
        static let enableLogThrottling = true
        static let logThrottleInterval: TimeInterval = 1.0
        static let maxLogsPerInterval = 10
    }

    // MARK: - Network

    enum Network {
        static let requestTimeout: TimeInterval = 30.0
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }

    // MARK: - HealthKit

    enum HealthKit {
        static let enableHealthKitSync = true
        static let syncInterval: TimeInterval = 3600 // 1 hour
        static let batchSize = 100
    }

    // MARK: - Demo Mode

    enum Demo {
        static let enableDemoMode = true
        static let mockDataUpdateInterval: TimeInterval = 0.1
        static let mockHeartRateRange = 68...76
        static let mockSpO2Range = 96...99
        static let mockTemperatureRange = 36.2...36.8
    }

    // MARK: - Feature Flags

    enum Features {
        static let enableBackgroundMonitoring = false
        static let enableAdvancedAnalytics = false
        static let enableMLPredictions = false
        static let enableAppleWatchSync = false
        static let enableNotifications = true
        static let enableHaptics = true
    }

    // MARK: - Debug

    #if DEBUG
    enum Debug {
        static let enableVerboseLogging = true
        static let enableBLELogging = true
        static let enablePerformanceMonitoring = false
        static let simulateSlowNetwork = false
        static let showDebugOverlay = false
    }
    #endif
}

// MARK: - Log Level Enum

enum LogLevel: String, Codable, CaseIterable {
    case verbose = "VERBOSE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var priority: Int {
        switch self {
        case .verbose: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        }
    }
}
