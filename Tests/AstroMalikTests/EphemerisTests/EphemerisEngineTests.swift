import XCTest
import CSwissEph
@testable import AstroMalik

final class EphemerisEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testComputeMonthForJune2026ContainsCoreEventsAndDailyRows() async throws {
        let month = try await EphemerisEngine.computeMonth(year: 2026, month: 6, timezone: "Europe/Madrid")

        XCTAssertEqual(month.id, "2026-06")
        XCTAssertEqual(month.year, 2026)
        XCTAssertEqual(month.month, 6)
        XCTAssertEqual(month.dailyRows.count, 30)
        XCTAssertTrue(month.events.contains { $0.kind == .newMoon })
        XCTAssertTrue(month.events.contains { $0.kind == .fullMoon })
        XCTAssertEqual(month.events.filter { $0.kind == .firstQuarter }.count, 1)
        XCTAssertEqual(month.events.filter { $0.kind == .lastQuarter }.count, 1)
        XCTAssertTrue(month.events.contains { $0.kind == .signIngress })
        XCTAssertTrue(month.events.contains { $0.kind == .voidOfCourse || $0.kind == .voidOfCourseEnd })
        XCTAssertTrue(month.events.contains { $0.kind == .mundaneAspect })
        XCTAssertEqual(month.events, month.events.sorted { $0.dateUTC < $1.dateUTC })
    }

    func testDailyRowsHaveTenPlanetsAndNorthNode() async throws {
        let (startJD, endJD) = EphemerisEngine.jdRangeForMonth(year: 2026, month: 6)
        let rows = try await EphemerisEngine.computeDailyRows(from: startJD, to: endJD, timezone: "UTC")

        XCTAssertEqual(rows.count, 30)
        XCTAssertEqual(rows.first?.date, "2026-06-01")
        XCTAssertEqual(rows.last?.date, "2026-06-30")
        XCTAssertTrue(rows.allSatisfy { $0.positions.count == 11 })
        XCTAssertTrue(rows.allSatisfy { row in row.positions.contains { $0.planetKey == "NODO_NORTE" } })
        XCTAssertTrue(rows.allSatisfy { (0..<360).contains($0.lunarPhaseAngle) })
        XCTAssertTrue(rows.allSatisfy { !$0.lunarPhaseLabel.isEmpty })
    }

    func testEventsByDayGroupsByLocalDate() async throws {
        let month = try await EphemerisEngine.computeMonth(year: 2026, month: 6, timezone: "Europe/Madrid")
        let groupedCount = month.eventsByDay.values.reduce(0) { $0 + $1.count }

        XCTAssertEqual(groupedCount, month.events.count)
        XCTAssertTrue(month.eventsByDay.keys.allSatisfy { $0.hasPrefix("2026-06") || $0.hasPrefix("2026-07") || $0.hasPrefix("2026-05") })
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
