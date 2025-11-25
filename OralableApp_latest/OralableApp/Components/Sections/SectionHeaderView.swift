//
//  SectionHeaderView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//

import SwiftUI

/// Section Header Component
struct SectionHeaderView: View {
    @EnvironmentObject var designSystem: DesignSystem
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: designSystem.spacing.xs) {
            Image(systemName: icon)
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textSecondary)

            Text(title)
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, designSystem.spacing.lg)
        .padding(.bottom, designSystem.spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG

struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        VStack(spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Account Information", icon: "person.circle")
            SectionHeaderView(title: "Settings", icon: "gearshape")
            SectionHeaderView(title: "About", icon: "info.circle")
        }
        .padding()
        .background(designSystem.colors.backgroundPrimary)
        .environmentObject(designSystem)
    }
}

#endif