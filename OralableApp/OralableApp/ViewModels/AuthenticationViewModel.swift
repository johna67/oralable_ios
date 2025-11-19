//
//  AuthenticationViewModel.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Final Fix: Corrected AuthenticationManager method calls
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
    private let subscriptionManager: SubscriptionManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(authenticationManager: AuthenticationManager, subscriptionManager: SubscriptionManager) {
        self.authenticationManager = authenticationManager
        self.subscriptionManager = subscriptionManager
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind to authentication manager state
        authenticationManager.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authenticationManager.$userID
            .assign(to: &$userID)
        
        authenticationManager.$userEmail
            .assign(to: &$userEmail)
        
        authenticationManager.$userFullName
            .assign(to: &$userFullName)
    }
    
    // MARK: - Computed Properties
    
    /// User initials for avatar display
    var userInitials: String {
        guard let fullName = userFullName else { return "?" }
        let components = fullName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
    
    /// Display name with fallback
    var displayName: String {
        if let fullName = userFullName {
            return fullName
        } else if let email = userEmail {
            return email.components(separatedBy: "@").first ?? "User"
        } else {
            return "Guest"
        }
    }
    
    /// Whether user has complete profile
    var hasCompleteProfile: Bool {
        userID != nil && userEmail != nil && userFullName != nil
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
    
    /// Profile completion percentage
    var profileCompletionPercentage: Double {
        var percentage: Double = 0
        
        // Check each profile field
        if userID != nil { percentage += 25 }
        if userEmail != nil { percentage += 25 }
        if userFullName != nil { percentage += 25 }
        if hasCompleteProfile { percentage += 25 }
        
        return min(percentage, 100)
    }
    
    /// Member since date text
    var memberSinceText: String {
        if isAuthenticated {
            // In a real app, you'd retrieve the actual registration date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: Date(timeIntervalSinceNow: -90*24*60*60)) // Example: 90 days ago
        }
        return "Not a member"
    }
    
    /// Last profile update text
    var lastUpdatedText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    /// Subscription status
    var subscriptionStatus: String {
        return subscriptionManager.isPaidSubscriber ? "Active" : "Free"
    }

    /// Subscription plan name
    var subscriptionPlan: String {
        return subscriptionManager.currentTier.displayName
    }

    /// Subscription expiry text
    var subscriptionExpiryText: String {
        if subscriptionManager.isPaidSubscriber {
            // In a real implementation, this would come from StoreKit
            return "Renews automatically"
        }
        return "No active subscription"
    }

    /// Whether user has active subscription
    var hasSubscription: Bool {
        return subscriptionManager.isPaidSubscriber
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication state
    func checkAuthenticationState() {
        authenticationManager.checkAuthenticationState()
    }
    
    /// Handle Sign In with Apple - FIXED: Now calls the correct method
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        
        // FIXED: Call the correct method that exists in AuthenticationManager
        authenticationManager.handleSignIn(result: result)
        
        // Handle completion
        DispatchQueue.main.async { [weak self] in
            self?.isAuthenticating = false
            
            // Check if there was an error
            if case .failure(let error) = result {
                self?.authenticationError = error.localizedDescription
                self?.showError = true
            }
        }
    }
    
    /// Sign out
    func signOut() {
        authenticationManager.signOut()
    }
    
    /// Refresh profile information
    func refreshProfile() {
        checkAuthenticationState()
    }
    
    /// Dismiss error alert
    func dismissError() {
        showError = false
        authenticationError = nil
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    /// Debug authentication state
    func debugAuthState() {
        Logger.shared.debug("=== Authentication Debug ===")
        Logger.shared.debug("Is Authenticated: \(isAuthenticated)")
        Logger.shared.debug("User ID: \(userID ?? "nil")")
        Logger.shared.debug("User Email: \(userEmail ?? "nil")")
        Logger.shared.debug("User Full Name: \(userFullName ?? "nil")")
        Logger.shared.debug("Has Complete Profile: \(hasCompleteProfile)")
        Logger.shared.debug("Profile Completion: \(profileCompletionPercentage)%")
        Logger.shared.debug("Subscription Status: \(subscriptionStatus)")
        Logger.shared.debug("===========================")
    }
    
    /// Reset Apple ID authentication (debug only)
    func resetAppleIDAuth() {
        // This would reset stored Apple ID credentials
        authenticationManager.resetAppleIDAuth()
        Logger.shared.info("[AuthenticationViewModel] Apple ID authentication has been reset")
    }
    #endif
}

// MARK: - Extensions for Sign In with Apple

extension AuthenticationViewModel {
    /// Create Sign In with Apple request
    func createSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    /// Handle Sign In with Apple completion
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        handleSignIn(result: result)
    }
}
