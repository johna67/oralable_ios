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
    @ObservedObject private var bleManager = OralableBLE.shared
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(designSystem.colors.textPrimary)
                }
            }
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
            if !bleManager.discoveredDevicesInfo.isEmpty {
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    Text("AVAILABLE DEVICES")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                        .padding(.top, designSystem.spacing.md)
                    
                    ForEach(bleManager.discoveredDevicesInfo) { deviceInfo in
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
                Text("Discovered: \(bleManager.discoveredDevicesInfo.count) device(s)")
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
            print("[DevicesView] Ignoring rapid button press (debounced)")
            return
        }
        lastActionTime = now
        
        if bleManager.isConnected {
            print("[DevicesView] Action: Disconnect")
            bleManager.disconnect()
        } else if isScanning {
            print("[DevicesView] Action: Stop scanning")
            stopScanning()
        } else {
            print("[DevicesView] Action: Start scanning")
            startScanning()
        }
    }
    
    private func startScanning() {
        print("[DevicesView] Starting scan...")
        isScanning = true
        bleManager.startScanning()
        
        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            // Check both local and bleManager state to be safe
            if self.isScanning || self.bleManager.isScanning {
                if !self.bleManager.isConnected {
                    print("[DevicesView] Auto-stopping scan after 10 seconds")
                    self.stopScanning()
                }
            }
        }
    }
    
    private func stopScanning() {
        print("[DevicesView] Stopping scan...")
        isScanning = false
        bleManager.stopScanning()
        
        // Report findings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.isScanning && !self.bleManager.isScanning {
                print("[DevicesView] Scan stopped, found \(self.bleManager.discoveredDevicesInfo.count) device(s)")
            }
        }
    }
    
    // Connect to discovered device
    private func connectToDevice(peripheral: CBPeripheral) {
        print("[DevicesView] Connecting to device: \(peripheral.name ?? "Unknown")")
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
        print("Renaming device...")
    }
    
    private func updateFirmware() {
        // Placeholder for firmware update
        print("Checking for firmware updates...")
    }
    
    private func calibrateDevice() {
        // Placeholder for calibration
        print("Starting calibration...")
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
            .environmentObject(DesignSystem.shared)
    }
}
