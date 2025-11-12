//
//  OnboardingView.swift
//  OralableApp
//
//  Created: November 12, 2025
//  First-launch onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.path.ecg",
            iconColor: .blue,
            title: "Real-Time Health Monitoring",
            description: "Connect to your Oralable device and view live PPG, heart rate, SpO2, and temperature data in real-time",
            features: [
                "Live sensor data streaming",
                "PPG waveform visualization",
                "Accurate vital signs"
            ]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: "Historical Tracking",
            description: "Track your health metrics over time with beautiful charts and detailed analytics",
            features: [
                "Daily, weekly, monthly views",
                "Trend analysis",
                "Data insights"
            ]
        ),
        OnboardingPage(
            icon: "square.and.arrow.up",
            iconColor: .orange,
            title: "Export & Share",
            description: "Export your data in CSV format and share with healthcare professionals or for personal analysis",
            features: [
                "CSV export",
                "Data import for review",
                "Secure data management"
            ]
        ),
        OnboardingPage(
            icon: "star.circle.fill",
            iconColor: .purple,
            title: "Choose Your Mode",
            description: "Select how you'd like to use Oralable based on your needs",
            features: [
                "Viewer: Real-time monitoring",
                "Full Access: Complete features",
                "Demo: Try before connecting"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Text("Skip")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                .padding()
            }

            // Content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Bottom button
            VStack(spacing: designSystem.spacing.md) {
                if currentPage == pages.count - 1 {
                    // Last page - Get Started
                    Button {
                        onComplete()
                    } label: {
                        Text("Get Started")
                            .font(designSystem.typography.buttonLarge)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(designSystem.spacing.md)
                            .background(designSystem.colors.primaryBlack)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }
                } else {
                    // Other pages - Next
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(designSystem.typography.buttonLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(designSystem.spacing.md)
                        .background(designSystem.colors.primaryBlack)
                        .cornerRadius(designSystem.cornerRadius.md)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    @EnvironmentObject var designSystem: DesignSystem
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.iconColor)
                .padding(.bottom, designSystem.spacing.lg)

            // Title
            Text(page.title)
                .font(designSystem.typography.h1)
                .foregroundColor(designSystem.colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Description
            Text(page.description)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.bottom, designSystem.spacing.lg)

            // Features
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                ForEach(page.features, id: \.self) { feature in
                    HStack(spacing: designSystem.spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)

                        Text(feature)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
            .padding(.horizontal, designSystem.spacing.xl)

            Spacer()
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let features: [String]
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
            .environmentObject(DesignSystem.shared)
    }
}
