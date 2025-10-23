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

// MARK: - Subscription Mode Content View (CLEAN - NO BADGE)
struct SubscriptionContentView: View {
    @StateObject private var ble = OralableBLE()
    @StateObject private var authManager = AuthenticationManager.shared
    @Binding var selectedMode: AppMode?
    @State private var selectedTab = 0
    @State private var showProfile = false
    @State private var showDevices = false
    
    var body: some View {
        ZStack {
            // Main Tab View
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
            
            // Top Navigation Bar Overlay (Withings Style - NO BADGE)
            VStack {
                HStack {
                    // Left: Profile Button
                    Button(action: { showProfile = true }) {
                        HStack(spacing: 10) {
                            // Apple ID Profile Icon
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            // User Name
                            if let name = authManager.userFullName {
                                Text(name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 16)
                    }
                    
                    Spacer()
                    
                    // Right: Devices Button
                    Button(action: { showDevices = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(ble.isConnected ? .green : .gray)
                        }
                        .padding(.trailing, 16)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView(selectedMode: $selectedMode)
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(ble: ble)
        }
    }
}

// MARK: - User Profile View (CLEAN - NO SUBSCRIPTION STUFF)
struct UserProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Binding var selectedMode: AppMode?
    @Environment(\.dismiss) var dismiss
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Header
                Section {
                    HStack(spacing: 16) {
                        // Large Profile Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(authManager.userFullName ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let email = authManager.userEmail {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "applelogo")
                                    .font(.caption2)
                                Text("Apple ID")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                }
                
                // Account Actions
                Section {
                    Button(action: { selectedMode = nil }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Switch Mode")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: { showSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // App Info
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                selectedMode = nil
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access subscription features.")
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
                    Label("Share", systemImage: "gauge")
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
