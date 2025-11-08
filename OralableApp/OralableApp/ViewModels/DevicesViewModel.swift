//
//  DevicesViewModel.swift
//  OralableApp
//
//  Created: November 7, 2025
//  MVVM Architecture - Device discovery and connection business logic
//

import Foundation
import Combine
import CoreBluetooth

@MainActor
class DevicesViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable by View)
    
    /// All discovered devices
    @Published var discoveredDevices: [DeviceInfo] = []
    
    /// Currently connected devices
    @Published var connectedDevices: [DeviceInfo] = []
    
    /// Primary active device
    @Published var primaryDevice: DeviceInfo?
    
    /// Scanning state
    @Published var isScanning: Bool = false
    
    /// Connecting state
    @Published var isConnecting: Bool = false
    
    /// Last error encountered
    @Published var lastError: DeviceError?
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Show error alert
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let deviceManager: DeviceManager
    private var cancellables = Set<AnyCancellable>()
    private var errorDismissTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Number of discovered devices
    var discoveredCount: Int {
        discoveredDevices.count
    }
    
    /// Number of connected devices
    var connectedCount: Int {
        connectedDevices.count
    }
    
    /// Whether any devices are connected
    var hasConnectedDevices: Bool {
        !connectedDevices.isEmpty
    }
    
    /// Whether any devices are discovered
    var hasDiscoveredDevices: Bool {
        !discoveredDevices.isEmpty
    }
    
    /// Scan button text
    var scanButtonText: String {
        isScanning ? "Stop Scanning" : "Scan for Devices"
    }
    
    /// Status text for display
    var statusText: String {
        if isConnecting {
            return "Connecting..."
        } else if isScanning {
            return "Scanning for devices..."
        } else if hasConnectedDevices {
            return "\(connectedCount) device\(connectedCount == 1 ? "" : "s") connected"
        } else if hasDiscoveredDevices {
            return "\(discoveredCount) device\(discoveredCount == 1 ? "" : "s") found"
        } else {
            return "No devices found"
        }
    }
    
    /// Primary device name
    var primaryDeviceName: String {
        primaryDevice?.name ?? "No Device"
    }
    
    /// Primary device connection status
    var primaryDeviceStatus: String {
        primaryDevice?.connectionState.displayName ?? "Disconnected"
    }
    
    // MARK: - Initialization
    
    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to device manager's published properties
        deviceManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredDevices)
        
        deviceManager.$connectedDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedDevices)
        
        deviceManager.$primaryDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$primaryDevice)
        
        deviceManager.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)
        
        deviceManager.$isConnecting
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnecting)
        
        deviceManager.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Scanning
    
    /// Start scanning for devices
    func startScanning() {
        Task {
            await deviceManager.startScanning()
        }
    }
    
    /// Stop scanning for devices
    func stopScanning() {
        deviceManager.stopScanning()
    }
    
    /// Toggle scanning state
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    /// Refresh scan (stop and restart)
    func refreshScan() {
        stopScanning()
        // Brief delay before restarting
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await deviceManager.startScanning()
        }
    }
    
    /// Refresh devices - used by pull-to-refresh
    func refreshDevices() async {
        stopScanning()
        // Brief delay before restarting
        try? await Task.sleep(nanoseconds: 500_000_000)
        await deviceManager.startScanning()
    }
    
    /// Check Bluetooth permission status
    func checkBluetoothPermission() {
        // Check if Bluetooth is available and authorized
        // The DeviceManager will handle the actual permission state
        if !isScanning && connectedDevices.isEmpty {
            startScanning()
        }
    }
    
    // MARK: - Public Methods - Connection
    
    /// Connect to a specific device
    func connect(to deviceInfo: DeviceInfo) {
        Task {
            do {
                try await deviceManager.connect(to: deviceInfo)
            } catch {
                handleError(error as? DeviceError ?? .unknownError(error.localizedDescription))
            }
        }
    }
    
    /// Disconnect from a specific device
    func disconnect(from deviceInfo: DeviceInfo) {
        Task {
            await deviceManager.disconnect(from: deviceInfo)
        }
    }
    
    /// Disconnect all connected devices
    func disconnectAll() {
        Task {
            await deviceManager.disconnectAll()
        }
    }
    
    /// Set primary device
    func setPrimaryDevice(_ deviceInfo: DeviceInfo) {
        deviceManager.setPrimaryDevice(deviceInfo)
    }
    
    // MARK: - Public Methods - Device Info
    
    /// Get device by ID
    func device(withId id: UUID) -> DeviceInfo? {
        discoveredDevices.first { $0.id == id }
    }
    
    /// Check if device is connected
    func isConnected(_ deviceInfo: DeviceInfo) -> Bool {
        connectedDevices.contains { $0.id == deviceInfo.id }
    }
    
    /// Check if device is primary
    func isPrimary(_ deviceInfo: DeviceInfo) -> Bool {
        primaryDevice?.id == deviceInfo.id
    }
    
    /// Get devices by type
    func devices(ofType type: DeviceType) -> [DeviceInfo] {
        discoveredDevices.filter { $0.type == type }
    }
    
    /// Get Oralable devices
    var oralableDevices: [DeviceInfo] {
        devices(ofType: .oralable)
    }
    
    /// Get ANR Muscle Sense devices
    var anrDevices: [DeviceInfo] {
        devices(ofType: .anrMuscleSense)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: DeviceError?) {
        // Cancel any pending dismiss task
        errorDismissTask?.cancel()
        
        guard let error = error else {
            errorMessage = nil
            showError = false
            lastError = nil
            return
        }
        
        lastError = error
        errorMessage = error.errorDescription ?? "Unknown error occurred"
        showError = true
        
        // Auto-dismiss error after 3 seconds
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            // Only dismiss if the task wasn't cancelled
            if !Task.isCancelled && self.showError {
                await MainActor.run {
                    self.dismissError()
                }
            }
        }
    }
    
    /// Dismiss error alert
    func dismissError() {
        errorDismissTask?.cancel()
        showError = false
        errorMessage = nil
        lastError = nil
    }
    
    // MARK: - Utility Methods
    
    /// Clear all discovered devices (when not scanning)
    func clearDiscoveredDevices() {
        guard !isScanning else { return }
        discoveredDevices.removeAll()
    }
    
    /// Get connection button text for device
    func connectionButtonText(for deviceInfo: DeviceInfo) -> String {
        if isConnected(deviceInfo) {
            return "Disconnect"
        } else if deviceInfo.isConnecting {
            return "Connecting..."
        } else {
            return "Connect"
        }
    }
    
    /// Whether connection button should be disabled
    func isConnectionButtonDisabled(for deviceInfo: DeviceInfo) -> Bool {
        deviceInfo.isConnecting || isConnecting
    }
}

// MARK: - Mock for Previews

extension DevicesViewModel {
    static func mock() -> DevicesViewModel {
        let mockManager = DeviceManager()
        let viewModel = DevicesViewModel(deviceManager: mockManager)
        
        // Add mock devices
        viewModel.discoveredDevices = [
            DeviceInfo.mock(type: .oralable),
            DeviceInfo(
                type: .oralable,
                name: "Oralable-002",
                peripheralIdentifier: UUID(),
                connectionState: .disconnected,
                batteryLevel: 65,
                signalStrength: -70
            ),
            DeviceInfo(
                type: .anrMuscleSense,
                name: "ANR-MS-001",
                peripheralIdentifier: UUID(),
                connectionState: .disconnected,
                batteryLevel: 90,
                signalStrength: -45
            )
        ]
        
        viewModel.connectedDevices = [
            DeviceInfo.mock(type: .oralable)
        ]
        
        viewModel.primaryDevice = DeviceInfo.mock(type: .oralable)
        
        return viewModel
    }
}
