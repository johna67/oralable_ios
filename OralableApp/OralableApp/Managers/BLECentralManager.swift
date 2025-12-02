//
//  BLECentralManager.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//  Updated: November 10, 2025 - nRF Connect Style Logging
//  Comprehensive debug logging matching nRF Connect for Mobile
//

import Foundation
import CoreBluetooth

/// Centralized BLE manager that surfaces discovery/connection events via callbacks
final class BLECentralManager: NSObject {

    // MARK: - Callbacks

    /// Called when a peripheral is discovered
    var onDeviceDiscovered: ((CBPeripheral, String, Int) -> Void)?

    /// Called when a peripheral is connected
    var onDeviceConnected: ((CBPeripheral) -> Void)?

    /// Called when a peripheral is disconnected
    var onDeviceDisconnected: ((CBPeripheral, Error?) -> Void)?

    /// Called when Bluetooth state changes
    var onBluetoothStateChanged: ((CBManagerState) -> Void)?

    // MARK: - Public State

    /// Current Bluetooth state - observable for UI updates
    private(set) var state: CBManagerState = .unknown

    /// Whether Bluetooth is ready for scanning/connecting
    var isReady: Bool { state == .poweredOn }

    // MARK: - Private

    // EAGER INITIALIZATION: CBCentralManager created immediately to get early state updates
    // This triggers Bluetooth permission dialog on first app launch (required for BLE apps)
    private var central: CBCentralManager!

    private var connectedPeripherals = Set<UUID>()
    private var pendingConnections = Set<UUID>()
    private let queue = DispatchQueue(label: "com.oralableapp.ble.central", qos: .userInitiated)

    // Optional: filter by services if you want to narrow scanning
    private var serviceFilter: [CBUUID]?

    // Pending operations to run when Bluetooth becomes ready
    private var pendingOperations: [() -> Void] = []

    // MARK: - Init

    override init() {
        super.init()
        // EAGER: Initialize CBCentralManager immediately
        // This requests Bluetooth permission and starts receiving state updates
        central = CBCentralManager(delegate: self, queue: queue)
        Logger.shared.info("[BLECentralManager] ⚡️ Initialized - waiting for Bluetooth state...")
    }

    // MARK: - Ready State Handling

    /// Execute an operation when Bluetooth is ready, or queue it if not ready yet
    func whenReady(_ operation: @escaping () -> Void) {
        if isReady {
            operation()
        } else {
            pendingOperations.append(operation)
            Logger.shared.info("[BLECentralManager] ⏳ Operation queued - waiting for Bluetooth to power on")
        }
    }

    /// Execute all pending operations (called when Bluetooth becomes ready)
    private func executePendingOperations() {
        guard isReady else { return }
        let operations = pendingOperations
        pendingOperations.removeAll()
        Logger.shared.info("[BLECentralManager] ✅ Executing \(operations.count) pending operation(s)")
        for operation in operations {
            operation()
        }
    }
    
    // MARK: - Scanning
    
    func startScanning(services: [CBUUID]? = nil) {
        serviceFilter = services

        Task { @MainActor in
            let serviceNames = services?.map { $0.uuidString } ?? ["all"]
            Logger.shared.info("Scanner On - Starting scan for services: \(serviceNames)")
        }

        guard central.state == .poweredOn else {
            Task { @MainActor in
                Logger.shared.error("Cannot start scan - Bluetooth not powered on (state: \(self.stateDescription(central.state)))")
            }
            return
        }
        guard !central.isScanning else {
            Task { @MainActor in
                Logger.shared.warning("Already scanning, ignoring start request")
            }
            return
        }

        central.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        Task { @MainActor in
            Logger.shared.info("Scan started successfully")
        }
    }
    
    func stopScanning() {
        guard central.isScanning else {
            Task { @MainActor in
                Logger.shared.debug("Already stopped, ignoring stop request")
            }
            return
        }
        Task { @MainActor in
            Logger.shared.info("Scanner Off")
        }
        central.stopScan()
    }
    
    // MARK: - Connections
    
    func connect(to peripheral: CBPeripheral) {
        pendingConnections.insert(peripheral.identifier)
        central.connect(peripheral, options: nil)
    }
    
    func disconnect(from peripheral: CBPeripheral) {
        central.cancelPeripheralConnection(peripheral)
    }
    
    func disconnectAll() {
        for uuid in connectedPeripherals {
            if let peripheral = central.retrievePeripherals(withIdentifiers: [uuid]).first {
                central.cancelPeripheralConnection(peripheral)
            }
        }
        connectedPeripherals.removeAll()
    }
    
    // MARK: - Helper Methods

    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "Unknown State (\(state.rawValue))"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let previousState = state
        state = central.state

        Task { @MainActor in
            Logger.shared.info("[BLECentralManager] 📶 Bluetooth state: \(self.stateDescription(previousState)) → \(self.stateDescription(central.state))")
        }

        // Execute pending operations when Bluetooth becomes ready
        if state == .poweredOn && previousState != .poweredOn {
            Task { @MainActor in
                Logger.shared.info("[BLECentralManager] ✅ Bluetooth powered on - ready for scanning/connecting")
            }
            executePendingOperations()
        }

        onBluetoothStateChanged?(central.state)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"

        // Log device discovery
        Task { @MainActor in
            Logger.shared.debug("Device Scanned - UUID: \(peripheral.identifier.uuidString)")

            // Detailed logging for discovered device
            var details = "Name: \(name), RSSI: \(RSSI) dBm"

            // Service UUIDs - MOST IMPORTANT
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                let uuidStrings = serviceUUIDs.map { $0.uuidString }
                details += ", Services: [\(uuidStrings.joined(separator: ", "))]"

                // Highlight TGM Service
                if serviceUUIDs.contains(where: { $0.uuidString.uppercased() == "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E" }) {
                    Logger.shared.info("TGM Service detected on device: \(name)")
                }
            }

            // Signal strength assessment
            let signalQuality: String
            if RSSI.intValue < -100 {
                signalQuality = "Very Weak"
                Logger.shared.warning("Signal very weak for \(name): \(RSSI) dBm")
            } else if RSSI.intValue < -80 {
                signalQuality = "Weak"
            } else if RSSI.intValue < -60 {
                signalQuality = "Good"
            } else {
                signalQuality = "Excellent"
            }
            details += ", Signal: \(signalQuality)"

            Logger.shared.debug(details)
        }

        // Fire callback
        onDeviceDiscovered?(peripheral, name, RSSI.intValue)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            Logger.shared.info("Connected to device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
        }

        connectedPeripherals.insert(peripheral.identifier)
        pendingConnections.remove(peripheral.identifier)
        onDeviceConnected?(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            Logger.shared.error("Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        }

        pendingConnections.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                Logger.shared.error("Disconnection error: \(error.localizedDescription)")
            } else {
                Logger.shared.info("Disconnected from device: \(peripheral.name ?? "Unknown")")
            }
        }

        connectedPeripherals.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }
}
