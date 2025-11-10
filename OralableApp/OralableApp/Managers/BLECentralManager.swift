//
//  BLECentralManager.swift
//  OralableApp
//
//  ENHANCED LOGGING VERSION
//  Created by John A Cogan on 03/11/2025.
//  Updated: November 10, 2025
//  Comprehensive debug logging for BLE discovery troubleshooting
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
        print("\n🔧 [BLECentralManager] Initializing...")
        central = CBCentralManager(delegate: self, queue: queue)
        print("🔧 [BLECentralManager] CBCentralManager created with delegate")
    }
    
    // MARK: - Scanning
    
    func startScanning(services: [CBUUID]? = nil) {
        print("\n🔍 [BLECentralManager] startScanning() called")
        print("🔍 [BLECentralManager] Service filter: \(services?.map { $0.uuidString } ?? ["nil (scan all devices)"])")
        
        serviceFilter = services
        
        // Check Bluetooth state
        print("🔍 [BLECentralManager] Current Bluetooth state: \(stateDescription(central.state))")
        guard central.state == .poweredOn else {
            print("❌ [BLECentralManager] Cannot start scan - Bluetooth state is \(stateDescription(central.state))")
            print("❌ [BLECentralManager] SCAN ABORTED - Bluetooth not powered on")
            return
        }
        
        // Check if already scanning
        print("🔍 [BLECentralManager] Is already scanning? \(central.isScanning)")
        guard !central.isScanning else {
            print("⚠️ [BLECentralManager] Already scanning, ignoring start request")
            return
        }
        
        print("✅ [BLECentralManager] Starting CoreBluetooth scan...")
        print("✅ [BLECentralManager] Services filter: \(services?.map { $0.uuidString } ?? ["nil (all)"])")
        print("✅ [BLECentralManager] Allow duplicates: false")
        
        central.scanForPeripherals(
            withServices: services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        print("✅ [BLECentralManager] scanForPeripherals() called successfully")
        print("✅ [BLECentralManager] Waiting for didDiscover callbacks...")
    }
    
    func stopScanning() {
        print("\n🛑 [BLECentralManager] stopScanning() called")
        print("🛑 [BLECentralManager] Is currently scanning? \(central.isScanning)")
        
        guard central.isScanning else {
            print("⚠️ [BLECentralManager] Already stopped, ignoring stop request")
            return
        }
        
        print("✅ [BLECentralManager] Calling stopScan()")
        central.stopScan()
        print("✅ [BLECentralManager] Scan stopped")
    }
    
    // MARK: - Connections
    
    func connect(to peripheral: CBPeripheral) {
        print("\n🔌 [BLECentralManager] connect() called for: \(peripheral.name ?? "Unknown")")
        print("🔌 [BLECentralManager] Peripheral UUID: \(peripheral.identifier)")
        pendingConnections.insert(peripheral.identifier)
        central.connect(peripheral, options: nil)
        print("🔌 [BLECentralManager] Connection request sent")
    }
    
    func disconnect(from peripheral: CBPeripheral) {
        print("\n🔌 [BLECentralManager] disconnect() called for: \(peripheral.name ?? "Unknown")")
        print("🔌 [BLECentralManager] Peripheral UUID: \(peripheral.identifier)")
        central.cancelPeripheralConnection(peripheral)
        print("🔌 [BLECentralManager] Disconnection request sent")
    }
    
    func disconnectAll() {
        print("\n🔌 [BLECentralManager] disconnectAll() called")
        print("🔌 [BLECentralManager] Connected peripherals count: \(connectedPeripherals.count)")
        
        for uuid in connectedPeripherals {
            if let peripheral = central.retrievePeripherals(withIdentifiers: [uuid]).first {
                print("🔌 [BLECentralManager] Disconnecting: \(peripheral.name ?? "Unknown") (\(uuid))")
                central.cancelPeripheralConnection(peripheral)
            }
        }
        connectedPeripherals.removeAll()
        print("🔌 [BLECentralManager] All disconnections requested")
    }
    
    // MARK: - Helper Methods
    
    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "Unknown"
        case .resetting:
            return "Resetting"
        case .unsupported:
            return "Unsupported"
        case .unauthorized:
            return "Unauthorized"
        case .poweredOff:
            return "Powered Off"
        case .poweredOn:
            return "Powered On"
        @unknown default:
            return "Unknown State (\(state.rawValue))"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\n📡 [BLECentralManager] centralManagerDidUpdateState()")
        print("📡 [BLECentralManager] New state: \(stateDescription(central.state))")
        print("📡 [BLECentralManager] State raw value: \(central.state.rawValue)")
        
        switch central.state {
        case .unknown:
            print("📡 [BLECentralManager] ⚠️ Bluetooth state is UNKNOWN")
        case .resetting:
            print("📡 [BLECentralManager] ⚠️ Bluetooth is RESETTING")
        case .unsupported:
            print("📡 [BLECentralManager] ❌ Bluetooth is UNSUPPORTED on this device")
        case .unauthorized:
            print("📡 [BLECentralManager] ❌ Bluetooth is UNAUTHORIZED - check Settings > Privacy > Bluetooth")
        case .poweredOff:
            print("📡 [BLECentralManager] ❌ Bluetooth is POWERED OFF - user needs to enable it")
        case .poweredOn:
            print("📡 [BLECentralManager] ✅ Bluetooth is POWERED ON - ready to scan")
        @unknown default:
            print("📡 [BLECentralManager] ⚠️ Unknown Bluetooth state: \(central.state.rawValue)")
        }
        
        onBluetoothStateChanged?(central.state)
        print("📡 [BLECentralManager] State change callback fired")
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        // COMPREHENSIVE LOGGING FOR EVERY DISCOVERED DEVICE
        print("\n" + String(repeating: "=", count: 80))
        print("📱 BLE DEVICE DISCOVERED")
        print(String(repeating: "=", count: 80))
        
        // Basic info
        print("📱 Timestamp: \(Date())")
        print("📱 Peripheral UUID: \(peripheral.identifier.uuidString)")
        print("📱 Peripheral.name: \(peripheral.name ?? "nil")")
        print("📱 Peripheral.state: \(peripheralStateDescription(peripheral.state))")
        
        // Advertisement data - DETAILED
        print("\n--- Advertisement Data ---")
        print("📱 Local Name: \(advertisementData[CBAdvertisementDataLocalNameKey] ?? "nil")")
        print("📱 Manufacturer Data: \(advertisementData[CBAdvertisementDataManufacturerDataKey] ?? "nil")")
        
        // Service UUIDs - THE MOST IMPORTANT FIELD
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            print("📱 Service UUIDs: [\(serviceUUIDs.count) services]")
            for (index, uuid) in serviceUUIDs.enumerated() {
                print("📱   [\(index)] \(uuid.uuidString)")
                
                // HIGHLIGHT if it's the TGM Service
                if uuid.uuidString.uppercased() == "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E" {
                    print("📱   ✅ ✅ ✅ THIS IS THE TGM SERVICE! ✅ ✅ ✅")
                }
            }
        } else {
            print("📱 Service UUIDs: nil (NO SERVICE UUIDs ADVERTISED)")
        }
        
        // Service Data
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            print("📱 Service Data: [\(serviceData.count) entries]")
            for (uuid, data) in serviceData {
                print("📱   \(uuid.uuidString): \(data.count) bytes")
            }
        } else {
            print("📱 Service Data: nil")
        }
        
        // Other advertisement fields
        print("📱 Is Connectable: \(advertisementData[CBAdvertisementDataIsConnectable] ?? "unknown")")
        print("📱 TX Power Level: \(advertisementData[CBAdvertisementDataTxPowerLevelKey] ?? "unknown")")
        print("📱 Overflow Service UUIDs: \(advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] ?? "nil")")
        print("📱 Solicited Service UUIDs: \(advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] ?? "nil")")
        
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
        
        // Service filter check
        print("\n--- Service Filter Check ---")
        if let filter = serviceFilter {
            print("📱 Service filter is active: \(filter.map { $0.uuidString })")
            
            if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                let matches = serviceUUIDs.filter { filter.contains($0) }
                if !matches.isEmpty {
                    print("📱 ✅ Device MATCHES filter: \(matches.map { $0.uuidString })")
                } else {
                    print("📱 ❌ Device DOES NOT match filter")
                    print("📱 ❌ Advertised: \(serviceUUIDs.map { $0.uuidString })")
                    print("📱 ❌ Required: \(filter.map { $0.uuidString })")
                }
            } else {
                print("📱 ❌ Device has NO service UUIDs - cannot match filter")
            }
        } else {
            print("📱 No service filter - accepting all devices")
        }
        
        print(String(repeating: "=", count: 80))
        print("📱 END OF DEVICE DISCOVERY")
        print(String(repeating: "=", count: 80) + "\n")
        
        // Fire the callback
        print("📱 Calling onDeviceDiscovered callback...")
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        onDeviceDiscovered?(peripheral, name, RSSI.intValue)
        print("📱 onDeviceDiscovered callback completed\n")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("\n✅ [BLECentralManager] didConnect")
        print("✅ [BLECentralManager] Connected to: \(peripheral.name ?? "Unknown")")
        print("✅ [BLECentralManager] UUID: \(peripheral.identifier)")
        
        connectedPeripherals.insert(peripheral.identifier)
        pendingConnections.remove(peripheral.identifier)
        
        print("✅ [BLECentralManager] Calling onDeviceConnected callback...")
        onDeviceConnected?(peripheral)
        print("✅ [BLECentralManager] Connection callback completed")
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        print("\n❌ [BLECentralManager] didFailToConnect")
        print("❌ [BLECentralManager] Failed to connect to: \(peripheral.name ?? "Unknown")")
        print("❌ [BLECentralManager] UUID: \(peripheral.identifier)")
        if let error = error {
            print("❌ [BLECentralManager] Error: \(error.localizedDescription)")
        }
        
        pendingConnections.remove(peripheral.identifier)
        
        print("❌ [BLECentralManager] Calling onDeviceDisconnected callback...")
        onDeviceDisconnected?(peripheral, error)
        print("❌ [BLECentralManager] Disconnection callback completed")
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        print("\n🔌 [BLECentralManager] didDisconnectPeripheral")
        print("🔌 [BLECentralManager] Disconnected from: \(peripheral.name ?? "Unknown")")
        print("🔌 [BLECentralManager] UUID: \(peripheral.identifier)")
        
        if let error = error {
            print("🔌 [BLECentralManager] Error: \(error.localizedDescription)")
        } else {
            print("🔌 [BLECentralManager] Clean disconnection (no error)")
        }
        
        connectedPeripherals.remove(peripheral.identifier)
        
        print("🔌 [BLECentralManager] Calling onDeviceDisconnected callback...")
        onDeviceDisconnected?(peripheral, error)
        print("🔌 [BLECentralManager] Disconnection callback completed")
    }
    
    // MARK: - Helper Methods
    
    private func peripheralStateDescription(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            return "Unknown (\(state.rawValue))"
        }
    }
}
