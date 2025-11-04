//
//  BLECentralManager.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  BLECentralManager.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Central BLE manager for device discovery and connection
//

import Foundation
import CoreBluetooth
import Combine

/// Central BLE manager for scanning and connecting to devices
@MainActor
class BLECentralManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isScanning: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    
    // Callbacks
    var onDeviceDiscovered: ((CBPeripheral, String, Int) -> Void)?
    var onDeviceConnected: ((CBPeripheral) -> Void)?
    var onDeviceDisconnected: ((CBPeripheral, Error?) -> Void)?
    var onBluetoothStateChanged: ((CBManagerState) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Scanning
    
    /// Start scanning for Oralable and ANR devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("⚠️ Bluetooth not ready. Current state: \(centralManager.state.rawValue)")
            return
        }
        
        guard !isScanning else {
            print("⚠️ Already scanning")
            return
        }
        
        print("🔍 Starting BLE scan...")
        
        // Scan for all devices (we'll filter by name and services)
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        isScanning = true
    }
    
    /// Stop scanning
    func stopScanning() {
        guard isScanning else { return }
        
        print("⏹️ Stopping BLE scan")
        centralManager.stopScan()
        isScanning = false
    }
    
    // MARK: - Connection
    
    /// Connect to a peripheral
    func connect(to peripheral: CBPeripheral) {
        print("📱 Connecting to: \(peripheral.name ?? "Unknown")")
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnect from a peripheral
    func disconnect(from peripheral: CBPeripheral) {
        print("📱 Disconnecting from: \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// Disconnect all peripherals
    func disconnectAll() {
        for peripheral in discoveredPeripherals.values {
            if peripheral.state == .connected || peripheral.state == .connecting {
                disconnect(from: peripheral)
            }
        }
    }
    
    // MARK: - Device Type Detection
    
    private func detectDeviceType(peripheral: CBPeripheral, advertisementData: [String: Any]) -> DeviceType {
        // Check by name first
        if let name = peripheral.name {
            let lowercaseName = name.lowercased()
            if lowercaseName.contains("oralable") {
                return .oralable
            } else if lowercaseName.contains("anr") || lowercaseName.contains("muscle") {
                return .anrMuscleSense
            }
        }
        
        // Check by service UUIDs
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for uuid in serviceUUIDs {
                let uuidString = uuid.uuidString.uppercased()
                
                // Oralable service UUID
                if uuidString == "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E" {
                    return .oralable
                }
                // ANR/Heart Rate service UUID
                else if uuidString == "0000180D-0000-1000-8000-00805F9B34FB" {
                    return .anrMuscleSense
                }
            }
        }
        
        return .unknown
    }
    
    // MARK: - Helper Methods
    
    private func isRelevantDevice(peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        let deviceType = detectDeviceType(peripheral: peripheral, advertisementData: advertisementData)
        return deviceType != .unknown
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("📡 Bluetooth state: \(central.state.debugDescription)")
        bluetoothState = central.state
        onBluetoothStateChanged?(central.state)
        
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth ready")
        case .poweredOff:
            print("⚠️ Bluetooth is powered off")
            isScanning = false
        case .unauthorized:
            print("⚠️ Bluetooth unauthorized")
        case .unsupported:
            print("⚠️ Bluetooth unsupported")
        case .resetting:
            print("⚠️ Bluetooth resetting")
        case .unknown:
            print("⚠️ Bluetooth state unknown")
        @unknown default:
            print("⚠️ Bluetooth unknown state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        // Filter out devices with no name or very weak signal
        guard let deviceName = peripheral.name, !deviceName.isEmpty else {
            return
        }
        
        guard RSSI.intValue > -100 else {
            return
        }
        
        // Check if this is a relevant device
        guard isRelevantDevice(peripheral: peripheral, advertisementData: advertisementData) else {
            return
        }
        
        let signalStrength = RSSI.intValue
        
        // Store peripheral
        discoveredPeripherals[peripheral.identifier] = peripheral
        
        // Detect device type for logging
        let deviceType = detectDeviceType(peripheral: peripheral, advertisementData: advertisementData)
        
        print("✅ Found: \(deviceName) (RSSI: \(signalStrength)dB, Type: \(deviceType.displayName))")
        
        // Notify delegate
        onDeviceDiscovered?(peripheral, deviceName, signalStrength)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to: \(peripheral.name ?? "Unknown")")
        
        // Discover services
        peripheral.discoverServices(nil)
        
        // Notify delegate
        onDeviceConnected?(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("❌ Disconnected from \(peripheral.name ?? "Unknown") with error: \(error.localizedDescription)")
        } else {
            print("✅ Disconnected from: \(peripheral.name ?? "Unknown")")
        }
        
        // Notify delegate
        onDeviceDisconnected?(peripheral, error)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
        
        // Notify delegate
        onDeviceDisconnected?(peripheral, error)
    }
}

// MARK: - CBManagerState Extension

extension CBManagerState {
    var debugDescription: String {
        switch self {
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
            return "Unknown State"
        }
    }
}