import SwiftUI

struct ViewerModeView: View {
    @Binding var selectedMode: AppMode?
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ViewerDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(0)
            
            ViewerDataView()
                .tabItem {
                    Label("Data", systemImage: "waveform.path.ecg")
                }
                .tag(1)
            
            ViewerFilesView()
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
                .tag(2)
            
            ViewerSettingsView(selectedMode: $selectedMode)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

// MARK: - Dashboard Tab
struct ViewerDashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Device Not Connected")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Viewer Mode does not support device connectivity. Import previously exported files to view your data.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding()
                    
                    // Info Cards
                    VStack(spacing: 16) {
                        InfoCard(
                            icon: "doc.text.viewfinder",
                            title: "Import Files",
                            description: "Go to the Files tab to import CSV or log files",
                            color: .blue
                        )
                        
                        InfoCard(
                            icon: "chart.xyaxis.line",
                            title: "View Data",
                            description: "Analyze imported data in the Data tab",
                            color: .green
                        )
                        
                        InfoCard(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Need Live Monitoring?",
                            description: "Switch to Subscription Mode to connect your device",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Data Tab
struct ViewerDataView: View {
    @State private var importedFiles: [ImportedDataFile] = []
    @State private var selectedFile: ImportedDataFile?
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationView {
            Group {
                if importedFiles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 70))
                            .foregroundColor(.secondary)
                        
                        Text("No Data to Display")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Import a file from the Files tab to view sensor data visualization")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
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
                    }
                } else {
                    List {
                        Section("Imported Files") {
                            ForEach(importedFiles) { file in
                                Button(action: {
                                    selectedFile = file
                                }) {
                                    HStack {
                                        Image(systemName: "waveform.path.ecg")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(file.name)
                                                .font(.headline)
                                            Text(file.formattedDate)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedFile?.id == file.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteFiles)
                        }
                        
                        if selectedFile != nil {
                            Section("Data Visualization") {
                                Text("Data visualization coming soon")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Data")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(importedFiles: $importedFiles, refreshID: .constant(UUID()))
            }
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        importedFiles.remove(atOffsets: offsets)
        if let selectedIndex = offsets.first, selectedFile?.id == importedFiles[selectedIndex].id {
            selectedFile = nil
        }
    }
}

// MARK: - Files Tab
struct ViewerFilesView: View {
    @State private var importedFiles: [ImportedDataFile] = []
    @State private var refreshID = UUID()
    @State private var activeSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case filePicker
        case fileViewer(ImportedDataFile)
        case shareSheet(URL)
        
        var id: String {
            switch self {
            case .filePicker: return "picker"
            case .fileViewer(let file): return "viewer_\(file.id)"
            case .shareSheet(let url): return "share_\(url.absoluteString)"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if importedFiles.isEmpty {
                    EmptyFileStateView(onImport: {
                        activeSheet = .filePicker
                    })
                } else {
                    List {
                        ForEach(importedFiles) { file in
                            Button(action: {
                                print("🔍 Tapped on file: \(file.name)")
                                activeSheet = .fileViewer(file)
                            }) {
                                FileRow(file: file, onShare: {
                                    print("📤 Share button tapped")
                                    activeSheet = .shareSheet(file.url)
                                })
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteFiles)
                    }
                    .id(refreshID)
                }
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        activeSheet = .filePicker
                        print("➕ Opening file picker")
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                Group {
                    switch sheet {
                    case .filePicker:
                        DocumentPicker(importedFiles: $importedFiles, refreshID: $refreshID)
                    case .fileViewer(let file):
                        FileContentView(file: file)
                    case .shareSheet(let url):
                        ShareSheet(items: [url])
                    }
                }
            }
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        importedFiles.remove(atOffsets: offsets)
        refreshID = UUID()
    }
}

// MARK: - Settings Tab
struct ViewerSettingsView: View {
    @Binding var selectedMode: AppMode?
    @State private var showModeChangeAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Mode Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Viewer Mode")
                                .font(.headline)
                        }
                        Spacer()
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                }
                
                // Device Connection (Disabled)
                Section("Device Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                            Text("Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            Text("Connect Device")
                            Spacer()
                        }
                    }
                    .disabled(true)
                    .foregroundColor(.secondary)
                }
                
                // Features
                Section("Features") {
                    FeatureRow(icon: "folder", text: "Import Files", isEnabled: true)
                    FeatureRow(icon: "eye", text: "View Data", isEnabled: true)
                    FeatureRow(icon: "square.and.arrow.up", text: "Share Files", isEnabled: true)
                    FeatureRow(icon: "antenna.radiowaves.left.and.right", text: "Device Connection", isEnabled: false)
                    FeatureRow(icon: "waveform.path.ecg", text: "Real-time Monitoring", isEnabled: false)
                }
                
                // Switch Mode
                Section {
                    Button(action: {
                        showModeChangeAlert = true
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
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Mode")
                        Spacer()
                        Text("Viewer")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Switch Mode", isPresented: $showModeChangeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Switch") {
                    selectedMode = nil
                }
            } message: {
                Text("Switch to Subscription Mode for device connectivity and real-time monitoring. You'll need to sign in with your Apple ID.")
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 30)
            Text(text)
                .foregroundColor(isEnabled ? .primary : .secondary)
        }
    }
}

// MARK: - Supporting Views
struct EmptyFileStateView: View {
    let onImport: () -> Void
    
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
            
            Button(action: onImport) {
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
                    .padding(8)
            }
            .buttonStyle(BorderlessButtonStyle())
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

// File Content Viewer - Optimized for large files
struct FileContentView: View {
    let file: ImportedDataFile
    @Environment(\.dismiss) var dismiss
    @State private var fileLines: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fileInfo: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    VStack {
                        ProgressView("Loading file...")
                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Error Loading File")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fileInfo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        
                        List {
                            ForEach(Array(fileLines.enumerated()), id: \.offset) { index, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                    
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareFile) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(fileLines.isEmpty)
                }
            }
        }
        .onAppear(perform: loadFileContent)
    }
    
    private func loadFileContent() {
        print("📖 Starting to load file: \(file.name)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: file.url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                
                print("📖 File loaded: \(lines.count) lines")
                
                DispatchQueue.main.async {
                    self.fileLines = lines
                    self.fileInfo = "\(lines.count) lines • \(ByteCountFormatter.string(fromByteCount: Int64(content.count), countStyle: .file))"
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading file: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func shareFile() {
        let activityVC = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// Document Picker for importing files
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var importedFiles: [ImportedDataFile]
    @Binding var refreshID: UUID
    
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
        
        private func copyFileToDocuments(_ sourceURL: URL) -> URL? {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            
            let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
            try? fileManager.removeItem(at: destinationURL)
            
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("✅ Copied file to: \(destinationURL.path)")
                return destinationURL
            } catch {
                print("❌ Failed to copy file: \(error.localizedDescription)")
                return nil
            }
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var filesToAdd: [ImportedDataFile] = []
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                guard let persistentURL = copyFileToDocuments(url) else { continue }
                
                let fileSize = try? FileManager.default.attributesOfItem(atPath: persistentURL.path)[.size] as? Int64
                
                let file = ImportedDataFile(
                    name: persistentURL.lastPathComponent,
                    url: persistentURL,
                    dateImported: Date(),
                    fileSize: fileSize
                )
                
                filesToAdd.append(file)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.parent.importedFiles.append(contentsOf: filesToAdd)
                self.parent.refreshID = UUID()
                print("📊 Total files: \(self.parent.importedFiles.count)")
            }
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ViewerModeView(selectedMode: .constant(.viewer))
}
