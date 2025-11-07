//
//  DesignSystem_WithAliases.swift
//  OralableApp
//
//  Version with both lowercase (correct) and uppercase (compatibility) properties
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
}

// MARK: - Typography System

struct TypographySystem {
    // Open Sans font with fallbacks
    private let fontFamily = "Open Sans"
    
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
    
    // Add missing properties that AuthenticationView needs
    var largeTitle: Font {
        Font.custom(fontFamily, size: 34).weight(.bold)
    }
    
    var headline: Font {
        Font.custom(fontFamily, size: 17).weight(.semibold)
    }
    
    // Body
    var body: Font {
        Font.custom(fontFamily, size: 16).weight(.regular)
    }
    
    var bodyBold: Font {
        Font.custom(fontFamily, size: 16).weight(.bold)
    }
    
    // Small
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
    let xs: CGFloat = 4
    let sm: CGFloat = 8
    let md: CGFloat = 16
    let lg: CGFloat = 24
    let xl: CGFloat = 32
    let xxl: CGFloat = 48
    
    // Specific use cases
    let buttonPadding: CGFloat = 12
    let cardPadding: CGFloat = 16
    let screenPadding: CGFloat = 20
}

// MARK: - Corner Radius System

struct CornerRadiusSystem {
    let small: CGFloat = 4
    let medium: CGFloat = 8
    let large: CGFloat = 12
    let xl: CGFloat = 16
    let full: CGFloat = 9999  // For circular shapes
    
    // Add alias for 'md' that AuthenticationView uses
    var md: CGFloat { medium }
    
    // Specific use cases
    let button: CGFloat = 8
    let card: CGFloat = 12
    let modal: CGFloat = 16
}
