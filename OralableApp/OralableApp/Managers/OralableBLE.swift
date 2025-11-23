//
//  OralableBLE.swift
//  OralableApp
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
final class OralableBLE: NSObject, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isRecording: Bool = false
    @Published var deviceName: String = "Unknown Device"

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func startRecording() {
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }
}

extension OralableBLE: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        connectedPeripheral = peripheral
        deviceName = peripheral.name ?? "Unnamed"
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectedPeripheral = peripheral
        deviceName = peripheral.name ?? "Connected Device"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
    }
}
