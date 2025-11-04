import SwiftUI

struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @StateObject private var ble = OralableBLE()
    @State private var selectedTab = 0
    @State private var showDevices = false

    var body: some View {
        ZStack {
            // Main Tab View for Viewer Mode
            TabView(selection: $selectedTab) {
                DashboardView(ble: ble, isViewerMode: true)
                    .tabItem {
                        Label("Dashboard", systemImage: "gauge")
                    }
                    .tag(0)

                ShareView(ble: ble, isViewerMode: true)
                    .tabItem {
                        Label("Import/Export", systemImage: "square.and.arrow.up")
                    }
                    .tag(1)
            }

            // Simple top overlay bar with a "Mode" button and optional devices shortcut
            VStack {
                HStack {
                    Button {
                        selectedMode = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Modes")
                        }
                    }

                    Spacer()

                    // Devices button (optional, for quick access if you later want to scan/connect in viewer mode)
                    Button {
                        showDevices = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(ble.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)

                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.title3)
                                .foregroundColor(ble.isConnected ? .green : .gray)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()
            }
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(ble: ble)
        }
    }
}

#Preview {
    ViewerModeView(selectedMode: .constant(.viewer))
}
