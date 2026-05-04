import XCTest
import CSwissEph
@testable import AstroMalik

final class EclipseCalculatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testFindEclipsesFor2026ReturnsSolarAndLunarEclipses() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let events = try await EclipseCalculator.findEclipses(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        )

        let solar = events.filter { $0.kind == .solarEclipse }
        let lunar = events.filter { $0.kind == .lunarEclipse }

        XCTAssertGreaterThanOrEqual(solar.count, 2)
        XCTAssertGreaterThanOrEqual(lunar.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.importance == .critical })
        XCTAssertTrue(events.allSatisfy { $0.dateUTC.hasPrefix("2026-") })
        XCTAssertTrue(events.allSatisfy { $0.eclipseType != nil && $0.signKey != nil && $0.longitude != nil })
    }

    func testKnown2026SolarEclipseTypesAndApproximateDates() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let solar = try await EclipseCalculator.findEclipses(
            from: startJD,
            to: endJD,
            timezone: "UTC"
        ).filter { $0.kind == .solarEclipse }

        XCTAssertTrue(solar.contains { $0.eclipseType == "anular" && $0.dateUTC.hasPrefix("2026-02") })
        XCTAssertTrue(solar.contains { $0.eclipseType == "total" && $0.dateUTC.hasPrefix("2026-08") })
    }

    func testKnown2026LunarEclipseTypesAndApproximateDates() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let lunar = try await EclipseCalculator.findEclipses(
            from: startJD,
            to: endJD,
            timezone: "UTC"
        ).filter { $0.kind == .lunarEclipse }

        XCTAssertTrue(lunar.contains { $0.eclipseType == "total" && $0.dateUTC.hasPrefix("2026-03") })
        XCTAssertTrue(lunar.contains { ($0.eclipseType == "parcial" || $0.eclipseType == "penumbral") && $0.dateUTC.hasPrefix("2026-08") })
    }

    private func jdRange(year: Int32) -> (Double, Double) {
        let start = swe_julday(year, 1, 1, 0, SE_GREG_CAL)
        let end = swe_julday(year + 1, 1, 1, 0, SE_GREG_CAL)
        return (start, end)
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
