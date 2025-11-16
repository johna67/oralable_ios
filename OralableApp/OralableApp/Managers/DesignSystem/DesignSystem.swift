//
//  DesignSystem.swift
//  OralableApp
//
//  TRULY FINAL version - adds bodyMedium
//

import SwiftUI
import Combine

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
    static var Layout: LayoutSystem { LayoutSystem() }  // Added
    static var Shadow: ShadowSystem { ShadowSystem() }  // Added
    static var Animation: AnimationSystem { AnimationSystem() }  // Added
    
    // Lowercase versions for consistency
    static var spacing: SpacingSystem { shared.spacing }
    static var colors: ColorSystem { shared.colors }
    static var typography: TypographySystem { shared.typography }
    static var cornerRadius: CornerRadiusSystem { shared.cornerRadius }
    static var sizing: SizingSystem { SizingSystem() }
}

// MARK: - Color System

struct ColorSystem {
    // Primary Colors
    let primaryBlack = Color.black
    let primaryWhite = Color.white

    // Text Colors (using hex values)
    let textPrimary = Color.black
    let textSecondary = Color(hex: "666666")
    let textTertiary = Color(hex: "999999")
    let textDisabled = Color(hex: "CCCCCC")

    // Background Colors (using hex values)
    let backgroundPrimary = Color.white
    let backgroundSecondary = Color(hex: "F5F5F5")
    let backgroundTertiary = Color(hex: "EEEEEE")

    // Accent Colors
    let accentGreen = Color(hex: "34C759")
    let accentBlue = Color(hex: "007AFF")
    let accentOrange = Color(hex: "FF9500")
    let accentRed = Color(hex: "FF3B30")

    // Border Colors
    let borderLight = Color(hex: "E5E5E5")
    let borderMedium = Color(hex: "CCCCCC")
    let borderDark = Color(hex: "999999")

    // Grayscale (for backward compatibility)
    let gray50 = Color(hex: "FAFAFA")
    let gray100 = Color(hex: "F5F5F5")
    let gray200 = Color(hex: "EEEEEE")
    let gray300 = Color(hex: "E0E0E0")
    let gray400 = Color(hex: "BDBDBD")
    let gray500 = Color(hex: "9E9E9E")
    let gray600 = Color(hex: "757575")
    let gray700 = Color(hex: "616161")
    let gray800 = Color(hex: "424242")
    let gray900 = Color(hex: "212121")

    // Interactive States
    let hover = Color(hex: "F5F5F5")
    let pressed = Color(hex: "EEEEEE")
    let border = Color(hex: "E5E5E5")
    let divider = Color(hex: "E5E5E5")

    // Semantic Colors
    let info = Color(hex: "007AFF")
    let warning = Color(hex: "FF9500")
    let error = Color(hex: "FF3B30")
    let success = Color(hex: "34C759")

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
    
    var captionSmall: Font {  // Added
        Font.custom(fontFamily, size: 12).weight(.regular)
    }

    var callout: Font {
        Font.custom(fontFamily, size: 16).weight(.regular)
    }

    var footnote: Font {
        Font.custom(fontFamily, size: 12).weight(.regular)
    }

    var subheadline: Font {
        Font.custom(fontFamily, size: 15).weight(.regular)
    }
    
    // Display variants
    var displaySmall: Font {  // Added
        Font.custom(fontFamily, size: 24).weight(.bold)
    }
    
    // Title variants
    var title: Font {  // Added
        Font.custom(fontFamily, size: 20).weight(.semibold)
    }

    var title1: Font {
        Font.custom(fontFamily, size: 28).weight(.bold)
    }

    var title2: Font {
        Font.custom(fontFamily, size: 22).weight(.semibold)
    }

    var title3: Font {
        Font.custom(fontFamily, size: 20).weight(.semibold)
    }

    // Interactive
    var button: Font {
        Font.custom(fontFamily, size: 16).weight(.semibold)
    }

    var buttonLarge: Font {  // Added
        Font.custom(fontFamily, size: 18).weight(.semibold)
    }

    var buttonMedium: Font {  // Added
        Font.custom(fontFamily, size: 16).weight(.medium)
    }

    var buttonSmall: Font {  // Added
        Font.custom(fontFamily, size: 14).weight(.semibold)
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
    let xs: CGFloat = 2  // Added
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
    
    // Design Shadow modifier with ShadowLevel enum
    func designShadow(_ level: ShadowSystem.ShadowLevel = .medium) -> some View {
        let shadow = ShadowSystem().shadowFor(level)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // Design Shadow modifier with ShadowStyle directly
    func designShadow(_ style: ShadowSystem.ShadowStyle) -> some View {
        return self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Layout System

struct LayoutSystem {
    // Grid columns based on size class
    func gridColumns(for sizeClass: UserInterfaceSizeClass?) -> Int {
        sizeClass == .regular ? 2 : 1
    }
    
    // Default grid columns (no arguments)
    var gridColumns: Int {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
        #else
        return 2
        #endif
    }
    
    // Device detection
    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Spacing
    let cardSpacing: CGFloat = 16
    let edgePadding: CGFloat = 20
    let sectionSpacing: CGFloat = 24
    
    // Content widths
    let contentWidth: CGFloat = 600  // Max width for content on larger screens
    let maxCardWidth: CGFloat = 400  // Max width for cards
    let maxFormWidth: CGFloat = 500  // Max width for forms
}

// MARK: - Shadow System

struct ShadowSystem {
    enum ShadowLevel {
        case small
        case medium
        case large
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    func shadowFor(_ level: ShadowLevel) -> ShadowStyle {
        switch level {
        case .small:
            return ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        case .medium:
            return ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        case .large:
            return ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    // Convenience properties
    let small = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    let large = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    
    // Aliases for different naming conventions
    var sm: ShadowStyle { small }
    var md: ShadowStyle { medium }
    var lg: ShadowStyle { large }
}

// MARK: - Animation System

struct AnimationSystem {
    // Animation instances
    let fast = Animation.easeInOut(duration: 0.15)
    let quick = Animation.easeInOut(duration: 0.2)
    let standard = Animation.easeInOut(duration: 0.3)
    let slow = Animation.easeInOut(duration: 0.5)
    let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // Duration values (TimeInterval/Double) for use in functions that need raw durations
    let fastDuration: TimeInterval = 0.15
    let quickDuration: TimeInterval = 0.2
    let standardDuration: TimeInterval = 0.3
    let slowDuration: TimeInterval = 0.5
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

