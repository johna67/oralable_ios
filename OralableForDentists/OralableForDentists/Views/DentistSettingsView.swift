//
//  DentistSettingsView.swift
//  OralableForDentists
//
//  Apple style settings - matches OralableApp
//  Updated with FeatureFlags and Developer Settings access
//

import SwiftUI

struct DentistSettingsView: View {
    @EnvironmentObject var authenticationManager: DentistAuthenticationManager
    @EnvironmentObject var subscriptionManager: DentistSubscriptionManager
    @EnvironmentObject var designSystem: DesignSystem
    @ObservedObject private var featureFlags = FeatureFlags.shared

    @State private var showingSignOutConfirmation = false
    @State private var versionTapCount = 0
    @State private var showDeveloperSettings = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    accountRow
                } header: {
                    Text("Account")
                }

                // Subscription section (feature flagged)
                if featureFlags.showSubscription {
                    Section {
                        subscriptionRow

                        if subscriptionManager.currentTier != .enterprise {
                            NavigationLink(destination: UpgradePromptView()) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Upgrade Plan")
                                }
                            }
                        }
                    } header: {
                        Text("Subscription")
                    }
                }

                Section {
                    Link(destination: URL(string: "https://oralable.com/help")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("Help & Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://oralable.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://oralable.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Support")
                }

                Section {
                    // Version row with hidden developer access (7 taps)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 7 {
                            showDeveloperSettings = true
                            versionTapCount = 0
                        }
                        // Reset tap count after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            versionTapCount = 0
                        }
                    }
                } header: {
                    Text("App")
                }

                Section {
                    Button(action: {
                        showingSignOutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authenticationManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showDeveloperSettings) {
                NavigationStack {
                    DeveloperSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showDeveloperSettings = false
                                }
                            }
                        }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var accountRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(authenticationManager.currentUserName ?? "Dentist")
                    .font(.headline)

                Text(authenticationManager.currentUserEmail ?? "Signed in with Apple")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var subscriptionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Plan")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(subscriptionManager.currentTier.displayName)
                    .font(.headline)
            }

            Spacer()

            Text("\(subscriptionManager.patientCount)/\(subscriptionManager.currentTier.maxPatients)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
