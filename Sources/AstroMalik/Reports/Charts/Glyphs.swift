import Foundation

/// Original, geometric SVG path approximations for astrological glyphs.
/// They are intentionally kept as path data instead of Unicode/font glyphs so report SVGs remain
/// fully self-contained inside generated PDFs and do not depend on external fonts or web resources.
enum AstroGlyph: String, CaseIterable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces
    case sun, moon, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto, northNode, southNode
    case conjunction, sextile, square, trine, opposition

    var d: String { pathD }

    var pathD: String {
        switch self {
        case .aries:
            return "M -34 28 C -30 -20 -10 -46 0 -6 C 10 -46 30 -20 34 28 M 0 -6 L 0 38"
        case .taurus:
            return "M -30 -36 C -16 -12 16 -12 30 -36 M 0 -18 A 30 30 0 1 1 0 42 A 30 30 0 1 1 0 -18"
        case .gemini:
            return "M -30 -36 C -10 -28 10 -28 30 -36 M -30 36 C -10 28 10 28 30 36 M -20 -30 L -20 30 M 20 -30 L 20 30"
        case .cancer:
            return "M -36 -10 C -18 -32 22 -26 22 -4 A 16 16 0 1 1 6 -20 M 36 10 C 18 32 -22 26 -22 4 A 16 16 0 1 1 -6 20"
        case .leo:
            return "M -30 22 C -10 32 6 14 0 -2 C -8 -24 12 -38 28 -26 C 42 -16 34 8 16 16 C 2 22 4 40 28 36"
        case .virgo:
            return "M -38 22 C -34 -10 -28 -22 -18 -18 C -8 -14 -8 12 -8 30 M -8 -18 C 4 -28 14 -14 14 28 M 14 -12 C 28 -26 36 -4 24 12 C 12 28 28 40 40 20"
        case .libra:
            return "M -42 30 L 42 30 M -36 12 L -10 12 C -18 -14 18 -14 10 12 L 36 12"
        case .scorpio:
            return "M -40 22 C -36 -10 -30 -22 -20 -18 C -10 -14 -10 12 -10 30 M -10 -18 C 2 -28 10 -12 10 28 M 10 -12 C 22 -26 30 -6 24 20 L 40 20 M 40 20 L 30 10 M 40 20 L 30 30"
        case .sagittarius:
            return "M -34 34 L 34 -34 M 6 -34 L 34 -34 L 34 -6 M -18 0 L 0 18"
        case .capricorn:
            return "M -38 -18 C -26 -38 -14 -6 -8 30 M -8 -18 C 4 -36 12 -4 16 22 C 22 52 54 20 30 2 C 18 -8 8 10 16 22"
        case .aquarius:
            return "M -42 -8 L -24 -20 L -8 -8 L 8 -20 L 24 -8 L 42 -20 M -42 18 L -24 6 L -8 18 L 8 6 L 24 18 L 42 6"
        case .pisces:
            return "M -26 -36 C -8 -12 -8 12 -26 36 M 26 -36 C 8 -12 8 12 26 36 M -36 0 L 36 0"
        case .sun:
            return "M 0 -34 A 34 34 0 1 1 0 34 A 34 34 0 1 1 0 -34 M 0 -6 A 6 6 0 1 1 0 6 A 6 6 0 1 1 0 -6"
        case .moon:
            return "M 18 -38 A 38 38 0 1 0 18 38 A 26 38 0 1 1 18 -38"
        case .mercury:
            return "M -22 -40 C -10 -24 10 -24 22 -40 M 0 -22 A 24 24 0 1 1 0 26 A 24 24 0 1 1 0 -22 M 0 26 L 0 46 M -16 36 L 16 36"
        case .venus:
            return "M 0 -36 A 25 25 0 1 1 0 14 A 25 25 0 1 1 0 -36 M 0 14 L 0 46 M -16 30 L 16 30"
        case .mars:
            return "M -10 10 A 25 25 0 1 1 8 28 A 25 25 0 1 1 -10 10 M 18 -18 L 42 -42 M 20 -42 L 42 -42 L 42 -20"
        case .jupiter:
            return "M -30 -8 C -8 -10 -8 -38 -28 -36 M -8 -38 L -8 40 M -34 14 L 28 14"
        case .saturn:
            return "M -14 -42 L -14 36 M -34 -22 L 10 -22 M -14 2 C 18 -8 28 12 12 28 C 2 38 -18 34 -8 18"
        case .uranus:
            return "M 0 -38 L 0 22 M -16 -20 L 16 -20 M -34 -34 L -34 16 M 34 -34 L 34 16 M -34 -8 L 34 -8 M 0 22 A 16 16 0 1 1 0 54 A 16 16 0 1 1 0 22"
        case .neptune:
            return "M -34 -28 C -28 -4 -16 4 0 4 C 16 4 28 -4 34 -28 M -34 -28 L -24 -18 M -34 -28 L -44 -18 M 34 -28 L 24 -18 M 34 -28 L 44 -18 M 0 -40 L 0 44 M -18 24 L 18 24"
        case .pluto:
            return "M 0 -42 A 18 18 0 1 1 0 -6 A 18 18 0 1 1 0 -42 M -28 0 C -18 18 18 18 28 0 M 0 12 L 0 44 M -18 30 L 18 30"
        case .northNode:
            return "M -28 16 A 28 28 0 1 1 28 16 M -30 16 L -30 36 M 30 16 L 30 36 M -36 36 L 36 36"
        case .southNode:
            return "M -28 -16 A 28 28 0 1 0 28 -16 M -30 -16 L -30 -36 M 30 -16 L 30 -36 M -36 -36 L 36 -36"
        case .conjunction:
            return "M -8 -26 A 26 26 0 1 1 -8 26 A 26 26 0 1 1 -8 -26 M 16 22 L 34 40"
        case .sextile:
            return "M 0 -38 L 0 38 M -34 -20 L 34 20 M 34 -20 L -34 20"
        case .square:
            return "M -28 -28 L 28 -28 L 28 28 L -28 28 Z"
        case .trine:
            return "M 0 -36 L 36 28 L -36 28 Z"
        case .opposition:
            return "M -28 -28 A 18 18 0 1 1 -28 8 A 18 18 0 1 1 -28 -28 M 28 -8 A 18 18 0 1 1 28 28 A 18 18 0 1 1 28 -8 M -14 0 L 14 0"
        }
    }

    var canonicalName: String { rawValue }

    static func sign(index: Int) -> AstroGlyph {
        let signs: [AstroGlyph] = [.aries, .taurus, .gemini, .cancer, .leo, .virgo, .libra, .scorpio, .sagittarius, .capricorn, .aquarius, .pisces]
        return signs[max(0, min(11, index))]
    }

    static func planet(for key: String) -> AstroGlyph? {
        switch key.uppercased() {
        case "SOL": return .sun
        case "LUNA": return .moon
        case "MERCURIO": return .mercury
        case "VENUS": return .venus
        case "MARTE": return .mars
        case "JUPITER": return .jupiter
        case "SATURNO": return .saturn
        case "URANO": return .uranus
        case "NEPTUNO": return .neptune
        case "PLUTON", "PLUTO": return .pluto
        case "NODO_NORTE", "NORTH_NODE": return .northNode
        case "NODO_SUR", "SOUTH_NODE": return .southNode
        default: return nil
        }
    }

    static func aspect(for key: String) -> AstroGlyph? {
        switch key.uppercased() {
        case "CONJUNCION", "CONJUNCTION": return .conjunction
        case "SEXTIL", "SEXTILE": return .sextile
        case "CUADRADO", "CUADRATURA", "SQUARE": return .square
        case "TRIGONO", "TRINE": return .trine
        case "OPOSICION", "OPPOSITION": return .opposition
        default: return nil
        }
    }
}
