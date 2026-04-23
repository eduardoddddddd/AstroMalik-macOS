import Foundation

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
        text: String? = nil, source: String? = nil
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
    }
}

extension TransitEvent {
    var aspectColorSwift: String { color }

    var starsDisplay: String {
        String(repeating: "★", count: stars) + String(repeating: "☆", count: max(0, 5 - stars))
    }
}
