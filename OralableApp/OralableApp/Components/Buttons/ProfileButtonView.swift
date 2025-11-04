//
//  ProfileButtonView.swift
//  OralableApp
//
//  Created: November 4, 2025
//  Enhanced profile button component
//

import SwiftUI

/// Enhanced Profile Button
struct ProfileButtonView: View {
    @ObservedObject var authManager: AuthenticationManager
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Add haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // User avatar
                UserAvatarView(
                    initials: authManager.userInitials,
                    size: 36,
                    showOnlineIndicator: authManager.hasCompleteProfile
                )
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.displayName)
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if let email = authManager.userEmail {
                        Text(email)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text("Tap to view profile")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Sizing.Icon.sm, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview

#if DEBUG

struct ProfileButtonView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProfileButtonView(
                authManager: AuthenticationManager.shared,
                action: {}
            )
        }
        .padding()
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

#endif
