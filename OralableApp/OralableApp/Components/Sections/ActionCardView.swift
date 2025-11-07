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
    
    @ObservedObject private var designSystem = DesignSystem.shared
    
    init(
        icon: String,
        title: String,
        description: String,
        iconColor: Color? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor ?? DesignSystem.shared.colors.textPrimary
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                
                // Title
                Text(title)
                    .font(designSystem.typography.h4)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                // Description
                Text(description)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(designSystem.spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: designSystem.cornerRadius.large)
                    .fill(designSystem.colors.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG

struct ActionCardView_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem.shared
        
        VStack(spacing: designSystem.spacing.md) {
            ActionCardView(
                icon: "chart.line.uptrend.xyaxis",
                title: "View Data",
                description: "Access your historical health data and trends",
                iconColor: .blue,
                action: {}
            )
            
            ActionCardView(
                icon: "arrow.down.doc.fill",
                title: "Export Data",
                description: "Download your data in CSV or JSON format",
                iconColor: .green,
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
        .background(designSystem.colors.backgroundPrimary)
    }
}

#endif