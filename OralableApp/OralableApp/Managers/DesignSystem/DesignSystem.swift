//
//  DesignSystem.swift
//  OralableApp
//
//  Created by John A Cogan on 03/11/2025.
//


//
//  DesignSystem.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Complete design system with built-in validation and testing
//

import SwiftUI

// MARK: - Design System

enum DesignSystem {
    
    // MARK: - Colors
    
    enum Colors {
        
        // MARK: Primary Colors
        
        static let primaryBlack = Color(red: 0/255, green: 0/255, blue: 0/255)
        static let primaryWhite = Color(red: 255/255, green: 255/255, blue: 255/255)
        
        // MARK: Grayscale Palette
        
        static let gray900 = Color(red: 28/255, green: 28/255, blue: 30/255)
        static let gray800 = Color(red: 44/255, green: 44/255, blue: 46/255)
        static let gray700 = Color(red: 58/255, green: 58/255, blue: 60/255)
        static let gray600 = Color(red: 72/255, green: 72/255, blue: 74/255)
        static let gray500 = Color(red: 99/255, green: 99/255, blue: 102/255)
        static let gray400 = Color(red: 142/255, green: 142/255, blue: 147/255)
        static let gray300 = Color(red: 174/255, green: 174/255, blue: 178/255)
        static let gray200 = Color(red: 209/255, green: 209/255, blue: 214/255)
        static let gray100 = Color(red: 229/255, green: 229/255, blue: 234/255)
        static let gray50 = Color(red: 242/255, green: 242/255, blue: 247/255)
        
        // MARK: Semantic Colors
        
        static let textPrimary = primaryBlack
        static let textSecondary = gray900
        static let textTertiary = gray700
        static let textDisabled = gray400
        
        static let backgroundPrimary = primaryWhite
        static let backgroundSecondary = gray50
        static let backgroundTertiary = gray100
        
        static let border = gray200
        static let divider = gray100
        
        // MARK: State Colors
        
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // MARK: Interactive Colors
        
        static let active = primaryBlack
        static let inactive = gray400
        static let hover = gray100
        static let pressed = gray200
    }
    
    // MARK: - Typography

    // MARK: - Typography

    enum Typography {
        
        // MARK: - Font Family Helper
        
        /// Custom font with system fallback
        private static func customFont(size: CGFloat, weight: Font.Weight) -> Font {
            // Try to load Open Sans, fall back to system font
            let fontName: String
            switch weight {
            case .bold:
                fontName = "OpenSans-Bold"
            case .semibold:
                fontName = "OpenSans-SemiBold"
            case .medium:
                fontName = "OpenSans-Medium"
            default:
                fontName = "OpenSans-Regular"
            }
            
            // Check if custom font is available
            if UIFont(name: fontName, size: size) != nil {
                return Font.custom(fontName, size: size)
            } else {
                // Fallback to system font
                return Font.system(size: size, weight: weight, design: .default)
            }
        }
        
        // MARK: Display Styles
        
        static let displayLarge = customFont(size: 32, weight: .bold)
        static let displayMedium = customFont(size: 28, weight: .bold)
        static let displaySmall = customFont(size: 24, weight: .bold)
        
        // MARK: Heading Styles
        
        static let h1 = customFont(size: 22, weight: .semibold)
        static let h2 = customFont(size: 20, weight: .semibold)
        static let h3 = customFont(size: 18, weight: .semibold)
        static let h4 = customFont(size: 16, weight: .semibold)
        
        // MARK: Body Styles
        
        static let bodyLarge = customFont(size: 17, weight: .regular)
        static let bodyMedium = customFont(size: 15, weight: .regular)
        static let bodySmall = customFont(size: 13, weight: .regular)
        
        // MARK: Label Styles
        
        static let labelLarge = customFont(size: 15, weight: .medium)
        static let labelMedium = customFont(size: 13, weight: .medium)
        static let labelSmall = customFont(size: 11, weight: .medium)
        
        // MARK: Caption Styles
        
        static let caption = customFont(size: 12, weight: .regular)
        static let captionSmall = customFont(size: 10, weight: .regular)
        
        // MARK: Button Styles
        
        static let buttonLarge = customFont(size: 17, weight: .semibold)
        static let buttonMedium = customFont(size: 15, weight: .semibold)
        static let buttonSmall = customFont(size: 13, weight: .semibold)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let huge: CGFloat = 48
        static let ultra: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let round: CGFloat = 1000
    }
    
    // MARK: - Sizing
    
    enum Sizing {
        enum Icon {
            static let xs: CGFloat = 12
            static let sm: CGFloat = 16
            static let md: CGFloat = 20
            static let lg: CGFloat = 24
            static let xl: CGFloat = 32
            static let xxl: CGFloat = 40
        }
        
        enum Button {
            static let sm: CGFloat = 32
            static let md: CGFloat = 44
            static let lg: CGFloat = 52
        }
        
        enum Avatar {
            static let xs: CGFloat = 24
            static let sm: CGFloat = 32
            static let md: CGFloat = 40
            static let lg: CGFloat = 48
            static let xl: CGFloat = 64
        }
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let sm = ShadowStyle(
            color: Colors.primaryBlack.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let md = ShadowStyle(
            color: Colors.primaryBlack.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let lg = ShadowStyle(
            color: Colors.primaryBlack.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let xl = ShadowStyle(
            color: Colors.primaryBlack.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let fast: Double = 0.1
        static let normal: Double = 0.2
        static let slow: Double = 0.3
        static let verySlow: Double = 0.5
    }
    
    // MARK: - Layout (iPad-specific)
    
    enum Layout {
        /// Detects if the current device is an iPad
        static var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        /// Returns content width optimized for readability on iPad
        static func contentWidth(for geometry: GeometryProxy) -> CGFloat {
            if isIPad {
                // On iPad, cap content width for better readability
                // but use full width if it's narrower than the cap
                return min(geometry.size.width * 0.9, 800)
            }
            return geometry.size.width
        }
        
        /// Number of columns for grid layouts based on device and size class
        static func gridColumns(for sizeClass: UserInterfaceSizeClass?) -> Int {
            if isIPad {
                switch sizeClass {
                case .regular:
                    return 3 // Full-width iPad or landscape
                case .compact:
                    return 2 // Split view or portrait narrow iPad
                default:
                    return 2
                }
            }
            return 1 // iPhone always uses single column
        }
        
        /// Padding for edges based on device
        static var edgePadding: CGFloat {
            isIPad ? Spacing.xl : Spacing.lg
        }
        
        /// Card spacing in grids
        static var cardSpacing: CGFloat {
            isIPad ? Spacing.lg : Spacing.md
        }
        
        /// Maximum card width on iPad
        static let maxCardWidth: CGFloat = 400
        
        /// Optimal sidebar width on iPad
        static let sidebarWidth: CGFloat = 320
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func designShadow(_ shadow: ShadowStyle) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Apply responsive card styling optimized for iPad
    func responsiveCard() -> some View {
        self
            .frame(maxWidth: DesignSystem.Layout.isIPad ? DesignSystem.Layout.maxCardWidth : .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.backgroundPrimary)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .designShadow(DesignSystem.Shadow.md)
    }
    
    /// Center content with optimal reading width on iPad
    func centeredContent(geometry: GeometryProxy) -> some View {
        self
            .frame(maxWidth: DesignSystem.Layout.contentWidth(for: geometry))
            .frame(maxWidth: .infinity)
    }
    
    /// Apply consistent padding based on device
    func devicePadding() -> some View {
        self.padding(DesignSystem.Layout.edgePadding)
    }
}

// MARK: - Design System Preview & Validation

#if DEBUG

struct DesignSystemPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Colors
            ColorsPreview()
                .tabItem {
                    Label("Colors", systemImage: "paintpalette")
                }
                .tag(0)
            
            // Tab 2: Typography
            TypographyPreview()
                .tabItem {
                    Label("Typography", systemImage: "textformat")
                }
                .tag(1)
            
            // Tab 3: Components
            ComponentsPreview()
                .tabItem {
                    Label("Components", systemImage: "square.stack.3d.up")
                }
                .tag(2)
            
            // Tab 4: Spacing & Shadows
            SpacingShadowsPreview()
                .tabItem {
                    Label("Layout", systemImage: "square.grid.2x2")
                }
                .tag(3)
        }
    }
}

// MARK: - Colors Preview

struct ColorsPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Color System")
                    .font(DesignSystem.Typography.displayMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Primary Colors
                ColorGroup(title: "Primary Colors") {
                    ColorSwatch(name: "Black", color: DesignSystem.Colors.primaryBlack, hex: "#000000")
                    ColorSwatch(name: "White", color: DesignSystem.Colors.primaryWhite, hex: "#FFFFFF", showBorder: true)
                }
                
                // Grayscale
                ColorGroup(title: "Grayscale") {
                    ColorSwatch(name: "Gray 50", color: DesignSystem.Colors.gray50, hex: "#F2F2F7")
                    ColorSwatch(name: "Gray 100", color: DesignSystem.Colors.gray100, hex: "#E5E5EA")
                    ColorSwatch(name: "Gray 200", color: DesignSystem.Colors.gray200, hex: "#D1D1D6")
                    ColorSwatch(name: "Gray 300", color: DesignSystem.Colors.gray300, hex: "#AEAEB2")
                    ColorSwatch(name: "Gray 400", color: DesignSystem.Colors.gray400, hex: "#8E8E93")
                    ColorSwatch(name: "Gray 500", color: DesignSystem.Colors.gray500, hex: "#636366")
                    ColorSwatch(name: "Gray 600", color: DesignSystem.Colors.gray600, hex: "#48484A")
                    ColorSwatch(name: "Gray 700", color: DesignSystem.Colors.gray700, hex: "#3A3A3C")
                    ColorSwatch(name: "Gray 800", color: DesignSystem.Colors.gray800, hex: "#2C2C2E")
                    ColorSwatch(name: "Gray 900", color: DesignSystem.Colors.gray900, hex: "#1C1C1E")
                }
                
                // Semantic Colors
                ColorGroup(title: "Text Colors") {
                    ColorSwatch(name: "Primary", color: DesignSystem.Colors.textPrimary, hex: "#000000")
                    ColorSwatch(name: "Secondary", color: DesignSystem.Colors.textSecondary, hex: "#1C1C1E")
                    ColorSwatch(name: "Tertiary", color: DesignSystem.Colors.textTertiary, hex: "#3A3A3C")
                    ColorSwatch(name: "Disabled", color: DesignSystem.Colors.textDisabled, hex: "#8E8E93")
                }
                
                ColorGroup(title: "Backgrounds") {
                    ColorSwatch(name: "Primary", color: DesignSystem.Colors.backgroundPrimary, hex: "#FFFFFF", showBorder: true)
                    ColorSwatch(name: "Secondary", color: DesignSystem.Colors.backgroundSecondary, hex: "#F2F2F7")
                    ColorSwatch(name: "Tertiary", color: DesignSystem.Colors.backgroundTertiary, hex: "#E5E5EA")
                }
                
                // State Colors
                ColorGroup(title: "State Colors") {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        StateColorBox(name: "Success", color: DesignSystem.Colors.success)
                        StateColorBox(name: "Warning", color: DesignSystem.Colors.warning)
                        StateColorBox(name: "Error", color: DesignSystem.Colors.error)
                        StateColorBox(name: "Info", color: DesignSystem.Colors.info)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

struct ColorGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.h3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            content
        }
    }
}

struct ColorSwatch: View {
    let name: String
    let color: Color
    let hex: String
    var showBorder: Bool = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(DesignSystem.Colors.border, lineWidth: showBorder ? 1 : 0)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(hex)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct StateColorBox: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color)
                .frame(height: 60)
            
            Text(name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Typography Preview

struct TypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Typography System")
                    .font(DesignSystem.Typography.displayMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Display Styles
                TypeGroup(title: "Display") {
                    TypeSample(text: "Display Large", font: DesignSystem.Typography.displayLarge, size: "32pt")
                    TypeSample(text: "Display Medium", font: DesignSystem.Typography.displayMedium, size: "28pt")
                    TypeSample(text: "Display Small", font: DesignSystem.Typography.displaySmall, size: "24pt")
                }
                
                // Headings
                TypeGroup(title: "Headings") {
                    TypeSample(text: "Heading 1", font: DesignSystem.Typography.h1, size: "22pt")
                    TypeSample(text: "Heading 2", font: DesignSystem.Typography.h2, size: "20pt")
                    TypeSample(text: "Heading 3", font: DesignSystem.Typography.h3, size: "18pt")
                    TypeSample(text: "Heading 4", font: DesignSystem.Typography.h4, size: "16pt")
                }
                
                // Body
                TypeGroup(title: "Body") {
                    TypeSample(text: "Body Large - The quick brown fox", font: DesignSystem.Typography.bodyLarge, size: "17pt")
                    TypeSample(text: "Body Medium - The quick brown fox", font: DesignSystem.Typography.bodyMedium, size: "15pt")
                    TypeSample(text: "Body Small - The quick brown fox", font: DesignSystem.Typography.bodySmall, size: "13pt")
                }
                
                // Labels
                TypeGroup(title: "Labels") {
                    TypeSample(text: "Label Large", font: DesignSystem.Typography.labelLarge, size: "15pt")
                    TypeSample(text: "Label Medium", font: DesignSystem.Typography.labelMedium, size: "13pt")
                    TypeSample(text: "Label Small", font: DesignSystem.Typography.labelSmall, size: "11pt")
                }
                
                // Captions
                TypeGroup(title: "Captions") {
                    TypeSample(text: "Caption", font: DesignSystem.Typography.caption, size: "12pt")
                    TypeSample(text: "Caption Small", font: DesignSystem.Typography.captionSmall, size: "10pt")
                }
                
                // Buttons
                TypeGroup(title: "Buttons") {
                    TypeSample(text: "Button Large", font: DesignSystem.Typography.buttonLarge, size: "17pt")
                    TypeSample(text: "Button Medium", font: DesignSystem.Typography.buttonMedium, size: "15pt")
                    TypeSample(text: "Button Small", font: DesignSystem.Typography.buttonSmall, size: "13pt")
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

struct TypeGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.h3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            content
        }
    }
}

struct TypeSample: View {
    let text: String
    let font: Font
    let size: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(text)
                .font(font)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(size)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Components Preview

struct ComponentsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Components")
                    .font(DesignSystem.Typography.displayMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xl)
                
                // Card Example
                SampleCard(
                    title: "Sample Card",
                    description: "This card demonstrates design system usage with proper spacing, typography, and shadows.",
                    iconName: "star.fill",
                    iconColor: DesignSystem.Colors.info
                )
                
                // Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Buttons")
                        .font(DesignSystem.Typography.h3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    PrimaryButton(title: "Primary Button")
                    SecondaryButton(title: "Secondary Button")
                }
                
                // List Item
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("List Item")
                        .font(DesignSystem.Typography.h3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    ListItemExample()
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

struct SampleCard: View {
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: DesignSystem.Sizing.Icon.lg))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(DesignSystem.Typography.h3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            
            Text(description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineSpacing(4)
            
            HStack {
                Text("Updated today")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Spacer()
                
                Button("View") {}
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.md)
    }
}

struct PrimaryButton: View {
    let title: String
    
    var body: some View {
        Button(action: {}) {
            Text(title)
                .font(DesignSystem.Typography.buttonMedium)
                .foregroundColor(DesignSystem.Colors.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.textPrimary)
                .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    
    var body: some View {
        Button(action: {}) {
            Text(title)
                .font(DesignSystem.Typography.buttonMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.backgroundSecondary)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        }
    }
}

struct ListItemExample: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "heart.fill")
                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                .foregroundColor(DesignSystem.Colors.error)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("List Item Title")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Subtitle text")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: DesignSystem.Sizing.Icon.sm))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Spacing & Shadows Preview

struct SpacingShadowsPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Layout System")
                    .font(DesignSystem.Typography.displayMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Spacing
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Spacing (8pt Grid)")
                        .font(DesignSystem.Typography.h3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        SpacingBox(size: DesignSystem.Spacing.xxs, label: "XXS - 4pt")
                        SpacingBox(size: DesignSystem.Spacing.xs, label: "XS - 8pt")
                        SpacingBox(size: DesignSystem.Spacing.sm, label: "SM - 12pt")
                        SpacingBox(size: DesignSystem.Spacing.md, label: "MD - 16pt")
                        SpacingBox(size: DesignSystem.Spacing.lg, label: "LG - 20pt")
                        SpacingBox(size: DesignSystem.Spacing.xl, label: "XL - 24pt")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                // Shadows
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Shadows")
                        .font(DesignSystem.Typography.h3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        ShadowExample(shadow: DesignSystem.Shadow.sm, label: "Small")
                        ShadowExample(shadow: DesignSystem.Shadow.md, label: "Medium")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        ShadowExample(shadow: DesignSystem.Shadow.lg, label: "Large")
                        ShadowExample(shadow: DesignSystem.Shadow.xl, label: "XL")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                // Corner Radius
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Corner Radius")
                        .font(DesignSystem.Typography.h3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        CornerRadiusExample(radius: DesignSystem.CornerRadius.sm, label: "SM - 4pt")
                        CornerRadiusExample(radius: DesignSystem.CornerRadius.md, label: "MD - 8pt")
                        CornerRadiusExample(radius: DesignSystem.CornerRadius.lg, label: "LG - 12pt")
                        CornerRadiusExample(radius: DesignSystem.CornerRadius.xl, label: "XL - 16pt")
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

struct SpacingBox: View {
    let size: CGFloat
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(DesignSystem.Colors.textPrimary)
                .frame(width: size, height: size)
            
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

struct ShadowExample: View {
    let shadow: ShadowStyle
    let label: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.backgroundPrimary)
                .frame(width: 100, height: 100)
                .designShadow(shadow)
            
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

struct CornerRadiusExample: View {
    let radius: CGFloat
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: radius)
                .fill(DesignSystem.Colors.backgroundSecondary)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Main Preview

struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemPreview()
    }
}

#endif
