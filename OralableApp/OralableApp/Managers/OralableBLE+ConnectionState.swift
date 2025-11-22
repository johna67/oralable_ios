//
//  OralableBLE+ConnectionState..swift
//  OralableApp
//
//  Created by John A Cogan on 22/11/2025.
//


import Foundation
import Combine
import CoreBluetooth

// Small extension providing the ConnectionStateProvider publishers required
// by the protocol. Keeps these forwarders in one place to avoid duplicates.
extension OralableBLE {
    // ConnectionStateProvider - publisher forwarders
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    var isScanningPublisher: Published<Bool>.Publisher { $isScanning }
    var deviceNamePublisher: Published<String>.Publisher { $deviceName }
    var deviceUUIDPublisher: Published<UUID?>.Publisher { $deviceUUID }
    var connectionStatePublisher: Published<String>.Publisher { $connectionState }
    var discoveredDevicesPublisher: Published<[CBPeripheral]>.Publisher { $discoveredDevices }
    var rssiPublisher: Published<Int>.Publisher { $rssi }
}