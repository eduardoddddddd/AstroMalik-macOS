import XCTest
@testable import AstroMalik

final class MonthlySummaryEngineTests: XCTestCase {

    func testLunationsProduceNatalHouseAndNarrative() {
        let chart = makeChart()
        let month = EphemerisMonth(
            id: "2026-06",
            year: 2026,
            month: 6,
            events: [
                makeEvent(kind: .newMoon, date: "2026-06-15", longitude: 105, title: "Luna Nueva en Cáncer"),
                makeEvent(kind: .fullMoon, date: "2026-06-29", longitude: 285, title: "Luna Llena en Capricornio"),
            ],
            dailyRows: []
        )

        let summary = MonthlySummaryEngine.generateSummary(
            ephemeris: month,
            natalChart: chart,
            transits: [],
            ingresses: []
        )

        XCTAssertEqual(summary.lunationHits.count, 2)
        for hit in summary.lunationHits {
            XCTAssertTrue((1...12).contains(hit.natalHouse))
            XCTAssertFalse(hit.narrative.isEmpty)
        }
    }

    func testLunationConjunctionOrbIsDetectedWithinFiveDegrees() {
        let chart = makeChart(bodies: [
            PlanetBody(key: "SOL", label: "☉ Sol", longitude: 104.2, formatted: "♋ Cáncer 14°12'", house: 4, retrograde: false),
            PlanetBody(key: "LUNA", label: "☽ Luna", longitude: 250, formatted: "♐ Sagitario 10°00'", house: 9, retrograde: false),
        ])
        let month = EphemerisMonth(
            id: "2026-06",
            year: 2026,
            month: 6,
            events: [makeEvent(kind: .newMoon, date: "2026-06-15", longitude: 105, title: "Luna Nueva")],
            dailyRows: []
        )

        let summary = MonthlySummaryEngine.generateSummary(
            ephemeris: month,
            natalChart: chart,
            transits: [],
            ingresses: []
        )

        let conjunction = summary.lunationHits.first?.conjunctPlanet
        XCTAssertEqual(conjunction?.planetKey, "SOL")
        XCTAssertLessThanOrEqual(conjunction?.orb ?? 99, 5.0)
    }

    func testStationOnNatalPlanetWithinThreeDegreesIsDetected() {
        let chart = makeChart(bodies: [
            PlanetBody(key: "LUNA", label: "☽ Luna", longitude: 102.5, formatted: "♋ Cáncer 12°30'", house: 4, retrograde: false),
        ])
        let month = EphemerisMonth(
            id: "2026-06",
            year: 2026,
            month: 6,
            events: [makeEvent(kind: .stationRetrograde, date: "2026-06-20", longitude: 104, title: "Saturno estacionario", planetKeyA: "SATURNO", planetLabelA: "Saturno")],
            dailyRows: []
        )

        let summary = MonthlySummaryEngine.generateSummary(
            ephemeris: month,
            natalChart: chart,
            transits: [],
            ingresses: []
        )

        XCTAssertEqual(summary.stationHits.count, 1)
        XCTAssertEqual(summary.stationHits.first?.natalPlanetKey, "LUNA")
        XCTAssertFalse(summary.stationHits.first?.narrative.isEmpty ?? true)
    }

    func testClimateVariesForEclipsesStationsAndPriorityTransits() {
        let chart = makeChart()
        let quietMonth = EphemerisMonth(id: "2026-06", year: 2026, month: 6, events: [], dailyRows: [])
        let loudMonth = EphemerisMonth(
            id: "2026-06",
            year: 2026,
            month: 6,
            events: [makeEvent(kind: .solarEclipse, date: "2026-06-15", longitude: 0, title: "Eclipse solar")],
            dailyRows: []
        )

        let quiet = MonthlySummaryEngine.generateSummary(ephemeris: quietMonth, natalChart: chart, transits: [], ingresses: [])
        let loud = MonthlySummaryEngine.generateSummary(
            ephemeris: loudMonth,
            natalChart: chart,
            transits: [makeTransit(from: "2026-05-20", to: "2026-06-20", priorityScore: 50, band: .critical)],
            ingresses: []
        )

        XCTAssertFalse(quiet.climateSummary.isEmpty)
        XCTAssertFalse(loud.climateSummary.isEmpty)
        XCTAssertNotEqual(quiet.climateSummary, loud.climateSummary)
        XCTAssertTrue(loud.climateSummary.contains("eclipse") || loud.climateSummary.contains("tránsito"))
    }

    func testActiveTransitsAreFilteredLimitedAndSorted() {
        let chart = makeChart()
        let month = EphemerisMonth(id: "2026-06", year: 2026, month: 6, events: [], dailyRows: [])
        let transits = [
            makeTransit(from: "2026-04-01", to: "2026-05-15", priorityScore: 999, band: .critical),
            makeTransit(from: "2026-06-10", to: "2026-06-20", priorityScore: 10, band: .low),
            makeTransit(from: "2026-05-25", to: "2026-06-05", priorityScore: 80, band: .high),
            makeTransit(from: "2026-06-30", to: "2026-07-10", priorityScore: 70, band: .high),
            makeTransit(from: "2026-07-01", to: "2026-07-31", priorityScore: 888, band: .critical),
        ] + (0..<10).map { index in
            makeTransit(from: "2026-06-01", to: "2026-06-02", priorityScore: Double(60 - index), band: .medium)
        }

        let summary = MonthlySummaryEngine.generateSummary(
            ephemeris: month,
            natalChart: chart,
            transits: transits,
            ingresses: []
        )

        XCTAssertEqual(summary.activeTransits.count, 8)
        XCTAssertFalse(summary.activeTransits.contains { $0.priorityScore == 999 || $0.priorityScore == 888 })
        XCTAssertEqual(summary.activeTransits.map(\.priorityScore), summary.activeTransits.map(\.priorityScore).sorted(by: >))
    }

    private func makeChart(bodies: [PlanetBody]? = nil) -> NatalChart {
        NatalChart(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Carta Test",
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            houseSystem: "Placidus",
            ascendant: AngularPoint(longitude: 0, formatted: "♈ Aries 00°00'"),
            mc: AngularPoint(longitude: 270, formatted: "♑ Capricornio 00°00'"),
            cusps: stride(from: 0.0, to: 360.0, by: 30.0).map { $0 },
            bodies: bodies ?? [
                PlanetBody(key: "SOL", label: "☉ Sol", longitude: 100, formatted: "♋ Cáncer 10°00'", house: 4, retrograde: false),
                PlanetBody(key: "LUNA", label: "☽ Luna", longitude: 280, formatted: "♑ Capricornio 10°00'", house: 10, retrograde: false),
                PlanetBody(key: "VENUS", label: "♀ Venus", longitude: 40, formatted: "♉ Tauro 10°00'", house: 2, retrograde: false),
            ]
        )
    }

    private func makeEvent(
        kind: CelestialEventKind,
        date: String,
        longitude: Double,
        title: String,
        planetKeyA: String? = nil,
        planetLabelA: String? = nil
    ) -> CelestialEvent {
        CelestialEvent(
            kind: kind,
            dateUTC: "\(date) 00:00 UTC",
            dateLocal: "\(date) 02:00",
            longitude: longitude,
            signKey: AstroEngine.degToSignKey(longitude),
            signLabel: AstroEngine.degToSign(longitude),
            formatted: AstroEngine.degToSign(longitude),
            planetKeyA: planetKeyA,
            planetLabelA: planetLabelA,
            eclipseType: kind == .solarEclipse || kind == .lunarEclipse ? "parcial" : nil,
            title: title,
            subtitle: nil,
            importance: kind == .solarEclipse || kind == .lunarEclipse ? .critical : .major
        )
    }

    private func makeTransit(
        from: String,
        to: String,
        priorityScore: Double,
        band: TransitPriorityBand
    ) -> TransitEvent {
        TransitEvent(
            transitKey: "SATURNO",
            transitLabel: "Saturno",
            natalKey: "SOL",
            natalLabel: "Sol",
            aspectKey: "CONJUNCION",
            aspectLabel: "Conjunción",
            color: "#d97706",
            fromDate: from,
            toDate: to,
            exactDate: from,
            activeDays: 1,
            minOrb: 0.5,
            retrogradeOnExact: false,
            score: priorityScore,
            stars: 5,
            priorityScore: priorityScore,
            priorityStars: band == .critical ? 5 : 4,
            priorityBand: band,
            metricReasons: ["Test"]
        )
    }
}
