//
//  UserAvatarView.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Reusable user avatar component
//

import SwiftUI

/// User Avatar Component
struct UserAvatarView: View {
    let initials: String
    let size: CGFloat
    let showOnlineIndicator: Bool
    
    init(initials: String, size: CGFloat = 36, showOnlineIndicator: Bool = false) {
        self.initials = initials
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
    }
    
    var body: some View {
        ZStack {
            // Avatar background
            Circle()
                .fill(DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
            
            // User initials
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.backgroundPrimary)
            
            // Online indicator (optional)
            if showOnlineIndicator {
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Colors.backgroundPrimary, lineWidth: 2)
                    )
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG

struct UserAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            UserAvatarView(initials: "JD", size: 36, showOnlineIndicator: false)
            UserAvatarView(initials: "SM", size: 48, showOnlineIndicator: true)
            UserAvatarView(initials: "AB", size: 64, showOnlineIndicator: false)
            UserAvatarView(initials: "CD", size: 80, showOnlineIndicator: true)
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif
