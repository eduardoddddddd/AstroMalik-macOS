import XCTest
@testable import AstroMalik

final class AstroLocationAnalyzerTests: XCTestCase {
    private func result(declination: Double = 23, origin: Double = 20, tolerance: Double = 0.9) throws -> AstrocartographyResult {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545), bodies: [.sun], geometryToleranceKm: tolerance)
        let snapshot = try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 0,
            positions: [AstroEquatorialPosition(body: .sun, rightAscensionDegrees: origin, declinationDegrees: declination, returnedFlags: 0)],
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        return try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: request)
    }
    func testBetweenVerticesAndSeamOnMeridian() throws {
        let r = try result(origin: 180)
        let a = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 12.345, longitude: -180), result: r)
        let mc = try XCTUnwrap(a.proximities.first { $0.lineID.angle == .mc })
        XCTAssertLessThan(mc.distanceKm, 1e-8)
        XCTAssertEqual(mc.nearestPoint.latitude, 12.345, accuracy: 1e-9)
        let nearSeam = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 0, longitude: 179), result: r)
        XCTAssertEqual(try XCTUnwrap(nearSeam.proximities.first { $0.lineID.angle == .mc }).distanceKm,
                       .pi / 180 * 6371.0088, accuracy: 1e-8)
    }
    func testHorizonIndependentPlaneOracleAndEndpoints() throws {
        var maximumError = 0.0
        // Independent spherical plane: solar zenith n=(cosδcosλ,cosδsinλ,sinδ).
        // Distance to the union of the two horizon semicircles is asin(|n·p|).
        for delta in [-89.999, -60, -23, -0.000001, 0, 0.000001, 23, 60, 89.999] {
            for origin in [1.0, 179.9, 250] {
                let r = try result(declination: delta, origin: origin)
                for lat in [-90.0, -78, -22.123, 0, 41.7, 89.9, 90] {
                    for lon in [-180.0, -179.9, 0, 87.23, 179.9] {
                        let c = try GeoCoordinate(latitude: lat, longitude: lon)
                        let analysis = try AstroLocationAnalyzer.analyze(location: c, result: r)
                        let closest = try XCTUnwrap(analysis.proximities.filter { [.asc, .dsc].contains($0.lineID.angle) }.first)
                        let d = delta * .pi / 180, p = lat * .pi / 180, h = (lon-origin) * .pi / 180
                        let dot = sin(d)*sin(p) + cos(d)*cos(p)*cos(h)
                        let cx = -sin(d)*cos(p)*sin(h)
                        let cy = sin(d)*cos(p)*cos(h)-cos(d)*sin(p)
                        let cz = cos(d)*cos(p)*sin(h)
                        let oracle = atan2(abs(dot), hypot(hypot(cx, cy), cz)) * 6371.0088
                        maximumError = max(maximumError, abs(closest.distanceKm-oracle))
                        XCTAssertEqual(closest.distanceKm, oracle, accuracy: AstroLocationAnalyzer.numericalAllowanceKm)
                    }
                }
            }
        }
        print("F4 spherical plane oracle maximum error km: \(maximumError)")
    }
    func testTangencyPolarOpenEndsAndNonUniqueBranch() throws {
        let r = try result(declination: 30, origin: 20)
        let tangent = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 60, longitude: -160), result: r)
        for p in tangent.proximities.filter({ [.asc,.dsc].contains($0.lineID.angle) }) { XCTAssertLessThan(p.distanceKm, 1e-8) }
        let polar = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 90, longitude: 50), result: result(declination: 0))
        for p in polar.proximities.filter({ [.asc,.dsc].contains($0.lineID.angle) }) {
            XCTAssertLessThan(p.distanceKm, 0.000001); XCTAssertGreaterThan(p.distanceKm, 0)
        }
        let unique = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 90, longitude: 0), result: result(declination: 90))
        XCTAssertEqual(unique.proximities.count, 2) // no invented ASC/DSC at nonunique horizon
    }
    func testFiltersPolicyAndCancellation() throws {
        let a = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 40, longitude: 0), result: result())
        XCTAssertEqual(a.proximities.count, 4)
        XCTAssertTrue(AstroLocationAnalyzer.filtered(a, bodies: [], angles: []).isEmpty)
        XCTAssertEqual(a.proximities.count, 4)
        let policy = try AstroProximityPolicy(nearKm: 10, regionalKm: 20)
        XCTAssertEqual(policy.band(for: 10), .near); XCTAssertEqual(policy.band(for: 20), .regional)
        XCTAssertEqual(policy.band(for: 21), .distant)
        XCTAssertThrowsError(try AstroProximityPolicy(nearKm: 20, regionalKm: 10))
        XCTAssertEqual(a.proximities[0].estimatedErrorKm, 0.900001, accuracy: 1e-12)
    }
    func testDistanceErrorAgainstIndependentGeographicEdgeMinimizer() throws {
        var maximumDifference = 0.0
        for delta in [-89.999, -45, -0.000001, 0, 0.000001, 45, 89.999] {
            let r = try result(declination: delta, origin: 179.9, tolerance: 0.9)
            for query in [try GeoCoordinate(latitude: 24.3, longitude: -177.7),
                          try GeoCoordinate(latitude: 82.1, longitude: 91.6)] {
                let analysis = try AstroLocationAnalyzer.analyze(location: query, result: r)
                for line in r.lines where [.asc,.dsc].contains(line.id.angle) {
                    var reference = Double.infinity
                    for segment in line.segments {
                        for (a,b) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                            var dl = b.longitude-a.longitude
                            if dl > 180 { dl -= 360 }; if dl < -180 { dl += 360 }
                            // Independent haversine on geographic interpolation;
                            // golden-section minimizes continuous s, not vertices.
                            func distance(_ s: Double) -> Double {
                                let lat = (a.latitude + (b.latitude-a.latitude)*s) * .pi / 180
                                let lon = (a.longitude+dl*s-query.longitude) * .pi / 180
                                let p = query.latitude * .pi / 180
                                let h = min(1, max(0, pow(sin((lat-p)/2),2) + cos(lat)*cos(p)*pow(sin(lon/2),2)))
                                return 2*6371.0088*atan2(sqrt(h),sqrt(1-h))
                            }
                            var lo = 0.0, hi = 1.0
                            let ratio = (sqrt(5.0)-1)/2
                            var x = hi-ratio*(hi-lo), y = lo+ratio*(hi-lo)
                            var fx = distance(x), fy = distance(y)
                            for _ in 0..<48 {
                                if fx < fy { hi = y; y = x; fy = fx; x = hi-ratio*(hi-lo); fx = distance(x) }
                                else { lo = x; x = y; fx = fy; y = lo+ratio*(hi-lo); fy = distance(y) }
                            }
                            reference = min(reference,distance(0),distance(1),fx,fy)
                        }
                    }
                    let actual = try XCTUnwrap(analysis.proximities.first { $0.lineID == line.id })
                    maximumDifference = max(maximumDifference,abs(actual.distanceKm-reference))
                    XCTAssertLessThanOrEqual(abs(actual.distanceKm-reference), actual.estimatedErrorKm)
                }
            }
        }
        print("F4 geographic interpolation distance maximum difference km: \(maximumDifference)")
    }

    func testDisconnectedSegmentsAreNotArtificiallyJoined() throws {
        let r = try result()
        let id = AstroLineID(body: .sun, angle: .mc)
        let pieces = try [[GeoCoordinate(latitude: 0, longitude: 0), GeoCoordinate(latitude: 10, longitude: 0)],
                          [GeoCoordinate(latitude: 50, longitude: 0), GeoCoordinate(latitude: 60, longitude: 0)]]
        let segmented = AstrocartographyResult(snapshot: r.snapshot,
            lines: [AstroLine(id: id, segments: pieces.map { AstroLineSegment(coordinates: $0) }, diagnostics: [])])
        let a = try AstroLocationAnalyzer.analyze(location: GeoCoordinate(latitude: 30, longitude: 0), result: segmented)
        XCTAssertEqual(a.proximities[0].distanceKm, 20 * .pi / 180 * 6371.0088, accuracy: 1e-8)
    }
}
