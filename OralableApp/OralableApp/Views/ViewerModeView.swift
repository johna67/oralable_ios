import SwiftUI

struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @EnvironmentObject var ble: OralableBLE
    @State private var selectedTab = 0

    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular {
                // iPad with regular width - use split view
                iPadSplitView
            } else {
                // iPhone or iPad in compact mode - use tab view
                iPhoneTabView
            }
        }
    }
    
    // MARK: - iPad Split View Layout

    private var iPadSplitView: some View {
        NavigationSplitView {
            List {
                Section("Viewer Mode") {
                    Button {
                        selectedTab = 0
                    } label: {
                        Label("Dashboard", systemImage: "house.fill")
                    }
                    .listRowBackground(selectedTab == 0 ? Color.accentColor.opacity(0.15) : Color.clear)

                    Button {
                        selectedTab = 1
                    } label: {
                        Label("Devices", systemImage: "sensor.fill")
                    }
                    .listRowBackground(selectedTab == 1 ? Color.accentColor.opacity(0.15) : Color.clear)

                    Button {
                        selectedTab = 2
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .listRowBackground(selectedTab == 2 ? Color.accentColor.opacity(0.15) : Color.clear)

                    Button {
                        selectedTab = 3
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .listRowBackground(selectedTab == 3 ? Color.accentColor.opacity(0.15) : Color.clear)
                }

                Section {
                    Button(action: { selectedMode = nil }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Switch Mode")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Oralable Viewer")
        } detail: {
            NavigationStack {
                detailView(for: selectedTab)
            }
        }
    }
    
    // MARK: - iPhone Tab View Layout

    private var iPhoneTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                DevicesView(isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Devices", systemImage: "sensor.fill")
            }
            .tag(1)

            NavigationStack {
                ShareView(ble: ble, isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tag(2)

            NavigationStack {
                SettingsView(isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
    }
    
    // MARK: - Detail View Helper

    @ViewBuilder
    private func detailView(for tab: Int) -> some View {
        switch tab {
        case 0:
            DashboardView(isViewerMode: true)
        case 1:
            DevicesView(isViewerMode: true)
        case 2:
            ShareView(ble: ble, isViewerMode: true)
        case 3:
            SettingsView(isViewerMode: true)
        default:
            DashboardView(isViewerMode: true)
        }
    }
}

#Preview {
    ViewerModeView(selectedMode: .constant(.viewer))
        .environmentObject(OralableBLE.shared)
        .environmentObject(DesignSystem.shared)
}
