import XCTest
@testable import AstroMalik

final class JulianDaySecondsTests: XCTestCase {
    func testParseLocalTimeKeepsLegacyMinutesAndAcceptsSeconds() throws {
        let legacy = try parseLocalTime("20:33")
        XCTAssertEqual(legacy, LocalTimeComponents(hour: 20, minute: 33, second: 0))
        XCTAssertEqual(legacy.formatted(), "20:33")
        XCTAssertEqual(legacy.formatted(includeSeconds: true), "20:33:00")

        let precise = try parseLocalTime("20:33:47")
        XCTAssertEqual(precise, LocalTimeComponents(hour: 20, minute: 33, second: 47))
        XCTAssertEqual(precise.totalSeconds, 74_027)
        XCTAssertEqual(precise.formatted(), "20:33:47")
    }

    func testParseLocalTimeRejectsMalformedAndOutOfRangeValues() {
        for invalid in ["", "20", "20:", "20:xx", "20:30:10:01", "24:00", "23:60", "23:59:60"] {
            XCTAssertThrowsError(try parseLocalTime(invalid), "Debía rechazar \(invalid)") { error in
                guard case JulianDayError.invalidTime = error else {
                    return XCTFail("Error inesperado para \(invalid): \(error)")
                }
            }
        }
    }

    func testLegacyAndExplicitZeroSecondsProduceSameJulianDay() throws {
        let legacy = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezoneName: "Europe/Madrid"
        )
        let explicit = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33:00",
            timezoneName: "Europe/Madrid"
        )
        XCTAssertEqual(legacy.jd, explicit.jd, accuracy: 1e-10)
        XCTAssertEqual(legacy.utcISO, explicit.utcISO)
    }

    func testJulianDayPreservesSecondPrecision() throws {
        let start = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33:00",
            timezoneName: "Europe/Madrid"
        )
        let later = try julianDayFromLocal(
            birthDate: "1976-10-11",
            birthTime: "20:33:30",
            timezoneName: "Europe/Madrid"
        )
        XCTAssertEqual(later.jd - start.jd, 30.0 / 86_400.0, accuracy: 1e-9)
        XCTAssertEqual(later.utFractionalHours - start.utFractionalHours, 30.0 / 3_600.0, accuracy: 1e-6)
    }

    func testTimezoneConversionCanCrossUTCDateBoundaryWithSeconds() throws {
        let result = try julianDayFromLocal(
            birthDate: "2026-01-01",
            birthTime: "00:00:30",
            timezoneName: "Europe/Madrid"
        )
        XCTAssertTrue(result.localISO.hasPrefix("2026-01-01T00:00:30"))
        XCTAssertTrue(result.utcISO.hasPrefix("2025-12-31T23:00:30"))
        XCTAssertEqual(result.utFractionalHours, 23.008333, accuracy: 1e-6)
    }

    func testStrictLocalDateRejectsInvalidCalendarDateAndDSTGap() {
        XCTAssertThrowsError(try localDateFromBirthData(
            birthDate: "2026-02-31",
            birthTime: "12:00:00",
            timezoneName: "Europe/Madrid"
        ))
        XCTAssertThrowsError(try localDateFromBirthData(
            birthDate: "2026-03-29",
            birthTime: "02:30:00",
            timezoneName: "Europe/Madrid"
        ))
    }
}

