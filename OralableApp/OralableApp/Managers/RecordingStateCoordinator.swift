//
//  RecordingStateCoordinator.swift
//  OralableApp
//
//  Created: November 29, 2025
//  Purpose: Single source of truth for recording state across the app
//  Eliminates duplicate isRecording state in multiple places
//  Updated: December 9, 2025 - Added auto-sync to CloudKit when recording stops
//  Updated: December 9, 2025 - Added 10-hour maximum session limit with auto-stop
//

import Foundation
import Combine

/// Single source of truth for recording state
/// Prevents state duplication between DashboardViewModel, DeviceManagerAdapter, and RecordingSessionManager
@MainActor
final class RecordingStateCoordinator: ObservableObject {
    static let shared = RecordingStateCoordinator()

    // MARK: - Constants

    /// Maximum recording duration (10 hours in seconds)
    /// Sessions auto-stop after this duration to prevent runaway recordings
    static let maxRecordingDuration: TimeInterval = 10 * 60 * 60  // 10 hours = 36000 seconds

    // MARK: - Published State
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var wasAutoStopped: Bool = false  // True if last stop was due to 10hr limit

    // MARK: - Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    // MARK: - Dependencies
    /// Reference to SharedDataManager for auto-sync after recording
    /// Set by AppDependencies during initialization
    weak var sharedDataManager: SharedDataManager?

    // MARK: - Private
    private var durationTimer: Timer?
    private var maxDurationTimer: Timer?

    private init() {
        Logger.shared.info("[RecordingStateCoordinator] Initialized with \(Self.maxRecordingDuration / 3600)hr max duration")
    }

    // MARK: - Public Methods

    func startRecording() {
        guard !isRecording else {
            Logger.shared.warning("[RecordingStateCoordinator] Already recording - ignoring start request")
            return
        }

        wasAutoStopped = false
        isRecording = true
        sessionStartTime = Date()
        sessionDuration = 0
        startDurationTimer()
        startMaxDurationTimer()

        Logger.shared.info("[RecordingStateCoordinator] ▶️ Recording started (max \(Self.maxRecordingDuration / 3600)hr limit)")
    }

    func stopRecording() {
        guard isRecording else {
            Logger.shared.warning("[RecordingStateCoordinator] Not recording - ignoring stop request")
            return
        }

        stopDurationTimer()
        stopMaxDurationTimer()
        isRecording = false

        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
            let stopReason = wasAutoStopped ? "auto-stopped (10hr limit)" : "manual stop"
            Logger.shared.info("[RecordingStateCoordinator] ⏹️ Recording stopped (\(stopReason)). Duration: \(String(format: "%.1f", sessionDuration))s")
        }

        sessionStartTime = nil

        // Auto-sync data to CloudKit after recording stops
        // This ensures professionals can always see the most recent session
        // Works for both manual stop and 10-hour auto-stop
        syncDataToCloudKit()
    }

    /// Called when the 10-hour maximum duration is reached
    private func autoStopDueToMaxDuration() {
        guard isRecording else { return }

        wasAutoStopped = true
        Logger.shared.warning("[RecordingStateCoordinator] ⚠️ Maximum recording duration (10 hours) reached - auto-stopping")
        stopRecording()
    }

    /// Sync sensor data to CloudKit for professional access
    private func syncDataToCloudKit() {
        guard let dataManager = sharedDataManager else {
            Logger.shared.warning("[RecordingStateCoordinator] SharedDataManager not set - skipping auto-sync")
            return
        }

        Task {
            Logger.shared.info("[RecordingStateCoordinator] 🔄 Auto-syncing data to CloudKit after recording...")
            await dataManager.uploadCurrentDataForSharing()
            Logger.shared.info("[RecordingStateCoordinator] ✅ Auto-sync complete")
        }
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

    private func startMaxDurationTimer() {
        // Schedule auto-stop after maximum duration (10 hours)
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.autoStopDueToMaxDuration()
            }
        }
    }

    private func stopMaxDurationTimer() {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
    }

    private func updateDuration() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Cleanup

    deinit {
        durationTimer?.invalidate()
        maxDurationTimer?.invalidate()
    }
}
