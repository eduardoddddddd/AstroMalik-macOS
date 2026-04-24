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
    static let appBackground = adaptive(light: "#F6F7F4", dark: "#12151A")
    static let appSidebar = adaptive(light: "#ECEFF3", dark: "#171B22")
    static let appPanel = adaptive(light: "#FFFFFF", dark: "#202630")
    static let appSurface = adaptive(light: "#F9FAFB", dark: "#252B35")
    static let appPrimaryText = adaptive(light: "#202833", dark: "#F3F5F7")
    static let appSecondaryAccent = adaptive(light: "#0F766E", dark: "#7DD3C7")
    static let appAccentFill = adaptive(light: "#6554C0", dark: "#A89BFF")
    static let appAccentForeground = adaptive(light: "#FFFFFF", dark: "#15131F")
    static let appChipBackground = adaptive(light: "#E6E9EE", dark: "#303844")
    static let appBorder = adaptive(light: "#D0D7DE", dark: "#3B4652")
    static let appInputBackground = adaptive(light: "#FFFFFF", dark: "#1D232B")
    static let appWarning = adaptive(light: "#B45309", dark: "#FBBF24")

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

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.appPanel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.appBorder.opacity(0.75), lineWidth: 1)
            )
    }

    func appSectionHeader() -> some View {
        self
            .font(.headline)
            .foregroundColor(.appPrimaryText)
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
