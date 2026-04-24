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
    @Published var minStars: Int = 1
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
        self.text = text
        self.source = source
        self.samples = samples
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
}
