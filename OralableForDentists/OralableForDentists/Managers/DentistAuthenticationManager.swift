import Foundation
import AuthenticationServices
import SwiftUI

/// Manages authentication for dentist app using Sign in with Apple
/// Inherits common Apple Sign In functionality from BaseAuthenticationManager
@MainActor
class DentistAuthenticationManager: BaseAuthenticationManager {
    static let shared = DentistAuthenticationManager()

    // MARK: - Dentist-Specific Properties

    /// Convenience property to access dentist ID (maps to userID)
    var dentistID: String? {
        get { userID }
        set { userID = newValue }
    }

    /// Convenience property to access dentist name (maps to userFullName)
    var dentistName: String? {
        get { userFullName }
        set { userFullName = newValue }
    }

    /// Convenience property to access dentist email (maps to userEmail)
    var dentistEmail: String? {
        get { userEmail }
        set { userEmail = newValue }
    }

    // MARK: - Keychain Configuration Override

    /// Use dentist-specific keychain keys
    override var keychainKeys: (userID: String, email: String, fullName: String) {
        return (
            "com.oralable.dentist.userID",
            "com.oralable.dentist.userEmail",
            "com.oralable.dentist.userFullName"
        )
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        migrateFromUserDefaults()
    }

    // MARK: - Migration from UserDefaults

    /// Migrate existing UserDefaults data to Keychain (one-time migration)
    private func migrateFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        var migrated = false

        // Migrate dentist ID
        if let dentistID = userDefaults.string(forKey: "dentistAppleID") {
            saveUserAuthentication(userID: dentistID, email: dentistEmail, fullName: dentistName)
            userDefaults.removeObject(forKey: "dentistAppleID")
            migrated = true
            Logger.shared.info("[DentistAuth] Migrated dentist ID from UserDefaults")
        }

        // Migrate dentist name
        if let dentistName = userDefaults.string(forKey: "dentistName") {
            self.dentistName = dentistName
            saveUserAuthentication(userID: dentistID ?? "", email: dentistEmail, fullName: dentistName)
            userDefaults.removeObject(forKey: "dentistName")
            migrated = true
            Logger.shared.info("[DentistAuth] Migrated dentist name from UserDefaults")
        }

        // Migrate dentist email
        if let dentistEmail = userDefaults.string(forKey: "dentistEmail") {
            self.dentistEmail = dentistEmail
            saveUserAuthentication(userID: dentistID ?? "", email: dentistEmail, fullName: dentistName)
            userDefaults.removeObject(forKey: "dentistEmail")
            migrated = true
            Logger.shared.info("[DentistAuth] Migrated dentist email from UserDefaults")
        }

        if migrated {
            userDefaults.synchronize()
            Logger.shared.info("[DentistAuth] Migration from UserDefaults completed")
            // Reload from keychain to ensure consistency
            checkAuthenticationState()
        }
    }

    // MARK: - Authentication Methods

    func signInWithApple() async throws {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        do {
            let controller = ASAuthorizationController(authorizationRequests: [request])
            // Note: In production, would use a proper delegate pattern
            // For now, this is a simplified version
            authenticationError = nil
        } catch {
            authenticationError = "Authentication failed: \(error.localizedDescription)"
            throw error
        }
    }

    /// Handles Sign in with Apple completion (backward compatibility)
    func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        // Delegate to base class implementation
        handleSignIn(result: result)

        // Log dentist-specific message on success
        if case .success = result {
            Logger.shared.info("[DentistAuth] Successfully authenticated: \(dentistID ?? "unknown")")
        }
    }

    // MARK: - Credential State Check

    func checkCredentialState() async {
        guard let dentistID = dentistID else { return }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: dentistID)

            await MainActor.run {
                switch state {
                case .authorized:
                    self.isAuthenticated = true
                case .revoked, .notFound:
                    self.signOut()
                case .transferred:
                    Logger.shared.warning("[DentistAuth] Credential transferred")
                @unknown default:
                    Logger.shared.warning("[DentistAuth] Unknown credential state")
                }
            }
        } catch {
            Logger.shared.error("[DentistAuth] Failed to check credential state: \(error)")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension DentistAuthenticationManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            handleSignInWithAppleCompletion(result: .success(authorization))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            handleSignInWithAppleCompletion(result: .failure(error))
        }
    }
}
