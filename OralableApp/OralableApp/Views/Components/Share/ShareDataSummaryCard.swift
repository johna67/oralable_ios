import SwiftUI

// MARK: - Data Summary Card Component
struct ShareDataSummaryCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    @ObservedObject var ble: OralableBLE

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Data Summary")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            Divider()

            // Metrics Grid
            HStack(spacing: designSystem.spacing.lg) {
                ShareMetricBox(
                    title: "Sensor Data",
                    value: "\(ble.sensorDataHistory.count)",
                    subtitle: "points",
                    icon: "waveform.path.ecg",
                    color: .blue
                )

                ShareMetricBox(
                    title: "Log Entries",
                    value: "\(ble.logMessages.count)",
                    subtitle: "messages",
                    icon: "doc.text",
                    color: .green
                )
            }

            if !ble.sensorDataHistory.isEmpty,
               let first = ble.sensorDataHistory.first,
               let last = ble.sensorDataHistory.last {
                Divider()

                VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                    Label("Recording Period", systemImage: "clock")
                        .font(designSystem.typography.labelMedium)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Text(first.timestamp, style: .date)
                        Image(systemName: "arrow.right")
                        Text(last.timestamp, style: .date)
                    }
                    .font(designSystem.typography.bodySmall)
                    .foregroundColor(designSystem.colors.textTertiary)
                }
            }
        }
        .padding(designSystem.spacing.lg)
        .background(designSystem.colors.backgroundPrimary)
        .cornerRadius(designSystem.cornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
    }
}

struct ShareMetricBox: View {
    @EnvironmentObject var designSystem: DesignSystem
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
            HStack(spacing: designSystem.spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                    .foregroundColor(color)

                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(designSystem.typography.displaySmall)
                    .foregroundColor(color)

                Text(subtitle)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(designSystem.spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(designSystem.cornerRadius.md)
    }
}
