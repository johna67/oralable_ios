//
//  AuthenticationView.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Refactored to use AuthenticationViewModel (MVVM pattern)
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    // MVVM: Use ViewModel instead of direct manager access
    @StateObject private var viewModel = AuthenticationViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showingProfileDetails = false
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.xl) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Authentication Status
                    authenticationStatusCard
                    
                    // Profile Information (if authenticated)
                    if viewModel.isAuthenticated {
                        profileInformationSection
                        profileActionsSection
                    } else {
                        signInSection
                    }
                    
                    // Debug Section (only in DEBUG builds)
                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingProfileDetails = true }) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.checkAuthenticationState()
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.authenticationError ?? "An authentication error occurred")
        }
        .sheet(isPresented: $showingProfileDetails) {
            ProfileDetailView(viewModel: viewModel)
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(viewModel.isAuthenticated ? Color.green : designSystem.colors.backgroundTertiary)
                    .frame(width: 100, height: 100)
                
                if viewModel.isAuthenticated {
                    Text(viewModel.userInitials)
                        .font(designSystem.typography.largeTitle)
                        .foregroundColor(designSystem.colors.primaryWhite)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 50))
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            
            // Greeting
            Text(viewModel.greetingText)
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
            // Display Name
            if let displayName = viewModel.displayName {
                Text(displayName)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
        }
    }
    
    // MARK: - Authentication Status Card
    
    private var authenticationStatusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                HStack {
                    Circle()
                        .fill(viewModel.isAuthenticated ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(viewModel.isAuthenticated ? "Signed In" : "Not Signed In")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
                
                Text(viewModel.profileStatusText)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Spacer()
            
            if viewModel.isAuthenticated {
                // Profile Completion
                CircularProgressView(
                    progress: viewModel.profileCompletionPercentage / 100,
                    lineWidth: 4,
                    size: 40
                ) {
                    Text("\(Int(viewModel.profileCompletionPercentage))%")
                        .font(designSystem.typography.caption2)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Sign In Section
    
    private var signInSection: some View {
        VStack(spacing: designSystem.spacing.lg) {
            // Benefits List
            VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                Text("Sign in to:")
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                FeatureRow(
                    icon: "icloud",
                    title: "Sync your data",
                    subtitle: "Access from any device"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Track progress",
                    subtitle: "View historical trends"
                )
                
                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Export reports",
                    subtitle: "Share with healthcare providers"
                )
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
            
            // Sign In Button
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    viewModel.handleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    
    // MARK: - Profile Information Section
    
    private var profileInformationSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Profile Information", icon: "person.text.rectangle")
            
            VStack(spacing: designSystem.spacing.sm) {
                if let email = viewModel.userEmail {
                    InfoRowView(label: "Email", value: email)
                }
                
                if let fullName = viewModel.userFullName {
                    InfoRowView(label: "Name", value: fullName)
                }
                
                if let userID = viewModel.userID {
                    InfoRowView(
                        label: "User ID",
                        value: String(userID.prefix(8)) + "..."
                    )
                }
                
                InfoRowView(
                    label: "Member Since",
                    value: viewModel.memberSinceText
                )
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    
    // MARK: - Profile Actions Section
    
    private var profileActionsSection: some View {
        VStack(spacing: designSystem.spacing.sm) {
            // Refresh Profile
            ActionCardView(
                icon: "arrow.clockwise",
                title: "Refresh Profile",
                subtitle: "Update profile information",
                action: {
                    viewModel.refreshProfile()
                }
            )
            
            // Export Data
            ActionCardView(
                icon: "square.and.arrow.up",
                title: "Export Data",
                subtitle: "Download all your data",
                action: {
                    // Navigate to export view
                }
            )
            
            // Privacy Settings
            ActionCardView(
                icon: "lock.shield",
                title: "Privacy Settings",
                subtitle: "Manage data and permissions",
                action: {
                    // Navigate to privacy settings
                }
            )
            
            // Sign Out
            ActionCardView(
                icon: "arrow.right.square",
                title: "Sign Out",
                subtitle: "Sign out of your account",
                color: .red,
                action: {
                    showingSignOutConfirmation = true
                }
            )
        }
    }
    
    // MARK: - Debug Section
    
    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Debug Information", icon: "ladybug")
            
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                Button(action: { viewModel.debugAuthState() }) {
                    HStack {
                        Image(systemName: "ant.circle")
                        Text("Print Auth State")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(designSystem.spacing.sm)
                    .background(designSystem.colors.backgroundTertiary)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                Button(action: { viewModel.resetAppleIDAuth() }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset Apple ID Auth")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(designSystem.spacing.sm)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                // Auth State Info
                Text("Auth State: \(viewModel.isAuthenticated ? "Authenticated" : "Not Authenticated")")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
                
                if let userID = viewModel.userID {
                    Text("User ID: \(userID)")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    #endif
}

// MARK: - Profile Detail View

struct ProfileDetailView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    
    let viewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Account Information") {
                    if let email = viewModel.userEmail {
                        InfoRowView(label: "Email", value: email)
                    }
                    
                    if let fullName = viewModel.userFullName {
                        InfoRowView(label: "Full Name", value: fullName)
                    }
                    
                    if let userID = viewModel.userID {
                        InfoRowView(label: "User ID", value: userID)
                    }
                }
                
                Section("Profile Stats") {
                    InfoRowView(label: "Completion", value: "\(Int(viewModel.profileCompletionPercentage))%")
                    InfoRowView(label: "Member Since", value: viewModel.memberSinceText)
                    InfoRowView(label: "Last Updated", value: viewModel.lastUpdatedText)
                }
                
                Section("Subscription") {
                    InfoRowView(label: "Status", value: viewModel.subscriptionStatus)
                    InfoRowView(label: "Plan", value: viewModel.subscriptionPlan)
                    if viewModel.hasSubscription {
                        InfoRowView(label: "Expires", value: viewModel.subscriptionExpiryText)
                    }
                }
                
                Section("Data & Privacy") {
                    Button(action: {
                        // Request data export
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Request Data Export")
                        }
                    }
                    
                    Button(action: {
                        // Delete account
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile Details")
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

// MARK: - Circular Progress View

struct CircularProgressView<Content: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            content()
        }
    }
}

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(DesignSystem.shared)
    }
}
