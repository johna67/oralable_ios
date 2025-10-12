import SwiftUI

struct DebugLogView: View {
    @ObservedObject var ble: OralableBLE
    @State private var autoScroll = true
    
    var body: some View {
        NavigationView {
            VStack {
                // Log viewer
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(ble.logMessages.enumerated()), id: \.offset) { index, message in
                                Text(message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(logColor(for: message))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .id(index)
                            }
                        }
                    }
                    .background(Color.black.opacity(0.9))
                    .onChange(of: ble.logMessages.count) { _ in
                        if autoScroll {
                            withAnimation {
                                proxy.scrollTo(ble.logMessages.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Controls
                HStack {
                    Toggle("Auto-scroll", isOn: $autoScroll)
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("Clear") {
                        ble.logMessages.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Export") {
                        exportLogs()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func logColor(for message: String) -> Color {
        if message.contains("✅") || message.contains("Connected") { return .green }
        if message.contains("❌") || message.contains("error") { return .red }
        if message.contains("⚠️") || message.contains("warning") { return .orange }
        if message.contains("PPG") || message.contains("IR=") { return .cyan }
        if message.contains("Temperature") { return .yellow }
        if message.contains("Battery") { return .mint }
        if message.contains("Accel") { return .blue }
        return .white
    }
    
    private func exportLogs() {
        let logText = ble.logMessages.joined(separator: "\n")
        UIPasteboard.general.string = logText
    }
}
