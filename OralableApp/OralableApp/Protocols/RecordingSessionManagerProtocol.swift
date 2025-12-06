//
//  RecordingSessionManagerProtocol.swift
//  OralableApp
//
//  Created: Refactoring Phase 2
//  Purpose: Protocol abstraction for RecordingSessionManager to enable dependency injection and testing
//

import Foundation
import Combine

/// Protocol defining the recording session manager interface
/// Enables dependency injection, mocking, and testing
@MainActor
protocol RecordingSessionManagerProtocol: AnyObject {
    // MARK: - Session State
    var currentSession: RecordingSession? { get }
    var sessions: [RecordingSession] { get }

    // MARK: - Session Management
    func startSession(deviceID: String?, deviceName: String?, deviceType: DeviceType?) throws -> RecordingSession
    func stopSession() throws
    func pauseSession() throws
    func resumeSession() throws

    // MARK: - Data Recording
    func recordSensorData(_ data: String)

    // MARK: - Session Management
    func deleteSession(_ session: RecordingSession)

    // MARK: - Publishers for Reactive UI
    var currentSessionPublisher: Published<RecordingSession?>.Publisher { get }
    var sessionsPublisher: Published<[RecordingSession]>.Publisher { get }
}

// MARK: - RecordingSessionManager Conformance

extension RecordingSessionManager: RecordingSessionManagerProtocol {
    var currentSessionPublisher: Published<RecordingSession?>.Publisher { $currentSession }
    var sessionsPublisher: Published<[RecordingSession]>.Publisher { $sessions }
}
