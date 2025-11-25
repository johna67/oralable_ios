//
//  KeychainManager.swift
//  OralableApp
//
//  Created: November 11, 2025
//  Purpose: Secure storage for sensitive authentication data using iOS Keychain
//

import Foundation
import Security

/// Secure storage manager using iOS Keychain for sensitive data
class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    // MARK: - Keychain Keys

    enum KeychainKey: String {
        case userID = "com.oralable.mam.userID"
        case userEmail = "com.oralable.mam.userEmail"
        case userFullName = "com.oralable.mam.userFullName"
    }

    // MARK: - Public Methods

    /// Save a string value securely to Keychain
    /// - Parameters:
    ///   - value: The string to save
    ///   - key: The key to store it under
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func save(_ value: String, forKey key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.shared.error("[KeychainManager] Failed to convert string to data")
            return false
        }

        // Delete any existing item first
        delete(forKey: key)

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.shared.info("[KeychainManager] Successfully saved value for key: \(key.rawValue)")
            return true
        } else {
            Logger.shared.error("[KeychainManager] Failed to save value for key: \(key.rawValue), status: \(status)")
            return false
        }
    }

    /// Retrieve a string value from Keychain
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored string, or nil if not found
    func retrieve(forKey key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                Logger.shared.warning("[KeychainManager] Failed to retrieve value for key: \(key.rawValue), status: \(status)")
            }
            return nil
        }

        return string
    }

    /// Delete a value from Keychain
    /// - Parameter key: The key to delete
    /// - Returns: True if successful or item doesn't exist, false if error occurred
    @discardableResult
    func delete(forKey key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success if deleted or if item didn't exist
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            Logger.shared.error("[KeychainManager] Failed to delete value for key: \(key.rawValue), status: \(status)")
            return false
        }
    }

    /// Delete all authentication-related data from Keychain
    func deleteAllAuthenticationData() {
        delete(forKey: .userID)
        delete(forKey: .userEmail)
        delete(forKey: .userFullName)
        Logger.shared.info("[KeychainManager] All authentication data deleted")
    }

    // MARK: - Authentication-Specific Methods

    /// Save user authentication data
    func saveUserAuthentication(userID: String, email: String?, fullName: String?) {
        save(userID, forKey: .userID)

        if let email = email {
            save(email, forKey: .userEmail)
        }

        if let fullName = fullName {
            save(fullName, forKey: .userFullName)
        }

        Logger.shared.info("[KeychainManager] User authentication data saved securely")
    }

    /// Retrieve user authentication data
    func retrieveUserAuthentication() -> (userID: String?, email: String?, fullName: String?) {
        let userID = retrieve(forKey: .userID)
        let email = retrieve(forKey: .userEmail)
        let fullName = retrieve(forKey: .userFullName)

        return (userID, email, fullName)
    }

    // MARK: - Migration from UserDefaults

    /// Migrate existing authentication data from UserDefaults to Keychain
    /// This should be called once during app initialization to migrate legacy data
    func migrateFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        var migrated = false

        // Check if migration is needed
        if let userID = userDefaults.string(forKey: "userID") {
            save(userID, forKey: .userID)
            userDefaults.removeObject(forKey: "userID")
            migrated = true
            Logger.shared.info("[KeychainManager] Migrated userID from UserDefaults")
        }

        if let email = userDefaults.string(forKey: "userEmail") {
            save(email, forKey: .userEmail)
            userDefaults.removeObject(forKey: "userEmail")
            migrated = true
            Logger.shared.info("[KeychainManager] Migrated userEmail from UserDefaults")
        }

        if let fullName = userDefaults.string(forKey: "userFullName") {
            save(fullName, forKey: .userFullName)
            userDefaults.removeObject(forKey: "userFullName")
            migrated = true
            Logger.shared.info("[KeychainManager] Migrated userFullName from UserDefaults")
        }

        if migrated {
            userDefaults.synchronize()
            Logger.shared.info("[KeychainManager] Migration from UserDefaults completed")
        }
    }
}
