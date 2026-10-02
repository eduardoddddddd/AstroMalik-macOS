import XCTest
@testable import AstroMalik

final class AstroThemeSummaryTests: XCTestCase {
    // MARK: Themes

    func testThemeMembershipCountsMatchTheirPublishedExplanation() {
        let expected: [AstroTheme: Int] = [.career: 10, .relationships: 13, .home: 13, .identity: 10, .growth: 6, .intensity: 16]
        for theme in AstroTheme.allCases {
            XCTAssertEqual(theme.lines.count, expected[theme], theme.title)
            XCTAssertEqual(Set(theme.lines).count, theme.lines.count)
            XCTAssertFalse(theme.explanation.isEmpty)
        }
        XCTAssertEqual(Set(AstroTheme.allCases.map(\.title)).count, AstroTheme.allCases.count)
        // Every one of the 40 lines belongs to at least one theme: no line is orphaned from filtering.
        for body in AstroBody.allCases {
            for angle in AstroAngle.allCases {
                let id = AstroLineID(body: body, angle: angle)
                XCTAssertTrue(AstroTheme.allCases.contains { $0.contains(id) }, "\(body) \(angle)")
            }
        }
        XCTAssertTrue(AstroTheme.career.lines.allSatisfy { $0.angle == .mc })
        XCTAssertTrue(AstroTheme.relationships.contains(AstroLineID(body: .venus, angle: .asc)))
        XCTAssertFalse(AstroTheme.relationships.contains(AstroLineID(body: .mars, angle: .mc)))
        XCTAssertTrue(AstroTheme.growth.contains(AstroLineID(body: .sun, angle: .mc)))
        XCTAssertFalse(AstroTheme.growth.contains(AstroLineID(body: .sun, angle: .ic)))
    }

    func testSpanishNamesHaveNoSymbolsAndMatchReadings() {
        XCTAssertEqual(AstroBody.allCases.map(\.spanishName),
                       ["Sol", "Luna", "Mercurio", "Venus", "Marte", "Júpiter", "Saturno", "Urano", "Neptuno", "Plutón"])
        XCTAssertEqual(AstroAngle.allCases.map(\.spanishName), ["Ascendente", "Descendente", "Medio Cielo", "Fondo del Cielo"])
    }

    // MARK: Summary

    func testSummaryIsGlobalOrderedAndRanksThemesByProximityNotScore() throws {
        let analysis = try syntheticAnalysis([(.sun, .mc, 20), (.moon, .asc, 99.9995), (.venus, .dsc, 250), (.mars, .ic, 301), (.pluto, .mc, 900)])
        let policy = try AstroProximityPolicy()
        let summary = AstroPlaceSummaryBuilder.build(placeName: "Lugar", analysis: analysis, policy: policy, catalog: try catalog())
        XCTAssertEqual(summary.headline, "Lugar: 2 líneas cerca (≤100 km) y 1 en el entorno regional (≤300 km).")
        XCTAssertEqual(summary.lines.map(\.phrase), ["Sol en el Medio Cielo · 20 km", "Luna en el Ascendente · 100 km", "Venus en el Descendente · 250 km"])
        XCTAssertEqual(summary.lines.map(\.band), [.near, .near, .regional])
        XCTAssertTrue(summary.lines.allSatisfy { $0.gist != nil })
        XCTAssertEqual(summary.nearest, analysis.proximities.first)
        // growth and career tie on count and distance (20 km): ties break by title.
        XCTAssertEqual(summary.themes.map(\.theme), [.growth, .career, .home, .identity, .relationships])
        XCTAssertEqual(summary.quietThemeCount, 1)
        XCTAssertEqual(summary.themes[0].nearCount, 1); XCTAssertEqual(summary.themes[4].regionalCount, 1)
        XCTAssertEqual(AstroPlaceSummaryBuilder.build(placeName: "Lugar", analysis: analysis, policy: policy, catalog: try catalog()), summary)
    }

    func testSummaryWhenNothingIsNearNamesTheClosestLineAndSingularizes() throws {
        let policy = try AstroProximityPolicy()
        let far = AstroPlaceSummaryBuilder.build(placeName: "Remoto", analysis: try syntheticAnalysis([(.saturn, .ic, 500), (.sun, .asc, 800)]),
                                                 policy: policy, catalog: .unavailable("x"))
        XCTAssertEqual(far.headline, "Remoto: ninguna línea dentro de 300 km. La más cercana es Saturno en el Fondo del Cielo · 500 km.")
        XCTAssertTrue(far.lines.isEmpty); XCTAssertTrue(far.themes.isEmpty); XCTAssertEqual(far.quietThemeCount, 6)
        let one = AstroPlaceSummaryBuilder.build(placeName: "Uno", analysis: try syntheticAnalysis([(.sun, .mc, 4.26)]),
                                                 policy: policy, catalog: .unavailable("sin recurso"))
        XCTAssertEqual(one.headline, "Uno: 1 línea cerca (≤100 km) y 0 en el entorno regional (≤300 km).")
        XCTAssertEqual(one.lines[0].phrase, "Sol en el Medio Cielo · 4.3 km")
        XCTAssertNil(one.lines[0].gist) // visible degradation: no editorial text, line still listed
        let empty = AstroPlaceSummaryBuilder.build(placeName: "Vacío", analysis: try syntheticAnalysis([]), policy: policy, catalog: .unavailable("x"))
        XCTAssertEqual(empty.headline, "Vacío: sin líneas con distancia definida.")
    }

    // MARK: Place ranking

    func testPlaceRankingByThemeOrdersByNearThenRegionalThenDistanceThenName() throws {
        let policy = try AstroProximityPolicy()
        func place(_ name: String, _ lines: [(AstroBody, AstroAngle, Double)]) throws -> AstroRankablePlace {
            AstroRankablePlace(id: name, name: name, analysis: try syntheticAnalysis(lines))
        }
        let places = [
            try place("Zeta", [(.sun, .mc, 250)]),                        // regional only
            try place("Beta", [(.sun, .mc, 30), (.moon, .mc, 40)]),       // 2 near
            try place("Alfa", [(.sun, .mc, 20)]),                         // 1 near, 20 km
            try place("Gamma", [(.sun, .mc, 60)]),                        // 1 near, 60 km
            try place("Delta", [(.sun, .asc, 5)]),                        // nothing in career
            try place("Ceta", [(.sun, .asc, 6)]),                         // nothing in career, ties with Delta
            try place("Omega", [(.moon, .mc, 20)]),                       // ties with Alfa: 1 near, 20 km
        ]
        let ranking = AstroPlaceRanking.rank(places: places, theme: .career, policy: policy)
        XCTAssertEqual(ranking.map(\.place.name), ["Beta", "Alfa", "Omega", "Gamma", "Zeta", "Ceta", "Delta"])
        XCTAssertEqual(ranking.map(\.rank), Array(1...7))
        XCTAssertEqual(ranking[0].activity.nearCount, 2)
        XCTAssertNil(ranking[5].activity.nearest) // no career line with distance → last, no invented value
        XCTAssertTrue(AstroPlaceRanking.rank(places: [], theme: .home, policy: policy).isEmpty)
        // A different theme reorders without touching the analyses.
        XCTAssertEqual(AstroPlaceRanking.rank(places: places, theme: .identity, policy: policy).first?.place.name, "Delta")
    }

    // MARK: View-model: filters, emphasis, summary and rankable places

    @MainActor
    func testViewModelThemeFilterEmphasisSummaryAndRankablePlaces() async throws {
        let model = AstrocartographyViewModel()
        XCTAssertNil(model.placeSummary); XCTAssertNil(model.emphasizedLines); XCTAssertTrue(model.rankablePlaces.isEmpty)
        await model.load(AstroChartInput(try natal()))
        XCTAssertEqual(model.visibleLines.count, 40)
        model.theme = .career
        XCTAssertEqual(model.visibleLines.count, 10)
        XCTAssertTrue(model.visibleLines.allSatisfy { $0.id.angle == .mc })
        model.selectedLine = AstroLineID(body: .sun, angle: .asc)
        model.reconcileSelection(); XCTAssertNil(model.selectedLine) // outside the theme
        model.bodies = [.sun, .moon]; XCTAssertEqual(model.visibleLines.count, 2)
        model.bodies = Set(AstroBody.allCases)

        await model.search(query: "Madrid", online: false)
        model.select(try XCTUnwrap(model.searchResults.first))
        await model.analyzePlace()
        let analysis = try XCTUnwrap(model.placeCalculation?.analysis)
        // Filters never change the global summary or the stored analysis.
        let summaryWithTheme = try XCTUnwrap(model.placeSummary)
        model.theme = nil
        XCTAssertEqual(try XCTUnwrap(model.placeSummary), summaryWithTheme)
        XCTAssertEqual(model.placeCalculation?.analysis, analysis)
        XCTAssertEqual(analysis.proximities.count, 40)

        // Emphasis: widen the thresholds so lines are certainly nearby.
        model.proximityPolicy = try AstroProximityPolicy(nearKm: 6000, regionalKm: 12000)
        let all = try XCTUnwrap(model.emphasizedLines)
        XCTAssertEqual(all.count, 40)
        model.theme = .career
        XCTAssertEqual(try XCTUnwrap(model.emphasizedLines), Set(AstroTheme.career.lines))
        model.emphasizeNearby = false; XCTAssertNil(model.emphasizedLines)
        model.emphasizeNearby = true
        model.proximityPolicy = try AstroProximityPolicy(nearKm: 0.001, regionalKm: 0.002)
        XCTAssertNil(model.emphasizedLines) // nothing nearby → no dimming of the whole map
        model.proximityPolicy = try AstroProximityPolicy()

        XCTAssertEqual(model.visibleProximities.count, 10)
        let readings = try XCTUnwrap(model.placeReadings(onlyVisible: true, includeDistant: true))
        XCTAssertEqual(readings.items.count, 10)
        XCTAssertTrue(readings.items.allSatisfy { $0.proximity.lineID.angle == .mc })
        XCTAssertEqual(readings.coverage.total, 40)

        model.addComparison()
        let rankable = model.rankablePlaces
        XCTAssertEqual(rankable.count, 1); XCTAssertEqual(rankable[0].analysis, analysis)
        XCTAssertEqual(AstroPlaceRanking.rank(places: rankable, theme: .career, policy: model.proximityPolicy).count, 1)
        model.cancel()
        XCTAssertNil(model.emphasizedLines)
    }

    func testPanelSectionsStartWithGuideAndAreUnique() {
        XCTAssertEqual(AstroPanelSection.allCases.first, .guia)
        XCTAssertEqual(AstroPanelSection.allCases.map(\.rawValue), ["Guía", "Mapa", "Lugar", "Relocada", "Comparar", "Datos"])
        XCTAssertEqual(Set(AstroPanelSection.allCases.map(\.systemImage)).count, 6)
    }

    // MARK: Helpers

    private func catalog() throws -> AstroReadingCatalog { .loaded(try AstrocartographyReadingLibrary.bundled()) }

    private func syntheticAnalysis(_ lines: [(AstroBody, AstroAngle, Double)]) throws -> LocationAnalysis {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545))
        let location = try GeoCoordinate(latitude: 40, longitude: -3)
        let proximities = lines.map {
            AstroLineProximity(lineID: AstroLineID(body: $0.0, angle: $0.1), distanceKm: $0.2, nearestPoint: location, estimatedErrorKm: 0.001)
        }.sorted { $0.distanceKm < $1.distanceKm }
        return LocationAnalysis(request: request, location: location, proximities: proximities, sphereRadiusKm: AstroLocationAnalyzer.sphereRadiusKm)
    }

    private func natal() throws -> NatalChart {
        try SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")!.deletingLastPathComponent().path)
            var c = try AstroEngine.computeNatalChart(jd: 2451545, lat: 40.4, lon: -3.7)
            c.birthDate = "2000-01-01"; c.birthTime = "12:00:00"; c.timezone = "UTC"
            return c
        }
    }
}
