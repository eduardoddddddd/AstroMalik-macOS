import Foundation

struct HoraryChart: Codable, Equatable {
    let header: HoraryHeader
    let angles: HoraryAngles
    let planetaryHourRuler: String
    let sect: String
    let bodies: [HoraryBody]
    let parts: [HoraryPart]
    let dignities: [HoraryDignity]
    let aspects: [HoraryAspect]
    let considerations: [HoraryConsideration]

    func body(named name: String) -> HoraryBody? {
        bodies.first(where: { $0.name == name })
    }

    func part(named name: String) -> HoraryPart? {
        parts.first(where: { $0.name == name })
    }

    func dignity(for name: String) -> HoraryDignity? {
        dignities.first(where: { $0.name == name })
    }

    var activeConsiderations: [HoraryConsideration] {
        considerations.filter(\.active)
    }
}

struct HoraryHeader: Codable, Equatable {
    let question: String
    let datetimeLocal: String
    let timezone: String
    let placeName: String
    let latitude: Double
    let longitude: Double
    let questionHouse: Int
    let questionTopic: String
}

struct HoraryAngles: Codable, Equatable {
    let asc: HoraryAngle
    let mc: HoraryAngle
}

struct HoraryAngle: Codable, Equatable {
    let longitude: Double
    let sign: String
    let degreeInSign: Double

    var formatted: String {
        "\(sign) \(String(format: "%.2f", degreeInSign))°"
    }
}

struct HoraryBody: Identifiable, Codable, Equatable {
    var id: String { name }

    let name: String
    let longitude: Double
    let latitude: Double
    let speed: Double
    let sign: String
    let degreeInSign: Double
    let house: Int
    let retrograde: Bool
    let stationary: Bool

    var formatted: String {
        "\(sign) \(String(format: "%.2f", degreeInSign))°"
    }
}

typealias HoraryPart = HoraryBody

struct HoraryDignity: Identifiable, Codable, Equatable {
    var id: String { name }

    let name: String
    let essentialScore: Int
    let accidentalScore: Int
    let totalScore: Int
    let essentialTags: [String]
    let accidentalTags: [String]
}

struct HoraryAspect: Identifiable, Codable, Equatable {
    var id: String { "\(bodyA)_\(bodyB)_\(aspectName)" }

    let bodyA: String
    let bodyB: String
    let aspectName: String
    let angle: Double
    let distance: Double
    let orb: Double
    let applying: Bool
    let separating: Bool
    let timeEstimate: String?
}

struct HoraryConsideration: Identifiable, Codable, Equatable {
    var id: String { key }

    let key: String
    let active: Bool
    let severity: String
    let description: String
}

struct HoraryJudgement: Codable, Equatable {
    let question: String
    let radical: Bool
    let perfectionKind: String
    let timeEstimate: String?
    let questionHouse: Int
    let questionTopic: String
    let significators: HorarySignificators
    let perfectionRoute: HoraryPerfectionRoute
    let activeConsiderationKeys: [String]
    let notes: [String]
    let verdict: String?
    let confidence: String?
    let mainReason: String?
    let supportingFactors: [String]?
    let blockingFactors: [String]?
    let technicalWarnings: [String]?
    let timingRange: String?
}

struct HorarySignificators: Codable, Equatable {
    let querent: String
    let quesited: String
    let moon: String
    let querentCosignifiers: [String]
    let quesitedCosignifiers: [String]
}

struct HoraryPerfectionRoute: Codable, Equatable {
    let kind: String
    let significatorQuerent: String
    let significatorQuesited: String
    let intermediary: String?
    let aspectName: String?
    let usesCosignifier: Bool
    let degreesToPerfect: Double?
    let degreesToSignChange: Double?
    let fasterBody: String?
    let perfectsBeforeSignChange: Bool?
    let confidence: String?
}
