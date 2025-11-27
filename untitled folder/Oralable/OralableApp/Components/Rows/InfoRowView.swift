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
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let value: String
    let iconColor: Color?

    init(
        icon: String,
        title: String,
        value: String,
        iconColor: Color? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack(spacing: designSystem.spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizing.Icon.md))
                .foregroundColor(iconColor ?? designSystem.colors.textPrimary)
                .frame(width: 28)
            
            // Title
            Text(title)
                .font(designSystem.typography.bodyMedium)
                .foregroundColor(designSystem.colors.textPrimary)
            
            Spacer()
            
            // Value
            Text(value)
                .font(designSystem.typography.labelMedium)
                .foregroundColor(designSystem.colors.textSecondary)
        }
        .padding(.vertical, designSystem.spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG

struct InfoRowView_Previews: PreviewProvider {
    static var previews: some View {
        let ds = DesignSystem()
        return VStack(spacing: ds.spacing.sm) {
            InfoRowView(
                icon: "person.fill",
                title: "Name",
                value: "John Doe"
            )

            InfoRowView(
                icon: "envelope.fill",
                title: "Email",
                value: "john@example.com",
                iconColor: .blue
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
                iconColor: .red
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .environmentObject(ds)
    }
}

#endif