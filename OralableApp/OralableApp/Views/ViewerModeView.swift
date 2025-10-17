import SwiftUI

struct ViewerModeView: View {
    @State private var selectedTab = 0
    @State private var showModeSwitch = false
    @Binding var selectedMode: AppMode?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FileViewerTab()
                .tabItem {
                    Label("Files", systemImage: "doc.text")
                }
                .tag(0)
            
            ViewerInfoTab(selectedMode: $selectedMode)
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
                .tag(1)
        }
    }
}

struct FileViewerTab: View {
    @State private var importedFiles: [ImportedDataFile] = []
    @State private var showFilePicker = false
    @State private var showShareSheet = false
    @State private var fileToShare: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                if importedFiles.isEmpty {
                    EmptyFileState(showFilePicker: $showFilePicker)
                } else {
                    List {
                        ForEach(importedFiles) { file in
                            FileRow(file: file, onShare: {
                                fileToShare = file.url
                                showShareSheet = true
                            })
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("Viewer Mode")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(importedFiles: $importedFiles)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = fileToShare {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        importedFiles.remove(atOffsets: offsets)
    }
}

struct EmptyFileState: View {
    @Binding var showFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Files Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import CSV or log files to view and analyze your bruxism data")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: { showFilePicker = true }) {
                Label("Import File", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported formats:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    FormatBadge(text: "CSV")
                    FormatBadge(text: "LOG")
                    FormatBadge(text: "TXT")
                }
            }
            .padding(.top, 30)
        }
        .padding()
    }
}

struct FormatBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
    }
}

struct FileRow: View {
    let file: ImportedDataFile
    let onShare: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                
                HStack {
                    Text(file.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let size = file.formattedSize {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
    
    private var fileIcon: String {
        switch file.fileExtension.lowercased() {
        case "csv":
            return "tablecells"
        case "log", "txt":
            return "doc.text"
        default:
            return "doc"
        }
    }
}

struct ImportedDataFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let dateImported: Date
    let fileSize: Int64?
    
    var fileExtension: String {
        url.pathExtension
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: dateImported)
    }
    
    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct ViewerInfoTab: View {
    @Binding var selectedMode: AppMode?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Viewer Mode")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("You're currently in Viewer Mode. This mode allows you to view and export data files without connecting to a device.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Capabilities") {
                    CapabilityRow(icon: "checkmark.circle.fill", text: "View imported data files", isEnabled: true)
                    CapabilityRow(icon: "checkmark.circle.fill", text: "Export and share files", isEnabled: true)
                    CapabilityRow(icon: "checkmark.circle.fill", text: "No sign-in required", isEnabled: true)
                    CapabilityRow(icon: "xmark.circle.fill", text: "Device connectivity", isEnabled: false)
                    CapabilityRow(icon: "xmark.circle.fill", text: "Real-time monitoring", isEnabled: false)
                }
                
                Section {
                    Button(action: {
                        selectedMode = nil
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Switch to Subscription Mode")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                        HStack {
                            Text("Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Info")
        }
    }
}

struct CapabilityRow: View {
    let icon: String
    let text: String
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .red)
            Text(text)
                .foregroundColor(isEnabled ? .primary : .secondary)
        }
    }
}

// Document Picker for importing files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var importedFiles: [ImportedDataFile]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .text, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
                
                let file = ImportedDataFile(
                    name: url.lastPathComponent,
                    url: url,
                    dateImported: Date(),
                    fileSize: fileSize
                )
                
                parent.importedFiles.append(file)
            }
            parent.dismiss()
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ViewerModeView(selectedMode: .constant(.viewer))
}
