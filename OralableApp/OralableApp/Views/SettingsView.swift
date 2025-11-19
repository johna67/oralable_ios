//
//  SettingsView.swift
//  OralableApp
//
//  Created: November 11, 2025
//  Uses SettingsViewModel (MVVM pattern)
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var bleManager: OralableBLE
    @State private var showingExportSheet = false
    @State private var showingAuthenticationView = false
    @State private var showingSubscriptionView = false
    @State private var showingSignOutAlert = false
    @State private var showingChangeModeAlert = false

    init(viewModel: SettingsViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            // Legacy path - create with new BLE manager instance
            let bleManager = OralableBLE()
            _viewModel = StateObject(wrappedValue: SettingsViewModel(bleManager: bleManager))
        }
    }

    var body: some View {
        NavigationView {
            List {
                accountAndPreferencesGroup
                deviceAndNotificationsGroup
                dataAndPrivacyGroup
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Clear All Data?", isPresented: $viewModel.showClearDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text("This will permanently delete all historical data. This action cannot be undone.")
        }
        .alert("Reset Settings?", isPresented: $viewModel.showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .sheet(isPresented: $showingExportSheet) {
            ShareView(ble: bleManager)
        }
        .sheet(isPresented: $showingAuthenticationView) {
            NavigationView {
                AuthenticationView()
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionTierSelectionView()
        }
        .alert("Sign Out?", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authenticationManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access subscription features.")
        }
        .alert("Change Mode?", isPresented: $showingChangeModeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Change Mode", role: .destructive) {
                appStateManager.clearMode()
            }
        } message: {
            Text("Changing modes will restart the app and may require signing in again. Are you sure?")
        }
    }

    // MARK: - View Groups

    @ViewBuilder
    private var accountAndPreferencesGroup: some View {
        // Account Section
        Section {
            if authenticationManager.isAuthenticated {
                // Signed In State
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

                Button {
                    showingAuthenticationView = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key")
                        Text("Manage Account")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }

                Button(role: .destructive) {
                    showingSignOutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            } else {
                // Not Signed In State
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
            Text("Account")
        } footer: {
            if !authenticationManager.isAuthenticated {
                Text("Sign in to access all features and sync your data across devices")
            }
        }

        // Subscription Section
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Text(subscriptionManager.currentTier.displayName)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)

                        if subscriptionManager.isPaidSubscriber {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                if subscriptionManager.currentTier == .basic {
                    Button("Upgrade") {
                        showingSubscriptionView = true
                    }
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.primaryBlack)
                }
            }
            .padding(.vertical, 4)

            Button {
                showingSubscriptionView = true
            } label: {
                HStack {
                    Image(systemName: "star.circle")
                    Text("Manage Subscription")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
        } header: {
            Text("Subscription")
        } footer: {
            if subscriptionManager.currentTier == .basic {
                Text("Upgrade to Premium for unlimited data storage, advanced analytics, and more")
            }
        }

        // App Mode Section
        Section {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(designSystem.colors.primaryBlack)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Mode")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    Text(appStateManager.selectedMode?.displayName ?? "Full Access")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
            }
            .padding(.vertical, 4)

            Button {
                showingChangeModeAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Change Mode")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
        } header: {
            Text("App Mode")
        } footer: {
            Text("Patient app with full subscription access")
        }
    }

    @ViewBuilder
    private var deviceAndNotificationsGroup: some View {
        // Device Settings Section
        Section {
            // PPG Channel Order
            NavigationLink {
                PPGChannelOrderView(selectedOrder: $viewModel.ppgChannelOrder)
            } label: {
                HStack {
                    Text("PPG Channel Order")
                    Spacer()
                    Text(viewModel.ppgChannelOrder.displayName)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            // Auto-connect
            Toggle("Auto-connect", isOn: $viewModel.autoConnectEnabled)

            // Debug Info
            Toggle("Show Debug Info", isOn: $viewModel.showDebugInfo)
                .tint(designSystem.colors.primaryBlack)
        } header: {
            Text("Device Settings")
        }

        // Notification Settings Section
        Section {
            Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
                .tint(designSystem.colors.primaryBlack)

            if viewModel.notificationsEnabled {
                Toggle("Connection Alerts", isOn: $viewModel.connectionAlerts)
                    .tint(designSystem.colors.primaryBlack)

                Toggle("Battery Alerts", isOn: $viewModel.batteryAlerts)
                    .tint(designSystem.colors.primaryBlack)

                if viewModel.batteryAlerts {
                    Stepper("Low Battery: \(viewModel.lowBatteryThreshold)%",
                           value: $viewModel.lowBatteryThreshold,
                           in: 5...50,
                           step: 5)
                }
            }
        } header: {
            Text("Notifications")
        }

        // Display Settings Section
        Section {
            Toggle("Use Metric Units", isOn: $viewModel.useMetricUnits)
                .tint(designSystem.colors.primaryBlack)

            Toggle("24-Hour Time", isOn: $viewModel.show24HourTime)
                .tint(designSystem.colors.primaryBlack)

            Picker("Chart Refresh", selection: $viewModel.chartRefreshRate) {
                ForEach(ChartRefreshRate.allCases, id: \.self) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }
        } header: {
            Text("Display")
        }
    }

    @ViewBuilder
    private var dataAndPrivacyGroup: some View {
        // Data Management Section
        Section {
            Stepper("Retention: \(viewModel.dataRetentionDays) days",
                   value: $viewModel.dataRetentionDays,
                   in: 1...365)

            Button(role: .destructive) {
                viewModel.showClearDataConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Data older than \(viewModel.dataRetentionDays) days will be automatically deleted.")
        }

        // Privacy Section
        Section {
            Toggle("Share Analytics", isOn: $viewModel.shareAnalytics)
                .tint(designSystem.colors.primaryBlack)

            Toggle("Local Storage Only", isOn: $viewModel.localStorageOnly)
                .tint(designSystem.colors.primaryBlack)
        } header: {
            Text("Privacy")
        } footer: {
            Text("When enabled, all data stays on this device and is never sent to cloud services.")
        }

        // Export & Share Section
        Section {
            Button {
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(designSystem.colors.primaryBlack)
                    Text("Export Data")
                        .foregroundColor(designSystem.colors.textPrimary)
                }
            }
        } header: {
            Text("Data Export")
        }

        // About Section
        Section {
            InfoRowView(icon: "info.circle", title: "Version", value: viewModel.appVersion)
            InfoRowView(icon: "number", title: "Build", value: viewModel.buildNumber)

            Button {
                viewModel.showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text(viewModel.versionText)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(designSystem.colors.textTertiary)
                .padding(.top, designSystem.spacing.md)
        }
    }
}

// MARK: - PPG Channel Order View

struct PPGChannelOrderView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedOrder: PPGChannelOrder

    var body: some View {
        List {
            ForEach(PPGChannelOrder.allCases, id: \.self) { order in
                Button {
                    selectedOrder = order
                    dismiss()
                } label: {
                    HStack {
                        Text(order.displayName)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)

                        Spacer()

                        if order == selectedOrder {
                            Image(systemName: "checkmark")
                                .foregroundColor(designSystem.colors.primaryBlack)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("PPG Channel Order")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PPGChannelOrder Extension

extension PPGChannelOrder {
    var displayName: String {
        return self.rawValue
    }
}




// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DesignSystem())
            .environmentObject(AuthenticationManager())
            .environmentObject(SubscriptionManager())
            .environmentObject(AppStateManager())
    }
}
