//
//  InfoRowView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  InfoRowView.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Information row component
//

import SwiftUI

/// Information Row Component
struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    init(
        icon: String,
        title: String,
        value: String,
        iconColor: Color = DesignSystem.Colors.textPrimary
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizing.Icon.md))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            // Title
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG

struct InfoRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            InfoRowView(
                icon: "person.fill",
                title: "Name",
                value: "John Doe"
            )
            
            InfoRowView(
                icon: "envelope.fill",
                title: "Email",
                value: "john@example.com",
                iconColor: DesignSystem.Colors.info
            )
            
            InfoRowView(
                icon: "calendar",
                title: "Member Since",
                value: "Jan 2025"
            )
            
            InfoRowView(
                icon: "heart.fill",
                title: "Heart Rate",
                value: "72 bpm",
                iconColor: DesignSystem.Colors.error
            )
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif