//
//  OralableApp.swift
//  OralableApp
//
//  Fixed version with proper initialization
//

import SwiftUI

@main
struct OralableApp: App {
    // Initialize design system
    @StateObject private var designSystem = DesignSystem.shared
    
    // Initialize managers
    @StateObject private var bleManager = OralableBLE.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @StateObject private var historicalDataManager = HistoricalDataManager.shared
    @StateObject private var authenticationManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(designSystem)
                .environmentObject(bleManager)
                .environmentObject(deviceManager)
                .environmentObject(historicalDataManager)
                .environmentObject(authenticationManager)
        }
    }
}

// MARK: - App Mode (if needed)

enum AppMode {
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
