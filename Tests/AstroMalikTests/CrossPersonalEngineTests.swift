import XCTest
import CSwissEph
@testable import AstroMalik

final class CrossPersonalEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testEngineProducesAnnualSignalsForReferenceChart() async throws {
        let chart = try referenceChart()
        let state = try await referenceCrossState(chart: chart)
        let annual = try XCTUnwrap(state.layer(.annual))
        let sources = Set(annual.signals.map(\.source))

        XCTAssertTrue(sources.contains("profection"))
        XCTAssertTrue(sources.contains("profection_loty"))
        XCTAssertTrue(sources.contains("firdaria_major"))
        XCTAssertTrue(sources.contains("zr_l1_spirit"))
        XCTAssertTrue(sources.contains("zr_l1_fortune"))
    }

    func testEngineProducesMediumAndShortTermLayers() async throws {
        let chart = try referenceChart()
        let state = try await referenceCrossState(chart: chart)

        XCTAssertFalse(try XCTUnwrap(state.layer(.mediumTerm)).signals.isEmpty)
        XCTAssertFalse(try XCTUnwrap(state.layer(.shortTerm)).signals.isEmpty)
        XCTAssertTrue(state.topics.contains { $0.layerCount >= 2 })
    }

    func testConvergenceBonusIncreasesScoreWithMoreLayers() async throws {
        let base = try await referenceCrossInputs()
        let venusMedium = syntheticProgressedAspect(targetKey: "VENUS", targetLabel: "♀ Venus", date: base.referenceDate)
        let venusShort = syntheticTransit(natalKey: "VENUS", natalLabel: "♀ Venus", exact: base.referenceDate)

        let twoLayerInputs = copyInputs(base, progressedAspects: [venusMedium], transits: [])
        let twoLayerState = CrossPersonalEngine.state(inputs: twoLayerInputs)
        let twoLayerVenus = try XCTUnwrap(twoLayerState.topics.first { $0.subject.key == "VENUS" })
        XCTAssertGreaterThan(twoLayerVenus.convergenceScore, 1.0)

        let threeLayerInputs = copyInputs(base, progressedAspects: [venusMedium], transits: [venusShort])
        let threeLayerState = CrossPersonalEngine.state(inputs: threeLayerInputs)
        let threeLayerVenus = try XCTUnwrap(threeLayerState.topics.first { $0.subject.key == "VENUS" })

        XCTAssertGreaterThan(threeLayerVenus.layerCount, twoLayerVenus.layerCount)
        XCTAssertGreaterThan(threeLayerVenus.convergenceScore, twoLayerVenus.convergenceScore)
    }

    func testLordOfTheYearBonusApplied() async throws {
        let base = try await referenceCrossInputs(lordOfYear: "VENUS")
        let date = base.referenceDate
        let venusMedium = syntheticProgressedAspect(targetKey: "VENUS", targetLabel: "♀ Venus", date: date)
        let marsMedium = syntheticProgressedAspect(targetKey: "MARTE", targetLabel: "♂ Marte", date: date)
        let venusShort = syntheticTransit(natalKey: "VENUS", natalLabel: "♀ Venus", exact: date)
        let marsShort = syntheticTransit(natalKey: "MARTE", natalLabel: "♂ Marte", exact: date)
        let marsAnnual = FirdariaPeriod(
            id: "synthetic-major-mars",
            kind: .major,
            ruler: .marte,
            cycleIndex: 0,
            sequenceIndex: 0,
            startDate: date.addingTimeInterval(-1000),
            endDate: date.addingTimeInterval(1000),
            nominalYears: 1
        )

        let inputs = copyInputs(
            base,
            progressedAspects: [venusMedium, marsMedium],
            firdariaMajor: marsAnnual,
            transits: [venusShort, marsShort]
        )
        let state = CrossPersonalEngine.state(inputs: inputs)
        let venus = try XCTUnwrap(state.topics.first { $0.subject.key == "VENUS" })
        let mars = try XCTUnwrap(state.topics.first { $0.subject.key == "MARTE" })

        XCTAssertGreaterThan(venus.convergenceScore, mars.convergenceScore)
    }

    func testTopicsAreSortedByScoreDescending() async throws {
        let state = try await referenceCrossState()
        let scores = state.topics.map(\.convergenceScore)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func testStateIsJSONSerializable() async throws {
        let state = try await referenceCrossState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CrossPersonalState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}

private func referenceCrossState(chart: NatalChart? = nil) async throws -> CrossPersonalState {
    try await CrossPersonalAssembler.state(
        chart: chart ?? referenceChart(),
        referenceDate: localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid"),
        corpusStore: try referenceCorpusStore(),
        options: CrossPersonalOptions(topTopicsLimit: 20, subjectScoringBonus: .default, convergenceMultipliers: .default, eclipseLunarMultiplier: 2.0)
    )
}

private func referenceCrossInputs(lordOfYear: String? = nil) async throws -> CrossPersonalInputs {
    let chart = try referenceChart()
    let inputs = try await CrossPersonalAssembler.assemble(
        chart: chart,
        referenceDate: localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid"),
        corpusStore: try referenceCorpusStore()
    )
    guard let lordOfYear else { return inputs }
    var annual = inputs.profections.annual
    annual.lordKey = lordOfYear
    annual.lordLabel = planetLabelForTest(lordOfYear)
    let profections = ProfectionResult(annual: annual, monthly: [], daily: [], activations: [])
    return copyInputs(inputs, profections: profections, solarReturn: nil, primaryDirections: [], solarArc: [], progressedAspects: [], transits: [], upcomingLunations: [], upcomingEclipses: [])
}

private func copyInputs(
    _ base: CrossPersonalInputs,
    profections: ProfectionResult? = nil,
    solarReturn: SolarReturnReading? = nil,
    primaryDirections: [PrimaryDirection]? = nil,
    solarArc: [SolarArcDirection]? = nil,
    progressedAspects: [ProgressedAspect]? = nil,
    firdariaMajor: FirdariaPeriod? = nil,
    firdariaMinor: FirdariaPeriod? = nil,
    transits: [TransitEvent]? = nil,
    upcomingLunations: [LunarPointHit]? = nil,
    upcomingEclipses: [LunarPointHit]? = nil
) -> CrossPersonalInputs {
    CrossPersonalInputs(
        chart: base.chart,
        referenceDate: base.referenceDate,
        natalExtended: base.natalExtended,
        profections: profections ?? base.profections,
        solarReturn: solarReturn,
        primaryDirections: primaryDirections ?? base.primaryDirections,
        solarArc: solarArc ?? base.solarArc,
        progressionSnapshot: base.progressionSnapshot,
        progressedAspects: progressedAspects ?? base.progressedAspects,
        firdariaMajor: firdariaMajor ?? base.firdariaMajor,
        firdariaMinor: firdariaMinor ?? base.firdariaMinor,
        firdariaUpcoming: base.firdariaUpcoming,
        zrSpirit: base.zrSpirit,
        zrFortune: base.zrFortune,
        transits: transits ?? base.transits,
        upcomingLunations: upcomingLunations ?? base.upcomingLunations,
        upcomingEclipses: upcomingEclipses ?? base.upcomingEclipses
    )
}

private func syntheticProgressedAspect(targetKey: String, targetLabel: String, date: Date) -> ProgressedAspect {
    ProgressedAspect(
        id: "synthetic-progressed-\(targetKey)",
        kind: .progressedToNatal,
        date: date,
        exactDate: "2026-05-14",
        progressedKey: "SOL",
        progressedLabel: "☉ Sol progresado",
        targetKey: targetKey,
        targetLabel: targetLabel,
        aspectKey: "CONJUNCION",
        aspectLabel: "☌ Conjunción",
        orb: 0,
        applying: true,
        priority: 2,
        progressedRetrograde: false
    )
}

private func syntheticTransit(natalKey: String, natalLabel: String, exact: Date) -> TransitEvent {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    let day = formatter.string(from: exact)
    return TransitEvent(
        transitKey: "SATURNO",
        transitLabel: "♄ Saturno",
        natalKey: natalKey,
        natalLabel: natalLabel,
        aspectKey: "CONJUNCION",
        aspectLabel: "☌ Conjunción",
        color: "#7C3AED",
        fromDate: day,
        toDate: day,
        exactDate: day,
        activeDays: 1,
        minOrb: 0,
        retrogradeOnExact: false,
        score: 20,
        stars: 4,
        technicalScore: 20,
        technicalStars: 4,
        personalRelevance: 1,
        temporalImpact: 1,
        priorityScore: 0.7,
        priorityStars: 4,
        priorityBand: .high,
        metricReasons: ["Sintético"],
        text: nil,
        source: nil,
        samples: []
    )
}

private func referenceChart(
    birthDate: String = "1976-10-11",
    birthTime: String = "20:33",
    timezoneName: String = "Europe/Madrid",
    lat: Double = 40.4168,
    lon: Double = -3.7038
) throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: birthDate,
        birthTime: birthTime,
        timezoneName: timezoneName
    )
    var chart = try AstroEngine.computeNatalChart(
        jd: jdResult.jd,
        lat: lat,
        lon: lon
    )
    chart.name = "Referencia"
    chart.birthDate = birthDate
    chart.birthTime = birthTime
    chart.timezone = timezoneName
    return chart
}

private func referenceCorpusStore() throws -> CorpusStore {
    try CorpusStore(path: referenceCorpusURL().path)
}

private func referenceCorpusURL() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let repoRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return repoRoot
        .appendingPathComponent("Sources/AstroMalik/Resources/corpus.db")
}

private func localDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int = 0,
    timezoneName: String
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timezoneName) ?? TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )) ?? Date()
}

private func planetLabelForTest(_ key: String) -> String {
    AstroPlanetKey(rawValue: key)?.label ?? key
}
