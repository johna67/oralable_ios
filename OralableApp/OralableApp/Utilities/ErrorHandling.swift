//
//  ErrorHandling.swift
//  OralableApp
//
//  Unified error handling system with user-facing messages and recovery strategies
//

import Foundation
import SwiftUI
import Combine

// MARK: - App Error Protocol

protocol AppError: Error, LocalizedError {
    var title: String { get }
    var message: String { get }
    var recoveryAction: RecoveryAction? { get }
    var severity: ErrorSeverity { get }
    var category: ErrorCategory { get }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case info       // Informational, no action needed
    case warning    // Warning, user should be aware
    case error      // Error, but app can continue
    case critical   // Critical error, app may not function properly
}

// MARK: - Error Category

enum ErrorCategory {
    case ble
    case sensor
    case data
    case network
    case authentication
    case subscription
    case storage
    case general
}

// MARK: - Recovery Action

struct RecoveryAction {
    let title: String
    let action: () -> Void

    static func retry(_ action: @escaping () -> Void) -> RecoveryAction {
        RecoveryAction(title: "Retry", action: action)
    }

    static func settings(_ action: @escaping () -> Void) -> RecoveryAction {
        RecoveryAction(title: "Open Settings", action: action)
    }

    static func reconnect(_ action: @escaping () -> Void) -> RecoveryAction {
        RecoveryAction(title: "Reconnect", action: action)
    }

    static func dismiss(_ action: @escaping () -> Void) -> RecoveryAction {
        RecoveryAction(title: "Dismiss", action: action)
    }
}

// MARK: - Specific Error Types

enum BLEError: AppError {
    case bluetoothOff
    case deviceNotFound
    case connectionFailed(reason: String)
    case connectionLost
    case serviceDiscoveryFailed
    case characteristicReadFailed
    case characteristicWriteFailed
    case weakSignal(rssi: Int)
    case unauthorized

    var title: String {
        switch self {
        case .bluetoothOff: return "Bluetooth Off"
        case .deviceNotFound: return "Device Not Found"
        case .connectionFailed: return "Connection Failed"
        case .connectionLost: return "Connection Lost"
        case .serviceDiscoveryFailed: return "Service Discovery Failed"
        case .characteristicReadFailed: return "Read Failed"
        case .characteristicWriteFailed: return "Write Failed"
        case .weakSignal: return "Weak Signal"
        case .unauthorized: return "Bluetooth Unauthorized"
        }
    }

    var message: String {
        switch self {
        case .bluetoothOff:
            return "Please turn on Bluetooth in Settings to connect to your device."
        case .deviceNotFound:
            return "Unable to find your Oralable device. Make sure it's powered on and nearby."
        case .connectionFailed(let reason):
            return "Failed to connect to device: \(reason)"
        case .connectionLost:
            return "Connection to your device was lost. Please try reconnecting."
        case .serviceDiscoveryFailed:
            return "Failed to discover device services. Try disconnecting and reconnecting."
        case .characteristicReadFailed:
            return "Failed to read data from device."
        case .characteristicWriteFailed:
            return "Failed to send data to device."
        case .weakSignal(let rssi):
            return "Weak signal detected (\(rssi) dBm). Move closer to your device for better connectivity."
        case .unauthorized:
            return "This app requires Bluetooth access. Please enable it in Settings."
        }
    }

    var recoveryAction: RecoveryAction? {
        switch self {
        case .bluetoothOff:
            return .settings {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .deviceNotFound:
            return .retry {
                OralableBLE.shared.startScanning()
            }
        case .connectionFailed, .connectionLost:
            return .reconnect {
                OralableBLE.shared.startScanning()
            }
        case .unauthorized:
            return .settings {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        default:
            return nil
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .weakSignal: return .warning
        case .bluetoothOff, .unauthorized: return .critical
        default: return .error
        }
    }

    var category: ErrorCategory {
        .ble
    }
}

enum SensorError: AppError {
    case calibrationFailed
    case invalidReading
    case lowQuality(quality: Double)
    case sensorTimeout

    var title: String {
        switch self {
        case .calibrationFailed: return "Calibration Failed"
        case .invalidReading: return "Invalid Reading"
        case .lowQuality: return "Low Quality Signal"
        case .sensorTimeout: return "Sensor Timeout"
        }
    }

    var message: String {
        switch self {
        case .calibrationFailed:
            return "Sensor calibration failed. Please ensure the device is properly positioned and try again."
        case .invalidReading:
            return "Received invalid sensor reading. This may be temporary."
        case .lowQuality(let quality):
            return "Signal quality is low (\(Int(quality * 100))%). Adjust device position for better readings."
        case .sensorTimeout:
            return "Sensor did not respond in time. Check device connection."
        }
    }

    var recoveryAction: RecoveryAction? {
        switch self {
        case .calibrationFailed:
            return .retry {
                // Trigger recalibration
            }
        default:
            return nil
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .lowQuality: return .warning
        case .invalidReading: return .info
        default: return .error
        }
    }

    var category: ErrorCategory {
        .sensor
    }
}

enum DataError: AppError {
    case saveFailed
    case loadFailed
    case exportFailed
    case importFailed(reason: String)
    case corruptedData
    case insufficientData

    var title: String {
        switch self {
        case .saveFailed: return "Save Failed"
        case .loadFailed: return "Load Failed"
        case .exportFailed: return "Export Failed"
        case .importFailed: return "Import Failed"
        case .corruptedData: return "Corrupted Data"
        case .insufficientData: return "Insufficient Data"
        }
    }

    var message: String {
        switch self {
        case .saveFailed:
            return "Failed to save data. Please try again."
        case .loadFailed:
            return "Failed to load data. The data may be corrupted or unavailable."
        case .exportFailed:
            return "Failed to export data. Check storage permissions and try again."
        case .importFailed(let reason):
            return "Failed to import data: \(reason)"
        case .corruptedData:
            return "The data appears to be corrupted and cannot be loaded."
        case .insufficientData:
            return "Not enough data available for this operation."
        }
    }

    var recoveryAction: RecoveryAction? {
        switch self {
        case .saveFailed, .exportFailed:
            return .retry {
                // Retry save/export
            }
        default:
            return nil
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .insufficientData: return .info
        case .corruptedData: return .critical
        default: return .error
        }
    }

    var category: ErrorCategory {
        .data
    }
}

enum AuthenticationError: AppError {
    case notAuthenticated
    case authenticationFailed
    case tokenExpired
    case invalidCredentials

    var title: String {
        switch self {
        case .notAuthenticated: return "Not Authenticated"
        case .authenticationFailed: return "Authentication Failed"
        case .tokenExpired: return "Session Expired"
        case .invalidCredentials: return "Invalid Credentials"
        }
    }

    var message: String {
        switch self {
        case .notAuthenticated:
            return "Please sign in to access this feature."
        case .authenticationFailed:
            return "Authentication failed. Please try signing in again."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .invalidCredentials:
            return "The credentials provided are invalid."
        }
    }

    var recoveryAction: RecoveryAction? {
        return .retry {
            // Navigate to authentication
        }
    }

    var severity: ErrorSeverity {
        .error
    }

    var category: ErrorCategory {
        .authentication
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppError?
    @Published var showingError = false

    private init() {}

    /// Handle an error by showing it to the user
    func handle(_ error: AppError) {
        // Log the error
        logError(error)

        // Show to user if severity requires it
        if error.severity != .info {
            currentError = error
            showingError = true
        }
    }

    /// Handle a standard Error by wrapping it
    func handle(_ error: Error, category: ErrorCategory = .general) {
        if let appError = error as? AppError {
            handle(appError)
        } else {
            // Wrap in generic error
            handle(GenericError(underlying: error, category: category))
        }
    }

    /// Dismiss the current error
    func dismiss() {
        showingError = false
        currentError = nil
    }

    /// Execute recovery action if available
    func executeRecovery() {
        currentError?.recoveryAction?.action()
        dismiss()
    }

    private func logError(_ error: AppError) {
        let logger = Logger.shared

        switch error.severity {
        case .info:
            logger.info(error.message, category: logCategory(for: error.category))
        case .warning:
            logger.warning(error.message, category: logCategory(for: error.category))
        case .error:
            logger.error(error.message, category: logCategory(for: error.category))
        case .critical:
            logger.critical(error.message, category: logCategory(for: error.category))
        }
    }

    private func logCategory(for errorCategory: ErrorCategory) -> Logger.Category {
        switch errorCategory {
        case .ble: return .ble
        case .sensor: return .sensor
        case .data: return .data
        case .network: return .network
        case .authentication: return .auth
        default: return .general
        }
    }
}

// MARK: - Generic Error Wrapper

struct GenericError: AppError {
    let underlying: Error
    let category: ErrorCategory

    var title: String {
        "Error"
    }

    var message: String {
        underlying.localizedDescription
    }

    var recoveryAction: RecoveryAction? {
        nil
    }

    var severity: ErrorSeverity {
        .error
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler

    func body(content: Content) -> some View {
        content
            .alert(errorHandler.currentError?.title ?? "Error", isPresented: $errorHandler.showingError) {
                if let recoveryAction = errorHandler.currentError?.recoveryAction {
                    Button(recoveryAction.title) {
                        errorHandler.executeRecovery()
                    }
                    Button("Cancel", role: .cancel) {
                        errorHandler.dismiss()
                    }
                } else {
                    Button("OK") {
                        errorHandler.dismiss()
                    }
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.message)
                }
            }
    }
}

extension View {
    /// Add error handling to any view
    func withErrorHandling() -> some View {
        modifier(ErrorAlert(errorHandler: ErrorHandler.shared))
    }
}

// MARK: - Usage Examples

/*
 // In your view models or views:

 // Handle specific errors
 ErrorHandler.shared.handle(BLEError.connectionFailed(reason: "Timeout"))
 ErrorHandler.shared.handle(SensorError.lowQuality(quality: 0.3))
 ErrorHandler.shared.handle(DataError.exportFailed)

 // Handle generic errors
 do {
     try somethingThatMightFail()
 } catch {
     ErrorHandler.shared.handle(error, category: .data)
 }

 // In your root view:
 ContentView()
     .withErrorHandling()
     .environmentObject(ErrorHandler.shared)
 */
