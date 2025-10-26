import SwiftUI

struct ModeSelectionView: View {
    @Binding var selectedMode: AppMode?
    @State private var showModeInfo = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Oralable")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sleep Bruxism Monitor")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Mode Selection Cards
                VStack(spacing: 20) {
                    // Viewer Mode Card
                    ModeCard(
                        icon: "doc.text.viewfinder",
                        title: "Viewer Mode",
                        subtitle: "View and export data files",
                        description: "No account required",
                        color: .green
                    ) {
                        selectedMode = .viewer
                    }
                    
                    // Subscription Mode Card
                    ModeCard(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Subscription Mode",
                        subtitle: "Full device connectivity",
                        description: "Sign in with Apple ID",
                        color: .blue
                    ) {
                        selectedMode = .subscription
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Info button
                Button(action: {
                    showModeInfo = true
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Learn more about modes")
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showModeInfo) {
            ModeInfoView()
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModeInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Viewer Mode Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Viewer Mode", systemImage: "doc.text.viewfinder")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("Perfect for:")
                            .font(.headline)
                        
                        BulletPoint(text: "Viewing previously exported data files")
                        BulletPoint(text: "Sharing data with healthcare providers")
                        BulletPoint(text: "Quick access without signing in")
                        BulletPoint(text: "Privacy-focused file browsing")
                        
                        Text("Limitations:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        BulletPoint(text: "Cannot connect to TGM device", isLimitation: true)
                        BulletPoint(text: "No real-time monitoring", isLimitation: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Subscription Mode Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Subscription Mode", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Features:")
                            .font(.headline)
                        
                        BulletPoint(text: "Full device connectivity via Bluetooth")
                        BulletPoint(text: "Real-time sensor data monitoring")
                        BulletPoint(text: "Live data visualization")
                        BulletPoint(text: "Data export and logging")
                        BulletPoint(text: "Device settings and configuration")
                        
                        Text("Requires:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        BulletPoint(text: "Sign in with Apple ID")
                        BulletPoint(text: "Bluetooth permissions")
                        
                        Text("Tiers:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Basic (Free) - Essential features")
                        }
                        
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.orange)
                            Text("Premium - Advanced analytics & unlimited exports")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("About Modes")
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

struct BulletPoint: View {
    let text: String
    var isLimitation: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isLimitation ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isLimitation ? .red : .green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ModeSelectionView(selectedMode: .constant(nil))
}
