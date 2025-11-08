//
//  DevicesView.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Refactored to use DevicesViewModel (MVVM pattern)
//

import SwiftUI
import CoreBluetooth

// MARK: - DeviceConnectionState View Extensions

extension DeviceConnectionState {
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    var displayText: String {
        self.displayName
    }
}

// MARK: - DeviceType View Extensions

extension DeviceType {
    var icon: String {
        self.iconName
    }
    
    var color: Color {
        switch self {
        case .oralable:
            return .blue
        case .anrMuscleSense:
            return .purple
        case .unknown:
            return .gray
        }
    }
}

// MARK: - DeviceInfo View Extensions

extension DeviceInfo {
    var deviceType: DeviceType {
        self.type
    }
    
    var connectionStatus: DeviceConnectionState {
        self.connectionState
    }
    
    var rssi: Int? {
        self.signalStrength
    }
    
    var services: [CBUUID] {
        // Return service UUIDs based on device type
        if let serviceUUID = type.serviceUUID {
            return [serviceUUID]
        }
        return []
    }
}

struct DevicesView: View {
    // MVVM: Use ViewModel instead of direct manager access
    @EnvironmentObject var deviceManager: DeviceManager
    @StateObject private var viewModel: DevicesViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showingDeviceDetails = false
    @State private var selectedDevice: DeviceInfo?
    
    init() {
        // We need to use a temporary workaround for @StateObject initialization
        // The actual initialization will happen in the body's first render
        _viewModel = StateObject(wrappedValue: DevicesViewModel(deviceManager: .shared))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Scanning Status
                    scanningStatusCard
                    
                    // Primary Device Section
                    if let primaryDevice = viewModel.primaryDevice {
                        primaryDeviceCard(primaryDevice)
                    }
                    
                    // Connected Devices Section
                    if viewModel.hasConnectedDevices {
                        connectedDevicesSection
                    }
                    
                    // Discovered Devices Section
                    if viewModel.hasDiscoveredDevices {
                        discoveredDevicesSection
                    }
                    
                    // Empty State
                    if !viewModel.hasConnectedDevices && !viewModel.hasDiscoveredDevices && !viewModel.isScanning {
                        emptyStateView
                    }
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.toggleScanning() }) {
                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshDevices()
            }
        }
        .onAppear {
            viewModel.checkBluetoothPermission()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(device: device, viewModel: viewModel)
        }
    }
    
    // MARK: - Scanning Status Card
    
    private var scanningStatusCard: some View {
        VStack(spacing: designSystem.spacing.sm) {
            HStack {
                Circle()
                    .fill(viewModel.isScanning ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.green, lineWidth: viewModel.isScanning ? 2 : 0)
                            .scaleEffect(viewModel.isScanning ? 2 : 1)
                            .opacity(viewModel.isScanning ? 0 : 1)
                            .animation(
                                viewModel.isScanning ? .easeInOut(duration: 1).repeatForever() : .default,
                                value: viewModel.isScanning
                            )
                    )
                
                Text(viewModel.statusText)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: designSystem.spacing.lg) {
                // Scan Button
                Button(action: { viewModel.toggleScanning() }) {
                    HStack {
                        Image(systemName: viewModel.isScanning ? "stop.fill" : "magnifyingglass")
                        Text(viewModel.scanButtonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.sm)
                    .background(viewModel.isScanning ? Color.red : designSystem.colors.primaryBlack)
                    .foregroundColor(designSystem.colors.primaryWhite)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                // Disconnect All Button
                if viewModel.hasConnectedDevices {
                    Button(action: { viewModel.disconnectAll() }) {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Disconnect All")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(designSystem.spacing.sm)
                        .background(designSystem.colors.backgroundTertiary)
                        .foregroundColor(designSystem.colors.textPrimary)
                        .cornerRadius(designSystem.cornerRadius.sm)
                    }
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Primary Device Card
    
    private func primaryDeviceCard(_ device: DeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Label("Primary Device", systemImage: "star.fill")
                    .font(designSystem.typography.headline)
                    .foregroundColor(.yellow)
                
                Spacer()
                
                ConnectionBadge(status: device.connectionStatus)
            }
            
            DeviceRow(
                device: device,
                isPrimary: true,
                onTap: {
                    selectedDevice = device
                },
                onConnect: {
                    Task {
                        await viewModel.connect(to: device)
                    }
                },
                onDisconnect: {
                    Task {
                        await viewModel.disconnect(from: device)
                    }
                }
            )
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundTertiary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Connected Devices Section
    
    private var connectedDevicesSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            HStack {
                SectionHeaderView(title: "Connected Devices", icon: "wifi")
                Spacer()
                Text("\(viewModel.connectedDevices.count)")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            ForEach(viewModel.connectedDevices.filter { $0.id != viewModel.primaryDevice?.id }) { device in
                DeviceRow(
                    device: device,
                    isPrimary: false,
                    onTap: {
                        selectedDevice = device
                    },
                    onConnect: nil,
                    onDisconnect: {
                        Task {
                            await viewModel.disconnect(from: device)
                        }
                    },
                    onSetPrimary: {
                        viewModel.setPrimaryDevice(device)
                    }
                )
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
    }
    
    // MARK: - Discovered Devices Section
    
    private var discoveredDevicesSection: some View {
        let availableDevicesCount = viewModel.discoveredDevices.filter { device in
            !viewModel.connectedDevices.contains(where: { $0.id == device.id })
        }.count
        
        return VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            HStack {
                SectionHeaderView(title: "Available Devices", icon: "dot.radiowaves.left.and.right")
                Spacer()
                Text("\(availableDevicesCount)")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            ForEach(viewModel.discoveredDevices.filter { device in
                !viewModel.connectedDevices.contains(where: { $0.id == device.id })
            }) { device in
                DeviceRow(
                    device: device,
                    isPrimary: false,
                    onTap: {
                        selectedDevice = device
                    },
                    onConnect: {
                        Task {
                            await viewModel.connect(to: device)
                        }
                    },
                    onDisconnect: nil
                )
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: designSystem.spacing.lg) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textTertiary)
            
            Text("No Devices Found")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
            Text("Make sure your Oralable device is powered on and within range")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { viewModel.startScanning() }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Start Scanning")
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.primaryBlack)
                .foregroundColor(designSystem.colors.primaryWhite)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
        .padding(designSystem.spacing.xl)
    }
}

// MARK: - Device Row Component

struct DeviceRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let device: DeviceInfo
    let isPrimary: Bool
    let onTap: () -> Void
    let onConnect: (() async -> Void)?
    let onDisconnect: (() async -> Void)?
    var onSetPrimary: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                // Device Icon
                Image(systemName: device.deviceType.icon)
                    .font(.title2)
                    .foregroundColor(device.deviceType.color)
                    .frame(width: 40, height: 40)
                    .background(device.deviceType.color.opacity(0.1))
                    .cornerRadius(designSystem.cornerRadius.sm)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)
                        
                        if isPrimary {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(device.deviceType.displayName)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if device.isConnected {
                        // Battery Level
                        if let battery = device.batteryLevel {
                            HStack(spacing: 4) {
                                Text("\(battery)%")
                                    .font(designSystem.typography.caption)
                                Image(systemName: batteryIcon(for: battery))
                            }
                            .foregroundColor(batteryColor(for: battery))
                        }
                        
                        // RSSI Signal
                        if let rssi = device.rssi {
                            HStack(spacing: 4) {
                                Text("\(rssi) dBm")
                                    .font(designSystem.typography.caption)
                                Image(systemName: signalIcon(for: rssi))
                            }
                            .foregroundColor(designSystem.colors.textTertiary)
                        }
                    } else if let rssi = device.rssi {
                        // RSSI Signal for discovered devices
                        HStack(spacing: 4) {
                            Text("\(rssi) dBm")
                                .font(designSystem.typography.caption)
                            Image(systemName: signalIcon(for: rssi))
                        }
                        .foregroundColor(designSystem.colors.textTertiary)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: designSystem.spacing.sm) {
                if device.isConnected {
                    if let onDisconnect = onDisconnect {
                        Button(action: { Task { await onDisconnect() } }) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                Text("Disconnect")
                            }
                            .font(designSystem.typography.caption)
                            .frame(maxWidth: .infinity)
                            .padding(designSystem.spacing.xs)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(designSystem.cornerRadius.sm)
                        }
                    }
                    
                    if !isPrimary, let onSetPrimary = onSetPrimary {
                        Button(action: onSetPrimary) {
                            HStack {
                                Image(systemName: "star")
                                Text("Set Primary")
                            }
                            .font(designSystem.typography.caption)
                            .frame(maxWidth: .infinity)
                            .padding(designSystem.spacing.xs)
                            .background(Color.yellow.opacity(0.1))
                            .foregroundColor(.yellow)
                            .cornerRadius(designSystem.cornerRadius.sm)
                        }
                    }
                } else if let onConnect = onConnect {
                    Button(action: { Task { await onConnect() } }) {
                        HStack {
                            Image(systemName: "link")
                            Text("Connect")
                        }
                        .font(designSystem.typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(designSystem.spacing.xs)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(designSystem.cornerRadius.sm)
                    }
                }
                
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .font(designSystem.typography.caption)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.xs)
                    .background(designSystem.colors.backgroundTertiary)
                    .foregroundColor(designSystem.colors.textPrimary)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
            }
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 51...100: return .green
        case 21...50: return .yellow
        default: return .red
        }
    }
    
    private func signalIcon(for rssi: Int) -> String {
        switch rssi {
        case -50...0: return "wifi"
        case -70...(-51): return "wifi"
        case -85...(-71): return "wifi"
        default: return "wifi.slash"
        }
    }
}

// MARK: - Connection Badge

struct ConnectionBadge: View {
    let status: DeviceConnectionState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    
    let device: DeviceInfo
    let viewModel: DevicesViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Device Information") {
                    InfoRowView(icon: "tag", title: "Name", value: device.name)
                    InfoRowView(icon: "cube.box", title: "Type", value: device.deviceType.displayName)
                    InfoRowView(icon: "number", title: "ID", value: device.id.uuidString)
                    InfoRowView(icon: "link", title: "Status", value: device.connectionStatus.displayText)
                }
                
                if device.isConnected {
                    Section("Connection Details") {
                        if let battery = device.batteryLevel {
                            InfoRowView(icon: "battery.100", title: "Battery", value: "\(battery)%")
                        }
                        if let rssi = device.rssi {
                            InfoRowView(icon: "wifi", title: "Signal", value: "\(rssi) dBm")
                        }
                        if let firmware = device.firmwareVersion {
                            InfoRowView(icon: "cpu", title: "Firmware", value: firmware)
                        }
                    }
                    
                    Section("Services") {
                        ForEach(device.services, id: \.self) { service in
                            Text(service.uuidString)
                                .font(designSystem.typography.caption)
                                .foregroundColor(designSystem.colors.textSecondary)
                        }
                    }
                }
                
                Section {
                    if device.isConnected {
                        Button(action: {
                            Task {
                                await viewModel.disconnect(from: device)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                Text("Disconnect Device")
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            Task {
                                await viewModel.connect(to: device)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect to Device")
                            }
                            .foregroundColor(.green)
                        }
                    }
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

// MARK: - Preview

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
            .environmentObject(DesignSystem.shared)
    }
}
