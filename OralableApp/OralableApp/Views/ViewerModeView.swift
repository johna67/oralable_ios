import SwiftUI

// MARK: - Viewer Mode View (Using Shared Views)
struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @StateObject private var ble = OralableBLE() // BLE manager, but won't connect in viewer mode
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Use the SAME DashboardView as Subscription Mode
            DashboardView(ble: ble, isViewerMode: true)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            // Use the SAME DataView as Subscription Mode
            DataView(ble: ble, isViewerMode: true)
                .tabItem {
                    Label("Data", systemImage: "waveform.path.ecg")
                }
                .tag(1)
            
            // Use the SAME LogExportView as Subscription Mode
            LogExportView(ble: ble, isViewerMode: true)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
            
            // Settings view adapted for Viewer Mode
            ViewerSettingsView(ble: ble, selectedMode: $selectedMode)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Ensure BLE doesn't try to connect in viewer mode
            ble.disconnect()
        }
    }
}

// MARK: - Viewer Settings View (Adapted from SubscriptionSettingsView)
struct ViewerSettingsView: View {
    @ObservedObject var ble: OralableBLE
    @Binding var selectedMode: AppMode?
    @State private var showModeChangeAlert = false
    @State private var showLogs = false
    
    var body: some View {
        NavigationView {
            List {
                // Mode Status Section (No Account in Viewer Mode)
                Section("Mode") {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Viewer Mode")
                                .font(.headline)
                            Text("No account required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Connection Section (DISABLED)
                Section("Device Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                            Text("Disabled in Viewer Mode")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Device connection buttons DISABLED
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            Text("Device Connection Unavailable")
                        }
                        .foregroundColor(.secondary)
                    }
                    .disabled(true)
                }
                
                // Logs Section (Still works in Viewer Mode)
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
                    
                    Button(action: { ble.logMessages.removeAll() }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Logs")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Features Section (Show what's available)
                Section("Available Features") {
                    FeatureRow(icon: "doc.text.viewfinder", text: "View Imported Files", isEnabled: true)
                    FeatureRow(icon: "chart.xyaxis.line", text: "Data Visualization", isEnabled: true)
                    FeatureRow(icon: "square.and.arrow.up", text: "Export Data", isEnabled: true)
                }
                
                Section("Unavailable in Viewer Mode") {
                    FeatureRow(icon: "antenna.radiowaves.left.and.right", text: "Device Connection", isEnabled: false)
                    FeatureRow(icon: "waveform.path.ecg", text: "Real-time Monitoring", isEnabled: false)
                    FeatureRow(icon: "person.circle", text: "Account Features", isEnabled: false)
                }
                
                // Switch Mode
                Section {
                    Button(action: {
                        showModeChangeAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Switch to Subscription Mode")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Mode")
                        Spacer()
                        Text("Viewer")
                            .foregroundColor(.secondary)
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
            .alert("Switch Mode", isPresented: $showModeChangeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Switch") {
                    selectedMode = nil
                }
            } message: {
                Text("Switch to Subscription Mode for device connectivity and real-time monitoring. You'll need to sign in with your Apple ID.")
            }
        }
        .sheet(isPresented: $showLogs) {
            LogsView(logs: ble.logMessages)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 30)
            Text(text)
                .foregroundColor(isEnabled ? .primary : .secondary)
        }
    }
}
