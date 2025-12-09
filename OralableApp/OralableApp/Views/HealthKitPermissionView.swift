//
//  HealthKitPermissionView.swift
//  OralableApp
//
//  Created: HealthKit Integration - Step 3
//  Purpose: Request HealthKit permissions after authentication
//

import SwiftUI
import HealthKit

struct HealthKitPermissionView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.xl) {
                    // Header
                    headerSection

                    // Permissions List
                    permissionsSection

                    // Why We Need This
                    whyWeNeedSection

                    Spacer()

                    // Action Buttons
                    actionButtonsSection
                }
                .padding(designSystem.spacing.lg)
            }
            .navigationTitle("Health Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(designSystem.colors.textSecondary)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Connect to Apple Health")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            Text("Integrate your bruxism data with comprehensive health insights from Apple Health")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, designSystem.spacing.xl)
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("We'll request access to:")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
                .padding(.horizontal, designSystem.spacing.sm)

            VStack(spacing: designSystem.spacing.sm) {
                PermissionRow(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    description: "View and write heart rate data for correlation analysis",
                    iconColor: .red,
                    accessType: "Read & Write"
                )

                PermissionRow(
                    icon: "lungs.fill",
                    title: "Blood Oxygen (SpO2)",
                    description: "Track oxygen saturation during sleep",
                    iconColor: .blue,
                    accessType: "Read & Write"
                )

                PermissionRow(
                    icon: "bed.double.fill",
                    title: "Sleep Analysis",
                    description: "Correlate bruxism with sleep patterns",
                    iconColor: .purple,
                    accessType: "Read Only"
                )
            }
        }
    }

    // MARK: - Why We Need Section

    private var whyWeNeedSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Why we need this:")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                BenefitRow(
                    icon: "chart.xyaxis.line",
                    text: "Correlate bruxism episodes with heart rate variability"
                )

                BenefitRow(
                    icon: "brain.head.profile",
                    text: "Understand sleep quality impact on teeth grinding"
                )

                BenefitRow(
                    icon: "person.fill.checkmark",
                    text: "Provide comprehensive reports to your provider"
                )

                BenefitRow(
                    icon: "lock.shield",
                    text: "All data stays private and encrypted on your device"
                )
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Allow Button
            Button(action: requestHealthKitPermission) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Allow Access")
                    }
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, designSystem.spacing.md)
                .background(designSystem.colors.primaryBlack)
                .cornerRadius(designSystem.cornerRadius.md)
            }
            .disabled(isRequesting)

            // Skip Button
            Button(action: { dismiss() }) {
                Text("Skip for Now")
                    .font(designSystem.typography.buttonMedium)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, designSystem.spacing.sm)
            }
            .disabled(isRequesting)

            // Privacy Note
            Text("You can change these permissions anytime in Settings")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func requestHealthKitPermission() {
        isRequesting = true

        Task {
            do {
                try await healthKitManager.requestAuthorization()

                // Wait a moment for the system permission sheet to complete
                try await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    isRequesting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Permission Row Component

struct PermissionRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let accessType: String

    var body: some View {
        HStack(alignment: .top, spacing: designSystem.spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textPrimary)

                    Spacer()

                    Text(accessType)
                        .font(designSystem.typography.caption2)
                        .foregroundColor(designSystem.colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
}

// MARK: - Benefit Row Component

struct BenefitRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: designSystem.spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 16))
                .frame(width: 20)

            Text(text)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

struct HealthKitPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitPermissionView()
            .environmentObject(DesignSystem())
            .environmentObject(HealthKitManager())
    }
}
