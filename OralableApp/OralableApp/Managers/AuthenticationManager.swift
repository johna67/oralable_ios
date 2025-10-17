import Foundation
import AuthenticationServices
import SwiftUI

class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var userEmail: String?
    @Published var userFullName: String?
    @Published var authenticationError: String?
    
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
                
                // Save to UserDefaults
                UserDefaults.standard.set(userID, forKey: "userID")
                if let email = email {
                    UserDefaults.standard.set(email, forKey: "userEmail")
                }
                if let fullName = fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    UserDefaults.standard.set(displayName, forKey: "userFullName")
                }
                
                // Update published properties
                DispatchQueue.main.async {
                    self.userID = userID
                    self.userEmail = email ?? self.userEmail
                    self.userFullName = fullName?.givenName ?? self.userFullName
                    self.isAuthenticated = true
                    self.authenticationError = nil
                }
            }
            
        case .failure(let error):
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
}
