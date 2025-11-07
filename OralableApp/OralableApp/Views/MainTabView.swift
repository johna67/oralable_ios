//
//  MainTabView_Fixed.swift
//  OralableApp
//
//  Main tab coordinator with all fixes applied
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
            
            HistoricalView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
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

// MARK: - Temporary View Placeholders (Replace with actual implementations)

struct HistoricalView: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: designSystem.spacing.lg) {
                    Text("Historical data and charts will appear here")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .padding()
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        NavigationView {
            List {
                Section("Device Settings") {
                    HStack {
                        Text("Auto-connect")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("Connection Timeout")
                        Spacer()
                        Text("30s")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                
                Section("Data Management") {
                    HStack {
                        Text("Data Retention")
                        Spacer()
                        Text("30 days")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    
                    Button(action: {}) {
                        Text("Clear Historical Data")
                            .foregroundColor(.red)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2025.11.07")
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(DesignSystem.shared)
    }
}
