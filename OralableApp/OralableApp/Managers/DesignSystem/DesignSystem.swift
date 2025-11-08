//
//  DesignSystem.swift
//  OralableApp
//
//  TRULY FINAL version - adds bodyMedium
//

import SwiftUI

// MARK: - Main Design System

class DesignSystem: ObservableObject {
    // Singleton instance
    static let shared = DesignSystem()
    
    // Published properties for SwiftUI updates (lowercase - correct)
    @Published var colors: ColorSystem
    @Published var typography: TypographySystem
    @Published var spacing: SpacingSystem
    @Published var cornerRadius: CornerRadiusSystem
    
    // Uppercase aliases for backward compatibility (fixes your errors)
    var Colors: ColorSystem { colors }
    var Typography: TypographySystem { typography }
    var Spacing: SpacingSystem { spacing }
    var CornerRadius: CornerRadiusSystem { cornerRadius }
    var Sizing: SpacingSystem { spacing }  // Alias Sizing to spacing
    
    private init() {
        self.colors = ColorSystem()
        self.typography = TypographySystem()
        self.spacing = SpacingSystem()
        self.cornerRadius = CornerRadiusSystem()
    }
}

// MARK: - Static Accessors
extension DesignSystem {
    // Static accessors so views can use DesignSystem.Spacing directly without .shared
    static var Spacing: SpacingSystem { shared.spacing }
    static var Colors: ColorSystem { shared.colors }
    static var Typography: TypographySystem { shared.typography }
    static var CornerRadius: CornerRadiusSystem { shared.cornerRadius }
    static var Sizing: SizingSystem { SizingSystem() }  // Returns new instance
    
    // Lowercase versions for consistency
    static var spacing: SpacingSystem { shared.spacing }
    static var colors: ColorSystem { shared.colors }
    static var typography: TypographySystem { shared.typography }
    static var cornerRadius: CornerRadiusSystem { shared.cornerRadius }
    static var sizing: SizingSystem { SizingSystem() }
}

// MARK: - Color System

struct ColorSystem {
    // Text Colors
    let textPrimary = Color("TextPrimary", bundle: nil)
    let textSecondary = Color("TextSecondary", bundle: nil)
    let textTertiary = Color("TextTertiary", bundle: nil)
    let textDisabled = Color("TextDisabled", bundle: nil)
    
    // Background Colors
    let backgroundPrimary = Color("BackgroundPrimary", bundle: nil)
    let backgroundSecondary = Color("BackgroundSecondary", bundle: nil)
    let backgroundTertiary = Color("BackgroundTertiary", bundle: nil)
    
    // Primary Colors
    let primaryBlack = Color("PrimaryBlack", bundle: nil)
    let primaryWhite = Color("PrimaryWhite", bundle: nil)
    
    // Grayscale
    let gray50 = Color("Gray50", bundle: nil)
    let gray100 = Color("Gray100", bundle: nil)
    let gray200 = Color("Gray200", bundle: nil)
    let gray300 = Color("Gray300", bundle: nil)
    let gray400 = Color("Gray400", bundle: nil)
    let gray500 = Color("Gray500", bundle: nil)
    let gray600 = Color("Gray600", bundle: nil)
    let gray700 = Color("Gray700", bundle: nil)
    let gray800 = Color("Gray800", bundle: nil)
    let gray900 = Color("Gray900", bundle: nil)
    
    // Interactive States
    let hover = Color("Hover", bundle: nil)
    let pressed = Color("Pressed", bundle: nil)
    let border = Color("Border", bundle: nil)
    let divider = Color("Divider", bundle: nil)
    
    // Semantic Colors
    let info = Color.blue
    let warning = Color.orange
    let error = Color.red
    let success = Color.green
    
    // Shadow color
    let shadow = Color.black.opacity(0.1)
}

// MARK: - Typography System

struct TypographySystem {
    // Open Sans font with fallbacks
    let fontFamily = "Open Sans"
    
    // Headings
    var h1: Font {
        Font.custom(fontFamily, size: 34).weight(.bold)
    }
    
    var h2: Font {
        Font.custom(fontFamily, size: 28).weight(.semibold)
    }
    
    var h3: Font {
        Font.custom(fontFamily, size: 22).weight(.semibold)
    }
    
    var h4: Font {
        Font.custom(fontFamily, size: 18).weight(.medium)
    }
    
    // Large title and headline
    var largeTitle: Font {
        Font.custom(fontFamily, size: 34).weight(.bold)
    }
    
    var headline: Font {
        Font.custom(fontFamily, size: 17).weight(.semibold)
    }
    
    // Body variants
    var body: Font {
        Font.custom(fontFamily, size: 16).weight(.regular)
    }
    
    var bodyBold: Font {
        Font.custom(fontFamily, size: 16).weight(.bold)
    }
    
    var bodyMedium: Font {  // ADDED THIS - FIXES THE LAST 2 ERRORS!
        Font.custom(fontFamily, size: 16).weight(.medium)
    }
    
    var bodyLarge: Font {
        Font.custom(fontFamily, size: 18).weight(.regular)
    }
    
    var bodySmall: Font {
        Font.custom(fontFamily, size: 14).weight(.regular)
    }
    
    // Label variants
    var labelLarge: Font {
        Font.custom(fontFamily, size: 16).weight(.medium)
    }
    
    var labelMedium: Font {
        Font.custom(fontFamily, size: 14).weight(.medium)
    }
    
    var labelSmall: Font {
        Font.custom(fontFamily, size: 12).weight(.medium)
    }
    
    // Small text
    var caption: Font {
        Font.custom(fontFamily, size: 14).weight(.regular)
    }
    
    var caption2: Font {
        Font.custom(fontFamily, size: 11).weight(.regular)
    }
    
    var captionBold: Font {
        Font.custom(fontFamily, size: 14).weight(.semibold)
    }
    
    var footnote: Font {
        Font.custom(fontFamily, size: 12).weight(.regular)
    }
    
    // Interactive
    var button: Font {
        Font.custom(fontFamily, size: 16).weight(.semibold)
    }
    
    var link: Font {
        Font.custom(fontFamily, size: 16).weight(.medium)
    }
}

// MARK: - Spacing System

struct SpacingSystem {
    // 4pt grid system
    let xxs: CGFloat = 2   // extra extra small
    let xs: CGFloat = 4    // extra small
    let sm: CGFloat = 8    // small
    let md: CGFloat = 16   // medium
    let lg: CGFloat = 24   // large
    let xl: CGFloat = 32   // extra large
    let xxl: CGFloat = 48  // extra extra large
    
    // Specific use cases
    let buttonPadding: CGFloat = 12
    let cardPadding: CGFloat = 16
    let screenPadding: CGFloat = 20
    let icon: CGFloat = 20  // Added for icon spacing
    let Icon: CGFloat = 20  // Capitalized version
}

// MARK: - Sizing System (Icon is instance property)

struct SizingSystem {
    // Icon as instance property with nested struct
    let Icon = IconSizes()
    
    // Icon sizes struct
    struct IconSizes {
        let xs: CGFloat = 16
        let sm: CGFloat = 20
        let md: CGFloat = 24
        let lg: CGFloat = 32
        let xl: CGFloat = 40
    }
    
    // Direct properties (for backward compatibility)
    let iconXS: CGFloat = 16
    let iconSM: CGFloat = 20
    let iconMD: CGFloat = 24
    let iconLG: CGFloat = 32
    let iconXL: CGFloat = 40
    
    // Card size
    let card: CGFloat = 12
}

// MARK: - Corner Radius System

struct CornerRadiusSystem {
    let small: CGFloat = 4
    let medium: CGFloat = 8
    let large: CGFloat = 12
    let xl: CGFloat = 16
    let full: CGFloat = 9999  // For circular shapes
    
    // Aliases
    var md: CGFloat { medium }
    var sm: CGFloat { small }
    var lg: CGFloat { large }
    
    // Specific use cases
    let button: CGFloat = 8
    let card: CGFloat = 12
    let modal: CGFloat = 16
}

// MARK: - CGFloat Extensions

extension CGFloat {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - View Extensions

extension View {
    // Card Styling
    func cardStyle() -> some View {
        self
            .background(DesignSystem.colors.backgroundPrimary)
            .cornerRadius(DesignSystem.sizing.card)
            .shadow(color: DesignSystem.colors.shadow, radius: 4, x: 0, y: 2)
    }
    
    // Button Styling
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .font(DesignSystem.typography.headline)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.colors.primaryBlack)
            .cornerRadius(DesignSystem.cornerRadius.button)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(DesignSystem.colors.primaryBlack)
            .font(DesignSystem.typography.headline)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.colors.backgroundSecondary)
            .cornerRadius(DesignSystem.cornerRadius.button)
    }
}
