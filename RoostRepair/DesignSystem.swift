//
//  DesignSystem.swift
//  RoostRepair
//
//  Central design system: barn-wood palette, gradients, typography,
//  spacing and reusable style modifiers. Everything visual flows from here.
//

import SwiftUI

// MARK: - Color helpers

extension Color {
    /// Build a color from a 0xRRGGBB hex value.
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Wrap a solid color as a (flat) LinearGradient so a `.fill(...)` ternary
    /// can choose between a gradient and a color while staying one concrete type
    /// (avoids iOS-15-only `AnyShapeStyle`).
    var asGradient: LinearGradient {
        LinearGradient(colors: [self, self], startPoint: .top, endPoint: .bottom)
    }

    /// A color that resolves differently for light/dark trait collections so
    /// that `preferredColorScheme` switching repaints the whole app instantly.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - Palette

/// Warm barn-wood palette with amber indicators.
enum Theme {
    // Surfaces
    static let background = Color.dynamic(light: 0xF4E9D8, dark: 0x241A12)
    static let backgroundDeep = Color.dynamic(light: 0xE9D8BE, dark: 0x1A120B)
    static let card = Color.dynamic(light: 0xFFFBF2, dark: 0x34271C)
    static let cardRaised = Color.dynamic(light: 0xFFFFFF, dark: 0x3F3022)
    static let stroke = Color.dynamic(light: 0xE2CFB0, dark: 0x4A3826)

    // Text
    static let textPrimary = Color.dynamic(light: 0x2E2114, dark: 0xF6ECDD)
    static let textSecondary = Color.dynamic(light: 0x7A6650, dark: 0xC3AC8E)
    static let textFaint = Color.dynamic(light: 0xA7937A, dark: 0x8E775D)

    // Brand
    static let amber = Color(hex: 0xE8A33D)
    static let amberDeep = Color(hex: 0xCE7C24)
    static let amberSoft = Color.dynamic(light: 0xFBE7C4, dark: 0x4A3417)
    static let rust = Color(hex: 0xC0612C)
    static let wood = Color(hex: 0x7A5230)
    static let barnRed = Color(hex: 0xA8392E)

    // Status
    static let ok = Color(hex: 0x6FA45C)
    static let warn = Color(hex: 0xE39A2B)
    static let danger = Color(hex: 0xC4503D)
    static let info = Color(hex: 0x4E8FA8)

    // Gradients
    static var amberGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xF2B65A), Color(hex: 0xD9842A)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var woodGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x8A5E36), Color(hex: 0x5E3F22)],
                       startPoint: .top, endPoint: .bottom)
    }
    static func splashGradient(_ phase: Double) -> LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x3A2715), Color(hex: 0x6B431F), Color(hex: 0xB5772C)],
            startPoint: UnitPoint(x: 0.1 + phase * 0.2, y: 0.0),
            endPoint: UnitPoint(x: 0.9, y: 1.0 - phase * 0.2)
        )
    }
}

// MARK: - Spacing & radius

enum Metric {
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12
    static let pad: CGFloat = 16
    static let padLarge: CGFloat = 22
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.72)
    static let softSpring = Animation.spring(response: 0.55, dampingFraction: 0.8)
}

// MARK: - Typography

extension Font {
    static func roost(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static var roostTitle: Font { .roost(28, .bold) }
    static var roostHeadline: Font { .roost(20, .semibold) }
    static var roostBody: Font { .roost(16, .regular) }
    static var roostCaption: Font { .roost(13, .medium) }
}

// MARK: - Barn wood textured background

struct BarnBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Theme.background, Theme.backgroundDeep],
                               startPoint: .top, endPoint: .bottom)

                // Subtle vertical plank seams to suggest barn-wood texture.
                let plankWidth: CGFloat = 84
                let count = Int(geo.size.width / plankWidth) + 2
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(Theme.stroke.opacity(0.30))
                        .frame(width: 1)
                        .offset(x: CGFloat(i) * plankWidth - geo.size.width / 2)
                }
                // Faint horizontal grain lines.
                let grain = Int(geo.size.height / 160) + 1
                ForEach(0..<grain, id: \.self) { i in
                    Rectangle()
                        .fill(Theme.stroke.opacity(0.18))
                        .frame(height: 1)
                        .offset(y: CGFloat(i) * 160 - geo.size.height / 2 + 60)
                }
                // Warm corner glow.
                RadialGradient(colors: [Theme.amber.opacity(0.16), .clear],
                               center: .topTrailing, startRadius: 8, endRadius: 360)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
