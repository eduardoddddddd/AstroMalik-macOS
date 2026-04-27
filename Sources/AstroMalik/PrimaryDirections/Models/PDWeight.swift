import Foundation

enum PDWeight: Int, Comparable, Codable, CaseIterable, Sendable {
    case minor = 1
    case moderate = 2
    case major = 3
    case critical = 4

    static func < (lhs: PDWeight, rhs: PDWeight) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .critical: return "Crítica"
        case .major: return "Mayor"
        case .moderate: return "Moderada"
        case .minor: return "Menor"
        }
    }

    var filterLabel: String {
        switch self {
        case .minor: return "Todos"
        case .moderate: return "≥Moderada"
        case .major: return "≥Mayor"
        case .critical: return "Solo críticas"
        }
    }

    var glyph: String {
        switch self {
        case .critical: return "◉"
        case .major: return "●"
        case .moderate: return "◎"
        case .minor: return "○"
        }
    }
}
