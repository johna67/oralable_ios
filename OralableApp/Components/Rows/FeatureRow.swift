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
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 40)
            
            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG

struct FeatureRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
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
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif