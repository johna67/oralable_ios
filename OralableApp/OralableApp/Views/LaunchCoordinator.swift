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
    @EnvironmentObject var bleManager: OralableBLE

    var body: some View {
        Group {
            if authenticationManager.isFirstLaunch {
                OnboardingView()
            } else if authenticationManager.isAuthenticated {
                MainDashboardView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            bleManager.startScanning()
        }
    }
}