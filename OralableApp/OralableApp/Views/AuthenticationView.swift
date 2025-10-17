import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Binding var selectedMode: AppMode?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("Sign In Required")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Connect your Apple ID to access subscription features")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            authManager.handleSignIn(result: result)
                            if case .failure = result {
                                showError = true
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    
                    if showError, let error = authManager.authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Back button
                Button(action: {
                    selectedMode = nil
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to Mode Selection")
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .font(.footnote)
                }
                .padding(.bottom, 40)
                
                // Privacy info
                Text("Your Apple ID is used only for authentication. We don't store or share your personal information.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                showError = false
            }
        } message: {
            Text(authManager.authenticationError ?? "An unknown error occurred")
        }
    }
}

struct SubscriptionTierSelectionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showUpgradeSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Start with Basic, upgrade anytime")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Basic Tier Card
                    TierCard(
                        tier: .basic,
                        isCurrentTier: subscriptionManager.currentTier == .basic,
                        action: {
                            subscriptionManager.resetToBasic()
                        }
                    )
                    
                    // Paid Tier Card
                    TierCard(
                        tier: .paid,
                        isCurrentTier: subscriptionManager.currentTier == .paid,
                        action: {
                            showUpgradeSheet = true
                        }
                    )
                    
                    // Continue button
                    if subscriptionManager.currentTier != .basic {
                        Button(action: {
                            // Continue with current tier
                        }) {
                            Text("Continue with \(subscriptionManager.currentTier.displayName)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView(showUpgradeSheet: $showUpgradeSheet)
        }
    }
}

struct TierCard: View {
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tier.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if isCurrentTier {
                            Text("CURRENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    if tier == .basic {
                        Text("Free Forever")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Coming Soon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if tier == .paid {
                    Image(systemName: "star.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }
            
            // Action button
            if !isCurrentTier {
                Button(action: action) {
                    Text(tier == .basic ? "Select Basic" : "Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tier == .basic ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: isCurrentTier ? Color.green.opacity(0.3) : Color.black.opacity(0.1), 
                radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentTier ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

struct UpgradeView: View {
    @Binding var showUpgradeSheet: Bool
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Premium Features")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming Soon!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("In-app purchases will be available in a future update. Premium features are under development.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: {
                    showUpgradeSheet = false
                }) {
                    Text("Got It")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showUpgradeSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    AuthenticationView(selectedMode: .constant(.subscription))
}
