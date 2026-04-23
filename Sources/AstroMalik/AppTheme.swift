import SwiftUI
import AppKit

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    static let appBackground = adaptive(light: "#FAF6F0", dark: "#14110F")
    static let appPanel = adaptive(light: "#F5EFE7", dark: "#231D1A")
    static let appSurface = adaptive(light: "#FFFFFF", dark: "#2B2420")
    static let appPrimaryText = adaptive(light: "#3C2A1E", dark: "#F1E3D2")
    static let appSecondaryAccent = adaptive(light: "#6B4F3A", dark: "#D1B08F")
    static let appAccentFill = adaptive(light: "#3C2A1E", dark: "#D4B08A")
    static let appAccentForeground = adaptive(light: "#FFFFFF", dark: "#1D1713")
    static let appChipBackground = adaptive(light: "#EDE5DA", dark: "#3B312B")
    static let appBorder = adaptive(light: "#D6C9BA", dark: "#4A3D35")
    static let appInputBackground = adaptive(light: "#FFFFFF", dark: "#2D2622")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    init(hex: String) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
