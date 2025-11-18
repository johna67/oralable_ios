//
//  MainTabView.swift
//  OralableApp
//
//  Fixed version - no duplicate views, correct parameters
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        TabView {
            DashboardView(viewModel: dependencies.makeDashboardViewModel())
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            DevicesView(viewModel: dependencies.makeDevicesViewModel())
                .tabItem {
                    Label("Devices", systemImage: "sensor.fill")
                }
                .tag(1)

            // Use the real HistoricalView from your Views folder
            HistoricalView(viewModel: dependencies.makeHistoricalViewModel())
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            // Use SettingsView, not ShareView
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(designSystem.colors.primaryBlack)
    }
}


// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(DesignSystem.shared)
    }
}
