import XCTest
import CSwissEph
@testable import AstroMalik

/// Numerical properties of phase-1 lines. Residuals use the horizon identity, not the engine as its own oracle.
final class AstrocartographyEngineTests: XCTestCase {
    func testSyntheticSnapshotProducesBothHemispheresAndFortyLineShape() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-equatorial-synthetic", withExtension: "json"))
        let snapshot = try JSONDecoder().decode(EquatorialSnapshot.self, from: Data(contentsOf: url))
        let result = try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot))
            .calculate(request: snapshot.request)
        XCTAssertEqual(result.lines.count, 8)
        XCTAssertEqual(result.lines.map(\.id.angle), Array(repeating: AstroAngle.allCases, count: 2).flatMap { $0 })

        let sunMC = try XCTUnwrap(result.lines.first { $0.id.body == .sun && $0.id.angle == .mc })
        let longitudes = sunMC.segments.flatMap(\.coordinates).map(\.longitude)
        XCTAssertEqual(longitudes, [0, 0, 0, 0, 0])
        let latitudes = sunMC.segments.flatMap(\.coordinates).map(\.latitude)
        XCTAssertTrue(latitudes.contains { $0 < 0 })
        XCTAssertTrue(latitudes.contains { $0 > 0 })

        let moonASC = try XCTUnwrap(result.lines.first { $0.id.body == .moon && $0.id.angle == .asc })
        let atEquator = try XCTUnwrap(moonASC.segments.flatMap(\.coordinates).first { $0.latitude == 0 })
        XCTAssertEqual(atEquator.longitude, -45, accuracy: 1e-9)
        XCTAssertFalse(result.lines.contains { $0.diagnostics.contains { $0.code == SwissAstrocartographyEphemeris.fallbackDiagnosticCode } })
    }

    func testRepeatedCalculationIsIdenticalAndFinite() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-equatorial-synthetic", withExtension: "json"))
        let snapshot = try JSONDecoder().decode(EquatorialSnapshot.self, from: Data(contentsOf: url))
        let engine = AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot))
        let first = try engine.calculate(request: snapshot.request)
        let second = try engine.calculate(request: snapshot.request)
        XCTAssertEqual(first, second)
        for line in first.lines {
            for coordinate in line.segments.flatMap(\.coordinates) {
                XCTAssertTrue(coordinate.latitude.isFinite && coordinate.longitude.isFinite)
                XCTAssertGreaterThanOrEqual(coordinate.longitude, -180)
                XCTAssertLessThan(coordinate.longitude, 180)
            }
            for segment in line.segments {
                for pair in segment.coordinates.adjacentPairs() {
                    // F2 domain follows the shortest local longitude branch;
                    // splitting the display seam belongs to AstroVisualGeometry.
                    XCTAssertLessThan(abs(canonical(pair.0.longitude - pair.1.longitude)), 180)
                }
            }
        }
    }

    func testSwissLinesStayInsideAnalyticTolerances() throws {
        let reference = try loadReference()
        let provider = SwissAstrocartographyEphemeris(ephemerisDirectory: ephemerisDirectory())
        var maxMeridianDegrees = 0.0
        var maxAltitudeSine = 0.0
        var crossingCount = 0
        var tangentCount = 0
        var absentCount = 0

        for sample in reference.cases {
            let instant = try AstroNatalInstant(julianDay: sample.julianDay)
            let request = try AstrocartographyRequest(instant: instant, bodies: AstroBody.allCases)
            let result = try AstrocartographyEngine(ephemeris: provider).calculate(request: request)
            XCTAssertEqual(result.lines.count, 40)
            for position in result.snapshot.positions {
                let mc = try XCTUnwrap(result.lines.first { $0.id.body == position.body && $0.id.angle == .mc })
                let ic = try XCTUnwrap(result.lines.first { $0.id.body == position.body && $0.id.angle == .ic })
                let expectedMC = canonical(position.rightAscensionDegrees - result.snapshot.greenwichSiderealDegrees)
                let expectedIC = canonical(expectedMC + 180)
                for coordinate in mc.segments.flatMap(\.coordinates) {
                    maxMeridianDegrees = max(maxMeridianDegrees, abs(canonical(coordinate.longitude - expectedMC)))
                    XCTAssertEqual(coordinate.longitude, expectedMC, accuracy: 1e-9)
                }
                for coordinate in ic.segments.flatMap(\.coordinates) {
                    maxMeridianDegrees = max(maxMeridianDegrees, abs(canonical(coordinate.longitude - expectedIC)))
                    XCTAssertEqual(angularSeparation(coordinate.longitude, expectedMC), 180, accuracy: 1e-9)
                }
                XCTAssertTrue(mc.segments.flatMap(\.coordinates).contains { $0.latitude < 0 })
                XCTAssertTrue(mc.segments.flatMap(\.coordinates).contains { $0.latitude > 0 })

                let ascendant = try XCTUnwrap(result.lines.first { $0.id.body == position.body && $0.id.angle == .asc })
                let descendant = try XCTUnwrap(result.lines.first { $0.id.body == position.body && $0.id.angle == .dsc })
                let east = ascendant.segments.flatMap(\.coordinates)
                let west = descendant.segments.flatMap(\.coordinates)
                XCTAssertEqual(east.map(\.latitude), west.map(\.latitude))
                XCTAssertFalse(east.isEmpty)
                for (eastPoint, westPoint) in zip(east, west) {
                    let separation = angularSeparation(eastPoint.longitude, westPoint.longitude)
                    if separation <= 1e-8 {
                        tangentCount += 1
                        XCTAssertEqual(sineHourAngle(position, sidereal: result.snapshot.greenwichSiderealDegrees, longitude: eastPoint.longitude), 0, accuracy: 1e-8)
                    } else {
                        crossingCount += 1
                        XCTAssertLessThan(sineHourAngle(position, sidereal: result.snapshot.greenwichSiderealDegrees, longitude: eastPoint.longitude), 0)
                        XCTAssertGreaterThan(sineHourAngle(position, sidereal: result.snapshot.greenwichSiderealDegrees, longitude: westPoint.longitude), 0)
                    }
                    for point in [eastPoint, westPoint] {
                        let sine = altitudeSine(position, sidereal: result.snapshot.greenwichSiderealDegrees, coordinate: point)
                        maxAltitudeSine = max(maxAltitudeSine, abs(sine))
                        XCTAssertEqual(sine, 0, accuracy: 1e-9)
                        XCTAssertLessThanOrEqual(abs(point.latitude) + abs(position.declinationDegrees), 90 + 1e-8)
                    }
                }
                let outside =  min(89, 90 - abs(position.declinationDegrees) + 1)
                if outside < 89 {
                    let absent = try MundaneAngles.horizon(
                        rightAscensionDegrees: position.rightAscensionDegrees,
                        declinationDegrees: position.declinationDegrees,
                        greenwichSiderealDegrees: result.snapshot.greenwichSiderealDegrees,
                        latitude: outside
                    )
                    if absent.status == .noCrossing { absentCount += 1 }
                }
                if position.returnedFlags & SEFLG_SWIEPH == 0 {
                    XCTAssertTrue(mc.diagnostics.contains { $0.code == SwissAstrocartographyEphemeris.fallbackDiagnosticCode })
                }
            }
        }

        print("F1.4 maxMeridianDegrees=\(maxMeridianDegrees) maxAltitudeSine=\(maxAltitudeSine) crossings=\(crossingCount) tangents=\(tangentCount) absentLatitudes=\(absentCount)")
        XCTAssertLessThanOrEqual(maxMeridianDegrees, 1e-6)
        XCTAssertLessThanOrEqual(maxAltitudeSine, 1e-9)
        XCTAssertGreaterThan(crossingCount, 0)
        XCTAssertGreaterThan(tangentCount, 0)
        XCTAssertGreaterThan(absentCount, 0)
    }

    private func altitudeSine(_ position: AstroEquatorialPosition, sidereal: Double, coordinate: GeoCoordinate) -> Double {
        let phi = coordinate.latitude * .pi / 180
        let delta = position.declinationDegrees * .pi / 180
        let hour = (sidereal + coordinate.longitude - position.rightAscensionDegrees) * .pi / 180
        return sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(hour)
    }

    private func sineHourAngle(_ position: AstroEquatorialPosition, sidereal: Double, longitude: Double) -> Double {
        sin((sidereal + longitude - position.rightAscensionDegrees) * .pi / 180)
    }

    private func angularSeparation(_ lhs: Double, _ rhs: Double) -> Double {
        abs(canonical(lhs - rhs))
    }

    private func canonical(_ degrees: Double) -> Double {
        let remainder = (degrees + 180).truncatingRemainder(dividingBy: 360)
        return (remainder < 0 ? remainder + 360 : remainder) - 180
    }

    private func loadReference() throws -> Reference {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-swiss-python-reference", withExtension: "json"))
        return try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
    }

    private func ephemerisDirectory() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AstroMalik/Resources/ephe")
            .path
    }

    private struct Reference: Decodable { let cases: [Case] }
    private struct Case: Decodable { let julianDay: Double }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { ($0, $1) }
    }
}
