//
//  Anonymizer.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Anonymization layer for pilot study data
//  Strips personal identifiers, replaces with randomized trial IDs, obfuscates timestamps
//

import Foundation
import CryptoKit

// MARK: - Anonymization Configuration

/// Configuration for the anonymization process
struct AnonymizationConfig: Codable, Equatable {
    /// Whether to obfuscate timestamps (round to nearest minute)
    var obfuscateTimestamps: Bool

    /// Granularity for timestamp obfuscation
    var timestampGranularity: TimestampGranularity

    /// Whether to strip device identifiers
    var stripDeviceIdentifiers: Bool

    /// Whether to strip user identifiers
    var stripUserIdentifiers: Bool

    /// Whether to strip session IDs
    var stripSessionIds: Bool

    /// Salt for generating consistent trial IDs (optional)
    var trialSalt: String?

    /// Study identifier prefix for trial IDs
    var studyPrefix: String

    /// Default configuration for pilot studies
    static var `default`: AnonymizationConfig {
        AnonymizationConfig(
            obfuscateTimestamps: true,
            timestampGranularity: .minute,
            stripDeviceIdentifiers: true,
            stripUserIdentifiers: true,
            stripSessionIds: false,
            trialSalt: nil,
            studyPrefix: "ORALABLE"
        )
    }

    /// Strict anonymization (maximum privacy)
    static var strict: AnonymizationConfig {
        AnonymizationConfig(
            obfuscateTimestamps: true,
            timestampGranularity: .hour,
            stripDeviceIdentifiers: true,
            stripUserIdentifiers: true,
            stripSessionIds: true,
            trialSalt: UUID().uuidString,
            studyPrefix: "STUDY"
        )
    }

    /// Minimal anonymization (preserve more data for research)
    static var minimal: AnonymizationConfig {
        AnonymizationConfig(
            obfuscateTimestamps: false,
            timestampGranularity: .second,
            stripDeviceIdentifiers: true,
            stripUserIdentifiers: true,
            stripSessionIds: false,
            trialSalt: nil,
            studyPrefix: "PILOT"
        )
    }
}

/// Granularity for timestamp obfuscation
enum TimestampGranularity: String, Codable, CaseIterable {
    case second = "SECOND"
    case minute = "MINUTE"
    case fiveMinutes = "FIVE_MINUTES"
    case fifteenMinutes = "FIFTEEN_MINUTES"
    case hour = "HOUR"
    case day = "DAY"

    /// Round a date to this granularity
    func round(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        switch self {
        case .second:
            // No rounding needed
            return date
        case .minute:
            components.second = 0
        case .fiveMinutes:
            components.second = 0
            if let minute = components.minute {
                components.minute = (minute / 5) * 5
            }
        case .fifteenMinutes:
            components.second = 0
            if let minute = components.minute {
                components.minute = (minute / 15) * 15
            }
        case .hour:
            components.second = 0
            components.minute = 0
        case .day:
            components.second = 0
            components.minute = 0
            components.hour = 0
        }

        return calendar.date(from: components) ?? date
    }
}

// MARK: - Anonymized Event

/// An anonymized version of a pilot event
struct AnonymizedEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let eventType: PilotEventType
    let category: PilotEventCategory
    let timestamp: Date
    let trialId: String
    let participantId: String
    let metadata: [String: String]
    let numericData: [String: Double]?
    let severity: PilotEventSeverity

    /// ISO 8601 formatted timestamp
    var isoTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: timestamp)
    }

    /// CSV row representation
    var csvRow: String {
        let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        let numericString = numericData?.map { "\($0.key)=\($0.value)" }.joined(separator: ";") ?? ""
        return "\"\(id.uuidString)\",\"\(eventType.rawValue)\",\"\(category.rawValue)\",\"\(isoTimestamp)\",\"\(trialId)\",\"\(participantId)\",\"\(severity.rawValue)\",\"\(metadataString)\",\"\(numericString)\""
    }
}

// MARK: - Anonymizer

/// Handles anonymization of pilot study data
/// Strips personal identifiers, generates randomized trial IDs, and obfuscates timestamps
class Anonymizer {

    // MARK: - Singleton

    static let shared = Anonymizer()

    // MARK: - Properties

    private var config: AnonymizationConfig
    private var identifierMapping: [String: String] = [:]
    private let mapLock = NSLock()

    // MARK: - Initialization

    init(config: AnonymizationConfig = .default) {
        self.config = config
    }

    // MARK: - Configuration

    /// Update the anonymization configuration
    func configure(with config: AnonymizationConfig) {
        self.config = config
        // Clear mappings when config changes
        mapLock.lock()
        identifierMapping.removeAll()
        mapLock.unlock()
    }

    /// Get the current configuration
    var currentConfig: AnonymizationConfig {
        return config
    }

    // MARK: - Anonymization Methods

    /// Anonymize a single pilot event
    /// - Parameter event: The event to anonymize
    /// - Returns: An anonymized version of the event
    func anonymize(_ event: PilotEvent) -> AnonymizedEvent {
        // Generate trial ID from session
        let trialId = config.stripSessionIds
            ? generateTrialId(from: "ANON-SESSION")
            : generateTrialId(from: event.sessionId)

        // Generate participant ID from device/user
        let participantId = generateParticipantId(
            deviceId: event.deviceIdentifier,
            userId: event.userId
        )

        // Obfuscate timestamp if configured
        let timestamp = config.obfuscateTimestamps
            ? config.timestampGranularity.round(event.timestamp)
            : event.timestamp

        // Clean metadata of any identifiers
        let cleanedMetadata = cleanMetadata(event.metadata)

        return AnonymizedEvent(
            id: UUID(), // Generate new ID to avoid traceability
            eventType: event.eventType,
            category: event.category,
            timestamp: timestamp,
            trialId: trialId,
            participantId: participantId,
            metadata: cleanedMetadata,
            numericData: event.numericData,
            severity: event.severity
        )
    }

    /// Anonymize multiple pilot events
    /// - Parameter events: The events to anonymize
    /// - Returns: Array of anonymized events
    func anonymize(_ events: [PilotEvent]) -> [AnonymizedEvent] {
        return events.map { anonymize($0) }
    }

    /// Anonymize sensor data for export
    func anonymizeSensorData(_ data: SensorData, deviceId: String, userId: String?) -> AnonymizedSensorData {
        let participantId = generateParticipantId(deviceId: deviceId, userId: userId)
        let timestamp = config.obfuscateTimestamps
            ? config.timestampGranularity.round(data.timestamp)
            : data.timestamp

        return AnonymizedSensorData(
            timestamp: timestamp,
            participantId: participantId,
            ppg: data.ppg,
            accelerometer: data.accelerometer,
            temperature: data.temperature,
            battery: data.battery,
            heartRate: data.heartRate,
            spo2: data.spo2
        )
    }

    // MARK: - Identifier Generation

    /// Generate a consistent trial ID from a session ID
    /// - Parameter sessionId: The original session ID
    /// - Returns: A randomized trial ID
    func generateTrialId(from sessionId: String) -> String {
        return generateMappedId(original: sessionId, prefix: "TRIAL")
    }

    /// Generate a consistent participant ID from device/user identifiers
    /// - Parameters:
    ///   - deviceId: The device identifier
    ///   - userId: The optional user identifier
    /// - Returns: A randomized participant ID
    func generateParticipantId(deviceId: String, userId: String?) -> String {
        let combinedId = config.stripDeviceIdentifiers && config.stripUserIdentifiers
            ? "\(deviceId):\(userId ?? "NONE")"
            : deviceId

        return generateMappedId(original: combinedId, prefix: "P")
    }

    /// Generate a mapped ID with consistent hashing
    private func generateMappedId(original: String, prefix: String) -> String {
        mapLock.lock()
        defer { mapLock.unlock() }

        // Check if we already have a mapping
        if let existing = identifierMapping[original] {
            return existing
        }

        // Generate new ID using hash
        let hashInput = config.trialSalt != nil
            ? "\(config.trialSalt!):\(original)"
            : original

        let hash = generateHash(hashInput)
        let shortHash = String(hash.prefix(8)).uppercased()
        let newId = "\(config.studyPrefix)-\(prefix)-\(shortHash)"

        identifierMapping[original] = newId
        return newId
    }

    /// Generate a deterministic hash for an identifier
    private func generateHash(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Metadata Cleaning

    /// Clean metadata dictionary of any potential identifiers
    /// - Parameter metadata: Original metadata
    /// - Returns: Cleaned metadata with identifiers removed or replaced
    func cleanMetadata(_ metadata: [String: String]) -> [String: String] {
        var cleaned: [String: String] = [:]

        let identifierKeys = [
            "deviceId", "deviceID", "device_id",
            "userId", "userID", "user_id",
            "appleId", "appleID", "apple_id",
            "peripheralId", "peripheralID", "peripheral_id",
            "uuid", "UUID", "id", "ID",
            "email", "phone", "name", "address"
        ]

        for (key, value) in metadata {
            // Skip known identifier keys
            if identifierKeys.contains(where: { key.lowercased().contains($0.lowercased()) }) {
                // Replace with anonymized version
                if config.stripDeviceIdentifiers || config.stripUserIdentifiers {
                    cleaned[key] = "[REDACTED]"
                } else {
                    cleaned[key] = generateMappedId(original: value, prefix: "ID")
                }
                continue
            }

            // Check if value looks like a UUID
            if looksLikeUUID(value) {
                cleaned[key] = "[UUID-REDACTED]"
                continue
            }

            // Check if value looks like an email
            if looksLikeEmail(value) {
                cleaned[key] = "[EMAIL-REDACTED]"
                continue
            }

            // Keep other values as-is
            cleaned[key] = value
        }

        return cleaned
    }

    /// Check if a string looks like a UUID
    private func looksLikeUUID(_ value: String) -> Bool {
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        return value.range(of: uuidPattern, options: .regularExpression) != nil
    }

    /// Check if a string looks like an email
    private func looksLikeEmail(_ value: String) -> Bool {
        return value.contains("@") && value.contains(".")
    }

    // MARK: - Timestamp Utilities

    /// Obfuscate a timestamp according to current configuration
    /// - Parameter date: The original date
    /// - Returns: The obfuscated date
    func obfuscateTimestamp(_ date: Date) -> Date {
        guard config.obfuscateTimestamps else { return date }
        return config.timestampGranularity.round(date)
    }

    /// Strip precise time information, keeping only date
    func stripTimeFromDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }

    // MARK: - Validation

    /// Validate that an event has been properly anonymized
    /// - Parameter event: The anonymized event to validate
    /// - Returns: True if properly anonymized
    func validateAnonymization(_ event: AnonymizedEvent) -> AnonymizationValidationResult {
        var issues: [String] = []

        // Check trial ID format
        if !event.trialId.hasPrefix(config.studyPrefix) {
            issues.append("Trial ID does not have expected prefix")
        }

        // Check participant ID format
        if !event.participantId.hasPrefix(config.studyPrefix) {
            issues.append("Participant ID does not have expected prefix")
        }

        // Check for potential identifiers in metadata
        for (key, value) in event.metadata {
            if looksLikeUUID(value) && value != "[UUID-REDACTED]" {
                issues.append("Potential UUID found in metadata key '\(key)'")
            }
            if looksLikeEmail(value) && value != "[EMAIL-REDACTED]" {
                issues.append("Potential email found in metadata key '\(key)'")
            }
        }

        // Check timestamp obfuscation
        if config.obfuscateTimestamps {
            let rounded = config.timestampGranularity.round(event.timestamp)
            if event.timestamp != rounded {
                issues.append("Timestamp may not be properly obfuscated")
            }
        }

        return AnonymizationValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }

    /// Validate a batch of anonymized events
    func validateBatch(_ events: [AnonymizedEvent]) -> BatchValidationResult {
        var validCount = 0
        var invalidCount = 0
        var allIssues: [String] = []

        for event in events {
            let result = validateAnonymization(event)
            if result.isValid {
                validCount += 1
            } else {
                invalidCount += 1
                allIssues.append(contentsOf: result.issues)
            }
        }

        return BatchValidationResult(
            totalEvents: events.count,
            validCount: validCount,
            invalidCount: invalidCount,
            issues: allIssues
        )
    }

    // MARK: - Reset

    /// Clear all identifier mappings (useful for new study sessions)
    func clearMappings() {
        mapLock.lock()
        identifierMapping.removeAll()
        mapLock.unlock()
        Logger.shared.info("[Anonymizer] Cleared identifier mappings")
    }

    /// Get the number of mapped identifiers
    var mappingCount: Int {
        mapLock.lock()
        defer { mapLock.unlock() }
        return identifierMapping.count
    }
}

// MARK: - Validation Results

/// Result of anonymization validation for a single event
struct AnonymizationValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Result of batch validation
struct BatchValidationResult {
    let totalEvents: Int
    let validCount: Int
    let invalidCount: Int
    let issues: [String]

    var passRate: Double {
        guard totalEvents > 0 else { return 0 }
        return Double(validCount) / Double(totalEvents) * 100
    }
}

// MARK: - Anonymized Sensor Data

/// Anonymized version of sensor data for export
struct AnonymizedSensorData: Codable {
    let timestamp: Date
    let participantId: String
    let ppg: PPGData
    let accelerometer: AccelerometerData
    let temperature: TemperatureData
    let battery: BatteryData
    let heartRate: HeartRateData?
    let spo2: SpO2Data?

    /// CSV row representation
    var csvRow: String {
        let dateFormatter = ISO8601DateFormatter()
        let hr = heartRate?.bpm ?? 0
        let sp = spo2?.percentage ?? 0
        return "\"\(dateFormatter.string(from: timestamp))\",\"\(participantId)\",\(ppg.ir),\(ppg.red),\(ppg.green),\(accelerometer.x),\(accelerometer.y),\(accelerometer.z),\(temperature.celsius),\(battery.percentage),\(hr),\(sp)"
    }
}
