//
//  RecordingSession.swift
//  OralableApp
//
//  Created: November 11, 2025
//  Purpose: Model for tracking data recording sessions
//

import Foundation

/// Represents a single data recording session
struct RecordingSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }

    var status: RecordingStatus
    var deviceID: String?
    var deviceName: String?

    // Counts of collected data
    var sensorDataCount: Int = 0
    var ppgDataCount: Int = 0
    var heartRateDataCount: Int = 0
    var spo2DataCount: Int = 0

    // File path where session data is stored
    var dataFilePath: URL?

    // Metadata
    var notes: String?
    var tags: [String] = []

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        status: RecordingStatus = .recording,
        deviceID: String? = nil,
        deviceName: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.status = status
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    /// Format duration as HH:MM:SS
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

/// Recording session status
enum RecordingStatus: String, Codable {
    case recording = "Recording"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"

    var icon: String {
        switch self {
        case .recording: return "record.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

/// Manages recording sessions
@MainActor
class RecordingSessionManager: ObservableObject {
    static let shared = RecordingSessionManager()

    @Published var currentSession: RecordingSession?
    @Published var sessions: [RecordingSession] = []

    private let fileManager = FileManager.default
    private var sessionDataBuffer: [String] = []
    private let maxBufferSize = 100

    private init() {
        loadSessions()
    }

    // MARK: - Session Management

    /// Start a new recording session
    func startSession(deviceID: String?, deviceName: String?) throws -> RecordingSession {
        // Check if a session is already in progress
        guard currentSession == nil else {
            throw DeviceError.recordingAlreadyInProgress
        }

        let session = RecordingSession(
            deviceID: deviceID,
            deviceName: deviceName
        )

        currentSession = session
        sessions.insert(session, at: 0)

        // Create data file for this session
        if let filePath = createSessionDataFile(for: session) {
            currentSession?.dataFilePath = filePath
        }

        Logger.shared.debug(" [RecordingSessionManager] Started session: \(session.id)")
        saveSessions()

        return session
    }

    /// Stop the current recording session
    func stopSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }

        session.endTime = Date()
        session.status = .completed

        // Flush any remaining buffered data
        flushDataBuffer()

        // Update in array
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        currentSession = nil
        Logger.shared.info(" [RecordingSessionManager] Stopped session: \(session.id) - Duration: \(session.formattedDuration)")
        saveSessions()
    }

    /// Pause the current recording session
    func pauseSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }

        session.status = .paused
        flushDataBuffer()

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        Logger.shared.info("⏸️ [RecordingSessionManager] Paused session: \(session.id)")
        saveSessions()
    }

    /// Resume the current recording session
    func resumeSession() throws {
        guard var session = currentSession else {
            throw DeviceError.recordingNotInProgress
        }

        session.status = .recording

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        Logger.shared.info("▶️ [RecordingSessionManager] Resumed session: \(session.id)")
        saveSessions()
    }

    // MARK: - Data Recording

    /// Record sensor data to the current session
    func recordSensorData(_ data: String) {
        guard currentSession != nil, currentSession?.status == .recording else {
            return
        }

        sessionDataBuffer.append(data)
        currentSession?.sensorDataCount += 1

        // Flush buffer if it gets too large
        if sessionDataBuffer.count >= maxBufferSize {
            flushDataBuffer()
        }

        // Update session in array
        if let session = currentSession,
           let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    /// Flush buffered data to file
    private func flushDataBuffer() {
        guard let session = currentSession,
              let filePath = session.dataFilePath,
              !sessionDataBuffer.isEmpty else {
            return
        }

        do {
            let dataString = sessionDataBuffer.joined(separator: "\n") + "\n"
            if let fileHandle = try? FileHandle(forWritingTo: filePath) {
                fileHandle.seekToEndOfFile()
                if let data = dataString.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // File doesn't exist, create it
                try dataString.write(to: filePath, atomically: true, encoding: .utf8)
            }

            sessionDataBuffer.removeAll()
            Logger.shared.debug("💾 [RecordingSessionManager] Flushed data buffer to file")
        } catch {
            Logger.shared.error(" [RecordingSessionManager] Failed to flush data: \(error)")
        }
    }

    // MARK: - File Management

    /// Create a data file for the recording session
    private func createSessionDataFile(for session: RecordingSession) -> URL? {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sessionsFolder = documentsPath.appendingPathComponent("RecordingSessions", isDirectory: true)

        // Create sessions folder if it doesn't exist
        if !fileManager.fileExists(atPath: sessionsFolder.path) {
            try? fileManager.createDirectory(at: sessionsFolder, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: session.startTime)
        let fileName = "session_\(dateString)_\(session.id.uuidString.prefix(8)).csv"
        let filePath = sessionsFolder.appendingPathComponent(fileName)

        // Create file with header
        let header = "timestamp,deviceID,sensorType,value,quality\n"
        try? header.write(to: filePath, atomically: true, encoding: .utf8)

        Logger.shared.info("📁 [RecordingSessionManager] Created session file: \(fileName)")
        return filePath
    }

    /// Delete a recording session and its data file
    func deleteSession(_ session: RecordingSession) {
        // Delete data file if it exists
        if let filePath = session.dataFilePath {
            try? fileManager.removeItem(at: filePath)
        }

        // Remove from array
        sessions.removeAll { $0.id == session.id }
        saveSessions()

        Logger.shared.info("🗑️ [RecordingSessionManager] Deleted session: \(session.id)")
    }

    // MARK: - Persistence

    private var sessionsFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("recording_sessions.json")
    }

    /// Save sessions metadata to disk
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL)
            Logger.shared.debug("💾 [RecordingSessionManager] Saved \(sessions.count) sessions")
        } catch {
            Logger.shared.error(" [RecordingSessionManager] Failed to save sessions: \(error)")
        }
    }

    /// Load sessions metadata from disk
    private func loadSessions() {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: sessionsFileURL)
            sessions = try JSONDecoder().decode([RecordingSession].self, from: data)
            Logger.shared.debug("📂 [RecordingSessionManager] Loaded \(sessions.count) sessions")
        } catch {
            Logger.shared.error(" [RecordingSessionManager] Failed to load sessions: \(error)")
        }
    }
}
