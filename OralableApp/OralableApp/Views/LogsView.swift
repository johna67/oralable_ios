import SwiftUI

struct LogsView: View {
    let logs: [String]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredLogs: [String] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredLogs.reversed(), id: \.self) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log)
                            .font(.caption)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    .padding(.vertical, 2)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Logs")
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
}

#Preview {
    LogsView(logs: [
        "[12:34:56.789] 🔍 Started scanning for Oralable devices...",
        "[12:34:57.123] 📱 Discovered Oralable device: Oralable-001",
        "[12:34:58.456] ✅ Connected to: Oralable-001"
    ])
}