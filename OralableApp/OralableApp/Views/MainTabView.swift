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
    @EnvironmentObject var bleManager: OralableBLE

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

            ShareView(ble: bleManager)
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tag(2)

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
