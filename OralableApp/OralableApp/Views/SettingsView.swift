//
//  SettingsView.swift
//  OralableApp
//
//  Created: November 11, 2025
//  Uses SettingsViewModel (MVVM pattern)
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showingExportSheet = false

    var body: some View {
        NavigationView {
            List {
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
            ShareView(ble: OralableBLE.shared)
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
            .environmentObject(DesignSystem.shared)
    }
}
