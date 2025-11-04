//
//  ActionCardView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  ActionCardView.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Action card component with icon, title, and description
//

import SwiftUI

/// Action Card Component
struct ActionCardView: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        description: String,
        iconColor: Color = DesignSystem.Colors.textPrimary,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizing.Icon.xl))
                    .foregroundColor(iconColor)
                
                // Title
                Text(title)
                    .font(DesignSystem.Typography.h4)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                // Description
                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG

struct ActionCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ActionCardView(
                icon: "chart.line.uptrend.xyaxis",
                title: "View Data",
                description: "Access your historical health data and trends",
                iconColor: DesignSystem.Colors.info,
                action: {}
            )
            
            ActionCardView(
                icon: "arrow.down.doc.fill",
                title: "Export Data",
                description: "Download your data in CSV or JSON format",
                iconColor: DesignSystem.Colors.success,
                action: {}
            )
            
            ActionCardView(
                icon: "gear",
                title: "Settings",
                description: "Configure app preferences and notifications",
                action: {}
            )
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif