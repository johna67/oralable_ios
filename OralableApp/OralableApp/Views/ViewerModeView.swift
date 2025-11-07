import SwiftUI

struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @StateObject private var ble = OralableBLE()
    @State private var selectedTab = 0
    @State private var showDevices = false
    
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        Group {
            if DesignSystem.Layout.isIPad && sizeClass == .regular {
                // iPad with regular width - use split view
                iPadSplitView
            } else {
                // iPhone or iPad in compact mode - use tab view
                iPhoneTabView
            }
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(ble: ble)
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
                        Label("Dashboard", systemImage: "gauge")
                    }
                    .listRowBackground(selectedTab == 0 ? Color.accentColor.opacity(0.15) : Color.clear)
                    
                    Button {
                        selectedTab = 1
                    } label: {
                        Label("Import/Export", systemImage: "square.and.arrow.up")
                    }
                    .listRowBackground(selectedTab == 1 ? Color.accentColor.opacity(0.15) : Color.clear)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showDevices = true }) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(ble.isConnected ? .green : .gray)
                    }
                }
            }
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
                DashboardView(ble: ble, isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                        
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showDevices = true }) {
                                Image(systemName: "wave.3.right.circle.fill")
                                    .foregroundColor(ble.isConnected ? .green : .gray)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }
            .tag(0)

            NavigationStack {
                ShareView(ble: ble, isViewerMode: true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { selectedMode = nil }) {
                                Label("Modes", systemImage: "chevron.left")
                            }
                        }
                        
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showDevices = true }) {
                                Image(systemName: "wave.3.right.circle.fill")
                                    .foregroundColor(ble.isConnected ? .green : .gray)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Import/Export", systemImage: "square.and.arrow.up")
            }
            .tag(1)
        }
    }
    
    // MARK: - Detail View Helper
    
    @ViewBuilder
    private func detailView(for tab: Int) -> some View {
        switch tab {
        case 0:
            DashboardView(ble: ble, isViewerMode: true)
        case 1:
            ShareView(ble: ble, isViewerMode: true)
        default:
            DashboardView(ble: ble, isViewerMode: true)
        }
    }
}

#Preview {
    ViewerModeView(selectedMode: .constant(.viewer))
}
