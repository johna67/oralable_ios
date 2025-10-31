import Foundation
import AuthenticationServices
import SwiftUI

class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var userEmail: String?
    @Published var userFullName: String?
    @Published var authenticationError: String?
    
    // MARK: - Profile UI Properties
    /// Get user initials for avatar display
    var userInitials: String {
        guard let fullName = userFullName, !fullName.isEmpty else {
            return "U" // Default to "U" for User
        }
        
        let components = fullName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        
        if initials.count >= 2 {
            return "\(initials[0])\(initials[1])"
        } else if let first = initials.first {
            return first
        } else {
            return "U"
        }
    }
    
    /// Get display name with fallback
    var displayName: String {
        if let fullName = userFullName, !fullName.isEmpty {
            return fullName
        } else if let email = userEmail {
            // Extract name part from email if full name not available
            let emailPrefix = String(email.prefix(while: { $0 != "@" }))
            return emailPrefix.replacingOccurrences(of: ".", with: " ").capitalized
        } else {
            return "User"
        }
    }
    
    /// Check if we have complete profile information
    var hasCompleteProfile: Bool {
        return userID != nil && (userFullName != nil || userEmail != nil)
    }
    
    static let shared = AuthenticationManager()
    
    private override init() {
        super.init()
        checkAuthenticationState()
    }
    
    // Check if user is already authenticated
    func checkAuthenticationState() {
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            self.userID = userID
            self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
            self.userFullName = UserDefaults.standard.string(forKey: "userFullName")
            self.isAuthenticated = true
        }
    }
    
    // Handle Apple Sign In authorization
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                print("🔐 Apple ID Sign In:")
                print("  User ID: \(userID)")
                print("  Email: \(email?.description ?? "nil")")
                print("  Full Name: \(fullName?.description ?? "nil")")
                print("  Given Name: \(fullName?.givenName ?? "nil")")
                print("  Family Name: \(fullName?.familyName ?? "nil")")
                
                // Save to UserDefaults
                UserDefaults.standard.set(userID, forKey: "userID")
                
                // Handle email (only provided on first sign-in)
                if let email = email, !email.isEmpty {
                    UserDefaults.standard.set(email, forKey: "userEmail")
                    print("✅ Email saved: \(email)")
                } else {
                    print("⚠️ Email not provided (likely subsequent sign-in)")
                }
                
                // Handle full name (only provided on first sign-in)
                if let fullName = fullName,
                   let givenName = fullName.givenName,
                   !givenName.isEmpty {
                    
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    UserDefaults.standard.set(displayName, forKey: "userFullName")
                    print("✅ Full name saved: \(displayName)")
                } else {
                    print("⚠️ Full name not provided (likely subsequent sign-in)")
                }
                
                // Update published properties with stored values
                DispatchQueue.main.async {
                    self.userID = userID
                    // Always load from UserDefaults to handle subsequent sign-ins
                    self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
                    self.userFullName = UserDefaults.standard.string(forKey: "userFullName")
                    self.isAuthenticated = true
                    self.authenticationError = nil
                    
                    print("📱 Updated properties:")
                    print("  Published email: \(self.userEmail ?? "nil")")
                    print("  Published name: \(self.userFullName ?? "nil")")
                }
            }
            
        case .failure(let error):
            print("❌ Apple ID Sign In failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.authenticationError = error.localizedDescription
                self.isAuthenticated = false
            }
        }
    }
    
    // Sign out
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "userID")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userFullName")
        
        DispatchQueue.main.async {
            self.userID = nil
            self.userEmail = nil
            self.userFullName = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Debug and Reset Methods
    
    /// Debug method to print current authentication state
    func debugAuthState() {
        print("🔍 Current Authentication State:")
        print("  isAuthenticated: \(isAuthenticated)")
        print("  userID: \(userID ?? "nil")")
        print("  userEmail: \(userEmail ?? "nil")")
        print("  userFullName: \(userFullName ?? "nil")")
        print("  userInitials: \(userInitials)")
        print("  displayName: \(displayName)")
        print("  hasCompleteProfile: \(hasCompleteProfile)")
        
        print("\n🗄️ UserDefaults Storage:")
        print("  userID: \(UserDefaults.standard.string(forKey: "userID") ?? "nil")")
        print("  userEmail: \(UserDefaults.standard.string(forKey: "userEmail") ?? "nil")")
        print("  userFullName: \(UserDefaults.standard.string(forKey: "userFullName") ?? "nil")")
    }
    
    /// Reset Apple ID authentication (for testing - forces fresh sign-in)
    func resetAppleIDAuth() {
        print("🔄 Resetting Apple ID authentication...")
        signOut()
        // Note: To get fresh Apple ID data, user needs to:
        // 1. Go to Settings > Apple ID > Sign-In & Security > Apps Using Apple ID
        // 2. Find your app and tap "Stop Using Apple ID"
        // 3. Then sign in again to get fresh data
    }
    
    /// Force refresh from UserDefaults (useful after app updates)
    func refreshFromStorage() {
        print("🔄 Refreshing from UserDefaults...")
        
        DispatchQueue.main.async {
            self.userID = UserDefaults.standard.string(forKey: "userID")
            self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
            self.userFullName = UserDefaults.standard.string(forKey: "userFullName")
            self.isAuthenticated = self.userID != nil
            
            print("✅ Refreshed authentication state")
            self.debugAuthState()
        }
    }
}
