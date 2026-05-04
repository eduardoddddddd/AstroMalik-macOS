import XCTest
import CSwissEph
@testable import AstroMalik

final class VoidOfCourseCalculatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testVoidPeriodsForWeekHaveReasonableDurations() async throws {
        let start = swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 6, 8, 0, SE_GREG_CAL)
        let events = try await VoidOfCourseCalculator.findVoidPeriods(from: start, to: end, timezone: "UTC")
        let starts = events.filter { $0.kind == .voidOfCourse }
        let ends = events.filter { $0.kind == .voidOfCourseEnd }

        XCTAssertGreaterThan(starts.count, 1)
        XCTAssertGreaterThanOrEqual(ends.count, starts.count)
        XCTAssertTrue(starts.allSatisfy { event in
            guard let minutes = event.voidDurationMinutes else { return false }
            return minutes > 0 && minutes < 48 * 60
        })
    }

    func testVoidEndsAreLunarIngressEvents() async throws {
        let start = swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 6, 8, 0, SE_GREG_CAL)
        let events = try await VoidOfCourseCalculator.findVoidPeriods(from: start, to: end, timezone: "UTC")
        let ends = events.filter { $0.kind == .voidOfCourseEnd }

        XCTAssertTrue(ends.allSatisfy { $0.planetKeyA == "LUNA" && $0.signKey != nil && $0.formatted?.contains("00°00'") == true })
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
