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

import UniformTypeIdentifiers
import UIKit

struct SettingsShareView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var viewModelInstance: ShareViewModel?
    
    // Computed property that safely unwraps the viewModel
    private var viewModel: ShareViewModel {
        if let vm = viewModelInstance {
            return vm
        }
        // Initialize if not already done
        // Create a BLE-backed repository adapter
        let repository = BLESensorRepository(ble: OralableBLE.shared)
        let vm = ShareViewModel(
            deviceManager: deviceManager,
            repository: repository
        )
        DispatchQueue.main.async {
            viewModelInstance = vm
        }
        return vm
    }
    
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
        }
        .alert("Export Complete", isPresented: Binding(
            get: { viewModel.showExportSuccess },
            set: { _ in }
        )) {
            Button("Share") {
                shareExportedData()
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your data has been exported successfully.")
        }
        .alert("Export Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { _ in }
        )) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Failed to export data")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .onAppear {
            // Ensure viewModel is initialized
            _ = viewModel
        }
    }
    
    // MARK: - Export Options Section
    
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Quick Export", icon: "square.and.arrow.up")
            
            HStack(spacing: designSystem.spacing.md) {
                // Today's Data
                QuickExportButton(
                    title: "Today",
                    icon: "calendar.day.timeline.left",
                    isSelected: viewModel.quickExportOption == .today,
                    action: {
                        viewModel.selectQuickExport(.today)
                    }
                )
                
                // This Week
                QuickExportButton(
                    title: "This Week",
                    icon: "calendar.badge.clock",
                    isSelected: viewModel.quickExportOption == .thisWeek,
                    action: {
                        viewModel.selectQuickExport(.thisWeek)
                    }
                )
                
                // This Month
                QuickExportButton(
                    title: "This Month",
                    icon: "calendar",
                    isSelected: viewModel.quickExportOption == .thisMonth,
                    action: {
                        viewModel.selectQuickExport(.thisMonth)
                    }
                )
                
                // Custom Range
                QuickExportButton(
                    title: "Custom",
                    icon: "calendar.badge.plus",
                    isSelected: viewModel.quickExportOption == .custom,
                    action: {
                        viewModel.selectQuickExport(.custom)
                    }
                )
            }
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Date Range", icon: "calendar")
            
            VStack(spacing: designSystem.spacing.sm) {
                // Start Date
                HStack {
                    Text("From")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.startDate },
                            set: { viewModel.startDate = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                }
                
                // End Date
                HStack {
                    Text("To")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .frame(width: 60, alignment: .leading)
                    
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.endDate },
                            set: { viewModel.endDate = $0 }
                        ),
                        in: viewModel.startDate...Date(),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
            
            // Date Range Info
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("\(viewModel.dateRangeDays) days of data")
                    .font(designSystem.typography.caption)
            }
            .foregroundColor(designSystem.colors.textTertiary)
        }
    }
    
    // MARK: - Data Types Section
    
    private var dataTypesSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Data Types", icon: "checklist")
            
            VStack(spacing: 0) {
                // Heart Rate
                DataTypeRow(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    color: .red,
                    isSelected: viewModel.includeHeartRate,
                    dataCount: viewModel.heartRateDataCount
                ) {
                    viewModel.includeHeartRate.toggle()
                }
                
                Divider()
                
                // SpO2
                DataTypeRow(
                    icon: "lungs.fill",
                    title: "SpO2",
                    color: .blue,
                    isSelected: viewModel.includeSpO2,
                    dataCount: viewModel.spo2DataCount
                ) {
                    viewModel.includeSpO2.toggle()
                }
                
                Divider()
                
                // Temperature
                DataTypeRow(
                    icon: "thermometer",
                    title: "Temperature",
                    color: .orange,
                    isSelected: viewModel.includeTemperature,
                    dataCount: viewModel.temperatureDataCount
                ) {
                    viewModel.includeTemperature.toggle()
                }
                
                Divider()
                
                // Accelerometer
                DataTypeRow(
                    icon: "figure.walk",
                    title: "Movement Data",
                    color: .green,
                    isSelected: viewModel.includeAccelerometer,
                    dataCount: viewModel.accelerometerDataCount
                ) {
                    viewModel.includeAccelerometer.toggle()
                }
                
                Divider()
                
                // Session Notes
                DataTypeRow(
                    icon: "note.text",
                    title: "Session Notes",
                    color: .purple,
                    isSelected: viewModel.includeNotes,
                    dataCount: viewModel.notesCount
                ) {
                    viewModel.includeNotes.toggle()
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
        SettingsShareView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(DeviceManager())
            .environmentObject(HistoricalDataManager(bleManager: OralableBLE.shared))
    }
}
