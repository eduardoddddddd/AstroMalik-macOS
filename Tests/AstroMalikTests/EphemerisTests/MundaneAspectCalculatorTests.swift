import XCTest
import CSwissEph
@testable import AstroMalik

final class MundaneAspectCalculatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testFindsMundaneAspectsForJune2026() async throws {
        let start = swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 7, 1, 0, SE_GREG_CAL)
        let events = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC")

        XCTAssertGreaterThan(events.count, 0)
        XCTAssertTrue(events.allSatisfy { $0.kind == .mundaneAspect })
        XCTAssertTrue(events.allSatisfy { $0.aspectKey != nil && $0.planetKeyA != nil && $0.planetKeyB != nil })
    }

    func testLunarOptionAddsMoreAspects() async throws {
        let start = swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 6, 3, 0, SE_GREG_CAL)
        let withoutMoon = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC", includeLunar: false)
        let withMoon = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC", includeLunar: true)

        XCTAssertGreaterThan(withMoon.count, withoutMoon.count)
        XCTAssertTrue(withMoon.contains { $0.planetKeyA == "LUNA" || $0.planetKeyB == "LUNA" })
    }

    func testKnownSlowAspectIfPresentIsMajor() async throws {
        let start = swe_julday(2026, 1, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2027, 1, 1, 0, SE_GREG_CAL)
        let events = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC")
        let slowSlow = events.filter { event in
            let slow: Set<String> = ["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
            guard let a = event.planetKeyA, let b = event.planetKeyB else { return false }
            return slow.contains(a) && slow.contains(b)
        }

        XCTAssertTrue(slowSlow.allSatisfy { $0.importance == .major })
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
