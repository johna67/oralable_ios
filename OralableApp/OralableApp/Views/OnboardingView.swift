//
//  OnboardingView.swift
//  OralableApp
//
//  Welcome screen with direct Apple Sign In
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @State private var currentPage = 0

    private let onboardingPages = [
        OnboardingPage(
            icon: "waveform.path.ecg",
            title: "Monitor Your Bruxism",
            description: "Track teeth grinding and jaw clenching with precision PPG sensor technology",
            color: .black
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Integrate with Apple Health",
            description: "Sync heart rate and SpO2 data with Apple Health for comprehensive health tracking",
            color: .black
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Understand Your Patterns",
            description: "Gain insights into when and why grinding occurs with detailed analytics",
            color: .black
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Share with Your Dentist",
            description: "Collaborate with your healthcare provider by securely sharing your data",
            color: .black
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            Image("OralableLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.top, 60)
                .padding(.bottom, 40)

            // Paging content
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 400)

            Spacer()

            // Sign In with Apple Button - Direct, no intermediate screen
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
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Footer
            VStack(spacing: 8) {
                Text("Requires Oralable device & Apple Health access")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)

                HStack(spacing: 12) {
                    Link("Privacy Policy", destination: URL(string: "https://oralable.com/privacy")!)
                    Text("•")
                    Link("Terms of Service", destination: URL(string: "https://oralable.com/terms")!)
                }
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
            }
            .padding(.bottom, 40)
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                authenticationManager.handleSignIn(with: appleIDCredential)
                Logger.shared.info("🔐 Apple Sign In successful - transitioning to main app")
            }
        case .failure(let error):
            Logger.shared.error("🔐 Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    @EnvironmentObject var designSystem: DesignSystem
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)

            Text(page.title)
                .font(designSystem.typography.largeTitle)
                .foregroundColor(designSystem.colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(DesignSystem())
        .environmentObject(AuthenticationManager())
}
