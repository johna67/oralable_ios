import SwiftUI

// MARK: - THIS FILE IS NOW A STUB
// ViewerModeView functionality is now in OralableApp.swift
// This file just defines LogsView for backward compatibility

// MARK: - Logs View Helper
struct LogsView: View {
    let logs: [String]
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
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
                    Text(log)
                        .font(.caption)
                        .lineLimit(nil)
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
