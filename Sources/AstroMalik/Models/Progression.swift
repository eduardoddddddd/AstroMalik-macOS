import Foundation

enum ASCMode: String, CaseIterable, Identifiable, Codable, Equatable {
    case naibod
    case bija

    var id: String { rawValue }

    var label: String {
        switch self {
        case .naibod: return "Naibod"
        case .bija: return "Día-por-año (Bija)"
        }
    }

    var explanation: String {
        switch self {
        case .naibod:
            return "RAMC natal + 0°59'08.33\" por año; ASC/MC recalculados para la latitud natal."
        case .bija:
            return "Los ángulos avanzan solidariamente con el Sol progresado respecto al Sol natal."
        }
    }
}

struct ProgressionSnapshot: Codable, Equatable {
    var chartID: UUID
    var chartName: String
    var calculatedAt: Date
    var targetDate: Date
    var natalJulianDay: Double
    var progressedJulianDay: Double
    var ageYears: Double
    var ascendantMode: ASCMode
    var bodies: [ProgressedBody]
    var ascendant: ProgressedAngle
    var mc: ProgressedAngle
    var cusps: [Double]
    var lunarPhase: ProgressedLunarPhase
    var nextLunarSignIngresses: [ProgressedIngress]
    var nextLunarHouseIngresses: [ProgressedIngress]
    var nextLunarPhaseTransitions: [ProgressedLunarPhase]
    var highlightedChanges: [ProgressedIngress]

    var progressedSun: ProgressedBody? { bodies.first { $0.key == "SOL" } }
    var progressedMoon: ProgressedBody? { bodies.first { $0.key == "LUNA" } }

    var ascendantRulerKey: String {
        EssentialDignityEngine.domicileRuler(of: EphemerisUtilities.signIndex(for: ascendant.longitude))
    }

    var ascendantRulerLabel: String {
        ProgressionLabels.planetName(for: ascendantRulerKey)
    }
}

struct ProgressedBody: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var longitude: Double
    var formatted: String
    var declination: Double
    var house: Int
    var retrograde: Bool
    var speed: Double

    var signIndex: Int { EphemerisUtilities.signIndex(for: longitude) }
    var signLabel: String { SIGN_LABELS[signIndex] }
}

struct ProgressedAngle: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var longitude: Double
    var formatted: String
    var house: Int

    var signIndex: Int { EphemerisUtilities.signIndex(for: longitude) }
    var signLabel: String { SIGN_LABELS[signIndex] }
}

enum ProgressedAspectKind: String, Codable, Equatable, Hashable {
    case progressedToNatal
    case progressedToProgressed

    var label: String {
        switch self {
        case .progressedToNatal: return "Prog → natal"
        case .progressedToProgressed: return "Prog → prog"
        }
    }
}

struct ProgressedAspect: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: ProgressedAspectKind
    var date: Date
    var exactDate: String
    var progressedKey: String
    var progressedLabel: String
    var targetKey: String
    var targetLabel: String
    var aspectKey: String
    var aspectLabel: String
    var orb: Double
    var applying: Bool
    var priority: Int
    var progressedRetrograde: Bool

    var title: String {
        "\(progressedLabel) \(aspectLabel) \(targetLabel)"
    }
}

enum ProgressedIngressKind: String, Codable, Equatable, Hashable {
    case lunarSign
    case lunarHouse
    case planetSign
    case station
    case lunarPhase

    var label: String {
        switch self {
        case .lunarSign: return "Ingreso lunar por signo"
        case .lunarHouse: return "Ingreso lunar por casa"
        case .planetSign: return "Cambio de signo"
        case .station: return "Estación progresada"
        case .lunarPhase: return "Cambio de fase lunar"
        }
    }
}

struct ProgressedIngress: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: ProgressedIngressKind
    var date: Date
    var dateLabel: String
    var bodyKey: String
    var bodyLabel: String
    var fromValue: String
    var toValue: String
    var longitude: Double
    var description: String
    var priority: Int
}

enum ProgressedLunarPhaseName: String, CaseIterable, Codable, Equatable, Hashable {
    case new = "Nueva"
    case crescent = "Creciente"
    case firstQuarter = "Cuarto creciente"
    case gibbous = "Gibosa"
    case full = "Llena"
    case disseminating = "Diseminada"
    case lastQuarter = "Último cuarto"
    case balsamic = "Balsámica"

    var next: ProgressedLunarPhaseName {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}

struct ProgressedLunarPhase: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: ProgressedLunarPhaseName
    var angle: Double
    var startsAt: Date?
    var dateLabel: String?
    var nextBoundary: Double

    var label: String { name.rawValue }
}

enum ProgressionLabels {
    static func planetName(for key: String) -> String {
        switch key {
        case "SOL": return "Sol"
        case "LUNA": return "Luna"
        case "MERCURIO": return "Mercurio"
        case "VENUS": return "Venus"
        case "MARTE": return "Marte"
        case "JUPITER": return "Júpiter"
        case "SATURNO": return "Saturno"
        case "URANO": return "Urano"
        case "NEPTUNO": return "Neptuno"
        case "PLUTON": return "Plutón"
        case "NODO_NORTE": return "Nodo Norte"
        case "NODO_SUR": return "Nodo Sur"
        case "ASC": return "Ascendente"
        case "MC": return "Medio Cielo"
        case "PARTE_FORTUNA": return "Parte de Fortuna"
        case "PARTE_ESPIRITU": return "Parte del Espíritu"
        default: return key.capitalized
        }
    }

    static func planetGlyphLabel(for key: String) -> String {
        switch key {
        case "SOL": return "☉ Sol"
        case "LUNA": return "☽ Luna"
        case "MERCURIO": return "☿ Mercurio"
        case "VENUS": return "♀ Venus"
        case "MARTE": return "♂ Marte"
        case "JUPITER": return "♃ Júpiter"
        case "SATURNO": return "♄ Saturno"
        case "URANO": return "⛢ Urano"
        case "NEPTUNO": return "♆ Neptuno"
        case "PLUTON": return "♇ Plutón"
        case "NODO_NORTE": return "☊ Nodo Norte"
        case "NODO_SUR": return "☋ Nodo Sur"
        case "ASC": return "Ascendente"
        case "MC": return "Medio Cielo"
        case "PARTE_FORTUNA": return "⊗ Parte de Fortuna"
        case "PARTE_ESPIRITU": return "✶ Parte del Espíritu"
        default: return planetName(for: key)
        }
    }
}
