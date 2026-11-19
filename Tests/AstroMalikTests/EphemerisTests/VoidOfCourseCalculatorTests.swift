import XCTest
import CSwissEph
@testable import AstroMalik

final class VoidOfCourseCalculatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testVoidPeriodsForWeekHaveReasonableDurations() async throws {
        let start = SwissEphemerisAccess.swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 6, 8, 0, SE_GREG_CAL)
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
        let start = SwissEphemerisAccess.swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 6, 8, 0, SE_GREG_CAL)
        let events = try await VoidOfCourseCalculator.findVoidPeriods(from: start, to: end, timezone: "UTC")
        let ends = events.filter { $0.kind == .voidOfCourseEnd }

        XCTAssertTrue(ends.allSatisfy { $0.planetKeyA == "LUNA" && $0.signKey != nil && $0.formatted?.contains("00°00'") == true })
    }

    func testVoidEndNamesTheSignTheMoonEnters() async throws {
        // La bisección puede quedarse un instante antes de 30°: antes el evento se etiquetaba
        // con el signo que la Luna abandona (17-11-2026 «ingreso en ♒ Acuario», 20-11-2026
        // «ingreso en ♓ Piscis»).
        let start = SwissEphemerisAccess.swe_julday(2026, 11, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 12, 1, 0, SE_GREG_CAL)
        let events = try await VoidOfCourseCalculator.findVoidPeriods(from: start, to: end, timezone: "Europe/Madrid")
        let ends = events.filter { $0.kind == .voidOfCourseEnd }

        func endSign(on day: String) -> String? {
            ends.first { $0.dateLocal.hasPrefix(day) }?.signKey
        }
        XCTAssertEqual(endSign(on: "2026-11-17"), "PISCIS")
        XCTAssertEqual(endSign(on: "2026-11-20"), "ARIES")
        XCTAssertEqual(endSign(on: "2026-11-22"), "TAURO")

        XCTAssertGreaterThan(ends.count, 10)
        let iso = ISO8601DateFormatter()
        for event in ends {
            let date = try XCTUnwrap(iso.date(from: event.dateUTC))
            let jd = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
            let after = try EphemerisUtilities.planetPosition(jd: jd + 10.0 / 1_440, planetID: SE_MOON, bodyName: "Luna")
            let before = try EphemerisUtilities.planetPosition(jd: jd - 10.0 / 1_440, planetID: SE_MOON, bodyName: "Luna")
            let entered = EphemerisUtilities.signIndex(for: after.longitude)
            XCTAssertEqual(event.signKey, SIGN_KEYS[entered], event.dateLocal)
            XCTAssertEqual(EphemerisUtilities.signIndex(for: before.longitude), (entered + 11) % 12, event.dateLocal)
            XCTAssertEqual(event.formatted, "\(SIGN_LABELS[entered]) 00°00'")
            XCTAssertEqual(event.title, "☽ Fin de Luna vacía: ingreso en \(SIGN_LABELS[entered])")
        }
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
