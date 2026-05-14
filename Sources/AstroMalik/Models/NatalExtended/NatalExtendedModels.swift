import Foundation

// MARK: - Natal Extended Analysis Models

struct NatalExtendedAnalysisConfiguration: Codable, Equatable {
    var aspectPatternOrb: Double
    var antisciaOrb: Double
    var declinationOrb: Double
    var fixedStarOrb: Double

    static let `default` = NatalExtendedAnalysisConfiguration(
        aspectPatternOrb: 6.0,
        antisciaOrb: 1.0,
        declinationOrb: 1.0,
        fixedStarOrb: 1.0
    )
}

struct NatalExtendedAnalysisResult: Codable, Equatable {
    var generatedAt: Date
    var configuration: NatalExtendedAnalysisConfiguration
    var lots: [NatalLot]
    var almutenFiguris: AlmutenFigurisResult
    var rulerOfGeniture: RulerOfGeniture
    var aspectPatterns: [AspectPattern]
    var distribution: NatalDistribution
    var receptions: [MutualReception]
    var antiscia: AntisciaResult
    var declinations: DeclinationResult
    var fixedStars: FixedStarResult
}

// MARK: - Lots

enum NatalLotKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case fortune
    case spirit
    case eros
    case necessity
    case victory
    case audacity
    case nemesis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fortune: return "Fortuna"
        case .spirit: return "Espíritu"
        case .eros: return "Eros"
        case .necessity: return "Necesidad"
        case .victory: return "Victoria"
        case .audacity: return "Audacia"
        case .nemesis: return "Némesis"
        }
    }

    var symbol: String {
        switch self {
        case .fortune: return "⊕"
        case .spirit: return "✶"
        case .eros: return "♡"
        case .necessity: return "☿"
        case .victory: return "♃"
        case .audacity: return "♂"
        case .nemesis: return "♄"
        }
    }
}

struct NatalLot: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var kind: NatalLotKind
    var name: String
    var formulaComment: String
    var longitude: Double
    var formatted: String
    var signIndex: Int
    var signKey: String
    var signLabel: String
    var house: Int
    var rulerKey: String
    var rulerLabel: String
    var dispositorKey: String
    var dispositorLabel: String
}

// MARK: - Almuten Figuris and Ruler of Geniture

struct AlmutenPointScore: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var name: String
    var longitude: Double
    var formatted: String
    var dignityAwards: [DignityAward]
}

struct DignityAward: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(planetKey)-\(dignity)-\(points)" }
    var planetKey: String
    var planetLabel: String
    var dignity: String
    var points: Int
}

struct AlmutenBonus: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(planetKey)-\(kind)" }
    var planetKey: String
    var planetLabel: String
    var kind: String
    var points: Int
    var detail: String
}

struct AlmutenPlanetScore: Identifiable, Codable, Equatable, Hashable {
    var id: String { planetKey }
    var planetKey: String
    var planetLabel: String
    var essentialPoints: Int
    var bonusPoints: Int
    var total: Int
}

struct PrenatalSyzygy: Codable, Equatable, Hashable {
    enum Kind: String, Codable, Hashable {
        case newMoon
        case fullMoon

        var label: String {
            switch self {
            case .newMoon: return "Luna nueva"
            case .fullMoon: return "Luna llena"
            }
        }
    }

    var kind: Kind
    var julianDay: Double
    var longitude: Double
    var formatted: String
}

struct AlmutenFigurisResult: Codable, Equatable, Hashable {
    var winnerKey: String
    var winnerLabel: String
    var totalScores: [AlmutenPlanetScore]
    var pointScores: [AlmutenPointScore]
    var bonuses: [AlmutenBonus]
    var prenatalSyzygy: PrenatalSyzygy
    var notes: [String]
}

struct RulerOfGeniture: Codable, Equatable, Hashable {
    var sectLabel: String
    var luminaryKey: String
    var luminaryLabel: String
    var luminaryLongitude: Double
    var luminaryFormatted: String
    var rulerKey: String
    var rulerLabel: String
    var dignityAwards: [DignityAward]
    var dignitySummary: String
}

// MARK: - Aspect Patterns

enum AspectPatternKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case tSquare
    case grandTrine
    case yod
    case grandCross
    case kite
    case mysticRectangle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tSquare: return "T-cuadrada"
        case .grandTrine: return "Gran Trígono"
        case .yod: return "Yod / Dedo de Dios"
        case .grandCross: return "Gran Cruz"
        case .kite: return "Kite"
        case .mysticRectangle: return "Rectángulo Místico"
        }
    }
}

struct AspectPattern: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: AspectPatternKind
    var title: String
    var planetKeys: [String]
    var planetLabels: [String]
    var averageOrb: Double
    var aspects: [PatternAspect]
}

struct PatternAspect: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(planetAKey)-\(planetBKey)-\(aspectKey)" }
    var planetAKey: String
    var planetALabel: String
    var planetBKey: String
    var planetBLabel: String
    var aspectKey: String
    var aspectLabel: String
    var exactAngle: Double
    var orb: Double
}

// MARK: - Distribution

enum DistributionCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case element
    case modality
    case hemisphere
    case quadrant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .element: return "Elemento"
        case .modality: return "Modalidad"
        case .hemisphere: return "Hemisferio"
        case .quadrant: return "Cuadrante"
        }
    }
}

struct DistributionBucket: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(category.rawValue)-\(name)" }
    var category: DistributionCategory
    var name: String
    var count: Int
    var planetKeys: [String]
    var planetLabels: [String]
}

struct SingletonPlanet: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(category.rawValue)-\(bucketName)-\(planetKey)" }
    var category: DistributionCategory
    var bucketName: String
    var planetKey: String
    var planetLabel: String
}

struct NatalDistribution: Codable, Equatable, Hashable {
    var elements: [DistributionBucket]
    var modalities: [DistributionBucket]
    var hemispheres: [DistributionBucket]
    var quadrants: [DistributionBucket]
    var singletons: [SingletonPlanet]
}

// MARK: - Receptions

enum MutualReceptionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case domicile
    case exaltation
    case mixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .domicile: return "Domicilio mutuo"
        case .exaltation: return "Exaltación mutua"
        case .mixed: return "Mixta domicilio/exaltación"
        }
    }
}

struct MutualReception: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: MutualReceptionKind
    var planetAKey: String
    var planetALabel: String
    var planetBKey: String
    var planetBLabel: String
    var detail: String
}

// MARK: - Antiscia

enum AntisciaContactKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case antiscion
    case contraAntiscion

    var id: String { rawValue }

    var label: String {
        switch self {
        case .antiscion: return "Antiscion"
        case .contraAntiscion: return "Contraantiscion"
        }
    }
}

struct AntisciaPoint: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(planetKey)-\(kind.rawValue)" }
    var planetKey: String
    var planetLabel: String
    var kind: AntisciaContactKind
    var longitude: Double
    var formatted: String
}

struct AntisciaContact: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: AntisciaContactKind
    var sourcePlanetKey: String
    var sourcePlanetLabel: String
    var targetPlanetKey: String
    var targetPlanetLabel: String
    var calculatedLongitude: Double
    var calculatedFormatted: String
    var orb: Double
}

struct AntisciaResult: Codable, Equatable, Hashable {
    var points: [AntisciaPoint]
    var contacts: [AntisciaContact]
}

// MARK: - Declinations

struct BodyDeclination: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var declination: Double
    var formatted: String
    var outOfBounds: Bool
}

enum DeclinationAspectKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case parallel
    case contraParallel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parallel: return "Paralelo"
        case .contraParallel: return "Contraparalelo"
        }
    }
}

struct DeclinationPair: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: DeclinationAspectKind
    var bodyAKey: String
    var bodyALabel: String
    var bodyBKey: String
    var bodyBLabel: String
    var orb: Double
}

struct DeclinationResult: Codable, Equatable, Hashable {
    var bodies: [BodyDeclination]
    var pairs: [DeclinationPair]
    var outOfBounds: [BodyDeclination]
}

// MARK: - Fixed Stars

struct FixedStarCatalogEntry: Codable, Equatable, Hashable {
    var key: String
    var name: String
    var longitudeJ2000: Double
    var latitudeJ2000: Double
    var magnitude: Double
    var nature: String
}

struct FixedStarPosition: Identifiable, Codable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var name: String
    var longitudeJ2000: Double
    var longitude: Double
    var latitude: Double
    var magnitude: Double
    var nature: String
    var formatted: String
}

struct FixedStarContact: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var starKey: String
    var starName: String
    var starLongitude: Double
    var starFormatted: String
    var targetKey: String
    var targetLabel: String
    var targetLongitude: Double
    var orb: Double
    var magnitude: Double
    var nature: String
}

struct FixedStarResult: Codable, Equatable, Hashable {
    var epochJulianDay: Double
    var precessionAppliedDegrees: Double
    var stars: [FixedStarPosition]
    var contacts: [FixedStarContact]
}
