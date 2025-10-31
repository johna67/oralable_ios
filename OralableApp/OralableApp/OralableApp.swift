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

// MARK: - User Avatar Component
struct UserAvatarView: View {
    let initials: String
    let size: CGFloat
    let showOnlineIndicator: Bool
    
    init(initials: String, size: CGFloat = 36, showOnlineIndicator: Bool = false) {
        self.initials = initials
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
    }
    
    var body: some View {
        ZStack {
            // Avatar background with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // User initials
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Online indicator (optional)
            if showOnlineIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
    }
}

// MARK: - Enhanced Profile Button
struct ProfileButtonView: View {
    @ObservedObject var authManager: AuthenticationManager
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                // User Avatar
                UserAvatarView(
                    initials: authManager.userInitials,
                    size: 40,
                    showOnlineIndicator: authManager.hasCompleteProfile
                )
                
                // User Name with truncation
                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if authManager.hasCompleteProfile {
                        Text("Tap to view profile")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Profile incomplete")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 120, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(isPressed ? 0.6 : 0.8))
                    .shadow(color: .black.opacity(0.1), radius: isPressed ? 2 : 4, x: 0, y: isPressed ? 1 : 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
// MARK: - Subscription Mode Content View
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
            
            // Top Navigation Bar Overlay (Withings Style)
            VStack {
                HStack {
                    // Left: Enhanced Profile Button
                    ProfileButtonView(
                        authManager: authManager,
                        action: { showProfile = true }
                    )
                    
                    Spacer()
                    
                    // Right: Devices Button with status indicator
                    Button(action: { showDevices = true }) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(ble.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "wave.3.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(ble.isConnected ? .green : .gray)
                                
                                // Connection status indicator
                                if ble.isConnected {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .offset(x: 14, y: -14)
                                }
                            }
                            
                            // Device status text
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ble.isConnected ? "Connected" : "Tap to connect")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(ble.isConnected ? .green : .secondary)
                                
                                if ble.isConnected {
                                    Text(ble.deviceName)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                } else {
                                    Text("No device")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6).opacity(0.8))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .ignoresSafeArea(edges: .top)
                )
                
                Spacer()
            }
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView(selectedMode: $selectedMode)
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(ble: ble)
        }
    }
}

// MARK: - Enhanced User Profile View
struct UserProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Binding var selectedMode: AppMode?
    @Environment(\.dismiss) var dismiss
    @State private var showSignOutAlert = false
    @State private var showAccountDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header Section
                    ProfileHeaderView(authManager: authManager)
                    
                    // Quick Actions Section
                    QuickActionsView(
                        selectedMode: $selectedMode,
                        showAccountDetails: $showAccountDetails
                    )
                    
                    // Account Section
                    AccountSectionView(
                        authManager: authManager,
                        showSignOutAlert: $showSignOutAlert
                    )
                    
                    // App Information Section
                    AppInfoSectionView()
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showAccountDetails) {
            AccountDetailsView()
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

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Large Avatar
            UserAvatarView(
                initials: authManager.userInitials,
                size: 100,
                showOnlineIndicator: false
            )
            
            // User Information
            VStack(spacing: 8) {
                Text(authManager.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let email = authManager.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                // Apple ID Badge
                HStack(spacing: 6) {
                    Image(systemName: "applelogo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Apple ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if authManager.hasCompleteProfile {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Quick Actions View
struct QuickActionsView: View {
    @Binding var selectedMode: AppMode?
    @Binding var showAccountDetails: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeaderView(title: "Quick Actions")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ActionCardView(
                    icon: "person.circle",
                    title: "Account Details",
                    subtitle: "View & manage",
                    color: .blue
                ) {
                    showAccountDetails = true
                }
                
                ActionCardView(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Switch Mode",
                    subtitle: "Change app mode",
                    color: .orange
                ) {
                    selectedMode = nil
                }
            }
        }
    }
}

// MARK: - Account Section View
struct AccountSectionView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Binding var showSignOutAlert: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeaderView(title: "Account")
            
            VStack(spacing: 12) {
                SettingsRowView(
                    icon: "person.2.circle",
                    title: "Privacy Settings",
                    subtitle: "Manage your data"
                ) {
                    // Handle privacy settings
                }
                
                SettingsRowView(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    subtitle: "Get assistance"
                ) {
                    // Handle help & support
                }
                
                SettingsRowView(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: "Sign out of Apple ID",
                    isDestructive: true
                ) {
                    showSignOutAlert = true
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

// MARK: - App Info Section View
struct AppInfoSectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            SectionHeaderView(title: "About")
            
            VStack(spacing: 12) {
                InfoRowView(
                    title: "Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                )
                
                InfoRowView(
                    title: "Build",
                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                )
                
                Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        Text("GitHub Repository")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
}

// MARK: - Helper Views
struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

struct ActionCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Account Details View
struct AccountDetailsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Apple ID Information") {
                    DetailRowView(label: "User ID", value: authManager.userID ?? "Unknown")
                    DetailRowView(label: "Full Name", value: authManager.userFullName ?? "Not provided")
                    DetailRowView(label: "Email", value: authManager.userEmail ?? "Not provided")
                    DetailRowView(label: "Display Name", value: authManager.displayName)
                    DetailRowView(label: "Initials", value: authManager.userInitials)
                }
                
                Section("Profile Status") {
                    HStack {
                        Text("Profile Complete")
                        Spacer()
                        Image(systemName: authManager.hasCompleteProfile ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(authManager.hasCompleteProfile ? .green : .red)
                    }
                }
                
                Section("Authentication") {
                    HStack {
                        Text("Signed In")
                        Spacer()
                        Image(systemName: authManager.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(authManager.isAuthenticated ? .green : .red)
                    }
                }
            }
            .navigationTitle("Account Details")
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

struct DetailRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
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
