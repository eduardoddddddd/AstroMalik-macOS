import XCTest
import CSwissEph
@testable import AstroMalik

final class SignIngressCalculatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testSunIngressesCancerAroundJuneSolstice2026() async throws {
        let start = swe_julday(2026, 6, 15, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 6, 25, 0, SE_GREG_CAL)
        let events = try await SignIngressCalculator.findIngresses(from: start, to: end, timezone: "UTC")
        let sunCancer = try XCTUnwrap(events.first { $0.planetKeyA == "SOL" && $0.signKey == "CANCER" })

        XCTAssertEqual(sunCancer.kind, .signIngress)
        XCTAssertEqual(sunCancer.ingressDirection, "directo")
        XCTAssertTrue(sunCancer.dateUTC.hasPrefix("2026-06-21") || sunCancer.dateUTC.hasPrefix("2026-06-20"))
        XCTAssertEqual(sunCancer.importance, .moderate)
    }

    func testFindsRetrogradeIngressIn2026() async throws {
        let (start, end) = jdRange(year: 2026)
        let retrogradeIngresses = try await SignIngressCalculator.findIngresses(from: start, to: end, timezone: "UTC")
            .filter { $0.ingressDirection == "retrógrado" }

        XCTAssertGreaterThan(retrogradeIngresses.count, 0)
        XCTAssertTrue(retrogradeIngresses.allSatisfy { $0.kind == .signIngress })
    }

    func testIncludeMoonAddsFrequentLunarIngresses() async throws {
        let start = swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = swe_julday(2026, 6, 8, 0, SE_GREG_CAL)
        let withoutMoon = try await SignIngressCalculator.findIngresses(from: start, to: end, timezone: "UTC", includeMoon: false)
        let withMoon = try await SignIngressCalculator.findIngresses(from: start, to: end, timezone: "UTC", includeMoon: true)

        XCTAssertEqual(withoutMoon.filter { $0.planetKeyA == "LUNA" }.count, 0)
        XCTAssertGreaterThan(withMoon.filter { $0.planetKeyA == "LUNA" }.count, 2)
    }

    private func jdRange(year: Int32) -> (Double, Double) {
        (swe_julday(year, 1, 1, 0, SE_GREG_CAL), swe_julday(year + 1, 1, 1, 0, SE_GREG_CAL))
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
