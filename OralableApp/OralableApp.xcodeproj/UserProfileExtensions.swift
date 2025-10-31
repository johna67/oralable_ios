import SwiftUI
import UIKit

// MARK: - Profile Utilities
extension AuthenticationManager {
    /// Generate a consistent color for the user based on their ID
    var avatarColor: Color {
        guard let userID = userID else { return .blue }
        
        // Create a hash from the user ID to generate consistent colors
        let hash = userID.hash
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .indigo, .teal, .cyan]
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    /// Check if the user just signed in (for welcome animations)
    var isNewSession: Bool {
        let lastLaunch = UserDefaults.standard.double(forKey: "lastLaunchTime")
        let currentTime = Date().timeIntervalSince1970
        
        // If more than 1 hour has passed, consider it a new session
        return currentTime - lastLaunch > 3600
    }
    
    /// Mark that the user has opened the app
    func markAppLaunch() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastLaunchTime")
    }
}

// MARK: - Profile Image Manager
class ProfileImageManager: ObservableObject {
    @Published var userProfileImage: UIImage?
    private let authManager: AuthenticationManager
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        loadProfileImage()
    }
    
    private func loadProfileImage() {
        // Check if we have a cached profile image
        if let userID = authManager.userID,
           let imageData = UserDefaults.standard.data(forKey: "profileImage_\(userID)"),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.userProfileImage = image
            }
        }
    }
    
    func saveProfileImage(_ image: UIImage) {
        guard let userID = authManager.userID,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        UserDefaults.standard.set(imageData, forKey: "profileImage_\(userID)")
        DispatchQueue.main.async {
            self.userProfileImage = image
        }
    }
    
    func clearProfileImage() {
        guard let userID = authManager.userID else { return }
        
        UserDefaults.standard.removeObject(forKey: "profileImage_\(userID)")
        DispatchQueue.main.async {
            self.userProfileImage = nil
        }
    }
}

// MARK: - Enhanced User Avatar with Image Support
struct EnhancedUserAvatarView: View {
    let initials: String
    let profileImage: UIImage?
    let size: CGFloat
    let showOnlineIndicator: Bool
    let color: Color
    
    init(
        initials: String,
        profileImage: UIImage? = nil,
        size: CGFloat = 36,
        showOnlineIndicator: Bool = false,
        color: Color = .blue
    ) {
        self.initials = initials
        self.profileImage = profileImage
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
        self.color = color
    }
    
    var body: some View {
        ZStack {
            if let profileImage = profileImage {
                // Use actual profile image
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                // Use initials with gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
            
            // Online indicator
            if showOnlineIndicator {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
    }
}

// MARK: - Profile Picture Picker
struct ProfilePicturePicker: View {
    @ObservedObject var profileImageManager: ProfileImageManager
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        Button(action: {
            showActionSheet = true
        }) {
            ZStack {
                EnhancedUserAvatarView(
                    initials: AuthenticationManager.shared.userInitials,
                    profileImage: profileImageManager.userProfileImage,
                    size: 100,
                    color: AuthenticationManager.shared.avatarColor
                )
                
                // Edit overlay
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 100, height: 100)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Edit")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .opacity(0.8)
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Profile Picture"),
                buttons: [
                    .default(Text("Take Photo")) {
                        sourceType = .camera
                        showImagePicker = true
                    },
                    .default(Text("Choose from Library")) {
                        sourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .destructive(Text("Remove Photo")) {
                        profileImageManager.clearProfileImage()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: sourceType,
                onImageSelected: { image in
                    profileImageManager.saveProfileImage(image)
                }
            )
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Resize image to reasonable size
                let resizedImage = image.resized(to: CGSize(width: 400, height: 400))
                parent.onImageSelected(resizedImage)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage Extension for Resizing
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Welcome Animation View
struct WelcomeAnimationView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var animateWelcome = false
    
    var body: some View {
        if authManager.isNewSession && authManager.isAuthenticated {
            VStack(spacing: 20) {
                EnhancedUserAvatarView(
                    initials: authManager.userInitials,
                    size: 80,
                    color: authManager.avatarColor
                )
                .scaleEffect(animateWelcome ? 1.0 : 0.5)
                .opacity(animateWelcome ? 1.0 : 0.0)
                
                Text("Welcome back, \(authManager.displayName)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .opacity(animateWelcome ? 1.0 : 0.0)
                
                Text("Ready to monitor your bruxism?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(animateWelcome ? 1.0 : 0.0)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0)) {
                    animateWelcome = true
                }
                
                // Mark app launch after showing welcome
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    authManager.markAppLaunch()
                }
            }
        }
    }
}