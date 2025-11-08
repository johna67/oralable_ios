//
//  ProfileView.swift
//  OralableApp
//
//  Created by John A Cogan on 08/11/2025.
//


//
//  ProfileView.swift
//  OralableApp
//
//  Created: November 8, 2025
//  Basic profile view for single-device launch
//

import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Profile Header
                    profileHeader
                    
                    // Account Section
                    accountSection
                    
                    // Device Info Section
                    deviceInfoSection
                    
                    // App Info Section
                    appInfoSection
                    
                    // Support Section
                    supportSection
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(designSystem.colors.primaryBlack)
                }
            }
            .background(designSystem.colors.backgroundPrimary)
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Profile Image
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(designSystem.colors.textSecondary)
            
            // User Name
            Text(authManager.displayName)
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)
            
            // User Email
            Text(authManager.userEmail ?? "Not signed in")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
        }
        .padding(designSystem.spacing.xl)
        .frame(maxWidth: .infinity)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Account")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                if authManager.isAuthenticated {
                    // Sign Out Button
                    Button(action: { showingSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(designSystem.spacing.md)
                    }
                } else {
                    // Sign In with Apple Button
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            authManager.handleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(designSystem.cornerRadius.medium)
                    .padding(designSystem.spacing.md)
                }
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Device Info Section
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Device")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                // Device Type
                InfoRowView(
                    icon: "cpu",
                    title: "Device Type",
                    value: "Oralable PPG"
                )
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // Firmware Version
                InfoRowView(
                    icon: "shippingbox",
                    title: "Firmware",
                    value: "1.0.0"
                )
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // Connection Status
                InfoRowView(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Status",
                    value: OralableBLE.shared.isConnected ? "Connected" : "Disconnected",
                    iconColor: OralableBLE.shared.isConnected ? .green : .gray
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("App Information")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                // App Version
                InfoRowView(
                    icon: "app.badge",
                    title: "Version",
                    value: "1.0.0 (Build 1)"
                )
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // iOS Version
                InfoRowView(
                    icon: "iphone",
                    title: "iOS Required",
                    value: "15.0+"
                )
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // Company
                InfoRowView(
                    icon: "building.2",
                    title: "Developer",
                    value: "JAC Dental Solutions"
                )
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Support")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)
            
            VStack(spacing: 0) {
                // User Guide
                NavigationLink(destination: Text("User Guide Coming Soon")) {
                    HStack {
                        Image(systemName: "book")
                            .foregroundColor(designSystem.colors.primaryBlack)
                        Text("User Guide")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .padding(designSystem.spacing.md)
                }
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // Support Email
                Button(action: openSupportEmail) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(designSystem.colors.primaryBlack)
                        Text("Contact Support")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .padding(designSystem.spacing.md)
                }
                
                Divider()
                    .padding(.horizontal, designSystem.spacing.md)
                
                // Privacy Policy
                Button(action: openPrivacyPolicy) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(designSystem.colors.primaryBlack)
                        Text("Privacy Policy")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .padding(designSystem.spacing.md)
                }
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }
    
    // MARK: - Actions
    
    private func openSupportEmail() {
        if let url = URL(string: "mailto:support@oralable.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://oralable.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(DesignSystem.shared)
    }
}
