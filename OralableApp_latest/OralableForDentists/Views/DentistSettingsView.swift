import SwiftUI
import StoreKit

struct DentistSettingsView: View {
    @EnvironmentObject var dependencies: DentistAppDependencies
    @State private var viewModel: DentistSettingsViewModel?
    @State private var showingSignOutAlert = false

    var body: some View {
        Group {
            if let vm = viewModel {
                settingsContent(viewModel: vm)
            } else {
                ProgressView("Loading...")
                    .task {
                        if viewModel == nil {
                            viewModel = dependencies.makeSettingsViewModel()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func settingsContent(viewModel: DentistSettingsViewModel) -> some View {
        NavigationView {
            List {
                // Account Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        VStack(alignment: .leading, spacing: 4) {
                            if let name = viewModel.dentistName {
                                Text(name)
                                    .font(.headline)
                            }

                            if let email = viewModel.dentistEmail {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                // Subscription Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(viewModel.currentTier.displayName)
                                .font(.headline)
                        }

                        Spacer()

                        if viewModel.currentTier != .practice {
                            NavigationLink(destination: UpgradePromptView()) {
                                Text("Upgrade")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    if viewModel.currentTier.isPaid {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(viewModel.subscriptionStatus)
                                .font(.body)

                            if let expiry = viewModel.subscriptionExpiryDate {
                                Text(viewModel.subscriptionDetails)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plan Features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(viewModel.currentTier.features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)

                                Text(feature)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                } header: {
                    Text("Subscription")
                }

                // Restore Purchases
                if viewModel.currentTier.isPaid {
                    Section {
                        Button(action: {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        }) {
                            if viewModel.isPurchasing {
                                HStack {
                                    ProgressView()
                                    Text("Restoring...")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Restore Purchases")
                            }
                        }
                        .disabled(viewModel.isPurchasing)
                    }
                }

                // Support Section
                Section {
                    Link(destination: URL(string: "https://oralable.com/dentist/support")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help & Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://oralable.com/dentist/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://oralable.com/dentist/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
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

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Sign Out
                Section {
                    Button(role: .destructive, action: {
                        showingSignOutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .task {
                await viewModel.loadProducts()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DentistSettingsView()
        .withDentistDependencies(DentistAppDependencies())
}
