// DevicesViewModel.swift
import Foundation
import Combine
import CoreBluetooth

@MainActor
class DevicesViewModel: ObservableObject {
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

    private let bleManager: BLEManagerProtocol
    private var cancellables = Set<AnyCancellable>()

    init(bleManager: BLEManagerProtocol = DeviceManager.shared) {
        self.bleManager = bleManager
        setupBindings()
    }

    private func setupBindings() {
        bleManager.isConnectedPublisher
            .assign(to: &$isConnected)

        bleManager.isScanningPublisher
            .assign(to: &$isScanning)

        // deviceName is computed, so we observe the BLE manager's objectWillChange
        // Type-erase the publisher to work with protocol types
        bleManager.objectWillChange
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.deviceName = self.bleManager.deviceName
            }
            .store(in: &cancellables)
    }

    func toggleScanning() {
        if isScanning {
            bleManager.stopScanning()
        } else {
            bleManager.startScanning()
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
