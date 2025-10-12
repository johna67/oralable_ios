import SwiftUI

struct SettingsView: View {
    @ObservedObject var ble: OralableBLE
    @State private var selectedSite = MeasurementSite.masseter
    @State private var autoReconnect = true
    @State private var showDebugLogs = false
    
    var body: some View {
        NavigationView {
            Form {
                // Measurement Site
                Section(header: Text("Measurement Site")) {
                    ForEach(MeasurementSite.allCases, id: \.self) { site in
                        HStack {
                            Text(site.name)
                            Spacer()
                            if selectedSite == site {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSite = site
                            ble.setMeasurementSite(site.rawValue)
                        }
                    }
                }
                
                // Connection Settings
                Section(header: Text("Connection")) {
                    Toggle("Auto-Reconnect", isOn: $autoReconnect)
                    
                    if ble.isConnected {
                        Button("Disconnect") {
                            ble.disconnect()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Debug
                Section(header: Text("Debug")) {
                    Toggle("Show Debug Logs", isOn: $showDebugLogs)
                    
                    NavigationLink(destination: LogsView(logs: ble.logMessages)) {
                        HStack {
                            Text("View Logs")
                            Spacer()
                            Text("\(ble.logMessages.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    if ble.isConnected {
                        HStack {
                            Text("Firmware Version")
                            Spacer()
                            Text(ble.sensorData.firmwareVersion)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Device UUID")
                            Spacer()
                            Text(String(format: "%016llX", ble.sensorData.deviceUUID))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct LogsView: View {
    let logs: [String]
    @State private var searchText = ""
    
    var filteredLogs: [String] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredLogs.reversed(), id: \.self) { log in
                Text(log)
                    .font(.caption)
                    .lineLimit(nil)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
    }
}
