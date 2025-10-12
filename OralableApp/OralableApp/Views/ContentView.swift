import SwiftUI

struct ContentView: View {
    @StateObject private var ble = OralableBLE()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(ble: ble)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            DataView(ble: ble)
                .tabItem {
                    Label("Data", systemImage: "waveform.path.ecg")
                }
                .tag(1)
            
            LogExportView(ble: ble)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)
            
            SettingsView(ble: ble)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}
