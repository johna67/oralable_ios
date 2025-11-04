//
//  BLECentralManager.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//  Updated: November 4, 2025
//  Thin wrapper around CoreBluetooth to surface discovery/connection callbacks
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
    
    // MARK: - Private
    
    private var central: CBCentralManager!
    private var connectedPeripherals = Set<UUID>()
    private var pendingConnections = Set<UUID>()
    private let queue = DispatchQueue(label: "com.oralableapp.ble.central", qos: .userInitiated)
    
    // Optional: filter by services if you want to narrow scanning
    private var serviceFilter: [CBUUID]?
    
    // MARK: - Init
    
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
    }
    
    // MARK: - Scanning
    
    func startScanning(services: [CBUUID]? = nil) {
        serviceFilter = services
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
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
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onBluetoothStateChanged?(central.state)
        
        // Auto-start scanning if desired when powered on
        if central.state == .poweredOn, central.isScanning == false {
            if let services = serviceFilter {
                startScanning(services: services)
            }
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        onDeviceDiscovered?(peripheral, name, RSSI.intValue)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripherals.insert(peripheral.identifier)
        pendingConnections.remove(peripheral.identifier)
        onDeviceConnected?(peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        pendingConnections.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedPeripherals.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }
}

