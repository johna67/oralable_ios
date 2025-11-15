//
//  SubscriptionGate.swift
//  OralableApp
//
//  Created: November 12, 2025
//  Reusable subscription gate component for premium features
//

import SwiftUI

/// A view that gates content behind a subscription requirement
struct SubscriptionGate<Content: View>: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showUpgradeSheet = false

    let feature: PremiumFeature
    let content: () -> Content

    var body: some View {
        if subscriptionManager.isPaidSubscriber {
            content()
        } else {
            SubscriptionPromptView(feature: feature, showUpgradeSheet: $showUpgradeSheet)
                .sheet(isPresented: $showUpgradeSheet) {
                    UpgradePromptSheet()
                }
        }
    }
}

/// A prompt view shown when a feature requires a subscription
struct SubscriptionPromptView: View {
    @EnvironmentObject var designSystem: DesignSystem
    let feature: PremiumFeature
    @Binding var showUpgradeSheet: Bool

    var body: some View {
        VStack(spacing: designSystem.spacing.lg) {
            Spacer()

            Image(systemName: feature.icon)
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textSecondary)

            VStack(spacing: designSystem.spacing.sm) {
                Text(feature.title)
                    .font(designSystem.typography.h3)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text(feature.description)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, designSystem.spacing.xl)
            }

            Button {
                showUpgradeSheet = true
            } label: {
                HStack {
                    Image(systemName: "star.circle.fill")
                    Text("Upgrade to Premium")
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(designSystem.cornerRadius.md)
            }
            .padding(.horizontal, designSystem.spacing.xl)

            Spacer()
        }
    }
}

/// Inline subscription badge for feature labels
struct SubscriptionBadge: View {
    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("PREMIUM")
                .font(designSystem.typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [.orange, .pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(designSystem.cornerRadius.sm)
    }
}

/// Small inline upgrade button
struct InlineUpgradeButton: View {
    @EnvironmentObject var designSystem: DesignSystem
    @State private var showUpgradeSheet = false

    var body: some View {
        Button {
            showUpgradeSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "star.circle.fill")
                    .font(.caption)
                Text("Upgrade")
                    .font(designSystem.typography.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(designSystem.cornerRadius.sm)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet()
        }
    }
}

// MARK: - Upgrade Prompt Sheet

struct UpgradePromptSheet: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var appStateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: designSystem.spacing.xl) {
                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.accentOrange)

                VStack(spacing: designSystem.spacing.md) {
                    Text("Upgrade to Subscription Mode")
                        .font(designSystem.typography.largeTitle)
                        .foregroundColor(designSystem.colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Switch to Subscription Mode to unlock Bluetooth connectivity, data export, and HealthKit integration.")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, designSystem.spacing.lg)
                }

                Spacer()

                VStack(spacing: designSystem.spacing.sm) {
                    Button(action: {
                        // Navigate to mode selection in Settings
                        dismiss()
                    }) {
                        Text("Go to Settings")
                            .font(designSystem.typography.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(designSystem.spacing.md)
                            .background(designSystem.colors.primaryBlack)
                            .foregroundColor(designSystem.colors.primaryWhite)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Not Now")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                .padding(.horizontal, designSystem.spacing.lg)
                .padding(.bottom, designSystem.spacing.xl)
            }
            .padding(designSystem.spacing.lg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Premium Features

enum PremiumFeature {
    case unlimitedExport
    case advancedAnalytics
    case cloudSync
    case historicalData
    case customReports

    var icon: String {
        switch self {
        case .unlimitedExport:
            return "square.and.arrow.up.circle.fill"
        case .advancedAnalytics:
            return "chart.line.uptrend.xyaxis.circle.fill"
        case .cloudSync:
            return "icloud.circle.fill"
        case .historicalData:
            return "clock.arrow.circlepath"
        case .customReports:
            return "doc.text.magnifyingglass"
        }
    }

    var title: String {
        switch self {
        case .unlimitedExport:
            return "Unlimited Data Export"
        case .advancedAnalytics:
            return "Advanced Analytics"
        case .cloudSync:
            return "Cloud Sync"
        case .historicalData:
            return "Historical Data Tracking"
        case .customReports:
            return "Custom Reports"
        }
    }

    var description: String {
        switch self {
        case .unlimitedExport:
            return "Export your data without limits. Free users are limited to basic exports."
        case .advancedAnalytics:
            return "Access detailed analytics, trends, and insights about your health data."
        case .cloudSync:
            return "Automatically sync your data across all your devices with secure cloud backup."
        case .historicalData:
            return "Access unlimited historical data and track your progress over time."
        case .customReports:
            return "Generate custom reports and share them with healthcare professionals."
        }
    }
}

// MARK: - Subscription Check Modifiers

extension View {
    /// Check if user has subscription, show upgrade prompt if not
    func requiresSubscription(
        feature: PremiumFeature,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        SubscriptionGate(feature: feature) {
            content()
        }
    }
}

// MARK: - Preview

struct SubscriptionGate_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPromptView(
            feature: .unlimitedExport,
            showUpgradeSheet: .constant(false)
        )
        .environmentObject(DesignSystem.shared)
    }
}
