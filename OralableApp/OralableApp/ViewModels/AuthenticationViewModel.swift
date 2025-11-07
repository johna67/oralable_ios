//
//  AuthenticationViewModel.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  AuthenticationViewModel.swift
//  OralableApp
//
//  Created: November 7, 2025
//  MVVM Architecture - User authentication business logic
//

import Foundation
import AuthenticationServices
import Combine

@MainActor
class AuthenticationViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable by View)
    
    /// Whether user is authenticated
    @Published var isAuthenticated: Bool = false
    
    /// User ID from Apple
    @Published var userID: String?
    
    /// User email
    @Published var userEmail: String?
    
    /// User full name
    @Published var userFullName: String?
    
    /// Authentication error message
    @Published var authenticationError: String?
    
    /// Whether to show error alert
    @Published var showError: Bool = false
    
    /// Whether authentication is in progress
    @Published var isAuthenticating: Bool = false
    
    // MARK: - Private Properties
    
    private let authenticationManager: AuthenticationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// User initials for avatar display
    var userInitials: String {
        authenticationManager.userInitials
    }
    
    /// Display name with fallback
    var displayName: String {
        authenticationManager.displayName
    }
    
    /// Whether user has complete profile
    var hasCompleteProfile: Bool {
        authenticationManager.hasCompleteProfile
    }
    
    /// Profile completion status text
    var profileStatusText: String {
        if hasCompleteProfile {
            return "Profile Complete"
        } else if userID != nil {
            return "Profile Incomplete"
        } else {
            return "Not Signed In"
        }
    }
    
    /// Greeting text
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 0..<12:
            greeting = "Good morning"
        case 12..<17:
            greeting = "Good afternoon"
        case 17..<22:
            greeting = "Good evening"
        default:
            greeting = "Hello"
        }
        
        if let firstName = userFullName?.components(separatedBy: " ").first {
            return "\(greeting), \(firstName)"
        } else {
            return greeting
        }
    }
    
    /// Sign in button text
    var signInButtonText: String {
        isAuthenticating ? "Signing In..." : "Sign in with Apple"
    }
    
    /// Whether sign in button should be disabled
    var isSignInButtonDisabled: Bool {
        isAuthenticating
    }
    
    // MARK: - Initialization
    
    init(authenticationManager: AuthenticationManager = .shared) {
        self.authenticationManager = authenticationManager
        setupBindings()
        checkAuthenticationState()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to authentication manager's published properties
        authenticationManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    self?.isAuthenticating = false
                }
            }
            .store(in: &cancellables)
        
        authenticationManager.$userID
            .receive(on: DispatchQueue.main)
            .assign(to: &$userID)
        
        authenticationManager.$userEmail
            .receive(on: DispatchQueue.main)
            .assign(to: &$userEmail)
        
        authenticationManager.$userFullName
            .receive(on: DispatchQueue.main)
            .assign(to: &$userFullName)
        
        authenticationManager.$authenticationError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Authentication
    
    /// Check current authentication state
    func checkAuthenticationState() {
        authenticationManager.checkAuthenticationState()
    }
    
    /// Handle Sign in with Apple result
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        authenticationManager.handleSignIn(result: result)
    }
    
    /// Sign out user
    func signOut() {
        authenticationManager.signOut()
    }
    
    /// Confirm sign out (for UI confirmation dialogs)
    func confirmSignOut(confirmed: Bool) {
        if confirmed {
            signOut()
        }
    }
    
    // MARK: - Public Methods - Profile Management
    
    /// Refresh profile from storage
    func refreshProfile() {
        authenticationManager.refreshFromStorage()
    }
    
    /// Get profile information dictionary
    func getProfileInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        if let userID = userID {
            info["User ID"] = userID
        }
        if let email = userEmail {
            info["Email"] = email
        }
        if let name = userFullName {
            info["Name"] = name
        }
        
        info["Status"] = profileStatusText
        
        return info
    }
    
    // MARK: - Public Methods - Debug
    
    /// Debug authentication state (for development)
    func debugAuthState() {
        authenticationManager.debugAuthState()
    }
    
    /// Reset Apple ID authentication (for testing)
    func resetAppleIDAuth() {
        authenticationManager.resetAppleIDAuth()
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: String?) {
        isAuthenticating = false
        
        guard let error = error else {
            authenticationError = nil
            showError = false
            return
        }
        
        authenticationError = error
        showError = true
        
        // Auto-dismiss error after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.showError && self.authenticationError == error {
                self.dismissError()
            }
        }
    }
    
    /// Dismiss error alert
    func dismissError() {
        showError = false
        authenticationError = nil
    }
    
    // MARK: - Utility Methods
    
    /// Check if user needs to update profile
    var needsProfileUpdate: Bool {
        userID != nil && (userEmail == nil || userFullName == nil)
    }
    
    /// Get profile completion percentage
    var profileCompletionPercentage: Double {
        guard userID != nil else { return 0.0 }
        
        var completed = 1.0 // User ID counts as 33%
        if userEmail != nil { completed += 1.0 }
        if userFullName != nil { completed += 1.0 }
        
        return (completed / 3.0) * 100.0
    }
    
    /// Format user since date
    func userSinceText() -> String? {
        // This would require storing the registration date
        // For now, return nil
        return nil
    }
}

// MARK: - SignInCoordinator

extension AuthenticationViewModel {
    /// Coordinate Sign in with Apple flow
    /// This can be called from views to initiate the sign-in process
    func beginSignInFlow() {
        isAuthenticating = true
        // The actual sign-in is handled by the view using SignInWithAppleButton
        // This just sets the state
    }
}

// MARK: - Mock for Previews

extension AuthenticationViewModel {
    static func mockAuthenticated() -> AuthenticationViewModel {
        let mockManager = AuthenticationManager.shared
        let viewModel = AuthenticationViewModel(authenticationManager: mockManager)
        
        // Simulate authenticated state
        viewModel.isAuthenticated = true
        viewModel.userID = "001234.abc123def456.1234"
        viewModel.userEmail = "user@example.com"
        viewModel.userFullName = "John Doe"
        
        return viewModel
    }
    
    static func mockUnauthenticated() -> AuthenticationViewModel {
        let mockManager = AuthenticationManager.shared
        let viewModel = AuthenticationViewModel(authenticationManager: mockManager)
        
        // Default unauthenticated state
        viewModel.isAuthenticated = false
        
        return viewModel
    }
    
    static func mockIncompleteProfile() -> AuthenticationViewModel {
        let mockManager = AuthenticationManager.shared
        let viewModel = AuthenticationViewModel(authenticationManager: mockManager)
        
        // Simulate authenticated but incomplete profile
        viewModel.isAuthenticated = true
        viewModel.userID = "001234.abc123def456.1234"
        viewModel.userEmail = nil
        viewModel.userFullName = nil
        
        return viewModel
    }
}
