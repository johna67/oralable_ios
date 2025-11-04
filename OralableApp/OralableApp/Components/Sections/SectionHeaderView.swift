//
//  SectionHeaderView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


//
//  SectionHeaderView.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Section header component
//

import SwiftUI

/// Section Header Component
struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(DesignSystem.Typography.h4)
            .foregroundColor(DesignSystem.Colors.textPrimary)
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
            SectionHeaderView(title: "Account Information")
            SectionHeaderView(title: "Settings")
            SectionHeaderView(title: "About")
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif