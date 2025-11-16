//
//  FirmwareUpdateView.swift
//  OralableApp
//
//  Firmware update flow for Oralable devices
//

import SwiftUI

struct FirmwareUpdateView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var bleManager = OralableBLE.shared

    @State private var updateStatus: UpdateStatus = .checking
    @State private var progress: Double = 0.0
    @State private var availableVersion: String = ""
    @State private var releaseNotes: String = ""

    enum UpdateStatus {
        case checking
        case upToDate
        case updateAvailable
        case downloading
        case installing
        case completed
        case error(String)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.xl) {
                    Spacer()
                        .frame(height: designSystem.spacing.xl)

                    // Status Icon
                    statusIcon

                    // Status Message
                    statusMessage

                    // Progress Bar (when downloading/installing)
                    if case .downloading = updateStatus {
                        progressView
                    } else if case .installing = updateStatus {
                        progressView
                    }

                    // Release Notes (when update available)
                    if case .updateAvailable = updateStatus {
                        releaseNotesView
                    }

                    // Action Buttons
                    actionButtons

                    Spacer()
                }
                .padding(designSystem.spacing.xl)
            }
            .background(designSystem.colors.backgroundPrimary)
            .navigationTitle("Firmware Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if updateStatus != .downloading && updateStatus != .installing {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            checkForUpdates()
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch updateStatus {
        case .checking:
            ProgressView()
                .scaleEffect(2)
                .padding(designSystem.spacing.xl)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
        case .updateAvailable:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
        case .downloading, .installing:
            ProgressView()
                .scaleEffect(2)
                .padding(designSystem.spacing.xl)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
        }
    }

    // MARK: - Status Message

    @ViewBuilder
    private var statusMessage: some View {
        VStack(spacing: designSystem.spacing.sm) {
            switch updateStatus {
            case .checking:
                Text("Checking for Updates...")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("Please wait while we check for firmware updates")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

            case .upToDate:
                Text("Up to Date")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("You're running the latest firmware version")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                Text("Version: \(bleManager.sensorData.firmwareVersion)")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
                    .padding(.top, designSystem.spacing.xs)

            case .updateAvailable:
                Text("Update Available")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("Version \(availableVersion) is available")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

            case .downloading:
                Text("Downloading Update")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("Please keep your device nearby")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

            case .installing:
                Text("Installing Update")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("Do not disconnect your device")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

            case .completed:
                Text("Update Complete")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text("Your device is now running version \(availableVersion)")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

            case .error(let message):
                Text("Update Failed")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text(message)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, designSystem.spacing.xl)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: designSystem.spacing.sm) {
            ProgressView(value: progress, total: 1.0)
                .padding(.horizontal, designSystem.spacing.xl)

            Text("\(Int(progress * 100))%")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
        }
        .padding(.top, designSystem.spacing.lg)
    }

    // MARK: - Release Notes

    private var releaseNotesView: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("What's New")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            Text(releaseNotes)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch updateStatus {
        case .updateAvailable:
            Button(action: { startUpdate() }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download and Install")
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(Color.blue)
                .cornerRadius(designSystem.cornerRadius.md)
            }

        case .checking:
            EmptyView()

        case .upToDate:
            Button(action: { checkForUpdates() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Again")
                }
                .font(designSystem.typography.button)
                .foregroundColor(designSystem.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }

        case .error:
            Button(action: { checkForUpdates() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(designSystem.typography.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(designSystem.spacing.md)
                .background(Color.blue)
                .cornerRadius(designSystem.cornerRadius.md)
            }

        case .completed:
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(designSystem.typography.buttonLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(Color.green)
                    .cornerRadius(designSystem.cornerRadius.md)
            }

        case .downloading, .installing:
            EmptyView()
        }
    }

    // MARK: - Update Logic

    private func checkForUpdates() {
        updateStatus = .checking

        // Simulate checking for updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Simulate: check if update is available
            let currentVersion = bleManager.sensorData.firmwareVersion
            let latestVersion = "1.1.0" // This would come from a server in production

            if currentVersion < latestVersion {
                availableVersion = latestVersion
                releaseNotes = """
                • Improved heart rate accuracy
                • Enhanced SpO2 calculation algorithm
                • Better battery optimization
                • Bug fixes and performance improvements
                """
                updateStatus = .updateAvailable
            } else {
                updateStatus = .upToDate
            }
        }
    }

    private func startUpdate() {
        // Start downloading
        updateStatus = .downloading
        progress = 0.0

        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            progress += 0.02

            if progress >= 1.0 {
                timer.invalidate()
                installUpdate()
            }
        }
    }

    private func installUpdate() {
        updateStatus = .installing
        progress = 0.0

        // Simulate installation progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            progress += 0.03

            if progress >= 1.0 {
                timer.invalidate()
                completeUpdate()
            }
        }
    }

    private func completeUpdate() {
        // In production, this would send the firmware update command to the device
        // For now, we'll just simulate success
        updateStatus = .completed

        // Note: In a real implementation, you would:
        // 1. Download firmware file from server
        // 2. Verify checksum
        // 3. Send firmware data to device via BLE
        // 4. Reboot device
        // 5. Verify new firmware version
    }
}

// MARK: - Preview

struct FirmwareUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        FirmwareUpdateView()
            .environmentObject(DesignSystem.shared)
    }
}
