import SwiftUI
import AuthenticationServices

@main
struct OralableForDentists: App {
    @StateObject private var dependencies: DentistAppDependencies

    init() {
        // Initialize dentist app dependencies
        let deps = DentistAppDependencies()
        _dependencies = StateObject(wrappedValue: deps)
    }

    var body: some Scene {
        WindowGroup {
            DentistRootView()
                .withDentistDependencies(dependencies)
        }
    }
}

/// Root view that determines which screen to show based on authentication state
struct DentistRootView: View {
    @EnvironmentObject var authenticationManager: DentistAuthenticationManager

    var body: some View {
        Group {
            if authenticationManager.isAuthenticated {
                DentistMainTabView()
            } else {
                DentistOnboardingView()
            }
        }
    }
}

/// Main tab view for authenticated dentists
struct DentistMainTabView: View {
    @EnvironmentObject var dependencies: DentistAppDependencies

    var body: some View {
        TabView {
            PatientListView()
                .tabItem {
                    Label("Patients", systemImage: "person.2.fill")
                }
                .tag(0)

            DentistSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(.black)
    }
}

/// Onboarding view for dentist app
struct DentistOnboardingView: View {
    @EnvironmentObject var authenticationManager: DentistAuthenticationManager

    private let onboardingPages = [
        DentistOnboardingPage(
            icon: "person.2.fill",
            title: "Manage Your Patients",
            description: "Access and monitor bruxism data from your patients in one secure location",
            color: .black
        ),
        DentistOnboardingPage(
            icon: "chart.bar.fill",
            title: "Track Progress",
            description: "View detailed analytics and trends to provide better treatment recommendations",
            color: .black
        ),
        DentistOnboardingPage(
            icon: "lock.shield.fill",
            title: "Secure & Private",
            description: "HIPAA-compliant data sharing with end-to-end encryption",
            color: .black
        )
    ]

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            Image(systemName: "stethoscope")
                .font(.system(size: 80))
                .foregroundColor(.black)
                .padding(.top, 60)
                .padding(.bottom, 40)

            Text("Oralable for Dentists")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 40)

            // Paging content
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    DentistOnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 400)

            Spacer()

            // Sign In with Apple Button
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: authenticationManager.handleSignIn
            )
            .frame(height: 50)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .signInWithAppleButtonStyle(.black)

            if let errorMessage = authenticationManager.authenticationError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Footer
            VStack(spacing: 8) {
                Text("For dental professionals only")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Link("Privacy Policy", destination: URL(string: "https://oralable.com/dentist/privacy")!)
                    Text("•")
                    Link("Terms of Service", destination: URL(string: "https://oralable.com/dentist/terms")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding Models

struct DentistOnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct DentistOnboardingPageView: View {
    let page: DentistOnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)

            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Authentication View

struct DentistAuthenticationView: View {
    @EnvironmentObject var authenticationManager: DentistAuthenticationManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 60))
                    .foregroundColor(.black)
                    .padding(.top, 60)

                Text("Sign In")
                    .font(.system(size: 34, weight: .bold))

                Text("Sign in with your Apple ID to access your dentist account")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Apple Sign In Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        authenticationManager.handleSignIn(result: result)
                        if case .success = result {
                            dismiss()
                        }
                    }
                )
                .frame(height: 50)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .signInWithAppleButtonStyle(.black)

                if let errorMessage = authenticationManager.authenticationError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DentistOnboardingView()
        .environmentObject(DentistAuthenticationManager())
}
