//
//  SettingsRowView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  SettingsRowView.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Settings row component with navigation
//

import SwiftUI

/// Settings Row Component
struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color
    let showChevron: Bool
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color = DesignSystem.Colors.textPrimary,
        showChevron: Bool = true,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconColor = iconColor
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizing.Icon.md))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.Sizing.Icon.sm))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG

struct SettingsRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            SettingsRowView(
                icon: "person.fill",
                title: "Account",
                subtitle: "Manage your profile",
                action: {}
            )
            
            SettingsRowView(
                icon: "bell.fill",
                title: "Notifications",
                iconColor: DesignSystem.Colors.warning,
                action: {}
            )
            
            SettingsRowView(
                icon: "lock.fill",
                title: "Privacy & Security",
                subtitle: "Control your data",
                action: {}
            )
            
            SettingsRowView(
                icon: "info.circle.fill",
                title: "About",
                iconColor: DesignSystem.Colors.info,
                showChevron: false,
                action: {}
            )
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif