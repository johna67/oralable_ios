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
    @EnvironmentObject var designSystem: DesignSystem
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
            HStack(spacing: designSystem.spacing.sm) {
                // User avatar
                UserAvatarView(
                    initials: authManager.userInitials,
                    size: 36,
                    showOnlineIndicator: authManager.hasCompleteProfile
                )
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.displayName)
                        .font(designSystem.typography.labelLarge)
                        .foregroundColor(designSystem.colors.textPrimary)
                        .lineLimit(1)
                    
                    if let email = authManager.userEmail {
                        Text(email)
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text("Tap to view profile")
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Sizing.Icon.sm, weight: .semibold))
                    .foregroundColor(designSystem.colors.textTertiary)
            }
            .padding(designSystem.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: designSystem.cornerRadius.lg)
                    .fill(designSystem.colors.backgroundSecondary)
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
        let designSystem = DesignSystem()
        let authManager = AuthenticationManager()
        VStack(spacing: designSystem.spacing.lg) {
            ProfileButtonView(
                authManager: authManager,
                action: {}
            )
        }
        .padding()
        .background(designSystem.colors.backgroundPrimary)
        .environmentObject(designSystem)
    }
}

#endif
