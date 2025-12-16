//
//  PilotLogger.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Structured logging for pilot study data collection
//  Logs BLE events, SensorData events, and app lifecycle events with metadata
//

import Foundation
import Combine

// MARK: - Pilot Event Types

/// Types of events that can be logged during pilot studies
enum PilotEventType: String, Codable, CaseIterable {
    // BLE Events
    case bleConnect = "BLE_CONNECT"
    case bleDisconnect = "BLE_DISCONNECT"
    case bleReconnectAttempt = "BLE_RECONNECT_ATTEMPT"
    case bleReconnectSuccess = "BLE_RECONNECT_SUCCESS"
    case bleReconnectFailure = "BLE_RECONNECT_FAILURE"
    case bleScanStart = "BLE_SCAN_START"
    case bleScanStop = "BLE_SCAN_STOP"
    case bleDeviceDiscovered = "BLE_DEVICE_DISCOVERED"
    case bleDataReceived = "BLE_DATA_RECEIVED"
    case bleError = "BLE_ERROR"

    // Sensor Data Events
    case sensorDataReceived = "SENSOR_DATA_RECEIVED"
    case sensorBruxismDetected = "SENSOR_BRUXISM_DETECTED"
    case sensorSleepCycleStart = "SENSOR_SLEEP_CYCLE_START"
    case sensorSleepCycleEnd = "SENSOR_SLEEP_CYCLE_END"
    case sensorAnomalyDetected = "SENSOR_ANOMALY_DETECTED"
    case sensorThresholdExceeded = "SENSOR_THRESHOLD_EXCEEDED"
    case sensorCalibrationStart = "SENSOR_CALIBRATION_START"
    case sensorCalibrationComplete = "SENSOR_CALIBRATION_COMPLETE"

    // App Lifecycle Events
    case appForeground = "APP_FOREGROUND"
    case appBackground = "APP_BACKGROUND"
    case appSuspend = "APP_SUSPEND"
    case appTerminate = "APP_TERMINATE"
    case appLaunch = "APP_LAUNCH"
    case appResume = "APP_RESUME"

    // User Interaction Events
    case userRecordingStart = "USER_RECORDING_START"
    case userRecordingStop = "USER_RECORDING_STOP"
    case userExportData = "USER_EXPORT_DATA"
    case userSettingsChange = "USER_SETTINGS_CHANGE"

    // System Events
    case systemLowMemory = "SYSTEM_LOW_MEMORY"
    case systemLowBattery = "SYSTEM_LOW_BATTERY"
    case systemNetworkChange = "SYSTEM_NETWORK_CHANGE"

    var category: PilotEventCategory {
        switch self {
        case .bleConnect, .bleDisconnect, .bleReconnectAttempt, .bleReconnectSuccess,
             .bleReconnectFailure, .bleScanStart, .bleScanStop, .bleDeviceDiscovered,
             .bleDataReceived, .bleError:
            return .ble
        case .sensorDataReceived, .sensorBruxismDetected, .sensorSleepCycleStart,
             .sensorSleepCycleEnd, .sensorAnomalyDetected, .sensorThresholdExceeded,
             .sensorCalibrationStart, .sensorCalibrationComplete:
            return .sensor
        case .appForeground, .appBackground, .appSuspend, .appTerminate, .appLaunch, .appResume:
            return .lifecycle
        case .userRecordingStart, .userRecordingStop, .userExportData, .userSettingsChange:
            return .userInteraction
        case .systemLowMemory, .systemLowBattery, .systemNetworkChange:
            return .system
        }
    }
}

/// Category grouping for pilot events
enum PilotEventCategory: String, Codable, CaseIterable {
    case ble = "BLE"
    case sensor = "SENSOR"
    case lifecycle = "LIFECYCLE"
    case userInteraction = "USER_INTERACTION"
    case system = "SYSTEM"
}

// MARK: - Pilot Event

/// Represents a single pilot study event with all relevant metadata
struct PilotEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let eventType: PilotEventType
    let category: PilotEventCategory
    let timestamp: Date
    let sessionId: String
    let deviceIdentifier: String
    let userId: String?
    let metadata: [String: String]
    let numericData: [String: Double]?
    let severity: PilotEventSeverity
    let source: String?

    init(
        id: UUID = UUID(),
        eventType: PilotEventType,
        timestamp: Date = Date(),
        sessionId: String,
        deviceIdentifier: String,
        userId: String? = nil,
        metadata: [String: String] = [:],
        numericData: [String: Double]? = nil,
        severity: PilotEventSeverity = .info,
        source: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.category = eventType.category
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.deviceIdentifier = deviceIdentifier
        self.userId = userId
        self.metadata = metadata
        self.numericData = numericData
        self.severity = severity
        self.source = source
    }

    /// ISO 8601 formatted timestamp
    var isoTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: timestamp)
    }

    /// CSV row representation
    var csvRow: String {
        let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        let numericString = numericData?.map { "\($0.key)=\($0.value)" }.joined(separator: ";") ?? ""
        return "\"\(id.uuidString)\",\"\(eventType.rawValue)\",\"\(category.rawValue)\",\"\(isoTimestamp)\",\"\(sessionId)\",\"\(deviceIdentifier)\",\"\(userId ?? "")\",\"\(severity.rawValue)\",\"\(metadataString)\",\"\(numericString)\""
    }
}

/// Severity levels for pilot events
enum PilotEventSeverity: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

// MARK: - Pilot Logger

/// Structured logger for pilot study data collection
/// Logs BLE events, SensorData events, and app lifecycle events
class PilotLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = PilotLogger()

    // MARK: - Properties

    @Published private(set) var events: [PilotEvent] = []
    @Published private(set) var isLogging: Bool = false
    @Published private(set) var currentSessionId: String

    private let maxEvents: Int
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private var cancellables = Set<AnyCancellable>()

    /// Device identifier for this device
    private(set) var deviceIdentifier: String

    /// User identifier (if available)
    var userId: String?

    // MARK: - Initialization

    init(maxEvents: Int = 10000, deviceIdentifier: String? = nil) {
        self.maxEvents = maxEvents
        self.currentSessionId = Self.generateSessionId()
        self.deviceIdentifier = deviceIdentifier ?? Self.getDeviceIdentifier()

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        loadPersistedEvents()

        Logger.shared.info("[PilotLogger] Initialized with session: \(currentSessionId)")
    }

    // MARK: - Session Management

    /// Start a new logging session
    func startSession() {
        currentSessionId = Self.generateSessionId()
        isLogging = true

        logEvent(
            type: .appLaunch,
            metadata: ["sessionStart": "true"],
            severity: .info
        )

        Logger.shared.info("[PilotLogger] Started session: \(currentSessionId)")
    }

    /// End the current logging session
    func endSession() {
        logEvent(
            type: .appTerminate,
            metadata: ["sessionEnd": "true"],
            severity: .info
        )

        persistEvents()
        isLogging = false

        Logger.shared.info("[PilotLogger] Ended session: \(currentSessionId)")
    }

    // MARK: - BLE Event Logging

    /// Log a BLE connection event
    func logBLEConnect(peripheralId: String, peripheralName: String?, rssi: Int? = nil) {
        var metadata: [String: String] = [
            "peripheralId": peripheralId
        ]
        if let name = peripheralName {
            metadata["peripheralName"] = name
        }

        var numeric: [String: Double]?
        if let rssi = rssi {
            numeric = ["rssi": Double(rssi)]
        }

        logEvent(
            type: .bleConnect,
            metadata: metadata,
            numericData: numeric,
            severity: .info
        )
    }

    /// Log a BLE disconnection event
    func logBLEDisconnect(peripheralId: String, reason: String?) {
        var metadata: [String: String] = ["peripheralId": peripheralId]
        if let reason = reason {
            metadata["reason"] = reason
        }

        logEvent(
            type: .bleDisconnect,
            metadata: metadata,
            severity: .warning
        )
    }

    /// Log a BLE reconnection attempt
    func logBLEReconnectAttempt(peripheralId: String, attemptNumber: Int) {
        logEvent(
            type: .bleReconnectAttempt,
            metadata: [
                "peripheralId": peripheralId,
                "attemptNumber": "\(attemptNumber)"
            ],
            severity: .info
        )
    }

    /// Log a BLE reconnection success
    func logBLEReconnectSuccess(peripheralId: String, attemptNumber: Int, durationMs: Int) {
        logEvent(
            type: .bleReconnectSuccess,
            metadata: ["peripheralId": peripheralId],
            numericData: [
                "attemptNumber": Double(attemptNumber),
                "durationMs": Double(durationMs)
            ],
            severity: .info
        )
    }

    /// Log a BLE reconnection failure
    func logBLEReconnectFailure(peripheralId: String, totalAttempts: Int, error: String?) {
        var metadata: [String: String] = [
            "peripheralId": peripheralId,
            "totalAttempts": "\(totalAttempts)"
        ]
        if let error = error {
            metadata["error"] = error
        }

        logEvent(
            type: .bleReconnectFailure,
            metadata: metadata,
            severity: .error
        )
    }

    /// Log BLE data received
    func logBLEDataReceived(peripheralId: String, dataSize: Int, characteristicId: String?) {
        var metadata: [String: String] = ["peripheralId": peripheralId]
        if let charId = characteristicId {
            metadata["characteristicId"] = charId
        }

        logEvent(
            type: .bleDataReceived,
            metadata: metadata,
            numericData: ["dataSize": Double(dataSize)],
            severity: .debug
        )
    }

    /// Log BLE error
    func logBLEError(peripheralId: String?, errorCode: Int, errorMessage: String) {
        var metadata: [String: String] = [
            "errorCode": "\(errorCode)",
            "errorMessage": errorMessage
        ]
        if let peripheralId = peripheralId {
            metadata["peripheralId"] = peripheralId
        }

        logEvent(
            type: .bleError,
            metadata: metadata,
            severity: .error
        )
    }

    // MARK: - Sensor Data Event Logging

    /// Log sensor data received
    func logSensorDataReceived(
        ppgIR: Int,
        ppgRed: Int,
        ppgGreen: Int,
        temperature: Double?,
        batteryLevel: Int?
    ) {
        var numeric: [String: Double] = [
            "ppgIR": Double(ppgIR),
            "ppgRed": Double(ppgRed),
            "ppgGreen": Double(ppgGreen)
        ]
        if let temp = temperature {
            numeric["temperature"] = temp
        }
        if let battery = batteryLevel {
            numeric["batteryLevel"] = Double(battery)
        }

        logEvent(
            type: .sensorDataReceived,
            numericData: numeric,
            severity: .debug
        )
    }

    /// Log bruxism detection event
    func logBruxismDetected(intensity: Double, duration: TimeInterval, confidence: Double) {
        logEvent(
            type: .sensorBruxismDetected,
            numericData: [
                "intensity": intensity,
                "durationSeconds": duration,
                "confidence": confidence
            ],
            severity: .info
        )
    }

    /// Log sleep cycle start
    func logSleepCycleStart(cycleNumber: Int) {
        logEvent(
            type: .sensorSleepCycleStart,
            metadata: ["cycleNumber": "\(cycleNumber)"],
            severity: .info
        )
    }

    /// Log sleep cycle end
    func logSleepCycleEnd(cycleNumber: Int, durationMinutes: Double, stage: String?) {
        var metadata: [String: String] = ["cycleNumber": "\(cycleNumber)"]
        if let stage = stage {
            metadata["sleepStage"] = stage
        }

        logEvent(
            type: .sensorSleepCycleEnd,
            metadata: metadata,
            numericData: ["durationMinutes": durationMinutes],
            severity: .info
        )
    }

    /// Log sensor anomaly detected
    func logSensorAnomaly(sensorType: String, value: Double, expectedRange: String) {
        logEvent(
            type: .sensorAnomalyDetected,
            metadata: [
                "sensorType": sensorType,
                "expectedRange": expectedRange
            ],
            numericData: ["anomalousValue": value],
            severity: .warning
        )
    }

    /// Log threshold exceeded
    func logThresholdExceeded(metric: String, value: Double, threshold: Double, direction: String) {
        logEvent(
            type: .sensorThresholdExceeded,
            metadata: [
                "metric": metric,
                "direction": direction
            ],
            numericData: [
                "value": value,
                "threshold": threshold
            ],
            severity: .warning
        )
    }

    // MARK: - App Lifecycle Event Logging

    /// Log app entering foreground
    func logAppForeground() {
        logEvent(
            type: .appForeground,
            metadata: ["memoryUsage": "\(getMemoryUsage())"],
            severity: .info
        )
    }

    /// Log app entering background
    func logAppBackground() {
        logEvent(
            type: .appBackground,
            metadata: ["memoryUsage": "\(getMemoryUsage())"],
            severity: .info
        )
    }

    /// Log app suspension
    func logAppSuspend() {
        logEvent(
            type: .appSuspend,
            severity: .info
        )
        persistEvents()
    }

    /// Log app resume
    func logAppResume() {
        logEvent(
            type: .appResume,
            severity: .info
        )
    }

    // MARK: - User Interaction Logging

    /// Log recording start
    func logRecordingStart() {
        logEvent(
            type: .userRecordingStart,
            severity: .info
        )
    }

    /// Log recording stop
    func logRecordingStop(durationMinutes: Double, dataPointsCollected: Int) {
        logEvent(
            type: .userRecordingStop,
            numericData: [
                "durationMinutes": durationMinutes,
                "dataPointsCollected": Double(dataPointsCollected)
            ],
            severity: .info
        )
    }

    /// Log data export
    func logDataExport(format: String, recordCount: Int, success: Bool, error: String? = nil) {
        var metadata: [String: String] = [
            "format": format,
            "success": "\(success)"
        ]
        if let error = error {
            metadata["error"] = error
        }

        logEvent(
            type: .userExportData,
            metadata: metadata,
            numericData: ["recordCount": Double(recordCount)],
            severity: success ? .info : .error
        )
    }

    /// Log settings change
    func logSettingsChange(setting: String, oldValue: String?, newValue: String) {
        var metadata: [String: String] = [
            "setting": setting,
            "newValue": newValue
        ]
        if let oldValue = oldValue {
            metadata["oldValue"] = oldValue
        }

        logEvent(
            type: .userSettingsChange,
            metadata: metadata,
            severity: .info
        )
    }

    // MARK: - System Event Logging

    /// Log low memory warning
    func logLowMemory(availableBytes: Int) {
        logEvent(
            type: .systemLowMemory,
            numericData: ["availableBytes": Double(availableBytes)],
            severity: .warning
        )
    }

    /// Log low battery
    func logLowBattery(level: Int) {
        logEvent(
            type: .systemLowBattery,
            numericData: ["batteryLevel": Double(level)],
            severity: .warning
        )
    }

    // MARK: - Generic Event Logging

    /// Log a generic event
    func logEvent(
        type: PilotEventType,
        metadata: [String: String] = [:],
        numericData: [String: Double]? = nil,
        severity: PilotEventSeverity = .info,
        source: String? = nil
    ) {
        let event = PilotEvent(
            eventType: type,
            timestamp: Date(),
            sessionId: currentSessionId,
            deviceIdentifier: deviceIdentifier,
            userId: userId,
            metadata: metadata,
            numericData: numericData,
            severity: severity,
            source: source
        )

        DispatchQueue.main.async { [weak self] in
            self?.addEvent(event)
        }
    }

    // MARK: - Event Management

    private func addEvent(_ event: PilotEvent) {
        events.append(event)

        // Trim if exceeding max events
        if events.count > maxEvents {
            let overflow = events.count - maxEvents
            events.removeFirst(overflow)
        }
    }

    /// Clear all logged events
    func clearEvents() {
        events.removeAll()
        Logger.shared.info("[PilotLogger] Cleared all events")
    }

    /// Get events filtered by type
    func events(ofType type: PilotEventType) -> [PilotEvent] {
        return events.filter { $0.eventType == type }
    }

    /// Get events filtered by category
    func events(inCategory category: PilotEventCategory) -> [PilotEvent] {
        return events.filter { $0.category == category }
    }

    /// Get events filtered by severity
    func events(withSeverity severity: PilotEventSeverity) -> [PilotEvent] {
        return events.filter { $0.severity == severity }
    }

    /// Get events within a date range
    func events(from startDate: Date, to endDate: Date) -> [PilotEvent] {
        return events.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    // MARK: - Export Methods

    /// Export events to JSON data
    func exportToJSON() -> Data? {
        do {
            return try encoder.encode(events)
        } catch {
            Logger.shared.error("[PilotLogger] Failed to encode events: \(error)")
            return nil
        }
    }

    /// Export events to CSV string
    func exportToCSV() -> String {
        var csv = "ID,EventType,Category,Timestamp,SessionID,DeviceID,UserID,Severity,Metadata,NumericData\n"
        for event in events {
            csv += event.csvRow + "\n"
        }
        return csv
    }

    /// Export events to file
    func exportToFile(format: PilotExportFormat) -> URL? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "pilot_events_\(currentSessionId)_\(timestamp).\(format.fileExtension)"
        let fileURL = getExportDirectory().appendingPathComponent(filename)

        do {
            switch format {
            case .json:
                if let data = exportToJSON() {
                    try data.write(to: fileURL)
                    return fileURL
                }
            case .csv:
                let csvContent = exportToCSV()
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
                return fileURL
            }
        } catch {
            Logger.shared.error("[PilotLogger] Failed to export to file: \(error)")
        }

        return nil
    }

    // MARK: - Persistence

    private func getExportDirectory() -> URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let exportDir = cacheDir.appendingPathComponent("PilotLogs", isDirectory: true)

        if !fileManager.fileExists(atPath: exportDir.path) {
            try? fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        }

        return exportDir
    }

    private func getPersistedEventsURL() -> URL {
        return getExportDirectory().appendingPathComponent("persisted_events.json")
    }

    func persistEvents() {
        let url = getPersistedEventsURL()

        do {
            let data = try encoder.encode(events)
            try data.write(to: url)
            Logger.shared.debug("[PilotLogger] Persisted \(events.count) events")
        } catch {
            Logger.shared.error("[PilotLogger] Failed to persist events: \(error)")
        }
    }

    private func loadPersistedEvents() {
        let url = getPersistedEventsURL()

        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedEvents = try decoder.decode([PilotEvent].self, from: data)
            events = loadedEvents
            Logger.shared.debug("[PilotLogger] Loaded \(events.count) persisted events")
        } catch {
            Logger.shared.error("[PilotLogger] Failed to load persisted events: \(error)")
        }
    }

    // MARK: - Helpers

    private static func generateSessionId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        return "SESSION-\(timestamp)-\(random)"
    }

    private static func getDeviceIdentifier() -> String {
        #if targetEnvironment(simulator)
        return "SIMULATOR-\(ProcessInfo.processInfo.processIdentifier)"
        #else
        return UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN"
        #endif
    }

    private func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024 / 1024
            return String(format: "%.1f MB", usedMB)
        }
        return "N/A"
    }
}

// MARK: - Export Format

/// Export formats for pilot logs
enum PilotExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"

    var fileExtension: String {
        rawValue.lowercased()
    }
}

// MARK: - UIKit Import for Device Identifier

#if canImport(UIKit)
import UIKit
#endif
