//
//  OralableApp.swift
//  OralableApp
//
//  Updated with mode selection and complete flow
//

import SwiftUI

@main
struct OralableApp: App {
    // Initialize the dependency injection container
    @StateObject private var dependencies: AppDependencies

    init() {
        // Determine app mode - use saved mode or default to subscription
        let savedMode = UserDefaults.standard.string(forKey: "com.oralable.selectedMode")
            .flatMap { AppMode(rawValue: $0) } ?? .subscription

        let deps = AppDependencies(appMode: savedMode)
        _dependencies = StateObject(wrappedValue: deps)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies(dependencies)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        Group {
            if appStateManager.needsModeSelection {
                // Show mode selection if no mode is selected
                ModeSelectionView()
            } else if let mode = appStateManager.selectedMode {
                // Show appropriate view based on selected mode
                contentView(for: mode)
            } else {
                // Fallback (shouldn't happen)
                ModeSelectionView()
            }
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
}

// MARK: - App Configuration

struct AppConfiguration {
    static let appVersion = "1.0.0"
    static let buildNumber = "2025.11.07"
    static let minimumOSVersion = "15.0"
}

