import Foundation
import AuthenticationServices
import SwiftUI

/// Manages authentication for dentist app using Sign in with Apple
@MainActor
class DentistAuthenticationManager: NSObject, ObservableObject {
    static let shared = DentistAuthenticationManager()

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var dentistID: String?
    @Published var dentistName: String?
    @Published var dentistEmail: String?
    @Published var authenticationError: String?

    // MARK: - Private Properties

    private let userIDKey = "dentistAppleID"
    private let nameKey = "dentistName"
    private let emailKey = "dentistEmail"

    // MARK: - Initialization

    private override init() {
        super.init()
        loadAuthenticationState()
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

    func handleSignInWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user

                // Extract name if available
                var fullName: String?
                if let givenName = appleIDCredential.fullName?.givenName,
                   let familyName = appleIDCredential.fullName?.familyName {
                    fullName = "\(givenName) \(familyName)"
                }

                // Extract email if available
                let email = appleIDCredential.email

                // Save authentication state
                self.dentistID = userID
                self.dentistName = fullName
                self.dentistEmail = email
                self.isAuthenticated = true

                saveAuthenticationState()

                Logger.shared.info("[DentistAuth] Successfully authenticated: \(userID)")
            }

        case .failure(let error):
            self.authenticationError = "Authentication failed: \(error.localizedDescription)"
            Logger.shared.error("[DentistAuth] Authentication failed: \(error)")
        }
    }

    func signOut() {
        dentistID = nil
        dentistName = nil
        dentistEmail = nil
        isAuthenticated = false

        clearAuthenticationState()

        Logger.shared.info("[DentistAuth] User signed out")
    }

    // MARK: - Persistence

    private func saveAuthenticationState() {
        UserDefaults.standard.set(dentistID, forKey: userIDKey)
        UserDefaults.standard.set(dentistName, forKey: nameKey)
        UserDefaults.standard.set(dentistEmail, forKey: emailKey)
    }

    private func loadAuthenticationState() {
        dentistID = UserDefaults.standard.string(forKey: userIDKey)
        dentistName = UserDefaults.standard.string(forKey: nameKey)
        dentistEmail = UserDefaults.standard.string(forKey: emailKey)

        isAuthenticated = dentistID != nil

        if isAuthenticated {
            Logger.shared.info("[DentistAuth] Loaded existing authentication state")
        }
    }

    private func clearAuthenticationState() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
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
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleSignInWithAppleCompletion(result: .success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        handleSignInWithAppleCompletion(result: .failure(error))
    }
}
