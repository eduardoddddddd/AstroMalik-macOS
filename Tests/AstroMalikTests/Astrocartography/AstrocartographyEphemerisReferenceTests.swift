import XCTest
import CSwissEph
@testable import AstroMalik

/// Independent Python binding fixture; not a substitute for testing F1 lines.
final class AstrocartographyEphemerisReferenceTests: XCTestCase {
    func testSwissFacadeMatchesPythonReferenceForTenBodiesAndFourDates() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-swiss-python-reference", withExtension: "json"))
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let ephe = root.appendingPathComponent("Sources/AstroMalik/Resources/ephe").path
        XCTAssertEqual(reference.cases.count, 4)
        for c in reference.cases {
            XCTAssertEqual(c.positions.filter { ($0.returnedFlags & SEFLG_SWIEPH) == 0 }.map(\.body), c.fallbackBodies)
            try SwissEphemerisAccess.transaction {
                AstroEngine.configure(ephePath: ephe)
                XCTAssertEqual(SwissEphemerisAccess.swe_sidtime(c.julianDay) * 15,
                               c.greenwichSiderealDegrees, accuracy: 1e-8)
                XCTAssertEqual(c.positions.count, 10)
                for p in c.positions {
                    let bodyID = try XCTUnwrap(PLANET_LIST.first { $0.key == p.body.rawValue }?.id)
                    var values = [Double](repeating: 0, count: 6)
                    var error = [CChar](repeating: 0, count: 256)
                    let flags = SwissEphemerisAccess.swe_calc_ut(c.julianDay, bodyID,
                        reference.requestedFlags, &values, &error)
                    XCTAssertEqual(flags, p.returnedFlags, p.body.rawValue)
                    XCTAssertEqual(values[0], p.rightAscensionDegrees, accuracy: 1e-8, p.body.rawValue)
                    XCTAssertEqual(values[1], p.declinationDegrees, accuracy: 1e-8, p.body.rawValue)
                }
            }
        }
    }

    private struct Reference: Decodable { let requestedFlags: Int32; let cases: [Case] }
    private struct Case: Decodable {
        let julianDay: Double
        let greenwichSiderealDegrees: Double
        let positions: [AstroEquatorialPosition]
        let fallbackBodies: [AstroBody]
    }
}
