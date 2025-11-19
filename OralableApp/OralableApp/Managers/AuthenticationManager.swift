import Foundation
import AuthenticationServices
import SwiftUI

/// Patient app authentication manager
/// Inherits common Apple Sign In functionality from BaseAuthenticationManager
class AuthenticationManager: BaseAuthenticationManager {

    override init() {
        super.init()
        // Migrate any existing UserDefaults data to Keychain
        KeychainManager.shared.migrateFromUserDefaults()
    }
}
