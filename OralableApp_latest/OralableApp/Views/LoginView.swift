import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authenticationManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In to Oralable")
                .font(.title2)
                .bold()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        authenticationManager.handleSignIn(with: credential)
                    }
                case .failure(let error):
                    Logger.shared.error("Apple Sign-In failed: \(error)")
                }
            }
            .frame(height: 45)
            .padding()

            Button("Continue as Guest") {
                authenticationManager.continueAsGuest()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
