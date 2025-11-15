//
//  SharingView.swift
//  OralableApp
//
//  NEW view for wireframe refactor
//  CRITICAL: Enforces mode-specific Import/Export logic
//  - Viewer Mode: Import ENABLED, Export DISABLED, HealthKit DISABLED
//  - Subscription Mode: Import DISABLED, Export ENABLED, HealthKit ENABLED
//

import SwiftUI
import UniformTypeIdentifiers

struct SharingView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showingImportPicker = false
    @State private var showingExportSheet = false
    @State private var showingHealthKitSheet = false

    var isViewerMode: Bool {
        appStateManager.selectedMode == .viewer
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // IMPORT SECTION - VIEWER MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("Import Data")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "arrow.down.doc.fill",
                            title: "Import CSV File",
                            description: isViewerMode ?
                                "Load historical data from exported files" :
                                "Import available in Viewer Mode only",
                            buttonText: "Select File",
                            isEnabled: isViewerMode  // ← ENABLED IN VIEWER ONLY
                        ) {
                            if isViewerMode {
                                showingImportPicker = true
                            }
                        }
                    }

                    // EXPORT SECTION - SUBSCRIPTION MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("Export Data")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "arrow.up.doc.fill",
                            title: "Export as CSV",
                            description: isViewerMode ?
                                "Export available in Subscription Mode" :
                                "Share your data for analysis",
                            buttonText: "Export Data",
                            isEnabled: !isViewerMode  // ← ENABLED IN SUBSCRIPTION ONLY
                        ) {
                            if !isViewerMode {
                                showingExportSheet = true
                            }
                        }
                    }

                    // HEALTHKIT SECTION - SUBSCRIPTION MODE ONLY
                    VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                        Text("HealthKit")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)

                        ActionCard(
                            icon: "heart.fill",
                            title: "Connect HealthKit",
                            description: isViewerMode ?
                                "HealthKit available in Subscription Mode" :
                                "Sync with Apple Health",
                            buttonText: "Connect HealthKit",
                            isEnabled: !isViewerMode,  // ← ENABLED IN SUBSCRIPTION ONLY
                            buttonStyle: .secondary
                        ) {
                            if !isViewerMode {
                                showingHealthKitSheet = true
                            }
                        }
                    }

                    // Mode info banner
                    modeInfoBanner
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.large)
            .background(designSystem.colors.backgroundSecondary.ignoresSafeArea())
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataSheet()
        }
        .sheet(isPresented: $showingHealthKitSheet) {
            HealthKitConnectionSheet()
        }
    }

    // MARK: - Mode Info Banner

    private var modeInfoBanner: some View {
        HStack(spacing: designSystem.spacing.sm) {
            Image(systemName: isViewerMode ? "eye.fill" : "crown.fill")
                .foregroundColor(isViewerMode ? designSystem.colors.accentBlue : designSystem.colors.accentGreen)

            VStack(alignment: .leading, spacing: 4) {
                Text(isViewerMode ? "Viewer Mode" : "Subscription Mode")
                    .font(designSystem.typography.captionBold)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text(isViewerMode ?
                    "You can import CSV files in this mode" :
                    "You can export data and use HealthKit in this mode")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            Spacer()

            if isViewerMode {
                Button(action: {
                    // Navigate to mode selection or settings to upgrade
                }) {
                    Text("Upgrade")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.accentBlue)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(
            (isViewerMode ? designSystem.colors.accentBlue : designSystem.colors.accentGreen)
                .opacity(0.1)
        )
        .cornerRadius(designSystem.cornerRadius.md)
    }

    // MARK: - Import Handler

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Import logic here - integrate with existing CSVImportManager
            print("Importing from: \(url)")
        case .failure(let error):
            print("Import error: \(error)")
        }
    }
}

// MARK: - Action Card Component

struct ActionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let isEnabled: Bool
    var buttonStyle: ActionCardButtonStyle = .primary
    let action: () -> Void

    @EnvironmentObject var designSystem: DesignSystem

    enum ActionCardButtonStyle {
        case primary, secondary
    }

    var body: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(isEnabled ? designSystem.colors.primaryBlack : designSystem.colors.textDisabled)

            // Title
            Text(title)
                .font(designSystem.typography.title)
                .foregroundColor(designSystem.colors.textPrimary)

            // Description
            Text(description)
                .font(designSystem.typography.callout)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)

            // Button
            Button(action: action) {
                Text(buttonText)
                    .font(designSystem.typography.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(
                        buttonStyle == .primary ?
                            (isEnabled ? designSystem.colors.primaryBlack : designSystem.colors.borderMedium) :
                            Color.clear
                    )
                    .foregroundColor(
                        buttonStyle == .primary ?
                            designSystem.colors.primaryWhite :
                            (isEnabled ? designSystem.colors.primaryBlack : designSystem.colors.textDisabled)
                    )
                    .cornerRadius(designSystem.cornerRadius.md)
                    .overlay(
                        buttonStyle == .secondary ?
                            RoundedRectangle(cornerRadius: designSystem.cornerRadius.md)
                                .stroke(isEnabled ? designSystem.colors.primaryBlack : designSystem.colors.borderMedium, lineWidth: 1) :
                            nil
                    )
            }
            .disabled(!isEnabled)
        }
        .padding(designSystem.spacing.lg)
        .frame(maxWidth: .infinity)
        .background(designSystem.colors.backgroundPrimary)
        .cornerRadius(designSystem.cornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: designSystem.cornerRadius.lg)
                .stroke(designSystem.colors.borderLight, lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Export Data Sheet

struct ExportDataSheet: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: designSystem.spacing.lg) {
                Text("Export functionality coming soon")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)

                Button("Close") {
                    dismiss()
                }
                .primaryButtonStyle()
            }
            .padding(designSystem.spacing.lg)
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - HealthKit Connection Sheet

struct HealthKitConnectionSheet: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: designSystem.spacing.lg) {
                Text("HealthKit integration coming soon")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)

                Button("Close") {
                    dismiss()
                }
                .primaryButtonStyle()
            }
            .padding(designSystem.spacing.lg)
            .navigationTitle("Connect HealthKit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

struct SharingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Viewer Mode Preview
            SharingView()
                .environmentObject({
                    let manager = AppStateManager.shared
                    manager.setMode(.viewer)
                    return manager
                }())
                .environmentObject(DesignSystem.shared)
                .previewDisplayName("Viewer Mode")

            // Subscription Mode Preview
            SharingView()
                .environmentObject({
                    let manager = AppStateManager.shared
                    manager.setMode(.subscription)
                    return manager
                }())
                .environmentObject(DesignSystem.shared)
                .previewDisplayName("Subscription Mode")
        }
    }
}
