import XCTest
import CSwissEph
@testable import AstroMalik

final class MundaneAspectCalculatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: ephemerisPath())
    }

    func testFindsMundaneAspectsForJune2026() async throws {
        let start = SwissEphemerisAccess.swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 7, 1, 0, SE_GREG_CAL)
        let events = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC")

        XCTAssertGreaterThan(events.count, 0)
        XCTAssertTrue(events.allSatisfy { $0.kind == .mundaneAspect })
        XCTAssertTrue(events.allSatisfy { $0.aspectKey != nil && $0.planetKeyA != nil && $0.planetKeyB != nil })
    }

    func testLunarOptionAddsMoreAspects() async throws {
        let start = SwissEphemerisAccess.swe_julday(2026, 6, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 6, 3, 0, SE_GREG_CAL)
        let withoutMoon = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC", includeLunar: false)
        let withMoon = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC", includeLunar: true)

        XCTAssertGreaterThan(withMoon.count, withoutMoon.count)
        XCTAssertTrue(withMoon.contains { $0.planetKeyA == "LUNA" || $0.planetKeyB == "LUNA" })
    }

    func testKnownSlowAspectIfPresentIsMajor() async throws {
        let start = SwissEphemerisAccess.swe_julday(2026, 1, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2027, 1, 1, 0, SE_GREG_CAL)
        let events = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "UTC")
        let slowSlow = events.filter { event in
            let slow: Set<String> = ["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
            guard let a = event.planetKeyA, let b = event.planetKeyB else { return false }
            return slow.contains(a) && slow.contains(b)
        }

        XCTAssertTrue(slowSlow.allSatisfy { $0.importance == .major })
    }

    func testSignJumpAtOppositePointIsNotACrossing() {
        // signedAngularDistance pasa de +180 a −180 en el punto opuesto al objetivo.
        XCTAssertFalse(MundaneAspectCalculator.crossesZero(179.5, -179.5))
        XCTAssertFalse(MundaneAspectCalculator.crossesZero(-178, 179))
        XCTAssertTrue(MundaneAspectCalculator.crossesZero(-0.8, 0.4))
        XCTAssertTrue(MundaneAspectCalculator.crossesZero(0, 2))
    }

    func testNovember2026HasNoMirroredAspects() async throws {
        // Antes cada aspecto salía con su espejo a la misma hora: el 04-11 «Sol ☌ Mercurio»
        // y «Sol ☍ Mercurio»; «Venus ⚹ Júpiter» y «Venus △ Júpiter».
        let start = SwissEphemerisAccess.swe_julday(2026, 11, 1, 0, SE_GREG_CAL)
        let end = SwissEphemerisAccess.swe_julday(2026, 12, 1, 0, SE_GREG_CAL)
        let events = try await MundaneAspectCalculator.findAspects(from: start, to: end, timezone: "Europe/Madrid")

        func aspects(_ a: String, _ b: String, on day: String) -> [String] {
            events.filter { $0.planetKeyA == a && $0.planetKeyB == b && $0.dateLocal.hasPrefix(day) }
                .compactMap(\.aspectKey)
        }
        XCTAssertEqual(aspects("SOL", "MERCURIO", on: "2026-11-04"), ["CONJUNCION"])
        XCTAssertEqual(aspects("VENUS", "JUPITER", on: "2026-11-04"), ["SEXTIL"])

        // Ningún par tiene dos aspectos exactos distintos en la misma hora.
        let byPair = Dictionary(grouping: events) { "\($0.planetKeyA ?? "")-\($0.planetKeyB ?? "")" }
        for (pair, pairEvents) in byPair {
            let sorted = pairEvents.sorted { $0.dateUTC < $1.dateUTC }
            for (lhs, rhs) in zip(sorted, sorted.dropFirst()) {
                XCTAssertNotEqual(String(lhs.dateUTC.prefix(13)), String(rhs.dateUTC.prefix(13)),
                                  "\(pair): \(lhs.title) y \(rhs.title) a la misma hora")
            }
        }
    }

    private func ephemerisPath() -> String? {
        let local = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Resources/ephe"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }
}
