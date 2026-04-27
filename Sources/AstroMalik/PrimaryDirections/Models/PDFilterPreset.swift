import Foundation

enum PDFilterPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case classical = "Clásico"
    case extended = "Extendido"
    case full = "Completo"

    var id: String { rawValue }

    var promissors: Set<String> {
        switch self {
        case .classical:
            return [
                "SOL", "LUNA", "MERCURIO", "VENUS", "MARTE",
                "JUPITER", "SATURNO", "ASC", "MC", "PARTFORTUNA"
            ]
        case .extended:
            return PDFilterPreset.classical.promissors.union(["URANO", "NEPTUNO", "PLUTON"])
        case .full:
            return PDFilterPreset.extended.promissors.union(["DSC", "IC"])
        }
    }

    var significators: Set<PDSignificator> {
        switch self {
        case .classical:
            return [.asc, .mc, .sun, .moon]
        case .extended:
            return [.asc, .mc, .sun, .moon, .saturn, .jupiter]
        case .full:
            return Set(PDSignificator.allCases)
        }
    }

    var aspects: Set<PDaspect> {
        switch self {
        case .classical:
            return [.conjunction, .sextile, .square, .trine, .opposition]
        case .extended, .full:
            return Set(PDaspect.allCases)
        }
    }

    var orderedPromissors: [String] {
        let order = PLANET_LIST.map(\.key) + ["ASC", "MC", "DSC", "IC", "PARTFORTUNA"]
        return order.filter { promissors.contains($0) }
    }

    var orderedSignificators: [PDSignificator] {
        PDSignificator.allCases.filter { significators.contains($0) }
    }

    var orderedAspects: [PDaspect] {
        PDaspect.allCases.filter { aspects.contains($0) }
    }

    var defaultMinimumWeight: PDWeight {
        switch self {
        case .classical:
            return .major
        case .extended:
            return .moderate
        case .full:
            return .minor
        }
    }

    var settingsDescription: String {
        switch self {
        case .classical:
            return "Clásico: 7 planetas + Pars Fortunae, 4 significadores (ASC, MC, Sol, Luna), 5 aspectos ptolemaicos. ~60-80 direcciones."
        case .extended:
            return "Extendido: añade Urano, Neptuno, Plutón y significadores Saturno y Júpiter. ~120-150 direcciones."
        case .full:
            return "Completo: todos los cuerpos, todos los significadores, todos los aspectos. ~280-300 direcciones."
        }
    }
}
