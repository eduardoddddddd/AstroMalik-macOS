import Foundation

typealias Chart = NatalChart

enum AstroPlanetKey: String, Codable, CaseIterable, Identifiable, Hashable {
    case sol = "SOL"
    case luna = "LUNA"
    case mercurio = "MERCURIO"
    case venus = "VENUS"
    case marte = "MARTE"
    case jupiter = "JUPITER"
    case saturno = "SATURNO"
    case nodoNorte = "NODO_NORTE"
    case nodoSur = "NODO_SUR"

    var id: String { rawValue }
    var key: String { rawValue }

    var label: String {
        switch self {
        case .sol: return "☉ Sol"
        case .luna: return "☽ Luna"
        case .mercurio: return "☿ Mercurio"
        case .venus: return "♀ Venus"
        case .marte: return "♂ Marte"
        case .jupiter: return "♃ Júpiter"
        case .saturno: return "♄ Saturno"
        case .nodoNorte: return "☊ Nodo Norte"
        case .nodoSur: return "☋ Nodo Sur"
        }
    }

    var shortLabel: String {
        switch self {
        case .sol: return "Sol"
        case .luna: return "Luna"
        case .mercurio: return "Mercurio"
        case .venus: return "Venus"
        case .marte: return "Marte"
        case .jupiter: return "Júpiter"
        case .saturno: return "Saturno"
        case .nodoNorte: return "Nodo Norte"
        case .nodoSur: return "Nodo Sur"
        }
    }

    var symbol: String {
        switch self {
        case .sol: return "☉"
        case .luna: return "☽"
        case .mercurio: return "☿"
        case .venus: return "♀"
        case .marte: return "♂"
        case .jupiter: return "♃"
        case .saturno: return "♄"
        case .nodoNorte: return "☊"
        case .nodoSur: return "☋"
        }
    }

    var colorHex: String {
        switch self {
        case .sol: return "#F59E0B"
        case .luna: return "#94A3B8"
        case .mercurio: return "#14B8A6"
        case .venus: return "#EC4899"
        case .marte: return "#DC2626"
        case .jupiter: return "#2563EB"
        case .saturno: return "#7C3AED"
        case .nodoNorte: return "#16A34A"
        case .nodoSur: return "#64748B"
        }
    }

    var isNode: Bool {
        self == .nodoNorte || self == .nodoSur
    }
}

struct SectInfo: Codable, Equatable {
    var isDiurnal: Bool
    var luminary: AstroPlanetKey
    var benefic: AstroPlanetKey
    var malefic: AstroPlanetKey
    var contrarySectBenefic: AstroPlanetKey
    var contrarySectMalefic: AstroPlanetKey

    var label: String { isDiurnal ? "Diurna" : "Nocturna" }
    var iconSystemName: String { isDiurnal ? "sun.max.fill" : "moon.stars.fill" }
}
