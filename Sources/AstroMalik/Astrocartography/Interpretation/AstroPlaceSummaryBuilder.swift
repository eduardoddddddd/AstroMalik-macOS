import Foundation

/// What a theme has near a place: counts per distance band and the closest line.
/// Ordering by these counts is a PRODUCT criterion for reading convenience; it is
/// not an intensity, a score or a prediction.
struct AstroThemeActivity: Equatable, Identifiable, Sendable {
    let theme: AstroTheme
    let nearCount: Int
    /// Lines in the regional band only (the near ones are not counted twice).
    let regionalCount: Int
    let nearest: AstroLineProximity?

    var id: String { theme.rawValue }
    var nearbyCount: Int { nearCount + regionalCount }
}

enum AstroThemeRanking {
    static func activity(of analysis: LocationAnalysis, theme: AstroTheme, policy: AstroProximityPolicy) -> AstroThemeActivity {
        let lines = analysis.proximities.filter { theme.contains($0.lineID) }
        let near = lines.filter { policy.band(for: $0.distanceKm) == .near }.count
        let regional = lines.filter { policy.band(for: $0.distanceKm) == .regional }.count
        return AstroThemeActivity(theme: theme, nearCount: near, regionalCount: regional,
                                  nearest: lines.min { $0.distanceKm < $1.distanceKm })
    }

    /// More near lines, then more regional lines, then the closest line; nil last.
    static func precedes(_ a: (near: Int, regional: Int, nearest: Double?),
                         _ b: (near: Int, regional: Int, nearest: Double?)) -> Bool? {
        if a.near != b.near { return a.near > b.near }
        if a.regional != b.regional { return a.regional > b.regional }
        switch (a.nearest, b.nearest) {
        case let (x?, y?): return x == y ? nil : x < y
        case (nil, nil): return nil
        case (_?, nil): return true
        case (nil, _?): return false
        }
    }
}

struct AstroPlaceSummaryLine: Equatable, Identifiable, Sendable {
    let proximity: AstroLineProximity
    let band: AstroProximityPolicy.Band
    /// «Sol en el Medio Cielo · 45 km»
    let phrase: String
    /// Editorial title when a reading exists; the full text stays in the reading block.
    let gist: String?
    var id: String { proximity.lineID.stableKey }
}

struct AstroPlaceSummary: Equatable, Sendable {
    let placeName: String
    let headline: String
    let nearest: AstroLineProximity?
    let lines: [AstroPlaceSummaryLine]
    /// Themes with at least one line within the regional threshold, best first.
    let themes: [AstroThemeActivity]
    let quietThemeCount: Int
}

enum AstroPlaceSummaryBuilder {
    static func distance(_ km: Double) -> String {
        km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km)
    }

    static func phrase(_ proximity: AstroLineProximity) -> String {
        "\(proximity.lineID.body.spanishName) en el \(proximity.lineID.angle.spanishName) · \(distance(proximity.distanceKm))"
    }

    /// Pure and deterministic. Always global: filters and the active theme never
    /// change a summary, so hiding lines cannot hide a nearby one from the user.
    static func build(placeName: String, analysis: LocationAnalysis, policy: AstroProximityPolicy,
                      catalog: AstroReadingCatalog) -> AstroPlaceSummary {
        let lines: [AstroPlaceSummaryLine] = analysis.proximities.compactMap { proximity in
            let band = policy.band(for: proximity.distanceKm)
            guard band != .distant else { return nil }
            return AstroPlaceSummaryLine(proximity: proximity, band: band, phrase: phrase(proximity),
                                         gist: catalog.lookup(proximity.lineID).entry?.title)
        }
        let nearCount = lines.filter { $0.band == .near }.count
        let regionalCount = lines.count - nearCount
        let nearest = analysis.proximities.first
        let headline: String
        if lines.isEmpty {
            headline = nearest.map {
                "\(placeName): ninguna línea dentro de \(Int(policy.regionalKm)) km. La más cercana es \(phrase($0))."
            } ?? "\(placeName): sin líneas con distancia definida."
        } else {
            headline = "\(placeName): \(nearCount) \(nearCount == 1 ? "línea cerca" : "líneas cerca") (≤\(Int(policy.nearKm)) km) y \(regionalCount) en el entorno regional (≤\(Int(policy.regionalKm)) km)."
        }
        let all = AstroTheme.allCases.map { AstroThemeRanking.activity(of: analysis, theme: $0, policy: policy) }
        let ranked = all.filter { $0.nearbyCount > 0 }.sorted { a, b in
            AstroThemeRanking.precedes((a.nearCount, a.regionalCount, a.nearest?.distanceKm),
                                       (b.nearCount, b.regionalCount, b.nearest?.distanceKm))
                ?? (a.theme.title < b.theme.title)
        }
        return AstroPlaceSummary(placeName: placeName, headline: headline, nearest: nearest, lines: lines,
                                 themes: ranked, quietThemeCount: all.count - ranked.count)
    }
}

/// A place that can enter a ranking: compared in memory, or saved with a still
/// valid result. Saved places needing recalculation are never ranked.
struct AstroRankablePlace: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let analysis: LocationAnalysis
}

struct AstroPlaceRankingEntry: Equatable, Identifiable, Sendable {
    let place: AstroRankablePlace
    let rank: Int
    let activity: AstroThemeActivity
    var id: String { place.id }
}

enum AstroPlaceRanking {
    static func rank(places: [AstroRankablePlace], theme: AstroTheme, policy: AstroProximityPolicy) -> [AstroPlaceRankingEntry] {
        let scored = places.map { ($0, AstroThemeRanking.activity(of: $0.analysis, theme: theme, policy: policy)) }
        let sorted = scored.sorted { a, b in
            AstroThemeRanking.precedes((a.1.nearCount, a.1.regionalCount, a.1.nearest?.distanceKm),
                                       (b.1.nearCount, b.1.regionalCount, b.1.nearest?.distanceKm))
                ?? (a.0.name < b.0.name)
        }
        return sorted.enumerated().map { AstroPlaceRankingEntry(place: $0.element.0, rank: $0.offset + 1, activity: $0.element.1) }
    }
}
