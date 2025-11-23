import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        TabView {
            // Existing tabs
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            // History tab
            NavigationStack {
                List {
                    NavigationLink("Movement History") {
                        HistoricalView(metricType: "Movement",
                                       historicalDataManager: historicalDataManager)
                    }
                    NavigationLink("Heart Rate History") {
                        HistoricalView(metricType: "Heart Rate",
                                       historicalDataManager: historicalDataManager)
                    }
                    NavigationLink("SpO2 History") {
                        HistoricalView(metricType: "SpO2",
                                       historicalDataManager: historicalDataManager)
                    }
                }
                .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "chart.line.uptrend.xyaxis")
            }

            // Other tabs (e.g. Settings, Profile)
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
