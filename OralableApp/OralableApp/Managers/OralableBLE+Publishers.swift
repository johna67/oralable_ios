//
//  publishers.swift
//  OralableApp
//
//  Created by John A Cogan on 22/11/2025.
//


import Foundation
import Combine
import CoreBluetooth

// Single place to forward @Published properties to protocol publishers.
// IMPORTANT: Keep only these forwarders for OralableBLE — delete any other duplicate var ...Publisher definitions elsewhere.
extension OralableBLE {
    // ConnectionStateProvider - publisher forwarders
    var isConnectedPublisher: Published<Bool>.Publisher { $isConnected }
    var isScanningPublisher: Published<Bool>.Publisher { $isScanning }
    var deviceNamePublisher: Published<String>.Publisher { $deviceName }
    var deviceUUIDPublisher: Published<UUID?>.Publisher { $deviceUUID }
    var connectionStatePublisher: Published<String>.Publisher { $connectionState }
    var discoveredDevicesPublisher: Published<[CBPeripheral]>.Publisher { $discoveredDevices }
    var rssiPublisher: Published<Int>.Publisher { $rssi }

    // DeviceStatusProvider - publisher forwarders
    var deviceStatePublisher: Published<DeviceStateResult?>.Publisher { $deviceState }
    var ppgChannelOrderPublisher: Published<PPGChannelOrder>.Publisher { $ppgChannelOrder }
    var discoveredServicesPublisher: Published<[String]>.Publisher { $discoveredServices }
    var packetsReceivedPublisher: Published<Int>.Publisher { $packetsReceived }
    var logMessagesPublisher: Published<[LogMessage]>.Publisher { $logMessages }
    var lastErrorPublisher: Published<String?>.Publisher { $lastError }
    var isRecordingPublisher: Published<Bool>.Publisher { $isRecording }

    // Biometric / Realtime Sensor Publishers
    var heartRatePublisher: Published<Int>.Publisher { $heartRate }
    var spO2Publisher: Published<Int>.Publisher { $spO2 }
    var heartRateQualityPublisher: Published<Double>.Publisher { $heartRateQuality }
    var batteryLevelPublisher: Published<Double>.Publisher { $batteryLevel }

    // PPG Publishers - fixed names to match protocol requirements
    var ppgRedValuePublisher: Published<Double>.Publisher { $ppgRedValue }
    var ppgIRValuePublisher: Published<Double>.Publisher { $ppgIRValue }
    var ppgGreenValuePublisher: Published<Double>.Publisher { $ppgGreenValue }

    var accelXPublisher: Published<Double>.Publisher { $accelX }
    var accelYPublisher: Published<Double>.Publisher { $accelY }
    var accelZPublisher: Published<Double>.Publisher { $accelZ }
    var temperaturePublisher: Published<Double>.Publisher { $temperature }

    // Historical/legacy data
    var sensorDataHistoryPublisher: Published<[SensorData]>.Publisher { $sensorDataHistory }
}