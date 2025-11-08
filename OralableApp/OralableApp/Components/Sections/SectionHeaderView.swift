//
//  SectionHeaderView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//

import SwiftUI

/// Section Header Component
struct SectionHeaderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG

struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            SectionHeaderView(title: "Account Information", icon: "person.circle")
            SectionHeaderView(title: "Settings", icon: "gearshape")
            SectionHeaderView(title: "About", icon: "info.circle")
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif