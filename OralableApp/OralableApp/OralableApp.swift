import SwiftUI

@main
struct OralableApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedMode: AppMode?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let mode = selectedMode {
                    switch mode {
                    case .viewer:
                        ViewerModeView(selectedMode: $selectedMode)
                    case .subscription:
                        if authManager.isAuthenticated {
                            SubscriptionContentView(selectedMode: $selectedMode)
                        } else {
                            AuthenticationView(selectedMode: $selectedMode)
                        }
                    }
                } else {
                    ModeSelectionView(selectedMode: $selectedMode)
                }
            }
            .onAppear {
                // Check if user was previously authenticated and in subscription mode
                if authManager.isAuthenticated && UserDefaults.standard.string(forKey: "lastMode") == "subscription" {
                    selectedMode = .subscription
                }
            }
            .onChange(of: selectedMode) { _, newMode in
                // Save last selected mode
                if let mode = newMode {
                    UserDefaults.standard.set(mode == .subscription ? "subscription" : "viewer", forKey: "lastMode")
                }
            }
        }
    }
}

// Subscription Mode Content View (wraps the original ContentView)
struct SubscriptionContentView: View {
    @StateObject private var ble = OralableBLE()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var selectedMode: AppMode?
    @State private var selectedTab = 0
    @State private var showSubscriptionInfo = false
    
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
            
            // NEW: History Tab
            HistoricalDataView(ble: ble)
                .tabItem {
                    Label("History", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
            
            LogExportView(ble: ble)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(3)
            
            SubscriptionSettingsView(ble: ble, selectedMode: $selectedMode)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .overlay(
            // Subscription tier badge
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSubscriptionInfo = true }) {
                        HStack(spacing: 6) {
                            if subscriptionManager.currentTier == .paid {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                            }
                            Text(subscriptionManager.currentTier == .paid ? "Premium" : "Basic")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(subscriptionManager.currentTier == .paid ? Color.orange : Color.gray)
                        .cornerRadius(12)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        )
        .sheet(isPresented: $showSubscriptionInfo) {
            SubscriptionTierSelectionView()
        }
    }
}
