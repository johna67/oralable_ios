import SwiftUI

// MARK: - Device Info Card Component
struct ShareDeviceInfoCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    @State private var isExpanded = false

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }

    private var deviceModel: String {
        UIDevice.current.model
    }

    private var systemVersion: String {
        UIDevice.current.systemVersion
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("Device Information", systemImage: "info.circle")
                        .font(designSystem.typography.labelMedium)
                        .foregroundColor(designSystem.colors.textSecondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: DesignSystem.Sizing.Icon.xs))
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(spacing: designSystem.spacing.sm) {
                    ShareInfoRow(label: "Device", value: deviceModel)
                    ShareInfoRow(label: "iOS", value: systemVersion)
                    ShareInfoRow(label: "App Version", value: appVersion)
                    ShareInfoRow(label: "Device ID", value: String(deviceID.prefix(12)) + "...")
                }
            }
        }
        .padding(designSystem.spacing.lg)
        .background(designSystem.colors.backgroundPrimary)
        .cornerRadius(designSystem.cornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
    }
}

struct ShareInfoRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(designSystem.typography.bodySmall)
                .foregroundColor(designSystem.colors.textTertiary)

            Spacer()

            Text(value)
                .font(designSystem.typography.bodySmall)
                .foregroundColor(designSystem.colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
