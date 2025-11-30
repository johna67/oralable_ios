//
//  RecordingStateCoordinator.swift
//  OralableApp
//
//  Created: November 29, 2025
//  Purpose: Single source of truth for recording state across the app
//  Eliminates duplicate isRecording state in multiple places
//

import Foundation
import Combine

/// Single source of truth for recording state
/// Prevents state duplication between DashboardViewModel, DeviceManagerAdapter, and RecordingSessionManager
@MainActor
final class RecordingStateCoordinator: ObservableObject {
    static let shared = RecordingStateCoordinator()

    // MARK: - Published State
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionDuration: TimeInterval = 0

    // MARK: - Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    // MARK: - Private
    private var durationTimer: Timer?

    private init() {
        Logger.shared.info("[RecordingStateCoordinator] Initialized as single source of truth")
    }

    // MARK: - Public Methods

    func startRecording() {
        guard !isRecording else {
            Logger.shared.warning("[RecordingStateCoordinator] Already recording - ignoring start request")
            return
        }

        isRecording = true
        sessionStartTime = Date()
        sessionDuration = 0
        startDurationTimer()

        Logger.shared.info("[RecordingStateCoordinator] ▶️ Recording started")
    }

    func stopRecording() {
        guard isRecording else {
            Logger.shared.warning("[RecordingStateCoordinator] Not recording - ignoring stop request")
            return
        }

        stopDurationTimer()
        isRecording = false

        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
            Logger.shared.info("[RecordingStateCoordinator] ⏹️ Recording stopped. Duration: \(String(format: "%.1f", sessionDuration))s")
        }

        sessionStartTime = nil
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Private Methods

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateDuration() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Cleanup

    deinit {
        durationTimer?.invalidate()
    }
}
