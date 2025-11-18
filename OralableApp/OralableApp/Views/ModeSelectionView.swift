//
//  ModeSelectionView.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Initial mode selection on first launch
//

import SwiftUI

struct ModeSelectionView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var selectedMode: AppMode?
    @State private var showingInfoSheet = false
    @State private var infoMode: AppMode?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.xl) {
                    // Header
                    headerSection
                    
                    // Mode Options
                    VStack(spacing: designSystem.spacing.lg) {
                        // Viewer Mode
                        ModeCard(
                            mode: .viewer,
                            icon: "eye",
                            title: "Viewer Mode",
                            subtitle: "View real-time data",
                            features: [
                                "Connect to Oralable device",
                                "View real-time sensor data",
                                "Basic data visualization",
                                "Export session data"
                            ],
                            limitations: [
                                "No data storage",
                                "No historical tracking",
                                "Limited features"
                            ],
                            price: "Free",
                            isSelected: selectedMode == .viewer,
                            onSelect: {
                                selectedMode = .viewer
                            },
                            onInfo: {
                                infoMode = .viewer
                                showingInfoSheet = true
                            }
                        )
                        
                        // Subscription Mode
                        ModeCard(
                            mode: .subscription,
                            icon: "crown",
                            title: "Full Access",
                            subtitle: "Complete feature set",
                            features: [
                                "All Viewer Mode features",
                                "Unlimited data storage",
                                "Historical analysis",
                                "Advanced visualizations",
                                "Health insights",
                                "Cloud sync",
                                "Priority support"
                            ],
                            limitations: [],
                            price: "Sign in required",
                            isSelected: selectedMode == .subscription,
                            isRecommended: true,
                            onSelect: {
                                selectedMode = .subscription
                            },
                            onInfo: {
                                infoMode = .subscription
                                showingInfoSheet = true
                            }
                        )
                    }
                    
                    // Continue Button
                    if let mode = selectedMode {
                        continueButton(for: mode)
                    }
                    
                    // Footer
                    footerSection
                }
                .padding(designSystem.spacing.md)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingInfoSheet) {
            if let mode = infoMode {
                ModeInfoSheet(mode: mode)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            // App Icon
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 80))
                .foregroundColor(designSystem.colors.primaryBlack)
                .padding(.bottom, designSystem.spacing.sm)

            // Welcome Text
            Text("Welcome to Oralable")
                .font(designSystem.typography.largeTitle)
                .foregroundColor(designSystem.colors.primaryBlack)

            Text("Choose how you'd like to use the app")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Continue Button
    
    private func continueButton(for mode: AppMode) -> some View {
        Button(action: {
            appStateManager.setMode(mode)
        }) {
            HStack {
                Text("Continue with \(mode.displayName)")
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.primaryBlack)
            .foregroundColor(designSystem.colors.primaryWhite)
            .cornerRadius(designSystem.cornerRadius.md)
        }
        .padding(.top, designSystem.spacing.lg)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: designSystem.spacing.sm) {
            Text("You can change modes anytime in Settings")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: designSystem.spacing.md) {
                Link("Privacy Policy", destination: URL(string: "https://oralable.com/privacy")!)
                Text("•")
                Link("Terms of Service", destination: URL(string: "https://oralable.com/terms")!)
            }
            .font(designSystem.typography.caption)
            .foregroundColor(designSystem.colors.textTertiary)
        }
        .padding(.top, designSystem.spacing.xl)
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let mode: AppMode
    let icon: String
    let title: String
    let subtitle: String
    let features: [String]
    let limitations: [String]
    let price: String
    let isSelected: Bool
    var isRecommended: Bool = false
    let onSelect: () -> Void
    let onInfo: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(mode.color)
                    .frame(width: 40, height: 40)
                    .background(mode.color.opacity(0.1))
                    .cornerRadius(designSystem.cornerRadius.sm)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                Text("Features")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
                
                ForEach(features.prefix(3), id: \.self) { feature in
                    HStack(spacing: designSystem.spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(feature)
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                
                if features.count > 3 {
                    Text("+ \(features.count - 3) more")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            
            // Limitations
            if !limitations.isEmpty {
                VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                    Text("Limitations")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    
                    ForEach(limitations.prefix(2), id: \.self) { limitation in
                        HStack(spacing: designSystem.spacing.sm) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(limitation)
                                .font(designSystem.typography.caption)
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
            
            Divider()
            
            // Price and Select Button
            HStack {
                Text(price)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                Button(action: onSelect) {
                    Text(isSelected ? "Selected" : "Select")
                        .font(designSystem.typography.caption)
                        .padding(.horizontal, designSystem.spacing.md)
                        .padding(.vertical, designSystem.spacing.xs)
                        .background(
                            isSelected ? mode.color : designSystem.colors.backgroundTertiary
                        )
                        .foregroundColor(
                            isSelected ? .white : designSystem.colors.textPrimary
                        )
                        .cornerRadius(designSystem.cornerRadius.sm)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: designSystem.cornerRadius.md)
                .stroke(
                    isSelected ? mode.color : Color.clear,
                    lineWidth: 2
                )
        )
        .cornerRadius(designSystem.cornerRadius.md)
    }
}

// MARK: - Mode Info Sheet

struct ModeInfoSheet: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    
    let mode: AppMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: designSystem.spacing.lg) {
                    // Icon and Title
                    HStack {
                        Image(systemName: mode.icon)
                            .font(.largeTitle)
                            .foregroundColor(mode.color)
                        
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                                .font(designSystem.typography.title)
                                .foregroundColor(designSystem.colors.textPrimary)
                            
                            Text(mode.description)
                                .font(designSystem.typography.body)
                                .foregroundColor(designSystem.colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(mode.color.opacity(0.1))
                    .cornerRadius(designSystem.cornerRadius.md)
                    
                    // Detailed Information
                    VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                        Text("What's Included")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)
                        
                        Text(mode.detailedDescription)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    
                    // Use Cases
                    VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                        Text("Best For")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.textPrimary)
                        
                        ForEach(mode.useCases, id: \.self) { useCase in
                            HStack(alignment: .top, spacing: designSystem.spacing.sm) {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(mode.color)
                                Text(useCase)
                                    .font(designSystem.typography.body)
                                    .foregroundColor(designSystem.colors.textPrimary)
                            }
                        }
                    }
                    
                    // Requirements
                    if !mode.requirements.isEmpty {
                        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                            Text("Requirements")
                                .font(designSystem.typography.headline)
                                .foregroundColor(designSystem.colors.textPrimary)
                            
                            ForEach(mode.requirements, id: \.self) { requirement in
                                HStack(alignment: .top, spacing: designSystem.spacing.sm) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                    Text(requirement)
                                        .font(designSystem.typography.body)
                                        .foregroundColor(designSystem.colors.textPrimary)
                                }
                            }
                        }
                    }
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("\(mode.displayName) Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - App Mode Extension

extension AppMode {
    var displayName: String {
        switch self {
        case .viewer: return "Viewer Mode"
        case .subscription: return "Full Access"
        }
    }

    var icon: String {
        switch self {
        case .viewer: return "eye"
        case .subscription: return "crown"
        }
    }

    var color: Color {
        switch self {
        case .viewer: return .blue
        case .subscription: return .green
        }
    }

    var description: String {
        switch self {
        case .viewer:
            return "View real-time data from your Oralable device"
        case .subscription:
            return "Unlock all features with your account"
        }
    }

    var detailedDescription: String {
        switch self {
        case .viewer:
            return "Viewer Mode provides essential functionality for monitoring your Oralable device in real-time. Perfect for quick sessions and immediate data viewing without the need for an account."
        case .subscription:
            return "Full Access unlocks the complete Oralable experience. Track your health metrics over time, gain insights from historical data, and sync across all your devices. Requires Sign in with Apple for secure authentication."
        }
    }

    var useCases: [String] {
        switch self {
        case .viewer:
            return [
                "Quick monitoring sessions",
                "Real-time data viewing",
                "Basic health tracking",
                "Testing device connectivity"
            ]
        case .subscription:
            return [
                "Long-term health monitoring",
                "Tracking treatment progress",
                "Sharing data with healthcare providers",
                "Multiple device management"
            ]
        }
    }

    var requirements: [String] {
        switch self {
        case .viewer:
            return ["Oralable device required"]
        case .subscription:
            return ["Apple ID required", "Oralable device required"]
        }
    }
}

// MARK: - Preview

struct ModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionView()
            .environmentObject(DesignSystem.shared)
            .environmentObject(AppStateManager.shared)
    }
}
