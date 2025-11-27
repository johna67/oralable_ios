//
//  LaunchCoordinator.swift
//  OralableApp
//
//  Created by John A Cogan on 23/11/2025.
//


import SwiftUI

struct LaunchCoordinator: View {
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        Group {
            // IMPORTANT: Check authentication BEFORE first launch
            // Once authenticated, always show main tab view regardless of first launch status
            if authenticationManager.isAuthenticated {
                // MainTabView has the bottom tab bar with Dashboard, Devices, Share, Settings
                MainTabView()
                    .onAppear {
                        Logger.shared.info("🟢 LaunchCoordinator: Showing MainTabView (authenticated)")
                    }
            } else if authenticationManager.isFirstLaunch {
                OnboardingView()
                    .onAppear {
                        Logger.shared.info("🟡 LaunchCoordinator: Showing OnboardingView (first launch)")
                    }
            } else {
                LoginView()
                    .onAppear {
                        Logger.shared.info("🔴 LaunchCoordinator: Showing LoginView (not authenticated)")
                    }
            }
        }
        .onAppear {
            Logger.shared.info("🔵 LaunchCoordinator appeared - isAuthenticated: \(authenticationManager.isAuthenticated), isFirstLaunch: \(authenticationManager.isFirstLaunch)")
            // Attempt to auto-reconnect to remembered devices on app launch
            deviceManager.attemptAutoReconnect()
        }
    }
}
