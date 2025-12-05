//
//  OralableForDentists.swift
//  OralableForDentists
//
//  Updated with DesignSystem - matches OralableApp
//

import SwiftUI

@main
struct OralableForDentists: App {
    @StateObject private var dependencies: DentistAppDependencies
    @StateObject private var designSystem = DesignSystem()

    init() {
        let deps = DentistAppDependencies()
        _dependencies = StateObject(wrappedValue: deps)
    }

    var body: some Scene {
        WindowGroup {
            DentistRootView()
                .withDentistDependencies(dependencies)
                .environmentObject(designSystem)
        }
    }
}

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

struct DentistOnboardingView: View {
    @EnvironmentObject var authenticationManager: DentistAuthenticationManager
    @EnvironmentObject var designSystem: DesignSystem

    private let onboardingPages = [
        DentistOnboardingPage(
            icon: "person.2.fill",
            title: "Manage Your Participants",
            description: "Access and monitor oral wellness data from your participants in one secure location",
            color: .black
        ),
        DentistOnboardingPage(
            icon: "chart.bar.fill",
            title: "Track Progress",
            description: "View detailed muscle activity analytics and trends to provide better wellness recommendations",
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
            Image(systemName: "stethoscope")
                .font(.system(size: 80))
                .foregroundColor(.black)
                .padding(.top, 60)
                .padding(.bottom, 40)

            Text("Oralable for Dentists")
                .font(designSystem.typography.h2)
                .padding(.bottom, 40)

            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    DentistOnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 400)

            Spacer()

            Button(action: {
                Task {
                    do {
                        try await authenticationManager.signInWithApple()
                    } catch {
                        // Error handling
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                    Text("Sign In with Apple")
                }
                .font(designSystem.typography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            VStack(spacing: 8) {
                Text("For dental professionals only")
                    .font(designSystem.typography.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Link("Privacy Policy", destination: URL(string: "https://oralable.com/dentist/privacy")!)
                    Text("•")
                    Link("Terms of Service", destination: URL(string: "https://oralable.com/dentist/terms")!)
                }
                .font(designSystem.typography.caption)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
    }
}

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
