//
//  ProfileButtonView.swift
//  OralableApp
//
//  Created: November 3, 2025
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
                if let userProfile = authManager.userProfile {
                    UserAvatarView(
                        initials: getInitials(from: userProfile.name),
                        size: 36,
                        showOnlineIndicator: true
                    )
                } else {
                    UserAvatarView(
                        initials: "?",
                        size: 36,
                        showOnlineIndicator: false
                    )
                }
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    if let userProfile = authManager.userProfile {
                        Text(userProfile.name)
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(userProfile.email)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    } else {
                        Text("Profile")
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
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
    
    // Helper function to get initials from name
    private func getInitials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }
}

// MARK: - Preview

#if DEBUG

struct ProfileButtonView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // With user profile
            ProfileButtonView(
                authManager: {
                    let manager = AuthenticationManager.shared
                    // Mock profile for preview
                    return manager
                }(),
                action: {}
            )
            
            // Without user profile
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