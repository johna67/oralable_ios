//
//  AuthenticationView.swift
//  OralableApp
//
//  Simplified: Apple Sign In Only - Wireframe Version
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var appStateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: designSystem.spacing.xxl) {
                Spacer()

                // Apple Logo Icon
                Image(systemName: "applelogo")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.primaryBlack)

                // Title and Description
                VStack(spacing: designSystem.spacing.md) {
                    Text("Sign in with Apple")
                        .font(designSystem.typography.largeTitle)
                        .foregroundColor(designSystem.colors.textPrimary)

                    Text("Use your Apple ID to unlock all features")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, designSystem.spacing.xl)
                }

                Spacer()

                // Sign in with Apple Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleSignInResult(result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(designSystem.cornerRadius.md)
                .padding(.horizontal, designSystem.spacing.xl)

                // Privacy Note
                VStack(spacing: designSystem.spacing.xs) {
                    Text("Your privacy is protected")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack(spacing: designSystem.spacing.md) {
                        Link("Privacy Policy", destination: URL(string: "https://oralable.com/privacy")!)
                        Text("•")
                        Link("Terms of Service", destination: URL(string: "https://oralable.com/terms")!)
                    }
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
                }
                .padding(.bottom, designSystem.spacing.xl)
            }
            .padding(designSystem.spacing.md)
            .navigationTitle("Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Go back to mode selection
                        appStateManager.clearMode()
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Handle Sign In Result

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            // Handle successful sign in
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Extract user information
                let userIdentifier = appleIDCredential.user
                let fullName = appleIDCredential.fullName
                let email = appleIDCredential.email

                // Process authentication with the manager
                authenticationManager.handleAppleSignIn(
                    userIdentifier: userIdentifier,
                    fullName: fullName,
                    email: email
                )

                // Dismiss the view after successful sign in
                dismiss()
            }

        case .failure(let error):
            // Handle sign in error
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled - don't show error
                    break
                case .failed:
                    errorMessage = "Authentication failed. Please try again."
                    showError = true
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple. Please try again."
                    showError = true
                case .notHandled:
                    errorMessage = "Authentication not handled. Please try again."
                    showError = true
                case .unknown:
                    errorMessage = "An unknown error occurred. Please try again."
                    showError = true
                @unknown default:
                    errorMessage = "An unexpected error occurred. Please try again."
                    showError = true
                }
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(AppStateManager.shared)
    }
}
