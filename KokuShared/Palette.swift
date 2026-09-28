import SwiftUI
import UIKit

// Shared by the app and its widgets, so both use exactly the same colours.

/// The one highlight colour. Chosen in Settings.
enum Highlight: String, CaseIterable, Identifiable {
    case mint, lime, sky, periwinkle, coral, amber

    var id: Self { self }
    var name: String { rawValue.capitalized }

    /// The bright colour, for filled things (the add button, progress, the highlighted bar). Put dark ink on top.
    var fill: Color { Color(hex: bright) }

    /// For text and icons: a deeper shade in light mode, so it stays readable on white; the bright colour in dark mode.
    var text: Color { Color(light: deep, dark: bright) }

    private var bright: UInt32 {
        switch self {
        case .mint: 0x34D399
        case .lime: 0xC4F042
        case .sky: 0x5AC8FA
        case .periwinkle: 0x8B93FF
        case .coral: 0xFF7A85
        case .amber: 0xFFC247
        }
    }

    private var deep: UInt32 {
        switch self {
        case .mint: 0x047857
        case .lime: 0x4D7C0F
        case .sky: 0x0369A1
        case .periwinkle: 0x4F46E5
        case .coral: 0xE11D48
        case .amber: 0xB45309
        }
    }
}

// MARK: Colour tokens

private enum Palette {
    static let canvas = Color(light: 0xF5F5F2, dark: 0x0B0B0C)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161618)
    static let surface2 = Color(light: 0xECECE8, dark: 0x232326)
    static let thumb = Color(light: 0xFFFFFF, dark: 0x3A3A3F)
    static let ink = Color(light: 0x111111, dark: 0xF4F4F5)
    static let ink2 = Color(light: 0x6E6E73, dark: 0x9B9BA1)
    static let ink3 = Color(light: 0xA1A1A6, dark: 0x5F5F66)
    static let hairline = Color(light: 0x111111, dark: 0xFFFFFF, lightOpacity: 0.07, darkOpacity: 0.06)
    static let chartBar = Color(light: 0xDCDCD6, dark: 0x2C2C30)
    static let onHighlight = Color(hex: 0x0B0B0C)
    static let warning = Color(light: 0xDC3B42, dark: 0xFF5A5F)
    static let toast = Color(light: 0x1C1C1E, dark: 0x2C2C30)
}

extension ShapeStyle where Self == Color {
    /// The page background.
    static var canvas: Color { Palette.canvas }
    /// Cards and rows.
    static var surface: Color { Palette.surface }
    /// Tiles, tracks, fields and unselected pills.
    static var surface2: Color { Palette.surface2 }
    /// The sliding thumb of a pill picker.
    static var thumb: Color { Palette.thumb }
    /// Main text.
    static var ink: Color { Palette.ink }
    /// Secondary text.
    static var ink2: Color { Palette.ink2 }
    /// Placeholders and the quietest details.
    static var ink3: Color { Palette.ink3 }
    static var hairline: Color { Palette.hairline }
    /// Chart bars that aren't highlighted.
    static var chartBar: Color { Palette.chartBar }
    /// Text and icons on top of a highlight fill.
    static var onHighlight: Color { Palette.onHighlight }
    /// Only for going over budget.
    static var warning: Color { Palette.warning }
    /// The undo banner, dark in both modes.
    static var toastBackground: Color { Palette.toast }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A colour that switches with light and dark mode.
    init(light: UInt32, dark: UInt32, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkOpacity)
                : UIColor(hex: light, alpha: lightOpacity)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
