import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

/// Production roots against the phase-0 analytic fixture. The fixture test stays independent.
final class MundaneAngleAnalyticTests: XCTestCase {
    func testEngineMatchesAnalyticFixtureRoots() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-analytic-lines", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.cases.count, 8)
        for sample in fixture.cases {
            let meridians = try MundaneAngles.meridians(
                rightAscensionDegrees: sample.ra,
                greenwichSiderealDegrees: sample.gst
            )
            XCTAssertEqual(meridians.mc, sample.mc, accuracy: 1e-9, sample.name)
            XCTAssertEqual(meridians.ic, sample.ic, accuracy: 1e-9, sample.name)
            XCTAssertEqual(angularSeparation(meridians.mc, meridians.ic), 180, accuracy: 1e-9, sample.name)

            let event = try MundaneAngles.horizon(
                rightAscensionDegrees: sample.ra,
                declinationDegrees: sample.declination,
                greenwichSiderealDegrees: sample.gst,
                latitude: sample.latitude
            )
            XCTAssertEqual(event.status.rawValue, sample.status, sample.name)
            if let ascendant = sample.asc, let descendant = sample.dsc {
                let east = try XCTUnwrap(event.ascendantLongitude)
                let west = try XCTUnwrap(event.descendantLongitude)
                XCTAssertEqual(east, ascendant, accuracy: 1e-9, sample.name)
                XCTAssertEqual(west, descendant, accuracy: 1e-9, sample.name)
                assertHorizonIdentity(sample: sample, longitude: east)
                assertHorizonIdentity(sample: sample, longitude: west)
                if sample.status == "crossing" {
                    XCTAssertLessThan(sineHourAngle(sample: sample, longitude: east), 0, sample.name)
                    XCTAssertGreaterThan(sineHourAngle(sample: sample, longitude: west), 0, sample.name)
                } else {
                    XCTAssertEqual(sample.status, "tangent")
                    XCTAssertEqual(east, west, accuracy: 1e-12, sample.name)
                }
            } else {
                XCTAssertNil(event.ascendantLongitude, sample.name)
                XCTAssertNil(event.descendantLongitude, sample.name)
            }
        }
    }

    func testCrossingJustInsidePolarLimitKeepsDistinctRoots() throws {
        // 1.2e-9° inside |φ| + |δ| = 90. Cosine is within 1e-10 of -1, but the roots stay apart.
        let event = try MundaneAngles.horizon(
            rightAscensionDegrees: 0,
            declinationDegrees: 45,
            greenwichSiderealDegrees: 0,
            latitude: 44.9999999988
        )
        XCTAssertEqual(event.status, .crossing)
        let east = try XCTUnwrap(event.ascendantLongitude)
        let west = try XCTUnwrap(event.descendantLongitude)
        XCTAssertEqual(east, -179.9994756, accuracy: 1e-6)
        XCTAssertEqual(west, 179.9994756, accuracy: 1e-6)
        XCTAssertGreaterThan(angularSeparation(east, west), 1e-4)
    }

    func testSouthernAndNorthernMeridiansShareLongitude() throws {
        let meridians = try MundaneAngles.meridians(rightAscensionDegrees: 350, greenwichSiderealDegrees: 10)
        XCTAssertEqual(meridians.mc, -20, accuracy: 1e-12)
        XCTAssertEqual(meridians.ic, 160, accuracy: 1e-12)
        for latitude in [-60.0, 60.0] {
            let event = try MundaneAngles.horizon(
                rightAscensionDegrees: 350,
                declinationDegrees: 0,
                greenwichSiderealDegrees: 10,
                latitude: latitude
            )
            XCTAssertEqual(event.status, .crossing)
            XCTAssertEqual(event.ascendantLongitude ?? .nan, -110, accuracy: 1e-9)
            XCTAssertEqual(event.descendantLongitude ?? .nan, 70, accuracy: 1e-9)
        }
    }

    private func assertHorizonIdentity(sample: Case, longitude: Double) {
        let phi = sample.latitude * .pi / 180
        let delta = sample.declination * .pi / 180
        let hour = (sample.gst + longitude - sample.ra) * .pi / 180
        let altitudeSine = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(hour)
        XCTAssertEqual(altitudeSine, 0, accuracy: 1e-12, sample.name)
    }

    private func sineHourAngle(sample: Case, longitude: Double) -> Double {
        sin((sample.gst + longitude - sample.ra) * .pi / 180)
    }

    private func angularSeparation(_ lhs: Double, _ rhs: Double) -> Double {
        abs(canonical(lhs - rhs))
    }

    private func canonical(_ degrees: Double) -> Double {
        let remainder = (degrees + 180).truncatingRemainder(dividingBy: 360)
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
