//
//  DevicesView.swift
//  OralableApp
//
//  Device management and settings view
//

import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @StateObject private var bleManager = OralableBLE.shared
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    
    @State private var showingSettings = false
    @State private var isScanning = false
    @State private var showingForgetDevice = false
    
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
    }
    
    // MARK: - Connection Card
    private var connectionCard: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Status Icon
            Image(systemName: bleManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(bleManager.isConnected ? .green : designSystem.colors.textTertiary)
                .animation(.easeInOut, value: bleManager.isConnected)
            
            // Status Text
            Text(connectionStatusText)
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)
            
            // Device Name
            if bleManager.isConnected {
                Text(bleManager.deviceName)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
            } else if isScanning {
                HStack(spacing: designSystem.spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching for devices...")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(designSystem.spacing.xl)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    private var connectionStatusText: String {
        if bleManager.isConnected {
            return "Connected"
        } else if isScanning {
            return "Scanning"
        } else {
            return "Disconnected"
        }
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("AVAILABLE DEVICES")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: designSystem.spacing.sm) {
                if isScanning {
                    // Mock discovered devices
                    ForEach(0..<2) { index in
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(designSystem.colors.textSecondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Oralable-\(String(format: "%03d", index + 1))")
                                    .font(designSystem.typography.body)
                                    .foregroundColor(designSystem.colors.textPrimary)
                                Text("Signal: -\(45 + index * 5) dBm")
                                    .font(designSystem.typography.caption)
                                    .foregroundColor(designSystem.colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button("Connect") {
                                connectToDevice(index: index)
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
                } else {
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
                    value: "Oralable PPG"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "number",
                    label: "Serial",
                    value: "ORA-2025-001"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "app.badge",
                    label: "Firmware",
                    value: "v1.0.0"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "hammer",
                    label: "Hardware",
                    value: "Rev A"
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Metrics Card
    private var deviceMetricsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("DEVICE METRICS")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: 0) {
                // Battery with visual indicator
                HStack {
                    Image(systemName: "battery.100")
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text("Battery")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                    Spacer()
                    
                    HStack(spacing: designSystem.spacing.xs) {
                        // Battery bar visualization
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(designSystem.colors.backgroundTertiary)
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(batteryColor)
                                    .frame(
                                        width: geometry.size.width * CGFloat(bleManager.batteryLevel / 100),
                                        height: 8
                                    )
                            }
                        }
                        .frame(width: 60, height: 8)
                        
                        Text("\(Int(bleManager.batteryLevel))%")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                .padding(designSystem.spacing.md)
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "wifi",
                    label: "Signal Strength",
                    value: "\(bleManager.rssi) dBm"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "clock",
                    label: "Connected For",
                    value: connectionDuration
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "waveform",
                    label: "Data Rate",
                    value: "50 Hz"
                )
                
                Divider().background(designSystem.colors.divider)
                
                DeviceInfoRow(
                    icon: "arrow.up.arrow.down",
                    label: "Packets Received",
                    value: "\(bleManager.packetsReceived)"
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Settings Card
    private var deviceSettingsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("QUICK SETTINGS")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.horizontal, designSystem.spacing.xs)
            
            VStack(spacing: designSystem.spacing.sm) {
                // LED Brightness
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    HStack {
                        Image(systemName: "light.max")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("LED Brightness")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Text("Auto")
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    
                    // Brightness slider (placeholder)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(designSystem.colors.backgroundTertiary)
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: geometry.size.width * 0.7, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.medium)
                
                // Sample Rate
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text("Sample Rate")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                    Spacer()
                    Text("50 Hz")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.medium)
                
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
            }
            .foregroundColor(designSystem.colors.textSecondary)
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Helper Properties
    private var batteryColor: Color {
        if bleManager.batteryLevel < 20 {
            return .red
        } else if bleManager.batteryLevel < 50 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var connectionDuration: String {
        // This would calculate from actual connection timestamp
        "5 min 32 sec"
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
        if bleManager.isConnected {
            bleManager.disconnect()
        } else if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    private func startScanning() {
        isScanning = true
        bleManager.startScanning()
        
        // Stop scanning after 10 seconds if nothing found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if isScanning && !bleManager.isConnected {
                stopScanning()
            }
        }
    }
    
    private func stopScanning() {
        isScanning = false
        bleManager.stopScanning()
    }
    
    private func connectToDevice(index: Int) {
        // This would connect to actual discovered device
        stopScanning()
        // bleManager.connect(to: device)
    }
    
    private func forgetDevice() {
        bleManager.disconnect()
        // Clear saved device from UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedDeviceUUID")
    }
    
    private func updateFirmware() {
        // Placeholder for firmware update
        print("Checking for firmware updates...")
    }
    
    private func calibrateDevice() {
        // Placeholder for calibration
        print("Starting calibration...")
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
