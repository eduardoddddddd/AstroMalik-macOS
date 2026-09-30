import XCTest
@testable import AstroMalik

final class AstroVisualGeometryTests: XCTestCase {
    func testEastwardAndWestwardAntimeridianHavePairedBordersAndNoGap() throws {
        let domain = try AstroVisualDomain(minimumLatitude: -90, maximumLatitude: 90)
        for coordinates in [[(0.0, 170.0), (20.0, -170.0)], [(20.0, -170.0), (0.0, 170.0)]] {
            let source = try line([coordinates])
            let output = try AstroVisualGeometry.adapt(source, domain: domain)
            XCTAssertEqual(output.id, source.id)
            XCTAssertEqual(output.segments.count, 2)
            let left = output.segments[0].coordinates.last!
            let right = output.segments[1].coordinates.first!
            XCTAssertEqual(left.latitude, 10, accuracy: 1e-12)
            XCTAssertEqual(right.latitude, 10, accuracy: 1e-12)
            XCTAssertEqual(abs(left.longitude), 180)
            XCTAssertEqual(right.longitude, -left.longitude)
            assertRenderable(output, domain: domain)
            XCTAssertEqual(source.segments.count, 1)
            XCTAssertEqual(source.segments[0].coordinates.count, 2) // input unmodified
        }
    }

    func testExactSeamVertexAndSeamMeridianDoNotProduceWorldChords() throws {
        let domain = try AstroVisualDomain()
        let cases = [
            [(0.0, 170.0), (10.0, -180.0), (20.0, -170.0)],
            [(0.0, -170.0), (10.0, -180.0), (20.0, 170.0)],
            [(0.0, 170.0), (10.0, -180.0), (20.0, 170.0)],
            [(-90.0, -180.0), (0.0, -180.0), (90.0, -180.0)]
        ]
        for coordinates in cases {
            let output = try AstroVisualGeometry.adapt(line([coordinates]), domain: domain)
            XCTAssertFalse(output.segments.isEmpty)
            assertRenderable(output, domain: domain)
        }
        let seam = try AstroVisualGeometry.adapt(line([cases[3]]), domain: domain)
        XCTAssertEqual(seam.segments.count, 1)
        XCTAssertEqual(seam.segments[0].coordinates.first!.latitude, domain.minimumLatitude)
        XCTAssertEqual(seam.segments[0].coordinates.last!.latitude, domain.maximumLatitude)
    }

    func testClippingNeverExtendsAstronomicalDomainOrConnectsSourceSegments() throws {
        let domain = try AstroVisualDomain(minimumLatitude: -60, maximumLatitude: 60)
        let source = try line([[(-80, 10), (0, 10), (80, 10)], [(80, 10), (85, 20)],
                               [(20, 20), (30, 30)], [(30, 30), (40, 40)]])
        let output = try AstroVisualGeometry.adapt(source, domain: domain)
        XCTAssertEqual(output.segments.count, 3)
        XCTAssertEqual(output.segments[0].coordinates.first!.latitude, -60)
        XCTAssertEqual(output.segments[0].coordinates.last!.latitude, 60)
        XCTAssertEqual(output.segments[1].coordinates.last, output.segments[2].coordinates.first)
        XCTAssertEqual(source.segments[0].coordinates.first!.latitude, -80)
        let inside = try AstroVisualGeometry.adapt(line([[(-45, 10), (45, 10)]]), domain: domain)
        XCTAssertEqual(inside.segments[0].coordinates.first!.latitude, -45)
        XCTAssertEqual(inside.segments[0].coordinates.last!.latitude, 45)
        assertRenderable(output, domain: domain)
    }

    func testClippingAndSeamIntersectionAtSamePoint() throws {
        let output = try AstroVisualGeometry.adapt(line([[(0, 170), (20, -170)]]),
                                                   domain: AstroVisualDomain(minimumLatitude: -10, maximumLatitude: 10))
        XCTAssertEqual(output.segments.count, 1)
        XCTAssertEqual(output.segments[0].coordinates.last, AstroVisualCoordinate(latitude: 10, longitude: 180))
        XCTAssertThrowsError(try AstroVisualDomain(minimumLatitude: 90, maximumLatitude: 90))
        XCTAssertThrowsError(try AstroVisualGeometry.adapt(line([[(0, 0), (0, -180)]]), domain: AstroVisualDomain()))
    }

    func testRealAdaptiveDomainCrossingSeamRetainsAllEdgesForAnalysis() throws {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545), bodies: [.sun])
        let position = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 170,
                                                   declinationDegrees: 45, returnedFlags: 0)
        let snapshot = try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 0, positions: [position],
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        let result = try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: request)
        let dsc = try XCTUnwrap(result.lines.first { $0.id.angle == .dsc })
        XCTAssertEqual(dsc.segments.count, 1)
        let coordinates = dsc.segments[0].coordinates
        XCTAssertTrue(zip(coordinates, coordinates.dropFirst()).contains { abs($0.longitude - $1.longitude) > 180 })
        let output = try AstroVisualGeometry.adapt(dsc, domain: AstroVisualDomain())
        XCTAssertEqual(output.segments.count, 2)
        let cutA = output.segments[0].coordinates.last!, cutB = output.segments[1].coordinates.first!
        XCTAssertEqual(cutA.latitude, cutB.latitude)
        XCTAssertEqual(abs(cutA.longitude), 180)
        XCTAssertEqual(cutA.longitude, -cutB.longitude)
        assertRenderable(output, domain: try AstroVisualDomain())
    }

    func testAdaptiveCurvesAcrossOriginsDeclinationsAndClippingExtents() throws {
        for origin in [0.0, 0.000001, 90, 179.999999, 180, 270, 359.999999] {
            for declination in [-89.9, -45, -0.000001, 0, 0.000001, 45, 89.9] {
                let position = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: origin,
                                                           declinationDegrees: declination, returnedFlags: 0)
                let samples = try AdaptiveAstroGeometry.horizon(position: position, siderealDegrees: 0, toleranceKm: 1)
                for coordinates in [samples.ascendant, samples.descendant] {
                    let source = AstroLine(id: AstroLineID(body: .sun, angle: .asc),
                                           segments: [AstroLineSegment(coordinates: coordinates)], diagnostics: [])
                    for extent in [30.0, 85.0511287798066, 90] {
                        let domain = try AstroVisualDomain(minimumLatitude: -extent, maximumLatitude: extent)
                        let output = try AstroVisualGeometry.adapt(source, domain: domain)
                        assertRenderable(output, domain: domain)
                        XCTAssertFalse(output.segments.isEmpty)
                        // Each branch is monotone in latitude/longitude: one
                        // clip interval and at most one interior antimeridian cut.
                        XCTAssertLessThanOrEqual(output.segments.count, 2,
                            "origin=\(origin) declination=\(declination) extent=\(extent)")
                    }
                }
            }
        }
    }

    private func line(_ segments: [[(Double, Double)]]) throws -> AstroLine {
        AstroLine(id: AstroLineID(body: .sun, angle: .asc), segments: try segments.map {
            AstroLineSegment(coordinates: try $0.map { try GeoCoordinate(latitude: $0.0, longitude: $0.1) })
        }, diagnostics: [])
    }
    private func assertRenderable(_ line: AstroVisualLine, domain: AstroVisualDomain, file: StaticString = #filePath, lineNumber: UInt = #line) {
        for segment in line.segments {
            XCTAssertGreaterThanOrEqual(segment.coordinates.count, 2, file: file, line: lineNumber)
            for point in segment.coordinates {
                XCTAssertTrue(point.latitude.isFinite && point.longitude.isFinite, file: file, line: lineNumber)
                XCTAssertTrue((domain.minimumLatitude...domain.maximumLatitude).contains(point.latitude), file: file, line: lineNumber)
                XCTAssertTrue((-180...180).contains(point.longitude), file: file, line: lineNumber)
            }
            for (a, b) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                XCTAssertLessThanOrEqual(abs(a.longitude - b.longitude), 180, file: file, line: lineNumber)
                XCTAssertNotEqual(a, b, file: file, line: lineNumber)
            }
        }
    }
}
