//
//  DevicesView.swift
//  OralableApp
//
//  Created: November 8, 2025
//  Simplified device view for single-device launch
//

import SwiftUI

struct DevicesView: View {
    @StateObject private var viewModel = DevicesViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDeviceDetails = false
    @State private var showingScanSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Connected Device Card
                    if viewModel.isConnected {
                        connectedDeviceCard
                    }
                    
                    // Scan Button (if not connected)
                    if !viewModel.isConnected {
                        scanSection
                    }
                    
                    // Discovered Devices (if scanning)
                    if viewModel.isScanning && !viewModel.discoveredDevices.isEmpty {
                        discoveredDevicesSection
                    }
                    
                    // Device Information
                    if viewModel.isConnected {
                        deviceInfoSection
                    }
                    
                    // Device Settings
                    if viewModel.isConnected {
                        deviceSettingsSection
                    }
                }
                .padding(designSystem.spacing.md)
            }
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
            .background(designSystem.colors.backgroundPrimary)
        }
        .sheet(isPresented: $showingDeviceDetails) {
            DeviceDetailsSheet(device: viewModel.connectedDevice)
        }
    }
    
    // MARK: - Connected Device Card
    
    private var connectedDeviceCard: some View {
        VStack(spacing: designSystem.spacing.md) {
            HStack {
                // Device Icon
                Image(systemName: "cpu")
                    .font(.system(size: 40))
                    .foregroundColor(designSystem.colors.textPrimary)
                    .frame(width: 60, height: 60)
                    .background(designSystem.colors.backgroundTertiary)
                    .cornerRadius(designSystem.cornerRadius.medium)
                
                VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                    Text(viewModel.deviceName)
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                    
                    Text("Oralable PPG Device")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    
                    HStack(spacing: designSystem.spacing.sm) {
                        // Connection Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Connected")
                                .font(designSystem.typography.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Battery
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon)
                                .font(.system(size: 12))
                            Text("\(viewModel.batteryLevel)%")
                                .font(designSystem.typography.caption)
                        }
                        .foregroundColor(batteryColor)
                        
                        // Signal Strength
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .font(.system(size: 12))
                            Text("\(viewModel.signalStrength)dB")
                                .font(designSystem.typography.caption)
                        }
                        .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Disconnect Button
            Button(action: { viewModel.disconnect() }) {
                Text("Disconnect")
                    .font(designSystem.typography.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.sm)
                    .background(Color.red)
                    .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Scan Section
    
    private var scanSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            // No Device Connected Message
            VStack(spacing: designSystem.spacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundColor(designSystem.colors.textSecondary)
                
                Text("No Device Connected")
                    .font(designSystem.typography.h3)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Text("Scan for nearby Oralable devices")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(designSystem.spacing.xl)
            
            // Scan Button
            Button(action: { viewModel.toggleScanning() }) {
                HStack {
                    if viewModel.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    
                    Text(viewModel.isScanning ? "Scanning..." : "Scan for Devices")
                }
                .font(designSystem.typography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(viewModel.isScanning ? Color.orange : designSystem.colors.primaryBlack)
                .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Discovered Devices Section
    
    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Discovered Devices")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: designSystem.spacing.sm) {
                ForEach(viewModel.discoveredDevices) { device in
                    DiscoveredDeviceRow(device: device) {
                        viewModel.connect(to: device)
                    }
                }
            }
        }
    }
    
    // MARK: - Device Info Section
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Device Information")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                DeviceInfoRow(label: "Model", value: "Oralable v1.0")
                Divider().padding(.horizontal)
                DeviceInfoRow(label: "Serial", value: viewModel.serialNumber)
                Divider().padding(.horizontal)
                DeviceInfoRow(label: "Firmware", value: viewModel.firmwareVersion)
                Divider().padding(.horizontal)
                DeviceInfoRow(label: "Last Sync", value: viewModel.lastSyncTime)
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Settings Section
    
    private var deviceSettingsSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Settings")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                // Auto-connect Toggle
                Toggle(isOn: $viewModel.autoConnect) {
                    HStack {
                        Image(systemName: "link.circle")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("Auto-connect")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                .padding(designSystem.spacing.md)
                
                Divider().padding(.horizontal)
                
                // LED Brightness Slider
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    HStack {
                        Image(systemName: "light.max")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Text("LED Brightness")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Text("\(Int(viewModel.ledBrightness * 100))%")
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    
                    Slider(value: $viewModel.ledBrightness, in: 0.1...1.0)
                        .accentColor(designSystem.colors.primaryBlack)
                }
                .padding(designSystem.spacing.md)
                
                Divider().padding(.horizontal)
                
                // Sample Rate Picker
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text("Sample Rate")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                    Spacer()
                    Picker("", selection: $viewModel.sampleRate) {
                        Text("25 Hz").tag(25)
                        Text("50 Hz").tag(50)
                        Text("100 Hz").tag(100)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }
                .padding(designSystem.spacing.md)
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Helpers
    
    private var batteryIcon: String {
        switch viewModel.batteryLevel {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    private var batteryColor: Color {
        switch viewModel.batteryLevel {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

// MARK: - Supporting Views

struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        HStack {
            Image(systemName: "cpu")
                .foregroundColor(designSystem.colors.textPrimary)
                .frame(width: 40, height: 40)
                .background(designSystem.colors.backgroundTertiary)
                .cornerRadius(designSystem.cornerRadius.small)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                HStack(spacing: designSystem.spacing.sm) {
                    Text("RSSI: \(device.rssi) dBm")
                    Text("•")
                    Text(device.isOralable ? "Oralable" : "Unknown")
                }
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Spacer()
            
            Button("Connect") {
                onConnect()
            }
            .font(designSystem.typography.button)
            .foregroundColor(designSystem.colors.primaryBlack)
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.medium)
    }
}

struct DeviceDetailsSheet: View {
    let device: ConnectedDeviceInfo?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let device = device {
                    VStack(spacing: designSystem.spacing.lg) {
                        Text("Device details will be shown here")
                    }
                    .padding()
                } else {
                    Text("No device connected")
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DeviceInfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        HStack {
            Text(label)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(designSystem.typography.bodyMedium)
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
