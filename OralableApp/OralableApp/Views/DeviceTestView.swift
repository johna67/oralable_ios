//
//  DeviceTestView.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Test view for device integration
//

import SwiftUI

struct DeviceTestView: View {
    @StateObject private var deviceManager = DeviceManager()
    @State private var autoStopTimer: Timer?
    
    // For preview/testing purposes
    private let previewDeviceManager: DeviceManager?
    
    init(previewDeviceManager: DeviceManager? = nil) {
        self.previewDeviceManager = previewDeviceManager
    }
    
    private var currentDeviceManager: DeviceManager {
        previewDeviceManager ?? deviceManager
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Scanning Section
                Section {
                    if currentDeviceManager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, DesignSystem.Spacing.xs)
                            Text("Scanning for devices...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                        
                        Button("Stop Scanning") {
                            currentDeviceManager.stopScanning()
                        }
                        .font(DesignSystem.Typography.buttonMedium)
                        .foregroundColor(DesignSystem.Colors.error)
                    } else {
                        Button {
                            Task {
                                await currentDeviceManager.startScanning()
                                
                                // Auto-stop after 30 seconds
                                autoStopTimer?.invalidate()
                                autoStopTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
                                    currentDeviceManager.stopScanning()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Start Scanning")
                            }
                            .font(DesignSystem.Typography.buttonMedium)
                        }
                    }
                } header: {
                    Text("Bluetooth Scanning")
                        .font(DesignSystem.Typography.labelMedium)
                }
                
                // MARK: - Discovered Devices Section
                Section {
                    if currentDeviceManager.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .italic()
                    } else {
                        ForEach(currentDeviceManager.discoveredDevices) { device in
                            DeviceRowView(device: device, deviceManager: currentDeviceManager)
                        }
                    }
                } header: {
                    HStack {
                        Text("Discovered Devices")
                            .font(DesignSystem.Typography.labelMedium)
                        Spacer()
                        Text("\(currentDeviceManager.discoveredDevices.count)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                // MARK: - Connected Devices Section
                if !currentDeviceManager.connectedDevices.isEmpty {
                    Section {
                        ForEach(currentDeviceManager.connectedDevices) { device in
                            ConnectedDeviceRowView(device: device, deviceManager: currentDeviceManager)
                        }
                    } header: {
                        HStack {
                            Text("Connected Devices")
                                .font(DesignSystem.Typography.labelMedium)
                            Spacer()
                            Text("\(currentDeviceManager.connectedDevices.count)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                // MARK: - Latest Readings Section
                if !currentDeviceManager.latestReadings.isEmpty {
                    Section {
                        ForEach(Array(currentDeviceManager.latestReadings.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { sensorType in
                            if let reading = currentDeviceManager.latestReadings[sensorType] {
                                SensorReadingRowView(reading: reading)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Latest Sensor Readings")
                                .font(DesignSystem.Typography.labelMedium)
                            Spacer()
                            Text("\(currentDeviceManager.latestReadings.count)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                // MARK: - Actions Section
                Section {
                    Button("Clear All Data") {
                        currentDeviceManager.clearReadings()
                    }
                    .font(DesignSystem.Typography.buttonMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Button("Disconnect All") {
                        Task {
                            await currentDeviceManager.disconnectAll()
                        }
                    }
                    .font(DesignSystem.Typography.buttonMedium)
                    .foregroundColor(DesignSystem.Colors.error)
                    .disabled(currentDeviceManager.connectedDevices.isEmpty)
                } header: {
                    Text("Actions")
                        .font(DesignSystem.Typography.labelMedium)
                }
            }
            .navigationTitle("Device Test")
            .navigationBarTitleDisplayMode(.large)
        }
        .onDisappear {
            autoStopTimer?.invalidate()
            currentDeviceManager.stopScanning()
        }
    }
}

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: DeviceInfo
    @ObservedObject var deviceManager: DeviceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Device Name and Icon
            HStack {
                Image(systemName: device.type.iconName)
                    .font(.system(size: DesignSystem.Sizing.Icon.lg))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(DesignSystem.Typography.bodyLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(device.type.displayName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Connection Status
                if device.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                        .font(.system(size: DesignSystem.Sizing.Icon.lg))
                } else if device.isConnecting {
                    ProgressView()
                }
            }
            
            // Signal Strength
            if let rssi = device.signalStrength {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: signalIcon(for: rssi))
                        .font(.system(size: DesignSystem.Sizing.Icon.sm))
                        .foregroundColor(signalColor(for: rssi))
                    
                    Text("\(device.signalText ?? "Unknown") (\(rssi) dB)")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            
            // Connection Button
            if !device.isConnected && !device.isConnecting {
                Button {
                    Task {
                        do {
                            try await deviceManager.connect(to: device)
                        } catch {
                            print("❌ Connection failed: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect")
                    }
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .buttonStyle(.plain)
            } else if device.isConnected {
                Button {
                    Task {
                        await deviceManager.disconnect(from: device)
                    }
                } label: {
                    HStack {
                        Image(systemName: "link.slash")
                        Text("Disconnect")
                    }
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundColor(DesignSystem.Colors.error)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private func signalIcon(for rssi: Int) -> String {
        switch rssi {
        case -50...0: return "antenna.radiowaves.left.and.right"
        case -70 ..< -50: return "wifi.circle"
        case -85 ..< -70: return "wifi.circle.fill"
        default: return "wifi.slash"
        }
    }
    
    private func signalColor(for rssi: Int) -> Color {
        switch rssi {
        case -50...0: return DesignSystem.Colors.success
        case -70 ..< -50: return DesignSystem.Colors.success
        case -85 ..< -70: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Connected Device Row View

struct ConnectedDeviceRowView: View {
    let device: DeviceInfo
    @ObservedObject var deviceManager: DeviceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Device Name
            HStack {
                Image(systemName: device.type.iconName)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(device.name)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if deviceManager.primaryDevice?.id == device.id {
                    Text("PRIMARY")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.success)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.success.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            
            // Battery Level
            if let battery = device.batteryLevel {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: batteryIcon(for: battery))
                        .foregroundColor(batteryColor(for: battery))
                    
                    Text("\(battery)%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Firmware Version
            if let firmware = device.firmwareVersion {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    
                    Text("Firmware: \(firmware)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Set Primary Button
            if deviceManager.primaryDevice?.id != device.id {
                Button("Set as Primary") {
                    deviceManager.setPrimaryDevice(device)
                }
                .font(DesignSystem.Typography.buttonSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 50...100: return DesignSystem.Colors.success
        case 20..<50: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Sensor Reading Row View

struct SensorReadingRowView: View {
    let reading: SensorReading
    
    var body: some View {
        HStack {
            Image(systemName: reading.sensorType.iconName)
                .font(.system(size: DesignSystem.Sizing.Icon.md))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.sensorType.displayName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(timeAgo(from: reading.timestamp))
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(reading.formattedValue)
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                if reading.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DesignSystem.Sizing.Icon.xs))
                        .foregroundColor(DesignSystem.Colors.success)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DesignSystem.Sizing.Icon.xs))
                        .foregroundColor(DesignSystem.Colors.error)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 2 {
            return "Just now"
        } else if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}

// MARK: - Preview

#Preview {
    DeviceTestView()
}

#Preview("With Mock Data") {
    let mockDeviceManager = DeviceManager()
    mockDeviceManager.discoveredDevices = [
        DeviceInfo.mock(type: .oralable),
        DeviceInfo.mock(type: .anrMuscleSense)
    ]
    
    return DeviceTestView(previewDeviceManager: mockDeviceManager)
}
