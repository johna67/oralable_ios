import SwiftUI
import AuthenticationServices

struct SubscriptionSettingsView: View {
    @ObservedObject var ble: OralableBLE
    @Binding var selectedMode: AppMode?
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSignOutAlert = false
    @State private var showLogs = false
    @State private var showSubscriptionInfo = false
    @State private var showAppleIDDebug = false
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userFullName ?? "User")
                                .font(.headline)
                            if let email = authManager.userEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Apple ID")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: { showSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Subscription Section
                Section("Subscription") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(subscriptionManager.currentTier.displayName)
                                    .font(.headline)
                                if subscriptionManager.currentTier == .paid {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        Spacer()
                        if subscriptionManager.currentTier == .basic {
                            Button("Upgrade") {
                                showSubscriptionInfo = true
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Button(action: { showSubscriptionInfo = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("View Plans")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Connection Section
                Section("Device Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ble.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(ble.isConnected ? "Connected" : "Disconnected")
                                .foregroundColor(ble.isConnected ? .green : .red)
                        }
                    }
                    
                    if ble.isConnected {
                        HStack {
                            Text("Device")
                            Spacer()
                            Text(ble.deviceName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Battery")
                            Spacer()
                            Text("\(ble.sensorData.batteryLevel)%")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { ble.disconnect() }) {
                            HStack {
                                Image(systemName: "link.slash")
                                Text("Disconnect")
                            }
                            .foregroundColor(.orange)
                        }
                    } else {
                        Button(action: { ble.toggleScanning() }) {
                            HStack {
                                Image(systemName: ble.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                                Text(ble.isScanning ? "Stop Scanning" : "Start Scanning")
                            }
                        }
                    }
                }
                
                // Logs Section
                Section("Diagnostics") {
                    Button(action: { showLogs = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Logs")
                            Spacer()
                            Text("\(ble.logMessages.count)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showAppleIDDebug = true }) {
                        HStack {
                            Image(systemName: "person.crop.rectangle.badge.plus")
                            Text("Apple ID Debug")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { ble.logMessages.removeAll() }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Logs")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // App Mode Section
                Section("App Mode") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Subscription Mode")
                                .font(.headline)
                        }
                    }
                    
                    Button(action: {
                        selectedMode = nil
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Change Mode")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    if ble.isConnected {
                        HStack {
                            Text("Firmware Version")
                            Spacer()
                            Text(ble.sensorData.firmwareVersion)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Device UUID")
                            Spacer()
                            Text(String(format: "%016llX", ble.sensorData.deviceUUID))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showLogs) {
            LogsView(logs: ble.logMessages)
        }
        .sheet(isPresented: $showSubscriptionInfo) {
            SubscriptionTierSelectionView()
        }
        .sheet(isPresented: $showAppleIDDebug) {
            AppleIDDebugView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                selectedMode = nil
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access subscription features.")
        }
    }
}
