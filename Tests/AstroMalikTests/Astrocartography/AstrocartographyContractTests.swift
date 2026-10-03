import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstrocartographyContractTests: XCTestCase {
    func testBodyOrderAndLineIdentityAreStable() throws {
        let instant = try AstroNatalInstant(julianDay: 2_451_545)
        let request = try AstrocartographyRequest(instant: instant, bodies: [.pluto, .moon, .sun])
        XCTAssertEqual(request.bodies, [.sun, .moon, .pluto])
        XCTAssertEqual(AstroBody.allCases.count, 10)
        let keys = AstroBody.allCases.flatMap { body in
            AstroAngle.allCases.map { AstroLineID(body: body, angle: $0).stableKey }
        }
        XCTAssertEqual(Set(keys).count, 40)
        XCTAssertEqual(try roundTrip(request), request)
    }

    func testRequestRejectsEmptyDuplicateAndInvalidTolerance() throws {
        let instant = try AstroNatalInstant(julianDay: 2_451_545)
        XCTAssertThrowsError(try AstrocartographyRequest(instant: instant, bodies: []))
        XCTAssertThrowsError(try AstrocartographyRequest(instant: instant, bodies: [.sun, .sun]))
        for value in [0.0, -1, .nan, .infinity] {
            XCTAssertThrowsError(try AstrocartographyRequest(instant: instant, geometryToleranceKm: value))
        }
    }

    func testInstantBoundsAndNonFiniteValues() throws {
        XCTAssertNoThrow(try AstroNatalInstant(julianDay: 2_378_496.5))
        XCTAssertNoThrow(try AstroNatalInstant(julianDay: 2_816_787.5 - 1))
        for jd in [2_378_496.4, 2_816_787.5, Double.nan, .infinity] {
            XCTAssertThrowsError(try AstroNatalInstant(julianDay: jd))
        }
    }

    func testCoordinateValidationAndAntimeridianCanonicalization() throws {
        XCTAssertEqual(try GeoCoordinate(latitude: 0, longitude: 180).longitude, -180)
        XCTAssertEqual(try roundTrip(GeoCoordinate(latitude: -90, longitude: -180)).latitude, -90)
        XCTAssertThrowsError(try GeoCoordinate(latitude: 91, longitude: 0))
        XCTAssertThrowsError(try GeoCoordinate(latitude: 0, longitude: 181))
        XCTAssertThrowsError(try GeoCoordinate(latitude: .nan, longitude: 0))
    }

    func testDecodingCannotBypassValidatedInitializers() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(GeoCoordinate.self,
            from: Data(#"{"latitude":120,"longitude":0}"#.utf8)))
        let fixture = try fixtureSnapshot()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture.request)) as? [String: Any])
        object["contractVersion"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(AstrocartographyRequest.self,
            from: JSONSerialization.data(withJSONObject: object)))
        object["contractVersion"] = 1
        object["convention"] = "topocentric"
        XCTAssertThrowsError(try JSONDecoder().decode(AstrocartographyRequest.self,
            from: JSONSerialization.data(withJSONObject: object)))
    }

    func testSyntheticFixtureIsExplicitAndMockRejectsAnotherInstant() throws {
        let snapshot = try fixtureSnapshot()
        XCTAssertEqual(snapshot.provenance.source, .syntheticFixture)
        XCTAssertEqual(snapshot.positions.map(\.body), snapshot.request.bodies)
        XCTAssertEqual(try roundTrip(snapshot), snapshot)
        let mock = StaticAstrocartographyEphemeris(fixture: snapshot)
        XCTAssertEqual(try mock.snapshot(for: snapshot.request), snapshot)
        let changed = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2_451_546), bodies: [.sun, .moon])
        XCTAssertThrowsError(try mock.snapshot(for: changed))
    }

    func testSnapshotRequiresExactlyOnePositionPerRequestedBody() throws {
        let fixture = try fixtureSnapshot()
        for positions in [[], [fixture.positions[0]], [fixture.positions[0], fixture.positions[0]]] {
            XCTAssertThrowsError(try EquatorialSnapshot(request: fixture.request,
                greenwichSiderealDegrees: 0, positions: positions, provenance: fixture.provenance))
        }
        XCTAssertThrowsError(try EquatorialSnapshot(request: fixture.request,
            greenwichSiderealDegrees: 360, positions: fixture.positions, provenance: fixture.provenance))
    }

    func testEquatorialPositionsValidateUnits() {
        XCTAssertThrowsError(try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 360,
            declinationDegrees: 0, returnedFlags: 0))
        XCTAssertThrowsError(try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 0,
            declinationDegrees: -91, returnedFlags: 0))
    }

    private func fixtureSnapshot() throws -> EquatorialSnapshot {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-equatorial-synthetic", withExtension: "json"))
        return try JSONDecoder().decode(EquatorialSnapshot.self, from: Data(contentsOf: url))
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}
