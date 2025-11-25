//
//  FeatureRow.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  FeatureRow.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Feature row component for displaying features
//

import SwiftUI

/// Feature Row Component
struct FeatureRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: designSystem.spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                .foregroundColor(designSystem.colors.textPrimary)
                .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: designSystem.spacing.xxs) {
                Text(title)
                    .font(designSystem.typography.bodyLarge)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text(description)
                    .font(designSystem.typography.bodySmall)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, designSystem.spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG

struct FeatureRow_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        VStack(spacing: designSystem.spacing.md) {
            FeatureRow(
                icon: "waveform.path.ecg",
                title: "Real-time Monitoring",
                description: "Track your dental health metrics in real-time with advanced sensors"
            )

            FeatureRow(
                icon: "heart.fill",
                title: "Heart Rate Tracking",
                description: "Monitor your heart rate during dental procedures"
            )

            FeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Historical Data",
                description: "View and analyze your health data over time"
            )

            FeatureRow(
                icon: "arrow.down.doc.fill",
                title: "Export Data",
                description: "Export your data in CSV or JSON format for analysis"
            )
        }
        .padding()
        .background(designSystem.colors.backgroundPrimary)
        .environmentObject(designSystem)
    }
}

#endif