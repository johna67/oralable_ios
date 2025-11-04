import SwiftUI

struct LogsView: View {
    let logs: [LogMessage]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredLogs: [LogMessage] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            // ✅ FIXED: Use LogMessage.id instead of String
            ForEach(filteredLogs.reversed()) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.message)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
                .padding(.vertical, 2)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Logs (\(logs.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LogsView(logs: [
            LogMessage(message: "[12:34:56] 🔍 Started scanning for Oralable devices..."),
            LogMessage(message: "[12:34:57] 📱 Discovered Oralable device: Oralable-001"),
            LogMessage(message: "[12:34:58] ✅ Connected to: Oralable-001")
        ])
    }
}
