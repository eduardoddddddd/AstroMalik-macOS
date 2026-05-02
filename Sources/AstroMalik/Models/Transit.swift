import Foundation

@MainActor
final class TransitWorkspaceState: ObservableObject {
    @Published var fromDate = Date()
    @Published var toDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @Published var excludeMoon = true
    @Published var events: [TransitEvent] = []
    @Published var isCalculating = false
    @Published var error: String? = nil
    @Published var selectedEventID: UUID? = nil
    @Published var selectedEvent: TransitEvent? = nil
    @Published var focusFilter: TransitFocusFilter = .focus
    @Published var needsRecalculation = true

    private var chartID: UUID?

    func prepare(for chart: NatalChart) {
        guard chartID != chart.id else { return }
        chartID = chart.id
        events = []
        error = nil
        selectedEventID = nil
        selectedEvent = nil
        needsRecalculation = true
    }

    func markInputsChanged() {
        if !events.isEmpty {
            needsRecalculation = true
        }
    }

    func markCalculated() {
        needsRecalculation = false
    }
}

enum TransitFocusFilter: String, CaseIterable, Identifiable {
    case focus
    case important
    case all
    case technical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focus: return "Foco"
        case .important: return "Importantes"
        case .all: return "Todos"
        case .technical: return "Técnicos"
        }
    }
}

enum TransitPriorityBand: String, Codable, Hashable {
    case low
    case medium
    case high
    case critical

    var label: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        case .critical: return "Crítica"
        }
    }

    var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

struct TransitEvent: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var transitKey: String        // "SATURNO"
    var transitLabel: String      // "Saturno"
    var natalKey: String          // "SOL"
    var natalLabel: String        // "Sol"
    var aspectKey: String         // "CONJUNCION"
    var aspectLabel: String       // "Conjuncion"
    var color: String             // hex "#d97706"
    var fromDate: String          // ISO "2026-03-01"
    var toDate: String
    var exactDate: String
    var activeDays: Int
    var minOrb: Double
    var retrogradeOnExact: Bool
    var score: Double
    var stars: Int                // 1-5
    var technicalScore: Double
    var technicalStars: Int
    var personalRelevance: Double
    var personalRelevanceStars: Int
    var temporalImpact: Double
    var temporalImpactStars: Int
    var priorityScore: Double
    var priorityStars: Int
    var priorityBand: TransitPriorityBand
    var metricReasons: [String]
    var text: String?
    var source: String?
    var samples: [TransitIntensitySample]

    init(
        id: UUID = UUID(),
        transitKey: String, transitLabel: String,
        natalKey: String, natalLabel: String,
        aspectKey: String, aspectLabel: String,
        color: String,
        fromDate: String, toDate: String, exactDate: String,
        activeDays: Int, minOrb: Double,
        retrogradeOnExact: Bool,
        score: Double, stars: Int,
        technicalScore: Double? = nil, technicalStars: Int? = nil,
        personalRelevance: Double = 1.0, personalRelevanceStars: Int? = nil,
        temporalImpact: Double = 1.0, temporalImpactStars: Int? = nil,
        priorityScore: Double? = nil, priorityStars: Int? = nil,
        priorityBand: TransitPriorityBand = .low,
        metricReasons: [String] = [],
        text: String? = nil, source: String? = nil,
        samples: [TransitIntensitySample] = []
    ) {
        self.id = id
        self.transitKey = transitKey
        self.transitLabel = transitLabel
        self.natalKey = natalKey
        self.natalLabel = natalLabel
        self.aspectKey = aspectKey
        self.aspectLabel = aspectLabel
        self.color = color
        self.fromDate = fromDate
        self.toDate = toDate
        self.exactDate = exactDate
        self.activeDays = activeDays
        self.minOrb = minOrb
        self.retrogradeOnExact = retrogradeOnExact
        self.score = score
        self.stars = stars
        self.technicalScore = technicalScore ?? score
        self.technicalStars = technicalStars ?? stars
        self.personalRelevance = personalRelevance
        self.personalRelevanceStars = personalRelevanceStars ?? Self.starsForMultiplier(personalRelevance)
        self.temporalImpact = temporalImpact
        self.temporalImpactStars = temporalImpactStars ?? Self.starsForMultiplier(temporalImpact)
        self.priorityScore = priorityScore ?? (score * personalRelevance * temporalImpact)
        self.priorityBand = priorityBand
        self.priorityStars = priorityStars ?? Self.starsForPriorityBand(priorityBand)
        self.metricReasons = metricReasons
        self.text = text
        self.source = source
        self.samples = samples
    }

    enum CodingKeys: String, CodingKey {
        case id
        case transitKey, transitLabel
        case natalKey, natalLabel
        case aspectKey, aspectLabel
        case color
        case fromDate, toDate, exactDate
        case activeDays, minOrb, retrogradeOnExact
        case score, stars
        case technicalScore, technicalStars
        case personalRelevance, personalRelevanceStars
        case temporalImpact, temporalImpactStars
        case priorityScore, priorityStars, priorityBand
        case metricReasons
        case text, source, samples
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        transitKey = try c.decode(String.self, forKey: .transitKey)
        transitLabel = try c.decode(String.self, forKey: .transitLabel)
        natalKey = try c.decode(String.self, forKey: .natalKey)
        natalLabel = try c.decode(String.self, forKey: .natalLabel)
        aspectKey = try c.decode(String.self, forKey: .aspectKey)
        aspectLabel = try c.decode(String.self, forKey: .aspectLabel)
        color = try c.decode(String.self, forKey: .color)
        fromDate = try c.decode(String.self, forKey: .fromDate)
        toDate = try c.decode(String.self, forKey: .toDate)
        exactDate = try c.decode(String.self, forKey: .exactDate)
        activeDays = try c.decode(Int.self, forKey: .activeDays)
        minOrb = try c.decode(Double.self, forKey: .minOrb)
        retrogradeOnExact = try c.decode(Bool.self, forKey: .retrogradeOnExact)
        score = try c.decode(Double.self, forKey: .score)
        stars = try c.decode(Int.self, forKey: .stars)
        technicalScore = try c.decodeIfPresent(Double.self, forKey: .technicalScore) ?? score
        technicalStars = try c.decodeIfPresent(Int.self, forKey: .technicalStars) ?? stars
        personalRelevance = try c.decodeIfPresent(Double.self, forKey: .personalRelevance) ?? 1.0
        personalRelevanceStars = try c.decodeIfPresent(Int.self, forKey: .personalRelevanceStars)
            ?? Self.starsForMultiplier(personalRelevance)
        temporalImpact = try c.decodeIfPresent(Double.self, forKey: .temporalImpact) ?? 1.0
        temporalImpactStars = try c.decodeIfPresent(Int.self, forKey: .temporalImpactStars)
            ?? Self.starsForMultiplier(temporalImpact)
        priorityScore = try c.decodeIfPresent(Double.self, forKey: .priorityScore)
            ?? (score * personalRelevance * temporalImpact)
        priorityBand = try c.decodeIfPresent(TransitPriorityBand.self, forKey: .priorityBand) ?? .low
        priorityStars = try c.decodeIfPresent(Int.self, forKey: .priorityStars)
            ?? Self.starsForPriorityBand(priorityBand)
        metricReasons = try c.decodeIfPresent([String].self, forKey: .metricReasons) ?? []
        text = try c.decodeIfPresent(String.self, forKey: .text)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        samples = try c.decodeIfPresent([TransitIntensitySample].self, forKey: .samples) ?? []
    }

    private static func starsForMultiplier(_ value: Double) -> Int {
        switch value {
        case 1.65...: return 5
        case 1.40...: return 4
        case 1.15...: return 3
        case 0.95...: return 2
        default: return 1
        }
    }

    private static func starsForPriorityBand(_ band: TransitPriorityBand) -> Int {
        switch band {
        case .critical: return 5
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        }
    }
}

struct TransitIntensitySample: Codable, Equatable, Hashable {
    var date: String              // ISO "2026-03-01"
    var orb: Double
    var intensity: Double         // 0...1, higher near exact aspect
}

extension TransitEvent {
    var aspectColorSwift: String { color }

    var starsDisplay: String {
        String(repeating: "★", count: stars) + String(repeating: "☆", count: max(0, 5 - stars))
    }

    var technicalStarsDisplay: String {
        String(repeating: "★", count: technicalStars) + String(repeating: "☆", count: max(0, 5 - technicalStars))
    }

    var personalRelevanceStarsDisplay: String {
        String(repeating: "★", count: personalRelevanceStars) + String(repeating: "☆", count: max(0, 5 - personalRelevanceStars))
    }

    var temporalImpactStarsDisplay: String {
        String(repeating: "★", count: temporalImpactStars) + String(repeating: "☆", count: max(0, 5 - temporalImpactStars))
    }

    var priorityStarsDisplay: String {
        String(repeating: "★", count: priorityStars) + String(repeating: "☆", count: max(0, 5 - priorityStars))
    }

    var priorityLabel: String {
        priorityBand.label
    }

    var compactReason: String {
        let priorityOrder = [
            "Activación del eje nodal",
            "Toca Ascendente",
            "Toca Medio Cielo",
            "Toca Sol/Luna",
            "Regente del Ascendente",
            "Nodo natal angular",
            "Toca Nodo natal",
            "Planeta natal angular",
            "Tránsito por casa angular",
            "Tres pasadas por retrogradación",
            "Dos pasadas por retrogradación",
            "Cluster de tránsitos al mismo punto",
            "Duración larga",
            "Duración muy larga",
            "Orbe exacto menor de 0.25°",
            "Orbe exacto menor de 0.5°",
            "Orbe exacto menor de 1°",
        ]
        let ordered = priorityOrder.filter { metricReasons.contains($0) }
        let fallback = metricReasons.filter { !ordered.contains($0) }
        let summary = Array((ordered + fallback).prefix(3))
        return summary.isEmpty ? "Sin énfasis personal claro" : summary.joined(separator: " · ")
    }
}
