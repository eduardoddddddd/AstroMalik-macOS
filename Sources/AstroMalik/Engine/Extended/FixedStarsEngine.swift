import Foundation

final class FixedStarsEngine {
    private let lotsEngine = LotsEngine()
    private let j2000 = 2_451_545.0
    private let tropicalYear = 365.2422
    private let precessionArcSecondsPerYear = 50.29

    func fixedStars(
        chart: Chart,
        orb: Double = NatalExtendedAnalysisConfiguration.default.fixedStarOrb
    ) throws -> FixedStarResult {
        let jd = try ExtendedAstro.birthJulianDay(for: chart)
        let entries = try catalog()
        let correction = precessionCorrectionDegrees(forJulianDay: jd)
        let stars = entries.map { entry in
            let longitude = ExtendedAstro.normalized(entry.longitudeJ2000 + correction)
            return FixedStarPosition(
                key: entry.key,
                name: entry.name,
                longitudeJ2000: entry.longitudeJ2000,
                longitude: ExtendedAstro.rounded(longitude, places: 6),
                latitude: entry.latitudeJ2000,
                magnitude: entry.magnitude,
                nature: entry.nature,
                formatted: AstroEngine.degToSign(longitude)
            )
        }

        let targets = try conjunctionTargets(chart: chart)
        var contacts: [FixedStarContact] = []
        for star in stars {
            for target in targets {
                let distance = ExtendedAstro.angularDistance(star.longitude, target.longitude)
                if distance <= orb {
                    contacts.append(FixedStarContact(
                        id: "\(star.key)-\(target.key)",
                        starKey: star.key,
                        starName: star.name,
                        starLongitude: star.longitude,
                        starFormatted: star.formatted,
                        targetKey: target.key,
                        targetLabel: target.label,
                        targetLongitude: ExtendedAstro.rounded(target.longitude, places: 6),
                        orb: ExtendedAstro.rounded(distance, places: 3),
                        magnitude: star.magnitude,
                        nature: star.nature
                    ))
                }
            }
        }

        return FixedStarResult(
            epochJulianDay: ExtendedAstro.rounded(jd, places: 6),
            precessionAppliedDegrees: ExtendedAstro.rounded(correction, places: 6),
            stars: stars.sorted { $0.longitude < $1.longitude },
            contacts: contacts.sorted { $0.orb == $1.orb ? $0.id < $1.id : $0.orb < $1.orb }
        )
    }

    func precessionCorrectionDegrees(forJulianDay jd: Double) -> Double {
        let years = (jd - j2000) / tropicalYear
        return years * precessionArcSecondsPerYear / 3600.0
    }

    func catalog() throws -> [FixedStarCatalogEntry] {
        guard let url = AppResources.bundle.url(forResource: "fixed_stars", withExtension: "json") else {
            throw NatalExtendedError.fixedStarResourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([FixedStarCatalogEntry].self, from: data)
        } catch {
            throw NatalExtendedError.fixedStarResourceInvalid(error.localizedDescription)
        }
    }

    private func conjunctionTargets(chart: Chart) throws -> [(key: String, label: String, longitude: Double)] {
        var targets: [(key: String, label: String, longitude: Double)] = ExtendedAstro.bodies(in: chart, keys: ExtendedAstro.tenPlanetKeys)
            .map { (key: $0.key, label: $0.label, longitude: $0.longitude) }
        targets.append((key: "ASC", label: "Ascendente", longitude: chart.ascendant.longitude))
        targets.append((key: "MC", label: "Medio Cielo", longitude: chart.mc.longitude))
        let fortune = try lotsEngine.lot(.fortune, chart: chart)
        targets.append((key: fortune.key, label: fortune.name, longitude: fortune.longitude))
        return targets
    }
}
