//
//  DevicesView.swift
//  OralableApp
//
//  iOS Bluetooth Settings Style - Shows remembered and discovered devices
//

import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var deviceManagerAdapter: DeviceManagerAdapter

    @State private var isScanning = false
    @State private var selectedDevice: DeviceRowItem?
    @State private var showingDeviceDetail = false

    private let persistenceManager = DevicePersistenceManager.shared

    var body: some View {
        NavigationView {
            List {
                myDevicesSection
                otherDevicesSection
            }
            .listStyle(.insetGrouped)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isScanning {
                        ProgressView()
                    } else {
                        Button("Scan") {
                            startScanning()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDeviceDetail) {
                if let device = selectedDevice {
                    DeviceDetailView(device: device, onForget: {
                        forgetDevice(device)
                        showingDeviceDetail = false
                    }, onDisconnect: {
                        disconnectDevice(device)
                        showingDeviceDetail = false
                    })
                }
            }
            .onAppear {
                startScanning()
            }
            .onDisappear {
                deviceManager.stopScanning()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - My Devices Section (Remembered)
    private var myDevicesSection: some View {
        Section {
            let rememberedDevices = persistenceManager.getRememberedDevices()

            if rememberedDevices.isEmpty {
                Text("No saved devices")
                    .foregroundColor(.secondary)
            } else {
                ForEach(rememberedDevices) { device in
                    DeviceRow(
                        name: device.name,
                        isConnected: isDeviceConnected(id: device.id),
                        onTap: {
                            if isDeviceConnected(id: device.id) {
                                selectedDevice = DeviceRowItem(id: device.id, name: device.name, isConnected: true)
                                showingDeviceDetail = true
                            } else {
                                connectToDevice(id: device.id)
                            }
                        },
                        onInfoTap: {
                            selectedDevice = DeviceRowItem(id: device.id, name: device.name, isConnected: isDeviceConnected(id: device.id))
                            showingDeviceDetail = true
                        }
                    )
                }
            }
        } header: {
            Text("My Devices")
        }
    }

    // MARK: - Other Devices Section (Discovered)
    private var otherDevicesSection: some View {
        Section {
            let discoveredDevices = deviceManager.discoveredDevices.filter { discovered in
                guard let peripheralId = discovered.peripheralIdentifier else { return true }
                return !persistenceManager.isDeviceRemembered(id: peripheralId.uuidString)
            }

            if discoveredDevices.isEmpty {
                if isScanning {
                    HStack {
                        Text("Searching...")
                            .foregroundColor(.secondary)
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("No devices found")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(discoveredDevices, id: \.peripheralIdentifier) { device in
                    DeviceRow(
                        name: device.name,
                        isConnected: false,
                        onTap: {
                            connectToNewDevice(device)
                        },
                        onInfoTap: nil
                    )
                }
            }
        } header: {
            HStack {
                Text("Other Devices")
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func isDeviceConnected(id: String) -> Bool {
        return deviceManager.connectedDevices.contains { $0.peripheralIdentifier?.uuidString == id }
    }

    private func startScanning() {
        isScanning = true
        Task {
            await deviceManager.startScanning()
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            await MainActor.run {
                isScanning = false
                deviceManager.stopScanning()
            }
        }
    }

    private func connectToDevice(id: String) {
        if let device = deviceManager.discoveredDevices.first(where: { $0.peripheralIdentifier?.uuidString == id }) {
            Task {
                do {
                    try await deviceManager.connect(to: device)
                } catch {
                    Logger.shared.error("[DevicesView] Failed to connect: \(error.localizedDescription)")
                }
            }
        } else {
            // Device not in discovered list, start scanning to find it
            startScanning()
        }
    }

    private func connectToNewDevice(_ device: DeviceInfo) {
        Task {
            do {
                try await deviceManager.connect(to: device)
                if let peripheralId = device.peripheralIdentifier {
                    persistenceManager.rememberDevice(id: peripheralId.uuidString, name: device.name)
                }
            } catch {
                Logger.shared.error("[DevicesView] Failed to connect: \(error.localizedDescription)")
            }
        }
    }

    private func forgetDevice(_ device: DeviceRowItem) {
        if device.isConnected {
            disconnectDevice(device)
        }
        persistenceManager.forgetDevice(id: device.id)
    }

    private func disconnectDevice(_ device: DeviceRowItem) {
        if let connectedDevice = deviceManager.connectedDevices.first(where: { $0.peripheralIdentifier?.uuidString == device.id }) {
            deviceManager.disconnect(from: connectedDevice)
        }
    }
}

// MARK: - Device Row Item Model
struct DeviceRowItem: Identifiable {
    let id: String
    let name: String
    let isConnected: Bool
}

// MARK: - Device Row Component
struct DeviceRow: View {
    let name: String
    let isConnected: Bool
    let onTap: () -> Void
    let onInfoTap: (() -> Void)?

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text(isConnected ? "Connected" : "Not Connected")
                .font(.system(size: 15))
                .foregroundColor(isConnected ? .blue : .secondary)

            if let onInfoTap = onInfoTap {
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview
struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppStateManager()
        let ble = OralableBLE()
        let healthKit = HealthKitManager()
        let sensorStore = SensorDataStore()
        let recordingSession = RecordingSessionManager()
        let historicalData = HistoricalDataManager(sensorDataProcessor: SensorDataProcessor.shared)
        let authManager = AuthenticationManager()
        let subscription = SubscriptionManager()
        let device = DeviceManager()
        let sharedData = SharedDataManager(
            authenticationManager: authManager,
            healthKitManager: healthKit,
            sensorDataProcessor: SensorDataProcessor.shared
        )
        let designSystem = DesignSystem()

        let dependencies = AppDependencies(
            authenticationManager: authManager,
            healthKitManager: healthKit,
            recordingSessionManager: recordingSession,
            historicalDataManager: historicalData,
            bleManager: ble,
            sensorDataStore: sensorStore,
            subscriptionManager: subscription,
            deviceManager: device,
            sensorDataProcessor: SensorDataProcessor.shared,
            appStateManager: appState,
            sharedDataManager: sharedData,
            designSystem: designSystem
        )

        return NavigationView {
            DevicesView()
        }
        .withDependencies(dependencies)
    }
}
