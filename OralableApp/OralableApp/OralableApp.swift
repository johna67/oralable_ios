//
//  OralableApp.swift
//  OralableApp
//
//  Updated with mode selection and complete flow
//

import SwiftUI

@main
struct OralableApp: App {
    init() {
        print("🚀 [APP] OralableApp init started")
    }

    // Initialize design system
    @StateObject private var designSystem = DesignSystem.shared

    // Initialize managers
    @StateObject private var bleManager = OralableBLE.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @StateObject private var historicalDataManager = HistoricalDataManager.shared
    @StateObject private var authenticationManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var appStateManager = AppStateManager.shared

    var body: some Scene {
        print("🚀 [APP] body being evaluated")
        return WindowGroup {
            RootView()
                .environmentObject(designSystem)
                .environmentObject(bleManager)
                .environmentObject(deviceManager)
                .environmentObject(historicalDataManager)
                .environmentObject(authenticationManager)
                .environmentObject(subscriptionManager)
                .environmentObject(appStateManager)
                .onAppear {
                    print("✅ [APP] RootView appeared - app launched successfully!")
                }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showOnboarding = false

    var body: some View {
        let _ = print("🔵 [RootView] body being evaluated")
        let _ = print("🔵 [RootView] needsModeSelection: \(appStateManager.needsModeSelection)")
        let _ = print("🔵 [RootView] selectedMode: \(String(describing: appStateManager.selectedMode))")

        Group {
            if appStateManager.needsModeSelection {
                // Show mode selection if no mode is selected
                let _ = print("🔵 [RootView] Showing ModeSelectionView")
                ModeSelectionView()
            } else if let mode = appStateManager.selectedMode {
                // Show appropriate view based on selected mode
                let _ = print("🔵 [RootView] Showing contentView for mode: \(mode)")
                contentView(for: mode)
            } else {
                // Fallback (shouldn't happen)
                let _ = print("⚠️ [RootView] Fallback to ModeSelectionView")
                ModeSelectionView()
            }
        }
        .onAppear {
            print("✅ [RootView] onAppear called")
            // Show onboarding on first launch
            if appStateManager.isFirstLaunch && !appStateManager.hasCompletedOnboarding {
                print("🔵 [RootView] Showing onboarding")
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                appStateManager.completeOnboarding()
                showOnboarding = false
            })
        }
    }

    @ViewBuilder
    private func contentView(for mode: AppMode) -> some View {
        switch mode {
        case .viewer:
            ViewerModeView(selectedMode: $appStateManager.selectedMode)
        case .subscription:
            // Check authentication for subscription mode
            if authenticationManager.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationRequiredView()
            }
        case .demo:
            DemoModeView()
        }
    }
}

// MARK: - Authentication Required View

struct AuthenticationRequiredView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var showAuthenticationView = false

    var body: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(designSystem.colors.primaryBlack)

            VStack(spacing: designSystem.spacing.md) {
                Text("Authentication Required")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text("Please sign in with your Apple ID to access Full Access mode")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, designSystem.spacing.xl)
            }

            VStack(spacing: designSystem.spacing.md) {
                Button {
                    showAuthenticationView = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Sign In with Apple")
                    }
                    .font(designSystem.typography.buttonLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.primaryBlack)
                    .cornerRadius(designSystem.cornerRadius.md)
                }
                .padding(.horizontal, designSystem.spacing.xl)

                Button {
                    appStateManager.clearMode()
                } label: {
                    Text("Choose Different Mode")
                        .font(designSystem.typography.buttonMedium)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showAuthenticationView) {
            NavigationView {
                AuthenticationView()
            }
        }
    }
}

// MARK: - Demo Mode View

struct DemoModeView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var appStateManager: AppStateManager

    var body: some View {
        MainTabView()
            .overlay(alignment: .top) {
                // Demo mode banner
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                    Text("Demo Mode - Sample Data")
                        .font(designSystem.typography.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        appStateManager.clearMode()
                    } label: {
                        Text("Exit")
                            .font(designSystem.typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(designSystem.cornerRadius.sm)
                    }
                }
                .padding(.horizontal, designSystem.spacing.md)
                .padding(.vertical, designSystem.spacing.sm)
                .background(Color.green)
            }
    }
}

// MARK: - App Mode

enum AppMode: String, Codable {
    case viewer
    case subscription
    case demo
}

// MARK: - App Configuration

struct AppConfiguration {
    static let appVersion = "1.0.0"
    static let buildNumber = "2025.11.07"
    static let minimumOSVersion = "15.0"
}

