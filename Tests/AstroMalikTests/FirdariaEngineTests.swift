import XCTest
@testable import AstroMalik

final class FirdariaEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testNocturnalOrderStartsWithMoonForNineYears() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()

        let timeline = engine.firdariaPeriods(chart: chart)
        let first = try XCTUnwrap(timeline.majorPeriods.first)

        XCTAssertFalse(timeline.sect.isDiurnal)
        XCTAssertEqual(first.ruler, .luna)
        XCTAssertEqual(first.nominalYears, 9, accuracy: 0.0001)
        XCTAssertEqual(timeline.majorPeriods.map(\.ruler), [
            .luna, .saturno, .jupiter, .marte, .sol, .venus, .mercurio, .nodoNorte, .nodoSur,
        ])
    }

    func testAge49IsVenusMajorAndCoherentMinor() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()
        let date = firdariaLocalDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")

        let current = engine.currentFirdaria(chart: chart, at: date)
        let minor = try XCTUnwrap(current.minor)

        XCTAssertEqual(current.major.ruler, .venus)
        XCTAssertEqual(current.major.startDate, firdariaLocalDate(year: 2025, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
        XCTAssertEqual(current.major.endDate, firdariaLocalDate(year: 2033, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
        XCTAssertEqual(minor.ruler, .venus)
        XCTAssertEqual(minor.startDate, current.major.startDate)
        XCTAssertTrue(minor.startDate <= date)
        XCTAssertTrue(date < minor.endDate)
        XCTAssertEqual(engine.minorPeriods(for: current.major, sect: SectEngine.sect(of: chart)).map(\.ruler), [
            .venus, .mercurio, .luna, .saturno, .jupiter, .marte, .sol,
        ])
    }

    func testNodesAreNotSubdivided() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()
        let nodeDate = firdariaLocalDate(year: 2047, month: 1, day: 1, hour: 12, timezoneName: "Europe/Madrid")

        let current = engine.currentFirdaria(chart: chart, at: nodeDate)

        XCTAssertEqual(current.major.ruler, .nodoNorte)
        XCTAssertNil(current.minor)
    }

    func testCycleRestartsAfter75Years() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()
        let after75 = firdariaLocalDate(year: 2051, month: 10, day: 12, hour: 12, timezoneName: "Europe/Madrid")

        let current = engine.currentFirdaria(chart: chart, at: after75)

        XCTAssertEqual(current.major.cycleIndex, 1)
        XCTAssertEqual(current.major.ruler, .luna)
        XCTAssertEqual(current.major.startDate, firdariaLocalDate(year: 2051, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
    }

    func testTimelineAtDateReturnsMatchingCycle() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()
        let after75 = firdariaLocalDate(year: 2051, month: 10, day: 12, hour: 12, timezoneName: "Europe/Madrid")

        let timeline = engine.firdariaTimeline(chart: chart, at: after75)

        XCTAssertEqual(timeline.cycleIndex, 1)
        XCTAssertEqual(timeline.majorPeriods.first?.ruler, .luna)
        XCTAssertEqual(timeline.cycleStartDate, firdariaLocalDate(year: 2051, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
    }

    func testUpcomingMinorChangesReturnsFiveDates() throws {
        let chart = try firdariaReferenceChart()
        let engine = FirdariaEngine()
        let date = firdariaLocalDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")

        let changes = engine.upcomingMinorChanges(chart: chart, at: date, limit: 5)

        XCTAssertEqual(changes.count, 5)
        XCTAssertTrue(changes.allSatisfy { $0.date > date })
        XCTAssertEqual(Array(changes.map { $0.period.ruler }.prefix(4)), [.mercurio, .luna, .saturno, .jupiter])
    }
}

private func firdariaReferenceChart() throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: "1976-10-11",
        birthTime: "20:33",
        timezoneName: "Europe/Madrid"
    )
    var chart = try AstroEngine.computeNatalChart(
        jd: jdResult.jd,
        lat: 40.4168,
        lon: -3.7038
    )
    chart.name = "Referencia"
    chart.birthDate = "1976-10-11"
    chart.birthTime = "20:33"
    chart.timezone = "Europe/Madrid"
    chart.placeName = "Madrid"
    return chart
}

private func firdariaLocalDate(
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
