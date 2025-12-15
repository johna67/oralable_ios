//
//  BLEBackgroundWorker.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Dedicated worker for background BLE tasks including reconnection,
//  RSSI polling, and connection health monitoring
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Background Worker Configuration

/// Configuration for BLEBackgroundWorker behavior
struct BLEBackgroundWorkerConfig {
    /// Maximum number of reconnection attempts before giving up
    var maxReconnectionAttempts: Int = 3

    /// Base delay for exponential backoff (in seconds)
    var baseReconnectionDelay: TimeInterval = 2.0

    /// Maximum reconnection delay cap (in seconds)
    var maxReconnectionDelay: TimeInterval = 30.0

    /// Interval for RSSI polling (in seconds)
    var rssiPollingInterval: TimeInterval = 5.0

    /// Interval for connection health checks (in seconds)
    var healthCheckInterval: TimeInterval = 10.0

    /// Timeout for considering a connection stale (in seconds)
    var connectionStaleTimeout: TimeInterval = 30.0

    /// Whether to auto-reconnect on unexpected disconnection
    var autoReconnectEnabled: Bool = true

    /// Default configuration
    static let `default` = BLEBackgroundWorkerConfig()

    /// Aggressive reconnection configuration
    static let aggressive = BLEBackgroundWorkerConfig(
        maxReconnectionAttempts: 5,
        baseReconnectionDelay: 1.0,
        maxReconnectionDelay: 15.0
    )

    /// Conservative configuration (battery saving)
    static let conservative = BLEBackgroundWorkerConfig(
        maxReconnectionAttempts: 2,
        baseReconnectionDelay: 5.0,
        rssiPollingInterval: 15.0,
        healthCheckInterval: 30.0
    )
}

// MARK: - Background Worker Events

/// Events emitted by the background worker
enum BLEBackgroundWorkerEvent {
    case reconnectionAttemptStarted(peripheralId: UUID, attempt: Int, maxAttempts: Int)
    case reconnectionSucceeded(peripheralId: UUID)
    case reconnectionFailed(peripheralId: UUID, error: Error?)
    case reconnectionGaveUp(peripheralId: UUID, totalAttempts: Int)
    case rssiUpdated(peripheralId: UUID, rssi: Int)
    case connectionHealthWarning(peripheralId: UUID, reason: String)
    case connectionStale(peripheralId: UUID)
    case workerStarted
    case workerStopped
}

// MARK: - Reconnection State

/// State tracking for a single device's reconnection
private struct ReconnectionState {
    let peripheralId: UUID
    var attemptCount: Int = 0
    var lastAttemptTime: Date?
    var task: Task<Void, Never>?
    var isActive: Bool = false

    mutating func incrementAttempt() {
        attemptCount += 1
        lastAttemptTime = Date()
    }

    mutating func reset() {
        attemptCount = 0
        lastAttemptTime = nil
        task?.cancel()
        task = nil
        isActive = false
    }
}

// MARK: - BLE Background Worker

/// Dedicated worker for handling background BLE tasks
/// Manages reconnection with exponential backoff, RSSI polling, and connection health monitoring
@MainActor
final class BLEBackgroundWorker: ObservableObject {

    // MARK: - Published State

    /// Whether the worker is currently running
    @Published private(set) var isRunning: Bool = false

    /// Active reconnection states by peripheral ID
    @Published private(set) var activeReconnections: Set<UUID> = []

    /// Latest RSSI values by peripheral ID
    @Published private(set) var rssiValues: [UUID: Int] = [:]

    /// Connection health status by peripheral ID
    @Published private(set) var connectionHealth: [UUID: ConnectionHealthStatus] = [:]

    // MARK: - Event Publisher

    /// Publisher for background worker events
    var eventPublisher: AnyPublisher<BLEBackgroundWorkerEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    private weak var bleService: BLEService?
    private let config: BLEBackgroundWorkerConfig

    // MARK: - Internal State

    private var reconnectionStates: [UUID: ReconnectionState] = [:]
    private var rssiPollingTask: Task<Void, Never>?
    private var healthCheckTask: Task<Void, Never>?
    private var lastDataReceived: [UUID: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let eventSubject = PassthroughSubject<BLEBackgroundWorkerEvent, Never>()

    // MARK: - Async Streams

    /// Async stream for reconnection events
    var reconnectionEvents: AsyncStream<BLEBackgroundWorkerEvent> {
        AsyncStream { continuation in
            let cancellable = eventPublisher
                .filter { event in
                    switch event {
                    case .reconnectionAttemptStarted, .reconnectionSucceeded,
                         .reconnectionFailed, .reconnectionGaveUp:
                        return true
                    default:
                        return false
                    }
                }
                .sink { event in
                    continuation.yield(event)
                }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Async stream for RSSI updates
    var rssiUpdates: AsyncStream<(UUID, Int)> {
        AsyncStream { continuation in
            let cancellable = eventPublisher
                .compactMap { event -> (UUID, Int)? in
                    if case .rssiUpdated(let id, let rssi) = event {
                        return (id, rssi)
                    }
                    return nil
                }
                .sink { value in
                    continuation.yield(value)
                }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    // MARK: - Initialization

    init(bleService: BLEService? = nil, config: BLEBackgroundWorkerConfig = .default) {
        self.bleService = bleService
        self.config = config
        Logger.shared.info("[BLEBackgroundWorker] Initialized with config: maxAttempts=\(config.maxReconnectionAttempts), baseDelay=\(config.baseReconnectionDelay)s")
    }

    /// Configure the BLE service (for dependency injection)
    func configure(bleService: BLEService) {
        self.bleService = bleService
        setupEventSubscription()
    }

    // MARK: - Lifecycle

    /// Start the background worker
    func start() {
        guard !isRunning else {
            Logger.shared.debug("[BLEBackgroundWorker] Already running, ignoring start request")
            return
        }

        Logger.shared.info("[BLEBackgroundWorker] Starting...")
        isRunning = true
        setupEventSubscription()
        startHealthCheckLoop()
        eventSubject.send(.workerStarted)
    }

    /// Stop the background worker
    func stop() {
        guard isRunning else { return }

        Logger.shared.info("[BLEBackgroundWorker] Stopping...")
        isRunning = false

        // Cancel all reconnection tasks
        for (_, state) in reconnectionStates {
            state.task?.cancel()
        }
        reconnectionStates.removeAll()
        activeReconnections.removeAll()

        // Cancel polling tasks
        rssiPollingTask?.cancel()
        rssiPollingTask = nil
        healthCheckTask?.cancel()
        healthCheckTask = nil

        // Clear subscriptions
        cancellables.removeAll()

        eventSubject.send(.workerStopped)
    }

    // MARK: - Reconnection Management

    /// Schedule a reconnection attempt for a peripheral
    /// - Parameters:
    ///   - peripheralId: The peripheral identifier
    ///   - peripheral: The CBPeripheral to reconnect to
    ///   - immediate: Whether to attempt immediately (skip initial delay)
    func scheduleReconnection(for peripheralId: UUID, peripheral: CBPeripheral, immediate: Bool = false) {
        guard config.autoReconnectEnabled else {
            Logger.shared.debug("[BLEBackgroundWorker] Auto-reconnect disabled, skipping")
            return
        }

        guard isRunning else {
            Logger.shared.warning("[BLEBackgroundWorker] Worker not running, cannot schedule reconnection")
            return
        }

        // Check if already reconnecting
        if reconnectionStates[peripheralId]?.isActive == true {
            Logger.shared.debug("[BLEBackgroundWorker] Already reconnecting to \(peripheralId)")
            return
        }

        // Initialize or get existing state
        var state = reconnectionStates[peripheralId] ?? ReconnectionState(peripheralId: peripheralId)

        // Check max attempts
        guard state.attemptCount < config.maxReconnectionAttempts else {
            Logger.shared.warning("[BLEBackgroundWorker] Max reconnection attempts reached for \(peripheralId)")
            eventSubject.send(.reconnectionGaveUp(peripheralId: peripheralId, totalAttempts: state.attemptCount))
            reconnectionStates[peripheralId]?.reset()
            activeReconnections.remove(peripheralId)
            return
        }

        state.isActive = true
        state.incrementAttempt()
        activeReconnections.insert(peripheralId)

        // Calculate delay with exponential backoff
        let delay: TimeInterval
        if immediate && state.attemptCount == 1 {
            delay = 0
        } else {
            let exponentialDelay = config.baseReconnectionDelay * pow(2.0, Double(state.attemptCount - 1))
            delay = min(exponentialDelay, config.maxReconnectionDelay)
        }

        Logger.shared.info("[BLEBackgroundWorker] Scheduling reconnection #\(state.attemptCount) for \(peripheralId) in \(String(format: "%.1f", delay))s")

        eventSubject.send(.reconnectionAttemptStarted(
            peripheralId: peripheralId,
            attempt: state.attemptCount,
            maxAttempts: config.maxReconnectionAttempts
        ))

        // Create reconnection task
        let currentAttempt = state.attemptCount
        state.task = Task { [weak self] in
            guard let self = self else { return }

            // Wait for delay
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    // Task was cancelled
                    return
                }
            }

            // Check if still active
            guard !Task.isCancelled, self.isRunning else { return }

            Logger.shared.info("[BLEBackgroundWorker] Attempting reconnection #\(currentAttempt) to \(peripheralId)")

            // Attempt connection
            self.bleService?.connect(to: peripheral)

            // Note: Success/failure will be handled via BLE service events
        }

        reconnectionStates[peripheralId] = state
    }

    /// Cancel reconnection attempts for a peripheral
    func cancelReconnection(for peripheralId: UUID) {
        guard var state = reconnectionStates[peripheralId] else { return }

        Logger.shared.info("[BLEBackgroundWorker] Cancelling reconnection for \(peripheralId)")
        state.reset()
        reconnectionStates[peripheralId] = state
        activeReconnections.remove(peripheralId)
    }

    /// Cancel all ongoing reconnection attempts
    func cancelAllReconnections() {
        Logger.shared.info("[BLEBackgroundWorker] Cancelling all reconnections")
        for peripheralId in reconnectionStates.keys {
            reconnectionStates[peripheralId]?.reset()
        }
        reconnectionStates.removeAll()
        activeReconnections.removeAll()
    }

    /// Handle successful connection (resets reconnection state)
    func handleConnectionSuccess(for peripheralId: UUID) {
        if reconnectionStates[peripheralId]?.isActive == true {
            Logger.shared.info("[BLEBackgroundWorker] Reconnection succeeded for \(peripheralId)")
            eventSubject.send(.reconnectionSucceeded(peripheralId: peripheralId))
        }
        reconnectionStates[peripheralId]?.reset()
        activeReconnections.remove(peripheralId)
        lastDataReceived[peripheralId] = Date()
        connectionHealth[peripheralId] = .healthy
    }

    /// Handle disconnection (may trigger reconnection)
    func handleDisconnection(for peripheralId: UUID, peripheral: CBPeripheral, wasUnexpected: Bool) {
        connectionHealth[peripheralId] = .disconnected
        lastDataReceived.removeValue(forKey: peripheralId)

        if wasUnexpected && config.autoReconnectEnabled {
            scheduleReconnection(for: peripheralId, peripheral: peripheral, immediate: true)
        } else {
            reconnectionStates[peripheralId]?.reset()
            activeReconnections.remove(peripheralId)
        }
    }

    // MARK: - RSSI Polling

    /// Start RSSI polling for connected peripherals
    func startRSSIPolling(for peripherals: [CBPeripheral]) {
        rssiPollingTask?.cancel()

        guard !peripherals.isEmpty else { return }

        rssiPollingTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled && self.isRunning {
                for peripheral in peripherals where peripheral.state == .connected {
                    peripheral.readRSSI()
                }

                do {
                    try await Task.sleep(nanoseconds: UInt64(self.config.rssiPollingInterval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    /// Stop RSSI polling
    func stopRSSIPolling() {
        rssiPollingTask?.cancel()
        rssiPollingTask = nil
    }

    /// Update RSSI value for a peripheral
    func updateRSSI(for peripheralId: UUID, rssi: Int) {
        rssiValues[peripheralId] = rssi
        eventSubject.send(.rssiUpdated(peripheralId: peripheralId, rssi: rssi))
    }

    // MARK: - Connection Health Monitoring

    /// Record that data was received from a peripheral
    func recordDataReceived(from peripheralId: UUID) {
        lastDataReceived[peripheralId] = Date()
        if connectionHealth[peripheralId] != .healthy {
            connectionHealth[peripheralId] = .healthy
        }
    }

    /// Start the health check loop
    private func startHealthCheckLoop() {
        healthCheckTask?.cancel()

        healthCheckTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled && self.isRunning {
                await self.performHealthCheck()

                do {
                    try await Task.sleep(nanoseconds: UInt64(self.config.healthCheckInterval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    /// Perform a health check on all tracked connections
    private func performHealthCheck() {
        let now = Date()

        for (peripheralId, lastReceived) in lastDataReceived {
            let elapsed = now.timeIntervalSince(lastReceived)

            if elapsed > config.connectionStaleTimeout {
                if connectionHealth[peripheralId] != .stale {
                    connectionHealth[peripheralId] = .stale
                    eventSubject.send(.connectionStale(peripheralId: peripheralId))
                    Logger.shared.warning("[BLEBackgroundWorker] Connection stale for \(peripheralId) - no data for \(Int(elapsed))s")
                }
            } else if elapsed > config.connectionStaleTimeout / 2 {
                if connectionHealth[peripheralId] == .healthy {
                    connectionHealth[peripheralId] = .warning
                    eventSubject.send(.connectionHealthWarning(
                        peripheralId: peripheralId,
                        reason: "No data received for \(Int(elapsed)) seconds"
                    ))
                }
            }
        }
    }

    // MARK: - Event Subscription

    private func setupEventSubscription() {
        guard let bleService = bleService else { return }

        bleService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleBLEEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleBLEEvent(_ event: BLEServiceEvent) {
        switch event {
        case .deviceConnected(let peripheral):
            handleConnectionSuccess(for: peripheral.identifier)

        case .deviceDisconnected(let peripheral, let error):
            let wasUnexpected = error != nil
            handleDisconnection(for: peripheral.identifier, peripheral: peripheral, wasUnexpected: wasUnexpected)

        case .characteristicUpdated(let peripheral, _, _):
            recordDataReceived(from: peripheral.identifier)

        default:
            break
        }
    }
}

// MARK: - Connection Health Status

/// Health status for a BLE connection
enum ConnectionHealthStatus: String {
    case healthy = "Healthy"
    case warning = "Warning"
    case stale = "Stale"
    case disconnected = "Disconnected"

    var isConnected: Bool {
        self != .disconnected
    }

    var needsAttention: Bool {
        self == .warning || self == .stale
    }
}

// MARK: - Singleton Access

extension BLEBackgroundWorker {
    /// Shared instance for app-wide use
    static let shared = BLEBackgroundWorker()
}
