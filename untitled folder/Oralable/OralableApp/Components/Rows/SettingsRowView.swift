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
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let subtitle: String?
    let iconColor: Color?
    let showChevron: Bool
    let action: () -> Void

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        iconColor: Color? = nil,
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
            HStack(spacing: designSystem.spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor ?? designSystem.colors.textPrimary)
                    .frame(width: 28)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(designSystem.typography.bodyMedium)
                        .foregroundColor(designSystem.colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            .padding(.vertical, designSystem.spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG

struct SettingsRowView_Previews: PreviewProvider {
    static var previews: some View {
        let ds = DesignSystem()
        return VStack(spacing: ds.spacing.xs) {
            SettingsRowView(
                icon: "person.fill",
                title: "Account",
                subtitle: "Manage your profile",
                action: {}
            )

            SettingsRowView(
                icon: "bell.fill",
                title: "Notifications",
                iconColor: .orange,
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
                iconColor: .blue,
                showChevron: false,
                action: {}
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .environmentObject(ds)
    }
}

#endif