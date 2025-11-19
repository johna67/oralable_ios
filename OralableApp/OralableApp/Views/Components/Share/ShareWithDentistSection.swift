import SwiftUI

// MARK: - Share with Dentist Component
struct ShareWithDentistSection: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var sharedDataManager: SharedDataManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var shareCode: String = ""
    @State private var showShareCode = false
    @State private var showUpgradePrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Share with Dentist")
                        .font(designSystem.typography.headline)

                    Text("Allow your dentist to view your data")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }

                Spacer()
            }

            // Generate Share Code Button
            Button(action: {
                if subscriptionManager.currentTier == .basic && sharedDataManager.sharedDentists.count >= 1 {
                    showUpgradePrompt = true
                } else {
                    generateShareCode()
                }
            }) {
                HStack {
                    Image(systemName: "qrcode")
                    Text("Generate Share Code")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Show generated code
            if showShareCode {
                VStack(spacing: 12) {
                    Text("Share Code:")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    Text(shareCode)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .tracking(8)

                    Text("Code expires in 48 hours")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    Button("Copy Code") {
                        UIPasteboard.general.string = shareCode
                    }
                    .font(designSystem.typography.buttonSmall)
                }
                .padding()
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(12)
            }

            // List of shared dentists
            if !sharedDataManager.sharedDentists.isEmpty {
                Divider()
                    .padding(.vertical, 8)

                Text("Shared With:")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)

                ForEach(sharedDataManager.sharedDentists) { dentist in
                    SharedDentistRow(dentist: dentist)
                }
            }

            // Tier limitation message
            if subscriptionManager.currentTier == .basic {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Basic tier: Share with 1 dentist")
                        .font(designSystem.typography.caption)
                }
                .foregroundColor(designSystem.colors.textSecondary)
                .padding(.top, 8)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundPrimary)
        .cornerRadius(designSystem.cornerRadius.md)
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradeToShareMoreView()
        }
    }

    private func generateShareCode() {
        Task {
            do {
                shareCode = try await sharedDataManager.createShareInvitation()
                showShareCode = true
            } catch {
                Logger.shared.error("[generating share code: \(error)")
            }
        }
    }
}

struct SharedDentistRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var sharedDataManager: SharedDataManager
    let dentist: SharedDentist
    @State private var showRevokeConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dentist.dentistName ?? "Dentist")
                    .font(designSystem.typography.body)

                Text("Shared: \(dentist.sharedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            Spacer()

            Button("Revoke") {
                showRevokeConfirmation = true
            }
            .font(designSystem.typography.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(8)
        .alert("Revoke Access?", isPresented: $showRevokeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Revoke", role: .destructive) {
                revokeAccess()
            }
        } message: {
            Text("This dentist will no longer be able to view your data.")
        }
    }

    private func revokeAccess() {
        Task {
            do {
                try await sharedDataManager.revokeAccessForDentist(dentistID: dentist.dentistID)
            } catch {
                Logger.shared.error("[revoking access: \(error)")
            }
        }
    }
}

struct UpgradeToShareMoreView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.black)

                Text("Share with More Providers")
                    .font(designSystem.typography.title)

                Text("Upgrade to Premium to share your data with unlimited healthcare providers.")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    ShareFeatureRow(icon: "checkmark.circle.fill", text: "Share with unlimited providers")
                    ShareFeatureRow(icon: "checkmark.circle.fill", text: "Advanced analytics")
                    ShareFeatureRow(icon: "checkmark.circle.fill", text: "Unlimited data export")
                    ShareFeatureRow(icon: "checkmark.circle.fill", text: "Priority support")
                }
                .padding()

                Button("Upgrade to Premium") {
                    dismiss()
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
                .padding(.horizontal)

                Button("Maybe Later") {
                    dismiss()
                }
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShareFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 15))
        }
    }
}
