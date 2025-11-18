//
//  Oralable.swift
//  Oralable
//
//  Patient App - Requires Device and Authentication
//

import SwiftUI

@main
struct Oralable: App {
    // Initialize the dependency injection container
    @StateObject private var dependencies: AppDependencies

    init() {
        // Patient app always uses subscription mode (device + authentication)
        let deps = AppDependencies(appMode: .subscription)
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
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        Group {
            if authenticationManager.isAuthenticated {
                // Show main app interface
                MainTabView()
            } else {
                // Show onboarding and authentication
                OnboardingView()
            }
        }
    }
}

// MARK: - App Configuration

struct AppConfiguration {
    static let appName = "Oralable"
    static let appType = "patient"
    static let appVersion = "1.0.0"
    static let buildNumber = "2025.11.18"
    static let minimumOSVersion = "15.0"
    static let bundleIdentifier = "com.jacdental.oralable"
}

// MARK: - App Mode (Keep for dependency compatibility)

enum AppMode: String, Codable {
    case subscription  // Patient app is always subscription mode

    var displayName: String {
        return "Full Access"
    }
}
