import Foundation

// MARK: - Session

struct RectificationSession: Identifiable, Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var baseChartID: UUID?
    var name: String
    var birthDate: String
    var reportedBirthTime: String
    var timezone: String
    var latitude: Double
    var longitude: Double
    var placeName: String
    var searchRange: RectificationSearchRange
    var events: [RectificationEvent]
    var ascendantQuestionnaire: AscendantQuestionnaire?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: UUID = UUID(),
        baseChartID: UUID? = nil,
        name: String,
        birthDate: String,
        reportedBirthTime: String,
        timezone: String,
        latitude: Double,
        longitude: Double,
        placeName: String,
        searchRange: RectificationSearchRange,
        events: [RectificationEvent] = [],
        ascendantQuestionnaire: AscendantQuestionnaire? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.baseChartID = baseChartID
        self.name = name
        self.birthDate = birthDate
        self.reportedBirthTime = reportedBirthTime
        self.timezone = timezone
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.searchRange = searchRange
        self.events = events
        self.ascendantQuestionnaire = ascendantQuestionnaire
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct RectificationSearchRange: Codable, Equatable {
    var centerTime: String
    var minutesBefore: Int
    var minutesAfter: Int
    var coarseStepSeconds: Int
    var fineStepSeconds: Int
    var includeFullDayFallback: Bool

    init(
        centerTime: String,
        minutesBefore: Int = 120,
        minutesAfter: Int = 120,
        coarseStepSeconds: Int = 300,
        fineStepSeconds: Int = 60,
        includeFullDayFallback: Bool = false
    ) {
        self.centerTime = centerTime
        self.minutesBefore = minutesBefore
        self.minutesAfter = minutesAfter
        self.coarseStepSeconds = coarseStepSeconds
        self.fineStepSeconds = fineStepSeconds
        self.includeFullDayFallback = includeFullDayFallback
    }

    var coarseCandidateEstimate: Int {
        let totalSeconds = includeFullDayFallback
            ? 24 * 60 * 60
            : (minutesBefore + minutesAfter) * 60
        return max(1, totalSeconds / max(1, coarseStepSeconds) + 1)
    }
}

// MARK: - Events

struct RectificationEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var type: RectificationEventType
    var title: String
    var dateStart: Date
    var dateEnd: Date?
    var precision: RectificationEventPrecision
    var importance: Int
    var description: String
    var tags: [String]
    var confidence: RectificationEventConfidence

    init(
        id: UUID = UUID(),
        type: RectificationEventType,
        title: String,
        dateStart: Date,
        dateEnd: Date? = nil,
        precision: RectificationEventPrecision,
        importance: Int = 3,
        description: String = "",
        tags: [String] = [],
        confidence: RectificationEventConfidence = .certain
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.dateStart = dateStart
        self.dateEnd = dateEnd
        self.precision = precision
        self.importance = importance
        self.description = description
        self.tags = tags
        self.confidence = confidence
    }
}

enum RectificationEventType: String, Codable, CaseIterable, Identifiable {
    case identityShift
    case relationshipStart
    case marriage
    case divorce
    case childBirth
    case siblingBirth
    case parentDeath
    case familyDeath
    case relocation
    case homePurchase
    case educationStart
    case graduation
    case careerStart
    case promotion
    case jobLoss
    case publicRecognition
    case accident
    case surgery
    case illness
    case legalIssue
    case travelAbroad
    case spiritualShift
    case financialGain
    case financialLoss
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .identityShift: return "Cambio de identidad"
        case .relationshipStart: return "Inicio de relación"
        case .marriage: return "Matrimonio"
        case .divorce: return "Divorcio o separación"
        case .childBirth: return "Nacimiento de hijo/a"
        case .siblingBirth: return "Nacimiento de hermano/a"
        case .parentDeath: return "Fallecimiento de progenitor"
        case .familyDeath: return "Fallecimiento familiar"
        case .relocation: return "Mudanza"
        case .homePurchase: return "Compra de vivienda"
        case .educationStart: return "Inicio de estudios"
        case .graduation: return "Graduación"
        case .careerStart: return "Inicio profesional"
        case .promotion: return "Ascenso"
        case .jobLoss: return "Pérdida de empleo"
        case .publicRecognition: return "Reconocimiento público"
        case .accident: return "Accidente"
        case .surgery: return "Cirugía"
        case .illness: return "Enfermedad"
        case .legalIssue: return "Asunto legal"
        case .travelAbroad: return "Viaje o traslado al extranjero"
        case .spiritualShift: return "Cambio espiritual"
        case .financialGain: return "Ganancia económica"
        case .financialLoss: return "Pérdida económica"
        case .other: return "Otro"
        }
    }
}

enum RectificationEventPrecision: String, Codable, CaseIterable, Identifiable {
    case exactDay
    case approximateWeek
    case approximateMonth
    case approximateQuarter
    case approximateYear
    case dateRange

    var id: String { rawValue }

    var scoreMultiplier: Double {
        switch self {
        case .exactDay: return 1.00
        case .approximateWeek: return 0.85
        case .approximateMonth: return 0.65
        case .approximateQuarter: return 0.45
        case .approximateYear: return 0.25
        case .dateRange: return 0.60
        }
    }

    var qualifiesForMinimumDataset: Bool {
        switch self {
        case .exactDay, .approximateWeek, .approximateMonth, .dateRange:
            return true
        case .approximateQuarter, .approximateYear:
            return false
        }
    }
}

enum RectificationEventConfidence: String, Codable, CaseIterable, Identifiable {
    case certain
    case probable
    case uncertain
    case thirdParty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .certain: return "Cierta / documentada"
        case .probable: return "Probable"
        case .uncertain: return "Incierta"
        case .thirdParty: return "Informada por terceros"
        }
    }

    /// Reliability is deliberately independent from date precision: an exact
    /// date reported by a third party is not equivalent to an exact document.
    var scoreMultiplier: Double {
        switch self {
        case .certain: return 1.00
        case .probable: return 0.85
        case .uncertain: return 0.65
        case .thirdParty: return 0.55
        }
    }
}

// MARK: - Configuration

enum RectificationTechnique: String, Codable, CaseIterable, Identifiable {
    case ascendantSignQuestionnaire
    case solarArc
    case primaryDirections
    case secondaryProgressions
    case transitsToAngles
    case profections
    case firdaria
    case zodiacalReleasing
    case natalHouseFit
    case lots
    case solarReturn

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascendantSignQuestionnaire: return "Cuestionario de Ascendente"
        case .solarArc: return "Arco solar"
        case .primaryDirections: return "Direcciones primarias"
        case .secondaryProgressions: return "Progresiones secundarias"
        case .transitsToAngles: return "Tránsitos a ángulos"
        case .profections: return "Profecciones"
        case .firdaria: return "Firdaria"
        case .zodiacalReleasing: return "Zodiacal Releasing"
        case .natalHouseFit: return "Ajuste natal por casas"
        case .lots: return "Lotes"
        case .solarReturn: return "Revolución solar"
        }
    }
}

enum RectificationHouseSystem: String, Codable, CaseIterable, Identifiable {
    case placidus
    case wholeSign
    case equal
    case regiomontanus
    case campanus
    case porphyry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .placidus: return "Placidus"
        case .wholeSign: return "Signos completos"
        case .equal: return "Casas iguales"
        case .regiomontanus: return "Regiomontanus"
        case .campanus: return "Campanus"
        case .porphyry: return "Porfirio"
        }
    }

    var swissEphemerisCode: Character {
        switch self {
        case .placidus: return "P"
        case .wholeSign: return "W"
        case .equal: return "E"
        case .regiomontanus: return "R"
        case .campanus: return "C"
        case .porphyry: return "O"
        }
    }
}

struct RectificationConfig: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var enabledTechniques: Set<RectificationTechnique>
    var houseSystem: RectificationHouseSystem
    var useModernPlanets: Bool
    var orbMultiplier: Double
    var techniqueWeights: [RectificationTechnique: Double]
    var minimumEventsForAnalysis: Int
    var penalizeWeakContacts: Bool
    var clusterWindowMinutes: Int
    var evaluateMultipleHouseSystems: Bool
    var school: RectificationSchool?
    var overfittingPenaltyStrength: Double?

    static let `default` = RectificationConfig(
        enabledTechniques: [.solarArc, .primaryDirections, .secondaryProgressions, .transitsToAngles, .ascendantSignQuestionnaire, .profections, .firdaria, .lots],
        houseSystem: .placidus,
        useModernPlanets: true,
        orbMultiplier: 1,
        techniqueWeights: [
            .primaryDirections: 1.50,
            .solarArc: 1.10,
            .secondaryProgressions: 1.00,
            .solarReturn: 0.80,
            .transitsToAngles: 0.75,
            .profections: 0.70,
            .zodiacalReleasing: 0.65,
            .lots: 0.60,
            .firdaria: 0.55,
            .ascendantSignQuestionnaire: 0.50,
        ],
        minimumEventsForAnalysis: 3,
        penalizeWeakContacts: true,
        clusterWindowMinutes: 10,
        evaluateMultipleHouseSystems: false,
        school: .balanced,
        overfittingPenaltyStrength: 0.35
    )

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        enabledTechniques: Set<RectificationTechnique>,
        houseSystem: RectificationHouseSystem,
        useModernPlanets: Bool,
        orbMultiplier: Double,
        techniqueWeights: [RectificationTechnique: Double],
        minimumEventsForAnalysis: Int,
        penalizeWeakContacts: Bool,
        clusterWindowMinutes: Int,
        evaluateMultipleHouseSystems: Bool,
        school: RectificationSchool? = .balanced,
        overfittingPenaltyStrength: Double? = 0.35
    ) {
        self.schemaVersion = schemaVersion
        self.enabledTechniques = enabledTechniques
        self.houseSystem = houseSystem
        self.useModernPlanets = useModernPlanets
        self.orbMultiplier = orbMultiplier
        self.techniqueWeights = techniqueWeights
        self.minimumEventsForAnalysis = minimumEventsForAnalysis
        self.penalizeWeakContacts = penalizeWeakContacts
        self.clusterWindowMinutes = clusterWindowMinutes
        self.evaluateMultipleHouseSystems = evaluateMultipleHouseSystems
        self.school = school
        self.overfittingPenaltyStrength = overfittingPenaltyStrength
    }

    var resolvedSchool: RectificationSchool { school ?? .balanced }
    var resolvedOverfittingPenaltyStrength: Double { min(1, max(0, overfittingPenaltyStrength ?? 0.35)) }
}

// MARK: - Results

struct RectificationCandidate: Identifiable, Codable, Equatable {
    var id: UUID
    var birthTime: String
    var chart: NatalChart
    var ascendantLongitude: Double
    var mcLongitude: Double
    var ascendantFormatted: String
    var mcFormatted: String
    var totalScore: Double
    var confidenceBand: RectificationConfidenceBand
    var techniqueScores: [RectificationTechnique: Double]
    var eventScores: [UUID: Double]
    var evidence: [RectificationEvidence]
    var warnings: [String]
    var overfittingDiagnostics: RectificationOverfittingDiagnostics? = nil
}

struct RectificationEvidence: Identifiable, Codable, Equatable {
    var id: UUID
    var eventID: UUID
    var technique: RectificationTechnique
    var factor: String
    var exactDate: Date?
    var eventDate: Date
    var deltaDays: Double?
    var orbDegrees: Double?
    var symbolicFit: RectificationSymbolicFit
    var score: Double
    var explanation: String
    var debugData: [String: String]
}

enum RectificationSymbolicFit: String, Codable, CaseIterable {
    case contradiction
    case neutral
    case weak
    case moderate
    case strong
}

enum RectificationConfidenceBand: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case inconclusive
}

struct CandidateCluster: Identifiable, Codable, Equatable {
    var id: UUID
    var centerTime: String
    var timeRange: String
    var candidateIDs: [UUID]
    var averageScore: Double
    var ascendantSign: String
}

struct RectificationHouseSystemEvaluation: Codable, Equatable, Identifiable {
    var houseSystem: RectificationHouseSystem
    var topBirthTime: String
    var topScore: Double
    var confidence: RectificationConfidenceBand

    var id: RectificationHouseSystem { houseSystem }
}

struct RectificationAnalysisResult: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var sessionID: UUID
    var candidates: [RectificationCandidate]
    var topCandidate: RectificationCandidate?
    var overallConfidence: RectificationConfidenceBand
    var clusters: [CandidateCluster]
    var eventCoverage: [UUID: Int]
    var sectCrossingDetected: Bool
    var warnings: [String]
    var analysisDate: Date
    var configUsed: RectificationConfig
    var computeTimeSeconds: Double
    /// Optional keeps schema-v1 archives readable while exposing the opt-in
    /// comparison introduced after the original rectification release.
    var houseSystemEvaluations: [RectificationHouseSystemEvaluation]? = nil

    var resolvedHouseSystemEvaluations: [RectificationHouseSystemEvaluation] {
        houseSystemEvaluations ?? []
    }
}
