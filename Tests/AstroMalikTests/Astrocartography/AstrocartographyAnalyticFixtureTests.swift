import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

/// Validates the reference artifact itself. Production roots are checked in MundaneAngleAnalyticTests.
final class AstrocartographyAnalyticFixtureTests: XCTestCase {
    func testReferenceCasesSatisfyIndependentHorizontalIdentities() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-analytic-lines", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.cases.count, 8)
        for c in fixture.cases {
            XCTAssertEqual(normalize(c.ra - c.gst), c.mc, accuracy: 1e-9, c.name)
            XCTAssertEqual(normalize(c.mc + 180), c.ic, accuracy: 1e-9, c.name)
            let phi = radians(c.latitude), delta = radians(c.declination)
            if let asc = c.asc, let dsc = c.dsc {
                for longitude in [asc, dsc] {
                    let h = radians(c.gst + longitude - c.ra)
                    let altitudeSine = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)
                    XCTAssertEqual(altitudeSine, 0, accuracy: 1e-12, c.name)
                }
                if c.status == "crossing" {
                    XCTAssertLessThan(sin(radians(c.gst + asc - c.ra)), 0, c.name)
                    XCTAssertGreaterThan(sin(radians(c.gst + dsc - c.ra)), 0, c.name)
                }
            } else if c.status == "noCrossing" {
                XCTAssertGreaterThan(abs(tan(phi) * tan(delta)), 1, c.name)
            } else {
                XCTAssertEqual(c.status, "nonUniquePolarHorizon")
                XCTAssertEqual(abs(cos(phi)), 0, accuracy: 1e-12)
            }
        }
    }

    private func radians(_ d: Double) -> Double { d * .pi / 180 }
    private func normalize(_ d: Double) -> Double {
        let remainder = (d + 180).truncatingRemainder(dividingBy: 360)
        return (remainder < 0 ? remainder + 360 : remainder) - 180
    }
    private struct Reference: Decodable { let cases: [Case] }
    private struct Case: Decodable {
        let name: String
        let ra, declination, gst, latitude, mc, ic: Double
        let asc, dsc: Double?
        let status: String
    }
}
