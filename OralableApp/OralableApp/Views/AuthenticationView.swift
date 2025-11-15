//
//  AuthenticationView.swift
//  OralableApp
//
//  Simplified for wireframe refactor
//  ONLY handles Apple Sign In - all other features moved to Settings
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var appStateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: designSystem.spacing.xl) {
                Spacer()

                // Apple Logo
                Image(systemName: "applelogo")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.primaryBlack)
                    .padding(.bottom, designSystem.spacing.md)

                // Title
                Text("Sign in with Apple")
                    .font(designSystem.typography.largeTitle)
                    .foregroundColor(designSystem.colors.textPrimary)
                    .multilineTextAlignment(.center)

                // Description
                Text("Sign in to access Subscription Mode with full Bluetooth connectivity, data export, and HealthKit integration.")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, designSystem.spacing.lg)

                Spacer()

                // Sign In Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        viewModel.handleSignIn(result: result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(designSystem.cornerRadius.md)
                .padding(.horizontal, designSystem.spacing.lg)

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
                .padding(.top, designSystem.spacing.md)
                .padding(.bottom, designSystem.spacing.xl)
            }
            .padding(designSystem.spacing.lg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(designSystem.colors.primaryBlack)
                    }
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.authenticationError ?? "An authentication error occurred")
        }
        .onChange(of: viewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Successfully authenticated - dismiss view
                dismiss()
            }
        }
    }
}

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(AppStateManager.shared)
    }
}
