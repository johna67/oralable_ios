import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            // Devices Tab
            DevicesView()
                .environmentObject(designSystem)
                .environmentObject(bleManager)
                .environmentObject(dependencies.deviceManager)
                .tabItem {
                    Label("Devices", systemImage: "cpu")
                }

            // Share Tab
            ShareView(ble: bleManager)
                .environmentObject(designSystem)
                .tabItem {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

            // Settings Tab
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
                .environmentObject(dependencies)
                .environmentObject(designSystem)
                .environmentObject(dependencies.authenticationManager)
                .environmentObject(dependencies.subscriptionManager)
                .environmentObject(dependencies.appStateManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
