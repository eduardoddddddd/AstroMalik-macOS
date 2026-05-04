import XCTest
import CSwissEph
@testable import AstroMalik

final class StationCalculatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testMercuryHasThreeRetrogradeAndThreeDirectStationsIn2026() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let mercury = try await StationCalculator.findStations(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        ).filter { $0.planetKeyA == "MERCURIO" }

        XCTAssertEqual(mercury.filter { $0.kind == .stationRetrograde }.count, 3)
        XCTAssertEqual(mercury.filter { $0.kind == .stationDirect }.count, 3)
        XCTAssertTrue(mercury.allSatisfy { abs($0.stationSpeed ?? 1) < 0.01 })
        XCTAssertTrue(mercury.allSatisfy { $0.importance == .major })
    }

    func testSaturnHasOneRetrogradeAndOneDirectStationIn2026() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let saturn = try await StationCalculator.findStations(
            from: startJD,
            to: endJD,
            timezone: "Europe/Madrid"
        ).filter { $0.planetKeyA == "SATURNO" }

        XCTAssertEqual(saturn.filter { $0.kind == .stationRetrograde }.count, 1)
        XCTAssertEqual(saturn.filter { $0.kind == .stationDirect }.count, 1)
        XCTAssertTrue(saturn.allSatisfy { abs($0.stationSpeed ?? 1) < 0.01 })
    }

    func testAll2026StationsHaveDateLongitudeAndNearZeroSpeed() async throws {
        let (startJD, endJD) = jdRange(year: 2026)
        let stations = try await StationCalculator.findStations(
            from: startJD,
            to: endJD,
            timezone: "UTC"
        )

        XCTAssertGreaterThan(stations.count, 10)
        XCTAssertTrue(stations.allSatisfy { $0.dateUTC.hasPrefix("2026-") })
        XCTAssertTrue(stations.allSatisfy { $0.longitude != nil && $0.signKey != nil })
        XCTAssertTrue(stations.allSatisfy { abs($0.stationSpeed ?? 1) < 0.01 })
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
