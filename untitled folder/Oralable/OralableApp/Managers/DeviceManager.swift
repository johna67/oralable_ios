//
//  DeviceManager.swift
//  OralableApp
//
//  CORRECTED: November 11, 2025
//  Fixed: connect() method now uses correct UUID key
//

import Foundation
import CoreBluetooth
import Combine

/// Manager for coordinating multiple BLE devices
@MainActor
class DeviceManager: ObservableObject {
    // MARK: - Published Properties
    
    /// All discovered devices
    @Published var discoveredDevices: [DeviceInfo] = []
    
    /// Currently connected devices
    @Published var connectedDevices: [DeviceInfo] = []
    
    /// Primary active device
    @Published var primaryDevice: DeviceInfo?
    
    /// All sensor readings from all devices
    @Published var allSensorReadings: [SensorReading] = []
    
    /// Latest readings by sensor type (aggregated from all devices)
    @Published var latestReadings: [SensorType: SensorReading] = [:]
    
    /// Connection state
    @Published var isScanning: Bool = false
    @Published var isConnecting: Bool = false
    
    /// Errors
    @Published var lastError: DeviceError?
    
    // MARK: - Private Properties

    private var devices: [UUID: BLEDeviceProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let maxDevices: Int = 5

    // BLE Integration
    private(set) var bleManager: BLECentralManager?

    // Discovery tracking
    private var discoveryCount: Int = 0
    private var scanStartTime: Date?

    // Reconnection management
    private var reconnectionAttempts: [UUID: Int] = [:]
    private let maxReconnectionAttempts = 3
    private var reconnectionTasks: [UUID: Task<Void, Never>] = [:]
    
    // Per-reading publisher (legacy, prefer batch)
    private let readingsSubject = PassthroughSubject<SensorReading, Never>()
    var readingsPublisher: AnyPublisher<SensorReading, Never> {
        readingsSubject.eraseToAnyPublisher()
    }

    // Batch publisher for efficient multi-reading delivery
    private let readingsBatchSubject = PassthroughSubject<[SensorReading], Never>()
    var readingsBatchPublisher: AnyPublisher<[SensorReading], Never> {
        readingsBatchSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() {
        Logger.shared.info("[DeviceManager] Initializing...")
        bleManager = BLECentralManager()
        setupBLECallbacks()
        Logger.shared.info("[DeviceManager] Initialization complete")
    }
    
    // MARK: - BLE Callbacks Setup
    
    private func setupBLECallbacks() {
        Logger.shared.info("[DeviceManager] Setting up BLE callbacks...")

        bleManager?.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            Logger.shared.debug("[DeviceManager] onDeviceDiscovered callback received")
            Logger.shared.debug("[DeviceManager] Peripheral: \(peripheral.identifier)")
            Logger.shared.debug("[DeviceManager] Name: \(name)")
            Logger.shared.debug("[DeviceManager] RSSI: \(rssi)")

            Task { @MainActor [weak self] in
                Logger.shared.debug("[DeviceManager] Dispatching to main actor...")
                self?.handleDeviceDiscovered(peripheral: peripheral, name: name, rssi: rssi)
            }
        }

        bleManager?.onDeviceConnected = { [weak self] peripheral in
            Logger.shared.debug("[DeviceManager] onDeviceConnected callback received")
            Logger.shared.debug("[DeviceManager] Peripheral: \(peripheral.identifier)")

            Task { @MainActor [weak self] in
                Logger.shared.debug("[DeviceManager] Dispatching to main actor...")
                self?.handleDeviceConnected(peripheral: peripheral)
            }
        }

        bleManager?.onDeviceDisconnected = { [weak self] peripheral, error in
            Logger.shared.debug("[DeviceManager] onDeviceDisconnected callback received")
            Logger.shared.debug("[DeviceManager] Peripheral: \(peripheral.identifier)")
            if let error = error {
                Logger.shared.error("[DeviceManager] Error: \(error.localizedDescription)")
            }

            Task { @MainActor [weak self] in
                Logger.shared.debug("[DeviceManager] Dispatching to main actor...")
                self?.handleDeviceDisconnected(peripheral: peripheral, error: error)
            }
        }

        bleManager?.onBluetoothStateChanged = { [weak self] state in
            Logger.shared.debug("[DeviceManager] onBluetoothStateChanged callback received")
            Logger.shared.debug("[DeviceManager] State: \(state.rawValue)")

            Task { @MainActor [weak self] in
                if state != .poweredOn && (self?.isScanning ?? false) {
                    Logger.shared.warning("[DeviceManager] Bluetooth not powered on, stopping scan")
                    self?.isScanning = false
                }
            }
        }

        Logger.shared.info("[DeviceManager] BLE callbacks configured successfully")
    }
    
    // MARK: - Device Discovery Handlers
    
    private func handleDeviceDiscovered(peripheral: CBPeripheral, name: String, rssi: Int) {
        discoveryCount += 1

        #if DEBUG
        Logger.shared.debug("[DeviceManager] Discovered device #\(discoveryCount): \(name) | RSSI: \(rssi) dBm")
        #endif

        // Check if already discovered
        if discoveredDevices.contains(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            // Update RSSI for existing device
            if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
                discoveredDevices[index].signalStrength = rssi
            }
            return
        }

        // Detect device type
        guard let deviceType = detectDeviceType(from: name, peripheral: peripheral) else {
            Logger.shared.debug("[DeviceManager] Unknown device type '\(name)' - rejected")
            return
        }

        Logger.shared.info("[DeviceManager] New device discovered: \(name) (\(deviceType))")

        // Create device info
        let deviceInfo = DeviceInfo(
            type: deviceType,
            name: name,
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected,
            signalStrength: rssi
        )

        // Add to discovered list
        discoveredDevices.append(deviceInfo)

        // Create device instance
        let device: BLEDeviceProtocol

        switch deviceType {
        case .oralable:
            device = OralableDevice(peripheral: peripheral)
        case .anr:
            device = ANRMuscleSenseDevice(peripheral: peripheral, name: name)
        case .demo:
            #if DEBUG
            device = MockBLEDevice(type: .demo)
            #else
            device = OralableDevice(peripheral: peripheral)
            #endif
        }

        // Store device - KEY POINT: Using peripheral.identifier as the key
        devices[peripheral.identifier] = device

        // Subscribe to device sensor readings
        subscribeToDevice(device)

        #if DEBUG
        Logger.shared.debug("[DeviceManager] Total devices discovered: \(discoveredDevices.count)")
        #endif
    }
    
    private func handleDeviceConnected(peripheral: CBPeripheral) {
        Logger.shared.info("[DeviceManager] Device connected: \(peripheral.name ?? "Unknown")")

        isConnecting = false

        // Update device info
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            discoveredDevices[index].connectionState = .connected

            // Add to connected devices if not already there
            if !connectedDevices.contains(where: { $0.id == discoveredDevices[index].id }) {
                connectedDevices.append(discoveredDevices[index])
            }

            // Set as primary if none set
            if primaryDevice == nil {
                primaryDevice = discoveredDevices[index]
            }
        }

        // Start device operations
        if let device = devices[peripheral.identifier] {
            Task {
                do {
                    // First, let the device discover its services
                    try await device.connect()

                    // Then start data collection
                    try await device.startDataCollection()
                    Logger.shared.info("[DeviceManager] Data collection started for \(device.name)")
                } catch {
                    Logger.shared.error("[DeviceManager] Error during device setup: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleDeviceDisconnected(peripheral: CBPeripheral, error: Error?) {
        let wasUnexpectedDisconnection = error != nil

        if let error = error {
            Logger.shared.warning("[DeviceManager] Device disconnected with error: \(error.localizedDescription)")
            lastError = .connectionLost
        } else {
            Logger.shared.info("[DeviceManager] Device disconnected: \(peripheral.name ?? "Unknown")")
        }

        isConnecting = false

        // Update device states
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheral.identifier }) {
            discoveredDevices[index].connectionState = .disconnected
        }

        connectedDevices.removeAll { $0.peripheralIdentifier == peripheral.identifier }

        if primaryDevice?.peripheralIdentifier == peripheral.identifier {
            primaryDevice = connectedDevices.first
        }

        // Attempt automatic reconnection if this was an unexpected disconnection
        if wasUnexpectedDisconnection {
            attemptReconnection(to: peripheral)
        } else {
            // Manual disconnection - reset reconnection attempts
            reconnectionAttempts[peripheral.identifier] = nil
            reconnectionTasks[peripheral.identifier]?.cancel()
            reconnectionTasks[peripheral.identifier] = nil
        }
    }

    // MARK: - Automatic Reconnection

    private func attemptReconnection(to peripheral: CBPeripheral) {
        let peripheralId = peripheral.identifier
        let attempts = reconnectionAttempts[peripheralId] ?? 0

        guard attempts < maxReconnectionAttempts else {
            Logger.shared.warning("[DeviceManager] Max reconnection attempts reached for \(peripheral.name ?? "device")")
            reconnectionAttempts[peripheralId] = nil
            return
        }

        reconnectionAttempts[peripheralId] = attempts + 1

        // Exponential backoff: 2^attempts seconds
        let delay = pow(2.0, Double(attempts))
        Logger.shared.info("[DeviceManager] Will attempt reconnection #\(attempts + 1) in \(Int(delay))s")

        // Cancel any existing reconnection task for this device
        reconnectionTasks[peripheralId]?.cancel()

        // Create new reconnection task
        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Check if task was cancelled
                guard !Task.isCancelled else {
                    Logger.shared.debug("[DeviceManager] Reconnection cancelled for \(peripheral.name ?? "device")")
                    return
                }

                // Attempt reconnection
                if let deviceInfo = discoveredDevices.first(where: { $0.peripheralIdentifier == peripheralId }) {
                    Logger.shared.info("[DeviceManager] Attempting reconnection #\(attempts + 1) to \(deviceInfo.name)")
                    try await connect(to: deviceInfo)
                }
            } catch {
                Logger.shared.error("[DeviceManager] Reconnection attempt failed: \(error.localizedDescription)")
            }
        }

        reconnectionTasks[peripheralId] = task
    }

    /// Cancel all ongoing reconnection attempts
    func cancelAllReconnections() {
        for (peripheralId, task) in reconnectionTasks {
            task.cancel()
            Logger.shared.debug("[DeviceManager] Cancelled reconnection for device: \(peripheralId)")
        }
        reconnectionTasks.removeAll()
        reconnectionAttempts.removeAll()
    }
    
    private func detectDeviceType(from name: String, peripheral: CBPeripheral) -> DeviceType? {
        let lowercaseName = name.lowercased()

        // Check for Oralable by name
        if lowercaseName.contains("oralable") ||
           lowercaseName.contains("tgm") ||
           lowercaseName.contains("n02cl") {
            return .oralable
        }

        // Check for ANR
        if lowercaseName.contains("anr") ||
           lowercaseName.contains("muscle") ||
           lowercaseName.contains("m40") ||
           lowercaseName.contains("anr corp") {
            return .anr
        }

        // Unknown device type
        return nil
    }
    
    // MARK: - Device Discovery
    
    /// Start scanning for devices
    func startScanning() async {
        Logger.shared.info("[DeviceManager] Starting device scan")

        scanStartTime = Date()
        discoveryCount = 0
        discoveredDevices.removeAll()
        isScanning = true

        // Scan for ALL BLE devices - TGM service is not advertised, only discovered after connection
        // Filters applied in handleDeviceDiscovered based on device name
        bleManager?.startScanning()

        // Note: Service-based filtering won't work because devices don't advertise TGM service UUID
        // let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        // bleManager?.startScanning(services: [tgmServiceUUID])
    }

    /// Stop scanning for devices
    func stopScanning() {
        #if DEBUG
        if let scanStart = scanStartTime {
            let elapsed = Date().timeIntervalSince(scanStart)
            Logger.shared.debug("[DeviceManager] Scan stopped | Duration: \(String(format: "%.1f", elapsed))s | Devices found: \(discoveredDevices.count)")
        }
        #endif

        isScanning = false
        bleManager?.stopScanning()
        scanStartTime = nil
    }
    
    // MARK: - Connection Management
    
    // ✅ CORRECTED METHOD - Using peripheralIdentifier as dictionary key
    func connect(to deviceInfo: DeviceInfo) async throws {
        Logger.shared.info("[DeviceManager] Connecting to device: \(deviceInfo.name)")

        // ✅ CRITICAL FIX: Use peripheralIdentifier, not deviceInfo.id
        guard let peripheralId = deviceInfo.peripheralIdentifier else {
            throw DeviceError.invalidPeripheral
        }

        guard let device = devices[peripheralId] else {
            Logger.shared.error("[DeviceManager] Device not found in registry")
            throw DeviceError.invalidPeripheral
        }

        guard let peripheral = device.peripheral else {
            throw DeviceError.invalidPeripheral
        }

        isConnecting = true

        // Update state
        if let index = discoveredDevices.firstIndex(where: { $0.peripheralIdentifier == peripheralId }) {
            discoveredDevices[index].connectionState = .connecting
        }

        // Reset reconnection attempts on manual connect
        reconnectionAttempts[peripheralId] = 0

        // Connect via BLE manager
        bleManager?.connect(to: peripheral)
    }
    
    func disconnect(from deviceInfo: DeviceInfo) {
        Logger.shared.info("[DeviceManager] Disconnecting from device: \(deviceInfo.name)")

        guard let peripheralId = deviceInfo.peripheralIdentifier,
              let device = devices[peripheralId],
              let peripheral = device.peripheral else {
            Logger.shared.error("[DeviceManager] Device or peripheral not found")
            return
        }

        // Cancel any pending reconnection attempts for this device
        reconnectionTasks[peripheralId]?.cancel()
        reconnectionTasks[peripheralId] = nil
        reconnectionAttempts[peripheralId] = nil

        bleManager?.disconnect(from: peripheral)

        // Stop data collection
        Task {
            try? await device.stopDataCollection()
        }
    }

    func disconnectAll() {
        Logger.shared.info("[DeviceManager] Disconnecting all devices")

        for deviceInfo in connectedDevices {
            disconnect(from: deviceInfo)
        }

        // Cancel all reconnection attempts
        cancelAllReconnections()
    }
    
    // MARK: - Sensor Data Management
    
    private func subscribeToDevice(_ device: BLEDeviceProtocol) {
        Logger.shared.debug("[DeviceManager] subscribeToDevice")
        Logger.shared.debug("[DeviceManager] Device: \(device.deviceInfo.name)")

        // Subscribe to batch publisher for efficient multi-reading delivery
        device.sensorReadingsBatch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] readings in
                self?.handleSensorReadingsBatch(readings, from: device)
            }
            .store(in: &cancellables)

        Logger.shared.debug("[DeviceManager] Batch subscription created")
    }
    
    private func handleSensorReading(_ reading: SensorReading, from device: BLEDeviceProtocol) {
        // Add to all readings
        allSensorReadings.append(reading)

        // Update latest readings
        latestReadings[reading.sensorType] = reading

        // Emit per-reading for streaming consumers
        readingsSubject.send(reading)

        // Trim history if needed (keep last 1000)
        if allSensorReadings.count > 1000 {
            allSensorReadings.removeFirst(100)
        }
    }

    private func handleSensorReadingsBatch(_ readings: [SensorReading], from device: BLEDeviceProtocol) {
        // Add to all readings
        allSensorReadings.append(contentsOf: readings)

        // Update latest readings
        for reading in readings {
            latestReadings[reading.sensorType] = reading
        }

        // Emit batch for efficient downstream processing
        readingsBatchSubject.send(readings)

        // Trim history if needed (keep last 1000)
        if allSensorReadings.count > 1000 {
            let removeCount = allSensorReadings.count - 1000
            allSensorReadings.removeFirst(removeCount)
        }
    }

    // MARK: - Device Info Access
    
    func device(withId id: UUID) -> DeviceInfo? {
        return discoveredDevices.first { $0.id == id }
    }

    /// Read-only helper to fetch the underlying CBPeripheral for a given peripheral identifier
    func peripheral(for id: UUID) -> CBPeripheral? {
        return devices[id]?.peripheral
    }
    
    // MARK: - Data Management
    
    /// Clear all sensor readings
    func clearReadings() {
        Logger.shared.info("[DeviceManager] clearReadings() called")
        allSensorReadings.removeAll()
        latestReadings.removeAll()
        Logger.shared.info("[DeviceManager] All readings cleared")
    }
    
    /// Set a device as the primary device
    func setPrimaryDevice(_ deviceInfo: DeviceInfo?) {
        Logger.shared.info("[DeviceManager] setPrimaryDevice() called")
        if let device = deviceInfo {
            Logger.shared.info("[DeviceManager] Setting primary device to: \(device.name)")
        } else {
            Logger.shared.info("[DeviceManager] Clearing primary device")
        }
        primaryDevice = deviceInfo
    }
}

