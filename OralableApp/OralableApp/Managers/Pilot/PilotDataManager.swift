//
//  PilotDataManager.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Manages aggregation and batch export of anonymized pilot study data
//  Handles error cases and integrates with DataExportManager
//

import Foundation
import Combine

// MARK: - Pilot Data Manager Errors

/// Errors that can occur during pilot data management
enum PilotDataError: Error, LocalizedError, Equatable {
    case noDataToExport
    case writePermissionDenied
    case fileWriteFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case aggregationFailed(reason: String)
    case consentNotGranted
    case exportDirectoryUnavailable
    case batchSizeTooLarge(requested: Int, maximum: Int)
    case invalidDateRange
    case anonymizationFailed

    static func == (lhs: PilotDataError, rhs: PilotDataError) -> Bool {
        switch (lhs, rhs) {
        case (.noDataToExport, .noDataToExport),
             (.writePermissionDenied, .writePermissionDenied),
             (.consentNotGranted, .consentNotGranted),
             (.exportDirectoryUnavailable, .exportDirectoryUnavailable),
             (.invalidDateRange, .invalidDateRange),
             (.anonymizationFailed, .anonymizationFailed):
            return true
        case (.fileWriteFailed, .fileWriteFailed),
             (.encodingFailed, .encodingFailed):
            return true
        case (.aggregationFailed(let lhsReason), .aggregationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.batchSizeTooLarge(let lhsReq, let lhsMax), .batchSizeTooLarge(let rhsReq, let rhsMax)):
            return lhsReq == rhsReq && lhsMax == rhsMax
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "No pilot data available to export"
        case .writePermissionDenied:
            return "Permission denied when writing pilot data"
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .aggregationFailed(let reason):
            return "Data aggregation failed: \(reason)"
        case .consentNotGranted:
            return "User has not consented to pilot study participation"
        case .exportDirectoryUnavailable:
            return "Export directory is not available"
        case .batchSizeTooLarge(let requested, let maximum):
            return "Batch size \(requested) exceeds maximum \(maximum)"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .anonymizationFailed:
            return "Failed to anonymize data"
        }
    }
}

// MARK: - Batch Export Result

/// Result of a batch export operation
struct BatchExportResult: Codable, Equatable {
    let exportId: String
    let timestamp: Date
    let eventCount: Int
    let sensorDataCount: Int
    let fileURLs: [String]
    let format: String
    let success: Bool
    let errorMessage: String?

    var summary: String {
        """
        Export ID: \(exportId)
        Events: \(eventCount)
        Sensor Data Points: \(sensorDataCount)
        Format: \(format)
        Success: \(success)
        """
    }
}

// MARK: - Pilot Study Settings

/// User settings for pilot study participation
class PilotStudySettings: ObservableObject {
    static let shared = PilotStudySettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let consentGranted = "pilot.consent.granted"
        static let consentDate = "pilot.consent.date"
        static let participantTrialId = "pilot.participant.trialId"
        static let dataCollectionEnabled = "pilot.data.collectionEnabled"
        static let autoExportEnabled = "pilot.export.autoEnabled"
        static let exportBatchSize = "pilot.export.batchSize"
        static let lastExportDate = "pilot.export.lastDate"
    }

    /// Whether the user has granted consent for pilot study participation
    @Published var consentGranted: Bool {
        didSet {
            defaults.set(consentGranted, forKey: Keys.consentGranted)
            if consentGranted && consentDate == nil {
                consentDate = Date()
            }
        }
    }

    /// Date when consent was granted
    @Published var consentDate: Date? {
        didSet {
            if let date = consentDate {
                defaults.set(date, forKey: Keys.consentDate)
            } else {
                defaults.removeObject(forKey: Keys.consentDate)
            }
        }
    }

    /// Participant's trial ID (generated on consent)
    @Published var participantTrialId: String? {
        didSet {
            if let id = participantTrialId {
                defaults.set(id, forKey: Keys.participantTrialId)
            } else {
                defaults.removeObject(forKey: Keys.participantTrialId)
            }
        }
    }

    /// Whether data collection is enabled
    @Published var dataCollectionEnabled: Bool {
        didSet { defaults.set(dataCollectionEnabled, forKey: Keys.dataCollectionEnabled) }
    }

    /// Whether automatic export is enabled
    @Published var autoExportEnabled: Bool {
        didSet { defaults.set(autoExportEnabled, forKey: Keys.autoExportEnabled) }
    }

    /// Batch size for exports
    @Published var exportBatchSize: Int {
        didSet { defaults.set(exportBatchSize, forKey: Keys.exportBatchSize) }
    }

    /// Last export date
    @Published var lastExportDate: Date? {
        didSet {
            if let date = lastExportDate {
                defaults.set(date, forKey: Keys.lastExportDate)
            } else {
                defaults.removeObject(forKey: Keys.lastExportDate)
            }
        }
    }

    init() {
        self.consentGranted = defaults.bool(forKey: Keys.consentGranted)
        self.consentDate = defaults.object(forKey: Keys.consentDate) as? Date
        self.participantTrialId = defaults.string(forKey: Keys.participantTrialId)
        self.dataCollectionEnabled = defaults.object(forKey: Keys.dataCollectionEnabled) as? Bool ?? true
        self.autoExportEnabled = defaults.bool(forKey: Keys.autoExportEnabled)
        self.exportBatchSize = defaults.object(forKey: Keys.exportBatchSize) as? Int ?? 1000
        self.lastExportDate = defaults.object(forKey: Keys.lastExportDate) as? Date
    }

    /// Grant consent and generate trial ID
    func grantConsent() {
        consentGranted = true
        consentDate = Date()
        participantTrialId = generateTrialId()
        dataCollectionEnabled = true
        Logger.shared.info("[PilotStudySettings] Consent granted, trial ID: \(participantTrialId ?? "none")")
    }

    /// Revoke consent and clear data
    func revokeConsent() {
        consentGranted = false
        consentDate = nil
        participantTrialId = nil
        dataCollectionEnabled = false
        Logger.shared.info("[PilotStudySettings] Consent revoked")
    }

    private func generateTrialId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 10000...99999)
        return "ORALABLE-\(timestamp)-\(random)"
    }
}

// MARK: - Pilot Data Manager

/// Manages aggregation and batch export of anonymized pilot study data
class PilotDataManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PilotDataManager()

    // MARK: - Dependencies

    private let logger: PilotLogger
    private let anonymizer: Anonymizer
    private let settings: PilotStudySettings
    private let fileManager = FileManager.default

    // MARK: - Properties

    @Published private(set) var anonymizedEvents: [AnonymizedEvent] = []
    @Published private(set) var anonymizedSensorData: [AnonymizedSensorData] = []
    @Published private(set) var isExporting: Bool = false
    @Published private(set) var lastExportResult: BatchExportResult?

    private let encoder: JSONEncoder
    private var cancellables = Set<AnyCancellable>()

    /// Maximum batch size for exports
    let maxBatchSize = 10000

    // MARK: - Initialization

    init(
        logger: PilotLogger = .shared,
        anonymizer: Anonymizer = .shared,
        settings: PilotStudySettings = .shared
    ) {
        self.logger = logger
        self.anonymizer = anonymizer
        self.settings = settings

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        setupObservers()
    }

    private func setupObservers() {
        // Auto-export when batch size is reached
        $anonymizedEvents
            .filter { [weak self] events in
                guard let self = self,
                      self.settings.autoExportEnabled,
                      self.settings.consentGranted else { return false }
                return events.count >= self.settings.exportBatchSize
            }
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    try? await self?.exportBatch()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Consent Verification

    /// Check if data collection is allowed
    var canCollectData: Bool {
        return settings.consentGranted && settings.dataCollectionEnabled
    }

    /// Verify consent before performing operation
    func verifyConsent() throws {
        guard settings.consentGranted else {
            throw PilotDataError.consentNotGranted
        }
    }

    // MARK: - Data Aggregation

    /// Aggregate events from the pilot logger
    func aggregateEvents() throws {
        try verifyConsent()

        let events = logger.events
        guard !events.isEmpty else {
            Logger.shared.debug("[PilotDataManager] No events to aggregate")
            return
        }

        let anonymized = anonymizer.anonymize(events)
        anonymizedEvents.append(contentsOf: anonymized)

        Logger.shared.info("[PilotDataManager] Aggregated \(anonymized.count) events")
    }

    /// Aggregate events from a specific time range
    func aggregateEvents(from startDate: Date, to endDate: Date) throws {
        try verifyConsent()

        guard startDate < endDate else {
            throw PilotDataError.invalidDateRange
        }

        let events = logger.events(from: startDate, to: endDate)
        guard !events.isEmpty else {
            throw PilotDataError.noDataToExport
        }

        let anonymized = anonymizer.anonymize(events)
        anonymizedEvents.append(contentsOf: anonymized)

        Logger.shared.info("[PilotDataManager] Aggregated \(anonymized.count) events from date range")
    }

    /// Aggregate sensor data
    func aggregateSensorData(_ data: [SensorData], deviceId: String, userId: String?) throws {
        try verifyConsent()

        guard !data.isEmpty else { return }

        let anonymized = data.map { sensorData in
            anonymizer.anonymizeSensorData(sensorData, deviceId: deviceId, userId: userId)
        }

        anonymizedSensorData.append(contentsOf: anonymized)

        Logger.shared.info("[PilotDataManager] Aggregated \(anonymized.count) sensor data points")
    }

    // MARK: - Batch Export

    /// Export current batch of anonymized data
    @MainActor
    func exportBatch(format: PilotExportFormat = .json) async throws -> BatchExportResult {
        try verifyConsent()

        guard !anonymizedEvents.isEmpty || !anonymizedSensorData.isEmpty else {
            throw PilotDataError.noDataToExport
        }

        isExporting = true
        defer { isExporting = false }

        let exportId = generateExportId()
        var fileURLs: [URL] = []

        do {
            let exportDir = try getExportDirectory()

            // Export events
            if !anonymizedEvents.isEmpty {
                let eventsURL = try exportEvents(to: exportDir, exportId: exportId, format: format)
                fileURLs.append(eventsURL)
            }

            // Export sensor data
            if !anonymizedSensorData.isEmpty {
                let sensorURL = try exportSensorData(to: exportDir, exportId: exportId, format: format)
                fileURLs.append(sensorURL)
            }

            // Export metadata
            let metadataURL = try exportMetadata(to: exportDir, exportId: exportId)
            fileURLs.append(metadataURL)

            // Create result
            let result = BatchExportResult(
                exportId: exportId,
                timestamp: Date(),
                eventCount: anonymizedEvents.count,
                sensorDataCount: anonymizedSensorData.count,
                fileURLs: fileURLs.map { $0.path },
                format: format.rawValue,
                success: true,
                errorMessage: nil
            )

            lastExportResult = result
            settings.lastExportDate = Date()

            // Clear exported data
            clearAggregatedData()

            Logger.shared.info("[PilotDataManager] Batch export completed: \(exportId)")

            return result

        } catch {
            let result = BatchExportResult(
                exportId: exportId,
                timestamp: Date(),
                eventCount: anonymizedEvents.count,
                sensorDataCount: anonymizedSensorData.count,
                fileURLs: [],
                format: format.rawValue,
                success: false,
                errorMessage: error.localizedDescription
            )

            lastExportResult = result
            Logger.shared.error("[PilotDataManager] Batch export failed: \(error)")

            throw error
        }
    }

    /// Export events to a file
    private func exportEvents(to directory: URL, exportId: String, format: PilotExportFormat) throws -> URL {
        let filename = "pilot_events_\(exportId).\(format.fileExtension)"
        let fileURL = directory.appendingPathComponent(filename)

        switch format {
        case .json:
            let data = try encoder.encode(anonymizedEvents)
            try writeData(data, to: fileURL)
        case .csv:
            var csv = "ID,EventType,Category,Timestamp,TrialID,ParticipantID,Severity,Metadata,NumericData\n"
            for event in anonymizedEvents {
                csv += event.csvRow + "\n"
            }
            try writeString(csv, to: fileURL)
        }

        return fileURL
    }

    /// Export sensor data to a file
    private func exportSensorData(to directory: URL, exportId: String, format: PilotExportFormat) throws -> URL {
        let filename = "pilot_sensor_data_\(exportId).\(format.fileExtension)"
        let fileURL = directory.appendingPathComponent(filename)

        switch format {
        case .json:
            let data = try encoder.encode(anonymizedSensorData)
            try writeData(data, to: fileURL)
        case .csv:
            var csv = "Timestamp,ParticipantID,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate,SpO2\n"
            for sensorData in anonymizedSensorData {
                csv += sensorData.csvRow + "\n"
            }
            try writeString(csv, to: fileURL)
        }

        return fileURL
    }

    /// Export metadata file
    private func exportMetadata(to directory: URL, exportId: String) throws -> URL {
        let filename = "pilot_metadata_\(exportId).json"
        let fileURL = directory.appendingPathComponent(filename)

        let metadata = ExportMetadata(
            exportId: exportId,
            exportDate: Date(),
            eventCount: anonymizedEvents.count,
            sensorDataCount: anonymizedSensorData.count,
            studyPrefix: anonymizer.currentConfig.studyPrefix,
            anonymizationConfig: anonymizer.currentConfig,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        )

        let data = try encoder.encode(metadata)
        try writeData(data, to: fileURL)

        return fileURL
    }

    // MARK: - File Operations

    private func getExportDirectory() throws -> URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let exportDir = cacheDir.appendingPathComponent("PilotExports", isDirectory: true)

        if !fileManager.fileExists(atPath: exportDir.path) {
            do {
                try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
            } catch {
                throw PilotDataError.exportDirectoryUnavailable
            }
        }

        return exportDir
    }

    private func writeData(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url)
        } catch let error as NSError {
            if error.code == NSFileWriteNoPermissionError {
                throw PilotDataError.writePermissionDenied
            }
            throw PilotDataError.fileWriteFailed(underlying: error)
        }
    }

    private func writeString(_ string: String, to url: URL) throws {
        do {
            try string.write(to: url, atomically: true, encoding: .utf8)
        } catch let error as NSError {
            if error.code == NSFileWriteNoPermissionError {
                throw PilotDataError.writePermissionDenied
            }
            throw PilotDataError.fileWriteFailed(underlying: error)
        }
    }

    // MARK: - Data Management

    /// Clear all aggregated data
    func clearAggregatedData() {
        anonymizedEvents.removeAll()
        anonymizedSensorData.removeAll()
        Logger.shared.info("[PilotDataManager] Cleared aggregated data")
    }

    /// Get statistics about current aggregated data
    var aggregationStatistics: AggregationStatistics {
        let eventsByCategory = Dictionary(grouping: anonymizedEvents) { $0.category }
        let eventsBySeverity = Dictionary(grouping: anonymizedEvents) { $0.severity }

        return AggregationStatistics(
            totalEvents: anonymizedEvents.count,
            totalSensorDataPoints: anonymizedSensorData.count,
            eventsByCategory: eventsByCategory.mapValues { $0.count },
            eventsBySeverity: eventsBySeverity.mapValues { $0.count },
            oldestEvent: anonymizedEvents.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
            newestEvent: anonymizedEvents.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        )
    }

    /// Get list of previous exports
    func getPreviousExports() -> [URL] {
        guard let exportDir = try? getExportDirectory() else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: exportDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            return contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            Logger.shared.error("[PilotDataManager] Failed to list exports: \(error)")
            return []
        }
    }

    /// Delete old exports older than specified days
    func deleteOldExports(olderThan days: Int) {
        guard let exportDir = try? getExportDirectory() else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: exportDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for url in contents {
                if let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: url)
                    Logger.shared.debug("[PilotDataManager] Deleted old export: \(url.lastPathComponent)")
                }
            }
        } catch {
            Logger.shared.error("[PilotDataManager] Failed to delete old exports: \(error)")
        }
    }

    // MARK: - Helpers

    private func generateExportId() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        return "EXPORT-\(dateFormatter.string(from: Date()))"
    }
}

// MARK: - Supporting Types

/// Statistics about aggregated data
struct AggregationStatistics {
    let totalEvents: Int
    let totalSensorDataPoints: Int
    let eventsByCategory: [PilotEventCategory: Int]
    let eventsBySeverity: [PilotEventSeverity: Int]
    let oldestEvent: Date?
    let newestEvent: Date?

    var timeRange: String {
        guard let oldest = oldestEvent, let newest = newestEvent else {
            return "No events"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: oldest)) - \(formatter.string(from: newest))"
    }
}

/// Metadata for an export batch
struct ExportMetadata: Codable {
    let exportId: String
    let exportDate: Date
    let eventCount: Int
    let sensorDataCount: Int
    let studyPrefix: String
    let anonymizationConfig: AnonymizationConfig
    let appVersion: String
    let buildNumber: String
}
