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
            
            // Top Navigation Bar Overlay
            VStack {
                HStack {
                    // Left: Profile Button
                    ProfileButtonView(
                        authManager: authManager,
                        action: { showProfile = true }
                    )
                    
                    Spacer()
                    
                    // Right: Devices Button
                    Button(action: { showDevices = true }) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(ble.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "wave.3.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(ble.isConnected ? .green : .gray)
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView()
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(ble: ble)
        }
    }
}

// MARK: - User Profile View
struct UserProfileView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAccountDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Quick Actions
                    QuickActionsView(showAccountDetails: $showAccountDetails)
                    
                    // Account Section
                    AccountSectionView(showAccountDetails: $showAccountDetails)
                    
                    // App Info
                    AppInfoSectionView()
                    
                    // Sign Out Button
                    Button(action: {
                        authManager.signOut()
                        dismiss()
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
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
            .sheet(isPresented: $showAccountDetails) {
                AccountDetailsView()
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            UserAvatarView(
                initials: authManager.userInitials,
                size: 80,
                showOnlineIndicator: true
            )
            
            // Name
            Text(authManager.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            // Email
            if let email = authManager.userEmail {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @Binding var showAccountDetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Quick Actions")
            
            VStack(spacing: 12) {
                ActionCardView(
                    icon: "person.circle",
                    title: "Account Details",
                    description: "View and edit your account information",
                    action: { showAccountDetails = true }
                )
                
                ActionCardView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "View Data",
                    description: "Access your health data and history",
                    action: {}
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Account Section
struct AccountSectionView: View {
    @Binding var showAccountDetails: Bool
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Account")
            
            VStack(spacing: 0) {
                SettingsRowView(
                    icon: "person.fill",
                    title: "Personal Information",
                    action: { showAccountDetails = true }
                )
                
                Divider().padding(.leading, 44)
                
                SettingsRowView(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    action: {}
                )
                
                Divider().padding(.leading, 44)
                
                SettingsRowView(
                    icon: "bell.fill",
                    title: "Notifications",
                    action: {}
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - App Info Section
struct AppInfoSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "About")
            
            VStack(spacing: 0) {
                SettingsRowView(
                    icon: "info.circle.fill",
                    title: "App Version",
                    subtitle: "1.0.0",
                    showChevron: false,
                    action: {}
                )
                
                Divider().padding(.leading, 44)
                
                SettingsRowView(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    action: {}
                )
                
                Divider().padding(.leading, 44)
                
                SettingsRowView(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    action: {}
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - Account Details View
struct AccountDetailsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Account Information
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(title: "Account Information")
                        
                        VStack(spacing: 12) {
                            if let name = authManager.userFullName {
                                InfoRowView(icon: "person.fill", title: "Name", value: name)
                                Divider().padding(.leading, 44)
                            }
                            
                            if let email = authManager.userEmail {
                                InfoRowView(icon: "envelope.fill", title: "Email", value: email)
                                Divider().padding(.leading, 44)
                            }
                            
                            if let userID = authManager.userID {
                                InfoRowView(icon: "key.fill", title: "User ID", value: userID)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
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
