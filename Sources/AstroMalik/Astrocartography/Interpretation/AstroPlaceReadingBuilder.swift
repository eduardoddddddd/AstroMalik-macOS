import Foundation

/// A line near a place, with its geographic distance kept as separate data from
/// the editorial text. The distance band is a product parameter and does not
/// intensify or weaken the symbolic reading.
struct AstroPlaceReadingItem: Equatable, Identifiable, Sendable {
    let proximity: AstroLineProximity
    let band: AstroProximityPolicy.Band
    let crossesBoundary: Bool
    let isVisibleByFilters: Bool
    let lookup: AstroReadingLookup

    var id: String { proximity.lineID.stableKey }
}

struct AstroPlaceReadingSet: Equatable, Sendable {
    /// Near and regional lines (and distant ones only if requested), by distance.
    let items: [AstroPlaceReadingItem]
    /// Lines outside the regional threshold that were not listed.
    let omittedDistantCount: Int
    /// Coverage over ALL lines defined at the place, hidden or distant included.
    let coverage: AstroReadingCoverage
    let editorialVersion: String?
    let policy: AstroProximityPolicy
}

enum AstroPlaceReadingBuilder {
    /// Pure and deterministic: same analysis, policy, filters and catalog give the
    /// same set. No distance, relocation or line is recomputed or modified.
    static func build(analysis: LocationAnalysis, policy: AstroProximityPolicy, catalog: AstroReadingCatalog,
                      bodies: Set<AstroBody> = Set(AstroBody.allCases),
                      angles: Set<AstroAngle> = Set(AstroAngle.allCases),
                      onlyVisible: Bool = false, includeDistant: Bool = false) -> AstroPlaceReadingSet {
        let everyLine = analysis.proximities.map(\.lineID)
        var omitted = 0
        var items: [AstroPlaceReadingItem] = []
        for proximity in analysis.proximities { // already ordered by distance, then stable key
            let band = policy.band(for: proximity.distanceKm)
            let visible = bodies.contains(proximity.lineID.body) && angles.contains(proximity.lineID.angle)
            if onlyVisible && !visible { continue }
            if band == .distant && !includeDistant { omitted += 1; continue }
            items.append(AstroPlaceReadingItem(proximity: proximity, band: band,
                crossesBoundary: policy.crossesBoundary(proximity), isVisibleByFilters: visible,
                lookup: catalog.lookup(proximity.lineID)))
        }
        return AstroPlaceReadingSet(items: items, omittedDistantCount: omitted,
                                    coverage: catalog.coverage(of: everyLine),
                                    editorialVersion: catalog.editorialVersion, policy: policy)
    }
}
