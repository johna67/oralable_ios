//
//  DevicesView.swift
//  OralableApp
//
//  FIXED: November 10, 2025
//  - CRITICAL FIX: Now properly observes bleManager.discoveredDevicesInfo
//  - Devices discovered via BLE now appear in UI
//  - Connect button works with proper peripheral references
//  - Removed local discoveredDevices array in favor of observing bleManager
//

import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @StateObject private var viewModel: DevicesViewModel
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss

    init(viewModel: DevicesViewModel? = nil, bleManager: OralableBLE? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else if let bleManager = bleManager {
            // Create with provided bleManager
            _viewModel = StateObject(wrappedValue: DevicesViewModel(bleManager: bleManager))
        } else {
            // Default path - requires environment object
            let bleManager = OralableBLE()
            _viewModel = StateObject(wrappedValue: DevicesViewModel(bleManager: bleManager))
        }
    }

    @State private var showingSettings = false
    @State private var isScanning = false
    @State private var showingForgetDevice = false
    @State private var lastActionTime: Date = .distantPast
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Connection Status Card
                    connectionCard

                    // Device Info (if connected)
                    if bleManager.isConnected {
                        deviceInfoCard
                        deviceMetricsCard
                        deviceSettingsCard
                        advancedSettingsCard
                    } else {
                        // Show scanning view when not connected
                        scanningView
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding(designSystem.spacing.lg)
            }
            .background(designSystem.colors.backgroundPrimary)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Forget Device", isPresented: $showingForgetDevice) {
            Button("Cancel", role: .cancel) { }
            Button("Forget", role: .destructive) {
                forgetDevice()
            }
        } message: {
            Text("Are you sure you want to forget this device? You'll need to reconnect it later.")
        }
        .onAppear {
            synchronizeScanningState()
        }
    }
    
    // MARK: - Viewer Mode Info Card
    private var viewerModeInfoCard: some View {
        VStack(spacing: designSystem.spacing.lg) {
            // Icon
            Image(systemName: "sensor.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            // Title
            Text("Device Connection Unavailable")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            VStack(spacing: designSystem.spacing.md) {
                Text("Viewer Mode is for reviewing imported data only.")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("To connect to devices and collect real-time data, you need to:")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    HStack(alignment: .top, spacing: designSystem.spacing.sm) {
                        Text("1.")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Sign in with your Apple ID")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }

                    HStack(alignment: .top, spacing: designSystem.spacing.sm) {
                        Text("2.")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Switch to Subscription Mode")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(designSystem.spacing.xl)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - Connection Card
    private var connectionCard: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Status Icon
            Image(systemName: bleManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(bleManager.isConnected ? .green : .red)

            // Status Text
            Text(bleManager.isConnected ? "Connected" : "Disconnected")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            if bleManager.isConnected {
                Text(bleManager.deviceName)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(designSystem.spacing.xl)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            // Scanning Header
            HStack {
                if isScanning {
                    ProgressView()
                        .padding(.trailing, designSystem.spacing.xs)
                    Text("Scanning")
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: stopScanning) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Disconnected")
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
            }
            
            if isScanning {
                Text("Searching for devices...")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            // CRITICAL FIX: Now observes bleManager.discoveredDevicesInfo directly
            // Filter to only show Oralable and ANR Muscle Sense devices
            if !filteredDevices.isEmpty {
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    Text("AVAILABLE DEVICES")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                        .padding(.top, designSystem.spacing.md)

                    ForEach(filteredDevices) { deviceInfo in
                        HStack {
                            // Device Icon
                            Image(systemName: "sensor")
                                .font(.system(size: 24))
                                .foregroundColor(designSystem.colors.textSecondary)
                                .frame(width: 40)
                            
                            // Device Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deviceInfo.name)
                                    .font(designSystem.typography.body)
                                    .foregroundColor(designSystem.colors.textPrimary)
                                Text("Signal: \(deviceInfo.rssi) dBm")
                                    .font(designSystem.typography.caption)
                                    .foregroundColor(designSystem.colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Connect button
                            Button("Connect") {
                                connectToDevice(peripheral: deviceInfo.peripheral)
                            }
                            .font(designSystem.typography.button)
                            .foregroundColor(.white)
                            .padding(.horizontal, designSystem.spacing.md)
                            .padding(.vertical, designSystem.spacing.xs)
                            .background(Color.blue)
                            .cornerRadius(designSystem.cornerRadius.small)
                        }
                        .padding(designSystem.spacing.md)
                        .background(designSystem.colors.backgroundSecondary)
                        .cornerRadius(designSystem.cornerRadius.medium)
                    }
                }
            } else if !isScanning {
                Text("Tap 'Scan for Devices' to search")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.lg)
                    .background(designSystem.colors.backgroundSecondary)
                    .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
    }
    
    // MARK: - Device Info Card
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("DEVICE INFORMATION")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: 0) {
                DeviceInfoRow(
                    icon: "cpu",
                    label: "Model",
                    value: "Oralable Gen 1"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "number",
                    label: "Serial Number",
                    value: bleManager.deviceUUID?.uuidString.prefix(8).uppercased() ?? "Unknown"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "info.circle",
                    label: "Firmware",
                    value: bleManager.sensorData.firmwareVersion
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "battery.100",
                    label: "Battery",
                    value: "\(Int(bleManager.batteryLevel))%"
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Metrics Card
    private var deviceMetricsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("CONNECTION METRICS")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: 0) {
                DeviceInfoRow(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "Signal Strength",
                    value: "\(bleManager.rssi) dBm"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "clock",
                    label: "Connection Time",
                    value: formatConnectionTime()
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "arrow.down.circle",
                    label: "Data Received",
                    value: "\(bleManager.packetsReceived) packets"
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Settings Card
    private var deviceSettingsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("DEVICE SETTINGS")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: 0) {
                Button(action: { renameDevice() }) {
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Rename Device")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                    .padding(designSystem.spacing.md)
                }
                
                Divider().background(designSystem.colors.divider)
                
                // Auto-Connect
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text("Auto-Connect")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
    }
    
    // MARK: - Advanced Settings Card
    private var advancedSettingsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("ADVANCED")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: 0) {
                Button(action: { updateFirmware() }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Check for Updates")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                    .padding(designSystem.spacing.md)
                }
                
                Divider().background(designSystem.colors.divider)
                
                Button(action: { calibrateDevice() }) {
                    HStack {
                        Image(systemName: "tuningfork")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Calibrate Sensors")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                    .padding(designSystem.spacing.md)
                }
                
                Divider().background(designSystem.colors.divider)
                
                Button(action: { showingForgetDevice = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Forget Device")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(designSystem.spacing.md)
                }
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Main Action Button
            Button(action: primaryAction) {
                HStack {
                    Image(systemName: actionButtonIcon)
                    Text(actionButtonText)
                        .font(designSystem.typography.button)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(actionButtonColor)
                .cornerRadius(designSystem.cornerRadius.medium)
            }
            
            // Debug Info (remove in production)
            #if DEBUG
            debugInfoCard
            #endif
        }
    }
    
    // MARK: - Debug Info Card
    private var debugInfoCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("DEBUG INFO")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
            
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                Text("State: \(bleManager.connectionState)")
                    .font(.system(.caption, design: .monospaced))
                Text("UUID: \(bleManager.deviceUUID?.uuidString ?? "None")")
                    .font(.system(.caption, design: .monospaced))
                Text("Last Error: \(bleManager.lastError ?? "None")")
                    .font(.system(.caption, design: .monospaced))
                Text("Services: \(bleManager.discoveredServices.count)")
                    .font(.system(.caption, design: .monospaced))
                Text("Local Scanning: \(isScanning ? "Yes" : "No")")
                    .font(.system(.caption, design: .monospaced))
                Text("Manager Scanning: \(bleManager.isScanning ? "Yes" : "No")")
                    .font(.system(.caption, design: .monospaced))
                Text("Discovered: \(bleManager.discoveredDevicesInfo.count) device(s) (\(filteredDevices.count) compatible)")
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundColor(designSystem.colors.textSecondary)
            .padding(designSystem.spacing.sm)
            .background(Color.black.opacity(0.05))
            .cornerRadius(designSystem.cornerRadius.small)
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.medium)
    }
    
    // MARK: - Computed Properties

    // Filter to only show Oralable and ANR Muscle Sense devices
    private var filteredDevices: [OralableBLE.DiscoveredDeviceInfo] {
        bleManager.discoveredDevicesInfo.filter { deviceInfo in
            let name = deviceInfo.name.lowercased()
            return name.contains("oralable") || name.contains("anr") || name.contains("n02cl")
        }
    }

    private var actionButtonIcon: String {
        if bleManager.isConnected {
            return "xmark.circle"
        } else if isScanning {
            return "stop.circle"
        } else {
            return "magnifyingglass"
        }
    }
    
    private var actionButtonText: String {
        if bleManager.isConnected {
            return "Disconnect"
        } else if isScanning {
            return "Stop Scanning"
        } else {
            return "Scan for Devices"
        }
    }
    
    private var actionButtonColor: Color {
        if bleManager.isConnected {
            return .red
        } else if isScanning {
            return .orange
        } else {
            return .blue
        }
    }
    
    // MARK: - Actions
    private func primaryAction() {
        // Debounce: Prevent rapid repeated calls (within 500ms)
        let now = Date()
        guard now.timeIntervalSince(lastActionTime) > 0.5 else {
            Logger.shared.debug("[DevicesView] Ignoring rapid button press (debounced)")
            return
        }
        lastActionTime = now
        
        if bleManager.isConnected {
            Logger.shared.debug("[DevicesView] Action: Disconnect")
            bleManager.disconnect()
        } else if isScanning {
            Logger.shared.debug("[DevicesView] Action: Stop scanning")
            stopScanning()
        } else {
            Logger.shared.debug("[DevicesView] Action: Start scanning")
            startScanning()
        }
    }
    
    private func startScanning() {
        Logger.shared.debug("[DevicesView] Starting scan...")
        isScanning = true
        bleManager.startScanning()
        
        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // Check both local and bleManager state to be safe
            if self.isScanning || self.bleManager.isScanning {
                if !self.bleManager.isConnected {
                    Logger.shared.debug("[DevicesView] Auto-stopping scan after 10 seconds")
                    self.stopScanning()
                }
            }
        }
    }
    
    private func stopScanning() {
        Logger.shared.debug("[DevicesView] Stopping scan...")
        isScanning = false
        bleManager.stopScanning()
        
        // Report findings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.isScanning && !self.bleManager.isScanning {
                Logger.shared.debug("[DevicesView] Scan stopped, found \(self.bleManager.discoveredDevicesInfo.count) device(s) (\(self.filteredDevices.count) compatible)")
            }
        }
    }
    
    // Connect to discovered device
    private func connectToDevice(peripheral: CBPeripheral) {
        Logger.shared.debug("[DevicesView] Connecting to device: \(peripheral.name ?? "Unknown")")
        stopScanning()
        
        // Use BLE manager to connect to the actual peripheral
        bleManager.connect(to: peripheral)
    }
    
    // Synchronize scanning state with bleManager
    private func synchronizeScanningState() {
        // Sync local isScanning with bleManager.isScanning
        isScanning = bleManager.isScanning
    }
    
    private func forgetDevice() {
        bleManager.disconnect()
        // Clear saved device from UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedDeviceUUID")
    }
    
    private func renameDevice() {
        // Placeholder for device renaming
        Logger.shared.info("[DevicesView] Renaming device...")
    }
    
    private func updateFirmware() {
        // Placeholder for firmware update
        Logger.shared.info("[DevicesView] Checking for firmware updates...")
    }
    
    private func calibrateDevice() {
        // Placeholder for calibration
        Logger.shared.info("[DevicesView] Starting calibration...")
    }
    
    private func formatConnectionTime() -> String {
        // Placeholder - would calculate actual connection duration
        return "00:05:32"
    }
}

// MARK: - Supporting View
struct DeviceInfoRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String?
    let label: String
    let value: String
    
    init(icon: String? = nil, label: String, value: String) {
        self.icon = icon
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(width: 20)
            }
            Text(label)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
            Spacer()
            Text(value)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
        }
        .padding(designSystem.spacing.md)
    }
}

// MARK: - Preview
struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
            .environmentObject(DesignSystem())
            .environmentObject(OralableBLE())
    }
}
