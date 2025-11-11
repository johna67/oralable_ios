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
        nrfLog("Normal", "BLECentralManager initialized")
        central = CBCentralManager(delegate: self, queue: queue)
    }
    
    // MARK: - Scanning
    
    func startScanning(services: [CBUUID]? = nil) {
        serviceFilter = services
        
        let timestamp = formatTimestamp(Date())
        nrfLog("Application", "Scanner On")
        print("[\(timestamp)] Normal: Starting scan for services: \(services?.map { $0.uuidString } ?? ["all"])")
        
        guard central.state == .poweredOn else {
            print("[\(timestamp)] Error: Cannot start scan - Bluetooth not powered on (state: \(stateDescription(central.state)))")
            return
        }
        guard !central.isScanning else {
            print("[\(timestamp)] Warning: Already scanning, ignoring start request")
            return
        }
        
        central.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        print("[\(timestamp)] Normal: Scan started successfully")
    }
    
    func stopScanning() {
        guard central.isScanning else {
            print("[BLECentralManager] Already stopped, ignoring stop request")
            return
        }
        let timestamp = formatTimestamp(Date())
        print("[\(timestamp)] Application: Scanner Off")
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
    
    private func nrfLog(_ level: String, _ message: String) {
        let timestamp = formatTimestamp(Date())
        print("[\(timestamp)] \(level): \(message)")
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSS"
        return formatter.string(from: date)
    }
    
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
        let timestamp = formatTimestamp(Date())
        print("[\(timestamp)] Normal: Bluetooth state changed to: \(stateDescription(central.state))")
        onBluetoothStateChanged?(central.state)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let timestamp = formatTimestamp(Date())
        
        // NRF CONNECT STYLE - Simple discovery log
        nrfLog("Normal", "Device Scanned")
        
        // DETAILED LOGGING - Like nRF Connect detailed view
        print("\n" + String(repeating: "=", count: 80))
        print("📱 BLE DEVICE DISCOVERED")
        print(String(repeating: "=", count: 80))
        print("📱 Timestamp: [\(timestamp)]")
        print("📱 Peripheral UUID: \(peripheral.identifier.uuidString)")
        print("📱 Peripheral.name: \(peripheral.name ?? "nil")")
        
        // Advertisement data
        print("\n--- Advertisement Data ---")
        print("📱 Local Name: \(advertisementData[CBAdvertisementDataLocalNameKey] ?? "nil")")
        print("📱 Manufacturer Data: \(advertisementData[CBAdvertisementDataManufacturerDataKey] ?? "nil")")
        
        // Service UUIDs - MOST IMPORTANT
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("📱 Service UUIDs: [\(serviceUUIDs.count) services]")
            for (index, uuid) in serviceUUIDs.enumerated() {
                print("📱   [\(index)] \(uuid.uuidString)")
                
                // Highlight TGM Service
                if uuid.uuidString.uppercased() == "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E" {
                    print("📱   ✅ ✅ ✅ THIS IS THE TGM SERVICE! ✅ ✅ ✅")
                }
            }
        } else {
            print("📱 Service UUIDs: nil (NO SERVICE UUIDs ADVERTISED)")
        }
        
        // Other fields
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            print("📱 Service Data: [\(serviceData.count) entries]")
            for (uuid, data) in serviceData {
                print("📱   \(uuid.uuidString): \(data.count) bytes")
            }
        } else {
            print("📱 Service Data: nil")
        }
        
        print("📱 Is Connectable: \(advertisementData[CBAdvertisementDataIsConnectable] ?? "unknown")")
        print("📱 TX Power Level: \(advertisementData[CBAdvertisementDataTxPowerLevelKey] ?? "unknown")")
        
        // Signal strength
        print("\n--- Signal Strength ---")
        print("📱 RSSI: \(RSSI) dBm")
        if RSSI.intValue < -100 {
            print("📱 ⚠️ Signal is VERY WEAK (< -100 dBm)")
        } else if RSSI.intValue < -80 {
            print("📱 ⚠️ Signal is WEAK (-80 to -100 dBm)")
        } else if RSSI.intValue < -60 {
            print("📱 ✅ Signal is GOOD (-60 to -80 dBm)")
        } else {
            print("📱 ✅ Signal is EXCELLENT (> -60 dBm)")
        }
        
        print(String(repeating: "=", count: 80))
        print("📱 END OF DEVICE DISCOVERY")
        print(String(repeating: "=", count: 80) + "\n")
        
        // Fire callback
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        onDeviceDiscovered?(peripheral, name, RSSI.intValue)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        nrfLog("Normal", "Connected")
        print("[\(formatTimestamp(Date()))] Normal: Connected to device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
        
        connectedPeripherals.insert(peripheral.identifier)
        pendingConnections.remove(peripheral.identifier)
        onDeviceConnected?(peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        nrfLog("Error", "Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        
        pendingConnections.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        nrfLog("Normal", "Disconnected")
        
        if let error = error {
            print("[\(formatTimestamp(Date()))] Error: Disconnection error: \(error.localizedDescription)")
        }
        
        connectedPeripherals.remove(peripheral.identifier)
        onDeviceDisconnected?(peripheral, error)
    }
}
