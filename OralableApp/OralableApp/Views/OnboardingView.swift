import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var showingAuthenticationView = false
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

            // Sign In Button
            Button(action: {
                showingAuthenticationView = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.key.fill")
                    Text("Sign In with Apple")
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(12)
            }
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
        .sheet(isPresented: $showingAuthenticationView) {
            NavigationView {
                AuthenticationView()
            }
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
