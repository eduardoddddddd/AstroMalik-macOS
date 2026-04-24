import Foundation

enum SynastryDirection: String, Codable, CaseIterable {
    case aToB
    case bToA

    var label: String {
        switch self {
        case .aToB: return "A sobre B"
        case .bToA: return "B sobre A"
        }
    }

    var sourceInitial: String {
        switch self {
        case .aToB: return "A"
        case .bToA: return "B"
        }
    }

    var targetInitial: String {
        switch self {
        case .aToB: return "B"
        case .bToA: return "A"
        }
    }
}

struct SynastryAspect: Identifiable, Codable, Equatable {
    var id: String { "\(direction.rawValue)_\(corpusClave)" }
    var direction: SynastryDirection
    var sourcePlanetKey: String
    var sourcePlanetLabel: String
    var targetPlanetKey: String
    var targetPlanetLabel: String
    var aspectKey: String
    var aspectLabel: String
    var orb: Double
    var corpusClave: String
    var interpretation: Interpretation?

    var hasText: Bool { interpretation != nil }
}

struct SynastryReading: Identifiable, Codable, Equatable {
    var id: String { "\(chartA.id.uuidString)-\(chartB.id.uuidString)" }
    var chartA: NatalChart
    var chartB: NatalChart
    var aspects: [SynastryAspect]

    var aspectsWithText: [SynastryAspect] {
        aspects.filter(\.hasText)
    }

    var missingTextCount: Int {
        aspects.count - aspectsWithText.count
    }

    var coverageSummary: String {
        "\(aspectsWithText.count) textos de \(aspects.count) aspectos"
    }
}
