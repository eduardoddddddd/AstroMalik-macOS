import Foundation

// MARK: - Subject

enum CrossSubjectKind: String, Codable, Hashable {
    case planet
    case house
    case sign
    case lot
    case axis
}

struct CrossSubject: Codable, Equatable, Hashable {
    let kind: CrossSubjectKind
    let key: String
    let label: String

    static func planet(_ key: String, label: String) -> CrossSubject {
        CrossSubject(kind: .planet, key: key, label: label)
    }

    static func house(_ number: Int) -> CrossSubject {
        CrossSubject(kind: .house, key: "CASA_\(number)", label: "Casa \(number)")
    }

    static func sign(_ index: Int) -> CrossSubject {
        let safe = ((index % 12) + 12) % 12
        return CrossSubject(kind: .sign, key: SIGN_KEYS[safe], label: SIGN_LABELS[safe])
    }

    static func lot(_ kind: NatalLotKind) -> CrossSubject {
        CrossSubject(kind: .lot, key: "LOTE_\(kind.rawValue.uppercased())", label: "Lote de \(kind.title)")
    }

    static func axis(_ key: String) -> CrossSubject {
        CrossSubject(kind: .axis, key: key, label: key == "ASC" ? "Ascendente" : key == "MC" ? "Medio Cielo" : key)
    }
}

// MARK: - Layer

enum CrossLayerKind: String, Codable, CaseIterable, Hashable {
    case annual
    case mediumTerm
    case shortTerm
    case lunar

    var label: String {
        switch self {
        case .annual: return "Capa anual"
        case .mediumTerm: return "Capa medio plazo"
        case .shortTerm: return "Capa corto plazo"
        case .lunar: return "Capa lunar y eclíptica"
        }
    }

    var weight: Double {
        switch self {
        case .annual: return 1.0
        case .mediumTerm: return 0.8
        case .shortTerm: return 0.6
        case .lunar: return 0.5
        }
    }
}

// MARK: - Signal

struct CrossSignal: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let layer: CrossLayerKind
    let source: String
    let subject: CrossSubject
    let secondarySubjects: [CrossSubject]
    let weight: Double
    let summary: String
    let detail: String?
    let startsAt: Date?
    let endsAt: Date?
    let exactAt: Date?
}

struct CrossLayer: Codable, Equatable {
    let kind: CrossLayerKind
    let label: String
    let signals: [CrossSignal]
}

// MARK: - Topic

struct PriorityTopic: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let subject: CrossSubject
    let convergenceScore: Double
    let layerCount: Int
    let layers: [CrossLayerKind]
    let signalIDs: [String]
    let summary: String
}

// MARK: - Natal Signature

struct CrossNatalSignature: Codable, Equatable {
    let sun: SignedPlacement
    let moon: SignedPlacement
    let ascendant: AngularSummary
    let mc: AngularSummary
    let sect: SectInfo
    let ascendantRulerKey: String
    let ascendantRulerLabel: String
    let almutenFigurisKey: String
    let almutenFigurisLabel: String
    let rulerOfGenitureKey: String
    let rulerOfGenitureLabel: String
    let prominentLots: [LotSummary]
    let aspectPatterns: [PatternSummary]
    let elementBalance: ElementBalance
    let modalityBalance: ModalityBalance
    let fixedStarContacts: [FixedStarSummary]
}

struct SignedPlacement: Codable, Equatable {
    let key: String
    let label: String
    let signLabel: String
    let house: Int
    let degree: String
    let retrograde: Bool
}

struct AngularSummary: Codable, Equatable {
    let signLabel: String
    let degree: String
}

struct LotSummary: Codable, Equatable {
    let kind: NatalLotKind
    let signLabel: String
    let house: Int
    let rulerLabel: String
}

struct PatternSummary: Codable, Equatable {
    let kind: String
    let title: String
    let planetLabels: [String]
    let averageOrb: Double
}

struct ElementBalance: Codable, Equatable {
    let fire: Int
    let earth: Int
    let air: Int
    let water: Int
}

struct ModalityBalance: Codable, Equatable {
    let cardinal: Int
    let fixed: Int
    let mutable: Int
}

struct FixedStarSummary: Codable, Equatable {
    let starName: String
    let targetLabel: String
    let orb: Double
    let nature: String
}

// MARK: - Metadata

struct CrossMetadata: Codable, Equatable {
    let generatedAt: Date
    let referenceDate: Date
    let chartID: UUID
    let chartName: String
    let engineVersion: String
}

// MARK: - State

struct CrossPersonalState: Codable, Equatable {
    let metadata: CrossMetadata
    let natalSignature: CrossNatalSignature
    let layers: [CrossLayer]
    let topics: [PriorityTopic]

    func layer(_ kind: CrossLayerKind) -> CrossLayer? {
        layers.first { $0.kind == kind }
    }
}

// MARK: - Options

struct CrossPersonalOptions: Codable, Equatable {
    var topTopicsLimit: Int
    var subjectScoringBonus: SubjectScoringBonus
    var convergenceMultipliers: ConvergenceMultipliers
    var eclipseLunarMultiplier: Double

    static let `default` = CrossPersonalOptions(
        topTopicsLimit: 12,
        subjectScoringBonus: .default,
        convergenceMultipliers: .default,
        eclipseLunarMultiplier: 2.0
    )
}

struct SubjectScoringBonus: Codable, Equatable {
    var lordOfTheYear: Double
    var sectLuminary: Double
    var rulerOfGeniture: Double
    var zrPeakSignMatch: Double

    static let `default` = SubjectScoringBonus(
        lordOfTheYear: 0.3,
        sectLuminary: 0.2,
        rulerOfGeniture: 0.2,
        zrPeakSignMatch: 0.3
    )
}

struct ConvergenceMultipliers: Codable, Equatable {
    var oneLayer: Double
    var twoLayers: Double
    var threeLayers: Double
    var fourOrMore: Double

    static let `default` = ConvergenceMultipliers(
        oneLayer: 1.0,
        twoLayers: 1.5,
        threeLayers: 2.0,
        fourOrMore: 2.5
    )

    func multiplier(for layerCount: Int) -> Double {
        switch layerCount {
        case ...1: return oneLayer
        case 2: return twoLayers
        case 3: return threeLayers
        default: return fourOrMore
        }
    }
}

// MARK: - Inputs

/// Conjunto de datos pre-calculados que alimenta `CrossPersonalEngine`.
/// El engine es puro: no calcula efemérides, no toca disco. El ensamblador
/// `CrossPersonalAssembler` se encarga de invocar los engines reales y
/// rellenar esta estructura.
struct CrossPersonalInputs {
    let chart: NatalChart
    let referenceDate: Date

    let natalExtended: NatalExtendedAnalysisResult
    let profections: ProfectionResult

    let solarReturn: SolarReturnReading?

    let primaryDirections: [PrimaryDirection]
    let solarArc: [SolarArcDirection]

    let progressionSnapshot: ProgressionSnapshot
    let progressedAspects: [ProgressedAspect]

    let firdariaMajor: FirdariaPeriod
    let firdariaMinor: FirdariaPeriod?
    let firdariaUpcoming: [FirdariaMinorChange]

    let zrSpirit: ZRTimeline
    let zrFortune: ZRTimeline

    let transits: [TransitEvent]
    let upcomingLunations: [LunarPointHit]
    let upcomingEclipses: [LunarPointHit]
}

/// Lunación o eclipse que toca un punto natal sensible. El assembler
/// emite estos pre-filtrados; el engine sólo consume.
struct LunarPointHit: Codable, Equatable {
    enum Kind: String, Codable {
        case newMoon
        case fullMoon
        case firstQuarter
        case lastQuarter
        case solarEclipse
        case lunarEclipse
    }

    let kind: Kind
    let date: Date
    let longitude: Double
    let signLabel: String
    let targetKey: String
    let targetLabel: String
    let orb: Double
}
