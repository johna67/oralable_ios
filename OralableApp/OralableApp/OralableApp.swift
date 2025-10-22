import SwiftUI

@main
struct OralableApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedMode: AppMode?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let mode = selectedMode {
                    switch mode {
                    case .viewer:
                        ViewerModeView(selectedMode: $selectedMode)
                    case .subscription:
                        if authManager.isAuthenticated {
                            SubscriptionContentView(selectedMode: $selectedMode)
                        } else {
                            AuthenticationView(selectedMode: $selectedMode)
                        }
                    }
                } else {
                    ModeSelectionView(selectedMode: $selectedMode)
                }
            }
            .onAppear {
                // Check if user was previously authenticated and in subscription mode
                if authManager.isAuthenticated && UserDefaults.standard.string(forKey: "lastMode") == "subscription" {
                    selectedMode = .subscription
                }
            }
            .onChange(of: selectedMode) { _, newMode in
                // Save last selected mode
                if let mode = newMode {
                    UserDefaults.standard.set(mode == .subscription ? "subscription" : "viewer", forKey: "lastMode")
                }
            }
        }
    }
}

// MARK: - Subscription Mode Content View
struct SubscriptionContentView: View {
    @StateObject private var ble = OralableBLE()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var selectedMode: AppMode?
    @State private var selectedTab = 0
    @State private var showSubscriptionInfo = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(ble: ble)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            ShareView(ble: ble)
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tag(1)
            
            SubscriptionSettingsView(ble: ble, selectedMode: $selectedMode)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .overlay(
            // Subscription tier badge
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSubscriptionInfo = true }) {
                        HStack(spacing: 6) {
                            if subscriptionManager.currentTier == .paid {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                            }
                            Text(subscriptionManager.currentTier == .paid ? "Premium" : "Basic")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(subscriptionManager.currentTier == .paid ? Color.orange : Color.gray)
                        .cornerRadius(12)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        )
        .sheet(isPresented: $showSubscriptionInfo) {
            SubscriptionTierSelectionView()
        }
    }
}

// MARK: - Viewer Mode View
struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @StateObject private var ble = OralableBLE()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(ble: ble, isViewerMode: true)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            ShareView(ble: ble, isViewerMode: true)
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tag(1)
            
            ViewerSettingsView(ble: ble, selectedMode: $selectedMode)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            // Ensure BLE doesn't try to connect in viewer mode
            ble.disconnect()
        }
    }
}

// MARK: - Viewer Settings View
struct ViewerSettingsView: View {
    @ObservedObject var ble: OralableBLE
    @Binding var selectedMode: AppMode?
    @State private var showModeChangeAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Current Mode Info
                Section("Current Mode") {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Viewer Mode")
                                .font(.headline)
                            Text("View data files without authentication")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Features Available in Viewer Mode
                Section("Available Features") {
                    FeatureRow(icon: "gauge", text: "Dashboard View", isEnabled: true)
                    FeatureRow(icon: "square.and.arrow.up", text: "Export Data", isEnabled: true)
                }
                
                Section("Unavailable in Viewer Mode") {
                    FeatureRow(icon: "antenna.radiowaves.left.and.right", text: "Device Connection", isEnabled: false)
                    FeatureRow(icon: "waveform.path.ecg", text: "Real-time Monitoring", isEnabled: false)
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
