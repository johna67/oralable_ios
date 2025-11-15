//
//  SettingsView.swift
//  OralableApp
//
//  Wireframe Version - Conditional sections based on mode
//  Viewer Mode: Mode badge, Diagnostics, About
//  Subscription Mode: Profile, Thresholds, Calibration, Diagnostics, About, Sign Out
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var showingAuthenticationView = false
    @State private var showingSignOutAlert = false
    @State private var showingChangeModeAlert = false
    @State private var showingLogs = false

    var isViewerMode: Bool {
        appStateManager.selectedMode == .viewer
    }

    var isSubscriptionMode: Bool {
        appStateManager.selectedMode == .subscription
    }

    var body: some View {
        NavigationView {
            List {
                // VIEWER MODE: Show mode badge with upgrade option
                if isViewerMode {
                    modeBadgeSection
                }

                // SUBSCRIPTION MODE ONLY: Profile Section
                if isSubscriptionMode {
                    profileSection
                }

                // SUBSCRIPTION MODE ONLY: Thresholds Section
                if isSubscriptionMode {
                    thresholdsSection
                }

                // SUBSCRIPTION MODE ONLY: Calibration Section
                if isSubscriptionMode {
                    calibrationSection
                }

                // BOTH MODES: Diagnostics Section
                diagnosticsSection

                // BOTH MODES: About Section
                aboutSection

                // SUBSCRIPTION MODE ONLY: Sign Out
                if isSubscriptionMode {
                    signOutSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAuthenticationView) {
            AuthenticationView()
                .environmentObject(designSystem)
                .environmentObject(authenticationManager)
                .environmentObject(appStateManager)
        }
        .sheet(isPresented: $showingLogs) {
            NavigationView {
                LogsView()
                    .environmentObject(designSystem)
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authenticationManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Change Mode", isPresented: $showingChangeModeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Change Mode", role: .destructive) {
                appStateManager.clearMode()
            }
        } message: {
            Text("Changing modes will return you to mode selection. Any unsaved data may be lost.")
        }
    }

    // MARK: - Mode Badge Section (Viewer Only)

    private var modeBadgeSection: some View {
        Section {
            VStack(spacing: designSystem.spacing.md) {
                HStack {
                    Image(systemName: "eye")
                        .foregroundColor(designSystem.colors.accentBlue)
                    Text("Viewer Mode")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)

                    Spacer()

                    Text("Free")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(4)
                }

                Button(action: {
                    showingChangeModeAlert = true
                }) {
                    HStack {
                        Image(systemName: "crown")
                        Text("Upgrade to Subscription Mode")
                    }
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.primaryWhite)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(designSystem.colors.primaryBlack)
                    .cornerRadius(designSystem.cornerRadius.md)
                }
            }
        } header: {
            Text("Current Mode")
        } footer: {
            Text("Upgrade to unlock Bluetooth connectivity, data export, and HealthKit integration.")
        }
    }

    // MARK: - Profile Section (Subscription Only)

    private var profileSection: some View {
        Section {
            if authenticationManager.isAuthenticated {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(designSystem.colors.primaryBlack)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authenticationManager.displayName)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)

                        if let email = authenticationManager.userEmail {
                            Text(email)
                                .font(designSystem.typography.caption)
                                .foregroundColor(designSystem.colors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                NavigationLink(destination: ProfileView()) {
                    HStack {
                        Image(systemName: "person.badge.key")
                        Text("Manage Profile")
                    }
                }
            } else {
                Button {
                    showingAuthenticationView = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key")
                            .foregroundColor(designSystem.colors.primaryBlack)
                        Text("Sign In with Apple")
                            .foregroundColor(designSystem.colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
            }
        } header: {
            Text("Profile")
        }
    }

    // MARK: - Thresholds Section (Subscription Only)

    private var thresholdsSection: some View {
        Section {
            NavigationLink(destination: ThresholdConfigurationView()) {
                HStack {
                    Image(systemName: "gauge")
                    Text("Heart Rate Thresholds")
                }
            }

            NavigationLink(destination: ThresholdConfigurationView()) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("SpO2 Thresholds")
                }
            }

            NavigationLink(destination: ThresholdConfigurationView()) {
                HStack {
                    Image(systemName: "thermometer")
                    Text("Temperature Thresholds")
                }
            }
        } header: {
            Text("Thresholds")
        } footer: {
            Text("Configure alert thresholds for health metrics.")
        }
    }

    // MARK: - Calibration Section (Subscription Only)

    private var calibrationSection: some View {
        Section {
            NavigationLink(destination: CalibrationView()) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Sensor Calibration")
                }
            }

            NavigationLink(destination: CalibrationView()) {
                HStack {
                    Image(systemName: "scope")
                    Text("PPG Calibration")
                }
            }
        } header: {
            Text("Calibration")
        } footer: {
            Text("Calibrate sensors for optimal accuracy.")
        }
    }

    // MARK: - Diagnostics Section (Both Modes)

    private var diagnosticsSection: some View {
        Section {
            Button {
                showingLogs = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(designSystem.colors.textPrimary)
                    Text("View Logs")
                        .foregroundColor(designSystem.colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            HStack {
                Image(systemName: "info.circle")
                Text("App Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            HStack {
                Image(systemName: "iphone")
                Text("Device Model")
                Spacer()
                Text(deviceModel)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            HStack {
                Image(systemName: "gearshape.2")
                Text("iOS Version")
                Spacer()
                Text(systemVersion)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
        } header: {
            Text("Diagnostics")
        }
    }

    // MARK: - About Section (Both Modes)

    private var aboutSection: some View {
        Section {
            Link(destination: URL(string: "https://oralable.com/privacy")!) {
                HStack {
                    Image(systemName: "hand.raised")
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            Link(destination: URL(string: "https://oralable.com/terms")!) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            Link(destination: URL(string: "https://oralable.com/support")!) {
                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("Support")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            Button {
                showingChangeModeAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(designSystem.colors.textPrimary)
                    Text("Change Mode")
                        .foregroundColor(designSystem.colors.textPrimary)
                }
            }
        } header: {
            Text("About")
        } footer: {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Oralable")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                    Text("Version \(appVersion)")
                        .font(designSystem.typography.caption2)
                        .foregroundColor(designSystem.colors.textTertiary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Sign Out Section (Subscription Only)

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helper Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var deviceModel: String {
        UIDevice.current.model
    }

    private var systemVersion: String {
        "iOS \(UIDevice.current.systemVersion)"
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(AppStateManager.shared)
    }
}
