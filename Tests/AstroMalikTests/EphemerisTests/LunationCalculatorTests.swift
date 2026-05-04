import XCTest
import CSwissEph
@testable import AstroMalik

final class LunationCalculatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testBisectAngularCrossingWithLinearFunction() throws {
        let jd = try bisectAngularCrossing(
            startJD: 10,
            endJD: 20,
            target: 15,
            toleranceJD: 0.000001,
            angularFunction: { $0 }
        )
        XCTAssertEqual(jd, 15, accuracy: 0.00001)
    }

    func testBisectAngularCrossingAcrossZeroDegreeWrap() throws {
        let jd = try bisectAngularCrossing(
            startJD: 0,
            endJD: 2,
            target: 0,
            toleranceJD: 0.000001,
            angularFunction: { sampleJD in
                // 359° → 0° → 1° across the search interval.
                EphemerisUtilities.normalizedDegree(359 + sampleJD)
            }
        )
        XCTAssertEqual(jd, 1, accuracy: 0.00001)
    }

    func testFindLunationsForJune2026FindsOneNewAndOneFullMoon() async throws {
        let (startJD, endJD) = jdRange(year: 2026, month: 6)
        let events = try await LunationCalculator.findLunations(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        )

        XCTAssertEqual(events.filter { $0.kind == .newMoon }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .fullMoon }.count, 1)
        XCTAssertTrue(events.allSatisfy { $0.importance == .major })
        XCTAssertTrue(events.allSatisfy { $0.longitude != nil && $0.signKey != nil })
    }

    func testJune2026LunationSignsAreStable() async throws {
        let (startJD, endJD) = jdRange(year: 2026, month: 6)
        let events = try await LunationCalculator.findLunations(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        )

        let newMoon = try XCTUnwrap(events.first { $0.kind == .newMoon })
        let fullMoon = try XCTUnwrap(events.first { $0.kind == .fullMoon })

        XCTAssertEqual(newMoon.signKey, "GEMINIS")
        XCTAssertEqual(fullMoon.signKey, "CAPRICORNIO")
    }

    func testLunarPhaseLabelsNearKnownJune2026Lunations() throws {
        // Valores aproximados UTC dentro de las ventanas de lunación calculadas por Swiss Ephemeris/Moshier.
        let newMoonJD = swe_julday(2026, 6, 15, 2.0, SE_GREG_CAL)
        let fullMoonJD = swe_julday(2026, 6, 29, 12.0, SE_GREG_CAL)

        let newPhase = try LunationCalculator.lunarPhase(at: newMoonJD)
        let fullPhase = try LunationCalculator.lunarPhase(at: fullMoonJD)

        XCTAssertEqual(newPhase.label, "Nueva")
        XCTAssertEqual(fullPhase.label, "Llena")
        XCTAssertTrue((0..<360).contains(newPhase.angle))
        XCTAssertTrue((0..<360).contains(fullPhase.angle))
    }

    func testFindQuartersForJune2026ReturnsTwoQuarters() async throws {
        let (startJD, endJD) = jdRange(year: 2026, month: 6)
        let events = try await LunationCalculator.findQuarters(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        )

        XCTAssertEqual(events.filter { $0.kind == .firstQuarter }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .lastQuarter }.count, 1)
    }

    private func jdRange(year: Int32, month: Int32) -> (Double, Double) {
        let start = swe_julday(year, month, 1, 0, SE_GREG_CAL)
        let nextMonth = month == 12 ? 1 : month + 1
        let nextYear = month == 12 ? year + 1 : year
        let end = swe_julday(nextYear, nextMonth, 1, 0, SE_GREG_CAL)
        return (start, end)
    }
}
