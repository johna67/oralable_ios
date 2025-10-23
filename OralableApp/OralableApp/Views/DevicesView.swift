//
//  DevicesView.swift
//  OralableApp
//
//  Created by John A Cogan on 22/10/2025.
//


import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @ObservedObject var ble: OralableBLE
    @Environment(\.dismiss) var dismiss
    
    @State private var showAddDevice = false
    @State private var savedDevices: [SavedDevice] = []
    
    var body: some View {
        NavigationView {
            List {
                // Currently Connected Device
                if ble.isConnected {
                    Section("Connected Device") {
                        ConnectedDeviceRow(ble: ble)
                    }
                }
                
                // Saved Devices
                Section {
                    if savedDevices.isEmpty {
                        EmptyDevicesState()
                    } else {
                        ForEach(savedDevices) { device in
                            SavedDeviceRow(
                                device: device,
                                ble: ble,
                                onDelete: { deleteDevice(device) }
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("My Devices")
                        Spacer()
                        Button(action: { showAddDevice = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Scan for Devices
                Section("Available Devices") {
                    if ble.isScanning {
                        ScanningIndicator()
                    } else if !ble.discoveredPeripherals.isEmpty {
                        ForEach(Array(ble.discoveredPeripherals.keys.sorted()), id: \.self) { uuid in
                            if let peripheral = ble.discoveredPeripherals[uuid] {
                                DiscoveredDeviceRow(
                                    peripheral: peripheral,
                                    ble: ble,
                                    onConnect: { connectToDevice(peripheral) }
                                )
                            }
                        }
                    } else {
                        Text("No devices found")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    Button(action: { ble.toggleScanning() }) {
                        HStack {
                            Image(systemName: ble.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            Text(ble.isScanning ? "Stop Scanning" : "Scan for Devices")
                        }
                    }
                }
                
                // Help Section
                Section("Help") {
                    NavigationLink(destination: DeviceSetupGuideView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Device Setup Guide")
                        }
                    }
                    
                    NavigationLink(destination: TroubleshootingView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Troubleshooting")
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSavedDevices()
            }
        }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(ble: ble, savedDevices: $savedDevices)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadSavedDevices() {
        if let data = UserDefaults.standard.data(forKey: "savedDevices"),
           let devices = try? JSONDecoder().decode([SavedDevice].self, from: data) {
            savedDevices = devices
        }
    }
    
    private func saveDevices() {
        if let data = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(data, forKey: "savedDevices")
        }
    }
    
    private func deleteDevice(_ device: SavedDevice) {
        savedDevices.removeAll { $0.id == device.id }
        saveDevices()
    }
    
    private func connectToDevice(_ peripheral: CBPeripheral) {
        ble.connect(to: peripheral)
        
        // Save device if not already saved
        let newDevice = SavedDevice(
            uuid: peripheral.identifier.uuidString,
            name: peripheral.name ?? "Unknown Device",
            lastConnected: Date()
        )
        
        if !savedDevices.contains(where: { $0.uuid == newDevice.uuid }) {
            savedDevices.append(newDevice)
            saveDevices()
        }
    }
}

// MARK: - Saved Device Model
struct SavedDevice: Identifiable, Codable {
    let id = UUID()
    let uuid: String
    let name: String
    var lastConnected: Date
    var nickname: String?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, name, lastConnected, nickname
    }
    
    init(uuid: String, name: String, lastConnected: Date, nickname: String? = nil) {
        self.uuid = uuid
        self.name = name
        self.lastConnected = lastConnected
        self.nickname = nickname
    }
}

// MARK: - Connected Device Row
struct ConnectedDeviceRow: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        HStack(spacing: 16) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(ble.deviceName)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(ble.sensorData.batteryLevel)%", systemImage: "battery.75")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(ble.sensorData.firmwareVersion, systemImage: "gear")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Disconnect Button
            Button(action: { ble.disconnect() }) {
                Text("Disconnect")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Saved Device Row
struct SavedDeviceRow: View {
    let device: SavedDevice
    @ObservedObject var ble: OralableBLE
    let onDelete: () -> Void
    
    var isCurrentDevice: Bool {
        ble.peripheral?.identifier.uuidString == device.uuid
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "wave.3.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.nickname ?? device.name)
                    .font(.headline)
                
                Text("Last connected: \(device.lastConnected, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCurrentDevice && ble.isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Button(action: { 
                    // Connect to saved device - we'll need to find it in discovered peripherals or trigger a scan
                    if let peripheral = ble.discoveredPeripherals[device.uuid] {
                        ble.connect(to: peripheral)
                    } else {
                        // Start scanning to find the device
                        ble.startScanning()
                    }
                }) {
                    Text("Connect")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Discovered Device Row
struct DiscoveredDeviceRow: View {
    let peripheral: CBPeripheral
    @ObservedObject var ble: OralableBLE
    let onConnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "wave.3.right")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.subheadline)
                
                Text(peripheral.identifier.uuidString.prefix(8) + "...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onConnect) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Devices State
struct EmptyDevicesState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Saved Devices")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Scan for devices and connect to save them")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Scanning Indicator
struct ScanningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Scanning for devices...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }
}

// MARK: - Add Device View
struct AddDeviceView: View {
    @ObservedObject var ble: OralableBLE
    @Binding var savedDevices: [SavedDevice]
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName = ""
    @State private var selectedPeripheral: CBPeripheral?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Name") {
                    TextField("Enter device nickname", text: $deviceName)
                }
                
                Section("Select Device") {
                    if ble.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ForEach(Array(ble.discoveredPeripherals.keys.sorted()), id: \.self) { uuid in
                        if let peripheral = ble.discoveredPeripherals[uuid] {
                            Button(action: {
                                selectedPeripheral = peripheral
                            }) {
                                HStack {
                                    Text(peripheral.name ?? "Unknown")
                                    Spacer()
                                    if selectedPeripheral?.identifier == peripheral.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        if let peripheral = selectedPeripheral {
                            let device = SavedDevice(
                                uuid: peripheral.identifier.uuidString,
                                name: peripheral.name ?? "Unknown",
                                lastConnected: Date(),
                                nickname: deviceName.isEmpty ? nil : deviceName
                            )
                            
                            savedDevices.append(device)
                            if let data = try? JSONEncoder().encode(savedDevices) {
                                UserDefaults.standard.set(data, forKey: "savedDevices")
                            }
                            dismiss()
                        }
                    }) {
                        Text("Add Device")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedPeripheral == nil)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !ble.isScanning {
                    ble.startScanning()
                }
            }
        }
    }
}

// MARK: - Device Setup Guide
struct DeviceSetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SetupStep(
                    number: 1,
                    title: "Turn on your device",
                    description: "Press and hold the power button until the LED blinks blue."
                )
                
                SetupStep(
                    number: 2,
                    title: "Enable Bluetooth",
                    description: "Make sure Bluetooth is enabled on your iPhone in Settings."
                )
                
                SetupStep(
                    number: 3,
                    title: "Scan for devices",
                    description: "Tap 'Scan for Devices' and wait for your device to appear."
                )
                
                SetupStep(
                    number: 4,
                    title: "Connect",
                    description: "Select your device from the list and tap Connect."
                )
                
                SetupStep(
                    number: 5,
                    title: "Start monitoring",
                    description: "Once connected, your device will start streaming data automatically."
                )
            }
            .padding()
        }
        .navigationTitle("Setup Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Troubleshooting View
struct TroubleshootingView: View {
    var body: some View {
        List {
            Section("Connection Issues") {
                TroubleshootingItem(
                    problem: "Device not appearing in scan",
                    solution: "Make sure the device is powered on and Bluetooth is enabled. Try restarting both the device and your iPhone."
                )
                
                TroubleshootingItem(
                    problem: "Connection fails",
                    solution: "Move closer to the device. Ensure no other apps are trying to connect to the same device."
                )
                
                TroubleshootingItem(
                    problem: "Frequent disconnections",
                    solution: "Check battery level. Ensure the device is within range (10 meters). Remove obstacles between device and phone."
                )
            }
            
            Section("Data Issues") {
                TroubleshootingItem(
                    problem: "No data showing",
                    solution: "Verify the device is properly positioned. Check that sensors are making good contact with skin."
                )
                
                TroubleshootingItem(
                    problem: "Erratic readings",
                    solution: "Clean the sensor contacts. Ensure proper placement on the jaw muscle."
                )
            }
            
            Section("Get Help") {
                Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("Visit GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
            }
        }
        .navigationTitle("Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TroubleshootingItem: View {
    let problem: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(problem)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
