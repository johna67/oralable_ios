//
//  ProfileButtonView.swift
//  OralableApp
//
//  Created by John A Cogan on 04/11/2025.
//


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
                UserAvatarView(
                    initials: authManager.userInitials,
                    size: 36,
                    showOnlineIndicator: authManager.isAuthenticated
                )
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(authManager.displayName)
                        .font(DesignSystem.Typography.labelLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if let email = authManager.userEmail {
                        Text(email)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
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
            // Using shared manager for preview
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
