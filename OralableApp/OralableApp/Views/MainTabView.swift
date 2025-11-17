//
//  MainTabView.swift
//  OralableApp
//
//  Fixed version - no duplicate views, correct parameters
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
            
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "sensor.fill")
                }
                .tag(1)

            ShareView()
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tag(2)

            SettingsView()
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
