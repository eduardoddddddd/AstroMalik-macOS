import XCTest
import CSwissEph
@testable import AstroMalik

final class SecondaryProgressionEngineTests: XCTestCase {
    private let engine = SecondaryProgressionEngine()

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testProgressedMoonAtAge49MatchesSwissEphemerisDayForYear() throws {
        let chart = try referenceChart()
        let natalJD = try julianDayFromLocal(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ).jd
        let targetDate = try dateAtAge(49, chart: chart)
        let snapshot = engine.progressions(chart: chart, at: targetDate)
        let moon = try XCTUnwrap(snapshot.bodies.first { $0.key == "LUNA" })

        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(natalJD + 49.0, SE_MOON, SEFLG_SPEED, &xx, &serr)
        XCTAssertGreaterThanOrEqual(rc, 0, String(cString: serr))
        XCTAssertEqual(moon.longitude, normalized(xx[0]), accuracy: 0.02)
        XCTAssertEqual(snapshot.progressedJulianDay, natalJD + 49.0, accuracy: 0.002)
    }

    func testProgressedSunAtAge49AdvancesAboutFortyEightDegrees() throws {
        let chart = try referenceChart()
        let targetDate = try dateAtAge(49, chart: chart)
        let snapshot = engine.progressions(chart: chart, at: targetDate)
        let progressedSun = try XCTUnwrap(snapshot.bodies.first { $0.key == "SOL" })
        let natalSun = try XCTUnwrap(chart.bodies.first { $0.key == "SOL" })
        let advance = normalized(progressedSun.longitude - natalSun.longitude)
        XCTAssertEqual(advance, 48.25, accuracy: 1.0)
    }

    func testProgressedLunarPhaseIsCalculatedFromSunMoonAngle() throws {
        let chart = try referenceChart()
        let targetDate = try dateAtAge(49, chart: chart)
        let snapshot = engine.progressions(chart: chart, at: targetDate)
        let sun = try XCTUnwrap(snapshot.bodies.first { $0.key == "SOL" })
        let moon = try XCTUnwrap(snapshot.bodies.first { $0.key == "LUNA" })
        let phaseAngle = normalized(moon.longitude - sun.longitude)
        let expectedIndex = Int(floor(phaseAngle / 45.0)) % 8
        let expected = ProgressedLunarPhaseName.allCases[expectedIndex]

        XCTAssertEqual(snapshot.lunarPhase.angle, phaseAngle, accuracy: 0.01)
        XCTAssertEqual(snapshot.lunarPhase.name, expected)
        XCTAssertFalse(snapshot.nextLunarPhaseTransitions.isEmpty)
    }

    func testProgressedAspectsReturnsAtLeastOneEventInOneYearWindow() throws {
        let chart = try referenceChart()
        let center = try dateAtAge(49, chart: chart)
        let from = Calendar(identifier: .gregorian).date(byAdding: .year, value: -1, to: center) ?? center
        let to = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: center) ?? center
        let events = engine.progressedAspects(chart: chart, from: from, to: to)
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.contains { $0.kind == .progressedToNatal })
    }

    private func referenceChart() throws -> NatalChart {
        let jdResult = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        var chart = try AstroEngine.computeNatalChart(jd: jdResult.jd, lat: 40.4168, lon: -3.7038)
        chart.name = "Referencia progresiones"
        chart.birthDate = "1976-10-11"
        chart.birthTime = "20:33"
        chart.timezone = "Europe/Madrid"
        chart.placeName = "Madrid"
        return chart
    }

    private func dateAtAge(_ age: Double, chart: NatalChart) throws -> Date {
        let parts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let time = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .gmt
        let birth = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: parts[0], month: parts[1], day: parts[2],
            hour: time[0], minute: time[1]
        )))
        return birth.addingTimeInterval(age * 365.2422 * 86_400.0)
    }

    private func normalized(_ degree: Double) -> Double {
        var d = degree.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }
}
