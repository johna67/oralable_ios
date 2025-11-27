//
//  DentistAuthenticationManager.swift
//  OralableForDentists
//
//  Manages authentication for dentist app using Sign in with Apple
//  Inherits common Apple Sign In functionality from BaseAuthenticationManager
//

import Foundation
import AuthenticationServices
import SwiftUI

/// Dentist app authentication manager
/// Inherits common Apple Sign In functionality from BaseAuthenticationManager
@MainActor
class DentistAuthenticationManager: BaseAuthenticationManager {

    // MARK: - Dentist-Specific Properties

    /// Convenience accessors for dentist-specific naming
    var dentistID: String? { userID }
    var dentistName: String? { userFullName }
    var dentistEmail: String? { userEmail }

    // MARK: - Keychain Configuration Override

    /// Override to use dentist-specific keychain keys
    override var keychainKeys: (userID: String, email: String, fullName: String) {
        return (
            "com.oralable.dentist.userID",
            "com.oralable.dentist.userEmail",
            "com.oralable.dentist.userFullName"
        )
    }

    // MARK: - Initialization

    override init() {
        super.init()

        // Migrate any existing UserDefaults data to Keychain
        migrateFromUserDefaults()

        Logger.shared.info("[DentistAuth] Dentist authentication manager initialized")
    }

    // MARK: - Migration from UserDefaults

    /// Migrate authentication data from UserDefaults to secure Keychain storage
    private func migrateFromUserDefaults() {
        let userIDKey = "dentistAppleID"
        let nameKey = "dentistName"
        let emailKey = "dentistEmail"

        // Check if there's data in UserDefaults that needs migration
        if let oldUserID = UserDefaults.standard.string(forKey: userIDKey) {
            Logger.shared.info("[DentistAuth] Migrating authentication data from UserDefaults to Keychain")

            let oldName = UserDefaults.standard.string(forKey: nameKey)
            let oldEmail = UserDefaults.standard.string(forKey: emailKey)

            // Save to keychain
            saveUserAuthentication(userID: oldUserID, email: oldEmail, fullName: oldName)

            // Update published properties
            self.userID = oldUserID
            self.userEmail = oldEmail
            self.userFullName = oldName
            self.isAuthenticated = true

            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: userIDKey)
            UserDefaults.standard.removeObject(forKey: nameKey)
            UserDefaults.standard.removeObject(forKey: emailKey)

            Logger.shared.info("[DentistAuth] Migration complete - data now securely stored in Keychain")
        }
    }

    // MARK: - Credential State Check

    /// Check if the Apple ID credential is still valid
    func checkCredentialState() async {
        guard let dentistID = dentistID else { return }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: dentistID)

            await MainActor.run {
                switch state {
                case .authorized:
                    self.isAuthenticated = true
                    Logger.shared.info("[DentistAuth] Credential state: authorized")

                case .revoked, .notFound:
                    Logger.shared.warning("[DentistAuth] Credential state: revoked/not found - signing out")
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
