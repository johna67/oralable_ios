//
//  ShareView.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Uses ShareViewModel (MVVM pattern)
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsShareView: View {
    @StateObject private var viewModel = ShareViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Export Options
                    exportOptionsSection
                    
                    // Date Range Selection
                    dateRangeSection
                    
                    // Data Types Selection
                    dataTypesSection
                    
                    // Export Format
                    exportFormatSection
                    
                    // Preview Section
                    if viewModel.hasDataToExport {
                        previewSection
                    }
                    
                    // Export Button
                    exportButtonSection
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .alert("Export Complete", isPresented: $viewModel.showExportSuccess) {
            Button("Share") {
                shareExportedData()
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your data has been exported successfully.")
        }
        .alert("Export Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Failed to export data")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
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
                        selection: $viewModel.startDate,
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
                        selection: $viewModel.endDate,
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
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
            
            // Select All / None
            HStack {
                Button("Select All") {
                    viewModel.selectAllDataTypes()
                }
                .font(designSystem.typography.caption)
                
                Spacer()
                
                Button("Select None") {
                    viewModel.deselectAllDataTypes()
                }
                .font(designSystem.typography.caption)
            }
            .padding(.horizontal, designSystem.spacing.sm)
        }
    }
    
    // MARK: - Export Format Section
    
    private var exportFormatSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Export Format", icon: "doc.text")
            
            VStack(spacing: 0) {
                // CSV
                FormatRow(
                    format: .csv,
                    isSelected: viewModel.selectedFormat == .csv
                ) {
                    viewModel.selectedFormat = .csv
                }
                
                Divider()
                
                // JSON
                FormatRow(
                    format: .json,
                    isSelected: viewModel.selectedFormat == .json
                ) {
                    viewModel.selectedFormat = .json
                }
                
                Divider()
                
                // PDF
                FormatRow(
                    format: .pdf,
                    isSelected: viewModel.selectedFormat == .pdf
                ) {
                    viewModel.selectedFormat = .pdf
                }
            }
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Export Preview", icon: "eye")
            
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                HStack {
                    Text("File Name:")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text(viewModel.exportFileName)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
                
                HStack {
                    Text("File Size (est.):")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text(viewModel.estimatedFileSize)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
                
                HStack {
                    Text("Data Points:")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    Text(viewModel.totalDataPointsText)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textPrimary)
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    
    // MARK: - Export Button Section
    
    private var exportButtonSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            Button(action: {
                Task {
                    await viewModel.exportData()
                    if viewModel.exportedFileURL != nil {
                        shareExportedData()
                    }
                }
            }) {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(viewModel.hasDataToExport ? designSystem.colors.primaryBlack : Color.gray)
                .foregroundColor(designSystem.colors.primaryWhite)
                .cornerRadius(designSystem.cornerRadius.md)
            }
            .disabled(!viewModel.hasDataToExport || viewModel.isExporting)
            
            if viewModel.exportProgress > 0 && viewModel.exportProgress < 1 {
                ProgressView(value: viewModel.exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(viewModel.exportProgress * 100))% Complete")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shareExportedData() {
        guard let fileURL = viewModel.exportedFileURL else { return }
        shareItems = [fileURL]
        showingShareSheet = true
    }
}

// MARK: - Quick Export Button

struct QuickExportButton: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: designSystem.spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(designSystem.typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(designSystem.spacing.sm)
            .background(isSelected ? designSystem.colors.primaryBlack : designSystem.colors.backgroundSecondary)
            .foregroundColor(isSelected ? designSystem.colors.primaryWhite : designSystem.colors.textPrimary)
            .cornerRadius(designSystem.cornerRadius.sm)
        }
    }
}

// MARK: - Data Type Row

struct DataTypeRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let dataCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                if dataCount > 0 {
                    Text("\(dataCount)")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? designSystem.colors.primaryBlack : designSystem.colors.textTertiary)
            }
            .padding(designSystem.spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Format Row

struct FormatRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let format: ShareViewModel.ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: format.icon)
                    .foregroundColor(format.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.displayName)
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)
                    
                    Text(format.description)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? designSystem.colors.primaryBlack : designSystem.colors.textTertiary)
            }
            .padding(designSystem.spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct SettingsShareView_Previews: PreviewProvider {
    static var previews: some View {
        ShareView()
            .environmentObject(DesignSystem.shared)
    }
}
