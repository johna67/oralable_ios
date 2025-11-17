// DevicesViewModel.swift
import Foundation
import Combine
import CoreBluetooth

@MainActor
class DevicesViewModel: BaseViewModel {
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var deviceName: String = "Oralable-001"
    @Published var batteryLevel: Int = 85
    @Published var signalStrength: Int = -45
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice: ConnectedDeviceInfo?

    // Settings
    @Published var autoConnect: Bool = true
    @Published var ledBrightness: Double = 0.5
    @Published var sampleRate: Int = 50

    // Device info
    var serialNumber: String { "ORA-2025-001" }
    var firmwareVersion: String { "1.0.0" }
    var lastSyncTime: String { "Just now" }

    private let bleManager = DeviceManager.shared

    override init() {
        super.init()
        setupBindings()
    }
    
    private func setupBindings() {
        bleManager.$isConnected
            .assign(to: &$isConnected)
        
        bleManager.$isScanning
            .assign(to: &$isScanning)
        
        bleManager.$deviceName
            .assign(to: &$deviceName)
    }
    
    func toggleScanning() {
        if isScanning {
            bleManager.stopScanning()
        } else {
            Task { await bleManager.startScanning() }
        }
    }
    
    func connect(to device: DiscoveredDevice) {
        // Implement connection logic
        print("Connecting to \(device.name)")
    }
    
    func disconnect() {
        bleManager.disconnect()
    }
}

// Supporting types
struct DiscoveredDevice: Identifiable {
    let id = UUID()
    let name: String
    let rssi: Int
    let isOralable: Bool
}

struct ConnectedDeviceInfo {
    let name: String
    let model: String
    let firmware: String
}
