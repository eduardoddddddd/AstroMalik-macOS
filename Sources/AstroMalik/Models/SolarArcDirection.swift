import Foundation

// MARK: - Solar Arc Direction Model

struct SolarArcDirection: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let directedPoint: String
    let directedPointLabel: String
    let directedNatalLongitude: Double
    let directedLongitude: Double
    let natalPoint: String
    let natalPointLabel: String
    let natalLongitude: Double
    let aspect: PDaspect
    let aspectAngle: Double
    let solarArc: Double
    let exactAge: Double
    let exactDate: Date
    let orb: Double
    let polarity: SolarArcAspectPolarity
    let mode: SolarArcMode
    let weight: PDWeight

    init(
        id: UUID = UUID(),
        directedPoint: String,
        directedPointLabel: String,
        directedNatalLongitude: Double,
        directedLongitude: Double,
        natalPoint: String,
        natalPointLabel: String,
        natalLongitude: Double,
        aspect: PDaspect,
        aspectAngle: Double,
        solarArc: Double,
        exactAge: Double,
        exactDate: Date,
        orb: Double,
        polarity: SolarArcAspectPolarity,
        mode: SolarArcMode,
        weight: PDWeight
    ) {
        self.id = id
        self.directedPoint = directedPoint
        self.directedPointLabel = directedPointLabel
        self.directedNatalLongitude = directedNatalLongitude
        self.directedLongitude = directedLongitude
        self.natalPoint = natalPoint
        self.natalPointLabel = natalPointLabel
        self.natalLongitude = natalLongitude
        self.aspect = aspect
        self.aspectAngle = aspectAngle
        self.solarArc = solarArc
        self.exactAge = exactAge
        self.exactDate = exactDate
        self.orb = orb
        self.polarity = polarity
        self.mode = mode
        self.weight = weight
    }
}

enum SolarArcAspectPolarity: String, Codable, Equatable, Sendable {
    case applying = "acercandose"
    case separating = "separandose"

    var label: String {
        switch self {
        case .applying: return "Acercándose"
        case .separating: return "Separándose"
        }
    }
}

struct SolarArcPoint: Codable, Equatable, Sendable {
    let key: String
    let label: String
    let longitude: Double
}
