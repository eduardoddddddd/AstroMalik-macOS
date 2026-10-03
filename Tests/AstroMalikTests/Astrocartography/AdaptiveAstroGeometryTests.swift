import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AdaptiveAstroGeometryTests: XCTestCase {
    func testWholeEdgesAgainstIndependentSphericalInterpolation() throws {
        // No fixture is generated from the production sampler. Reference points
        // use Cartesian slerp between verified horizon roots, not its parameterization.
        let declinations = [-89.999, -80, -45, -23.4, -0.000001, -1.0001e-9,
                            0, 1e-10, 1.0001e-9, 0.000001, 23.4, 45, 80, 89.999]
        var maxima: [Double: Double] = [:]
        var edges = 0
        for tolerance in [10.0, 1.0, 0.1, 0.01] {
            var maximum = 0.0
            for declination in declinations {
                let position = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 179.7,
                                                           declinationDegrees: declination, returnedFlags: 0)
                let samples = try AdaptiveAstroGeometry.horizon(position: position, siderealDegrees: 0,
                                                                toleranceKm: tolerance)
                XCTAssertLessThanOrEqual(samples.maximumBoundKm, tolerance)
                XCTAssertEqual(samples.ascendant.map(\.latitude), samples.descendant.map(\.latitude))
                for coordinates in [samples.ascendant, samples.descendant] {
                    var length = 0.0
                    for point in coordinates {
                        let phi = point.latitude * .pi / 180
                        let delta = declination * .pi / 180
                        let hour = (point.longitude - 179.7) * .pi / 180
                        XCTAssertEqual(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(hour), 0, accuracy: 3e-14)
                    }
                    for (a, b) in zip(coordinates, coordinates.dropFirst()) {
                        let u = vector(a), v = vector(b)
                        let arc = angle(u, v)
                        length += arc
                        XCTAssertLessThanOrEqual(arc, .pi / 4 + 1e-12)
                        let dl = unwrap(b.longitude - a.longitude)
                        // Includes quarters/eighths, not only the midpoint.
                        for step in 0...32 {
                            let t = Double(step) / 32
                            let chord = try GeoCoordinate(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                longitude: unwrap(a.longitude + dl * t))
                            let truePoint: SIMD3<Double>
                            if arc < 1e-12 {
                                truePoint = normalized(u * (1 - t) + v * t)
                            } else {
                                truePoint = normalized((u * sin((1 - t) * arc) + v * sin(t * arc)) / sin(arc))
                            }
                            let error = angle(vector(chord), truePoint) * 6371.0088
                            maximum = max(maximum, error)
                            XCTAssertLessThanOrEqual(error, tolerance, "δ=\(declination), t=\(t), tolerance=\(tolerance)")
                        }
                        edges += 1
                    }
                    // Each branch covers a complete semicircle, apart from the
                    // explicitly excluded non-unique polar epsilon at δ≈0.
                    XCTAssertEqual(length, .pi, accuracy: 2e-9)
                }
            }
            maxima[tolerance] = maximum
        }
        print("F2 dense spherical comparison edges=\(edges), 33 samples/edge, maxErrorKmByTolerance=\(maxima)")
    }

    func testRefinementTangenciesAndOpenPolarEndpoints() throws {
        let p = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 0,
                                           declinationDegrees: 45, returnedFlags: 0)
        let coarse = try AdaptiveAstroGeometry.horizon(position: p, siderealDegrees: 0, toleranceKm: 1)
        let fine = try AdaptiveAstroGeometry.horizon(position: p, siderealDegrees: 0, toleranceKm: 0.1)
        XCTAssertGreaterThan(fine.ascendant.count, coarse.ascendant.count)
        XCTAssertEqual(fine.ascendant.first?.latitude, -45)
        XCTAssertEqual(fine.ascendant.last?.latitude, 45)
        XCTAssertEqual(fine.ascendant.first, fine.descendant.first)
        XCTAssertEqual(fine.ascendant.last, fine.descendant.last)
        XCTAssertEqual(fine.ascendant.last?.longitude, -180)
        let points = coarse.ascendant
        XCTAssertLessThan(points[1].latitude - points[0].latitude,
                          points[points.count / 2].latitude - points[points.count / 2 - 1].latitude)
        for delta in [-90.0, -89.9999999999, 0, 89.9999999999, 90] {
            let position = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 10,
                                                       declinationDegrees: delta, returnedFlags: 0)
            let result = try AdaptiveAstroGeometry.horizon(position: position, siderealDegrees: 0, toleranceKm: 1)
            if delta == 0 {
                XCTAssertTrue(result.excludesNonUniquePoles)
                XCTAssertTrue(result.ascendant.allSatisfy { abs($0.latitude) < 90 })
                XCTAssertEqual(result.ascendant.first!.latitude, -90 + 4e-9, accuracy: 1e-12)
                XCTAssertTrue(result.ascendant.allSatisfy { abs($0.longitude + 80) < 1e-12 })
            } else {
                XCTAssertTrue(result.ascendant.isEmpty)
                XCTAssertTrue(result.descendant.isEmpty)
            }
        }
    }

    func testUnsupportedPrecisionFailsExplicitlyWithoutRelaxingRequest() throws {
        let position = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 0,
                                                   declinationDegrees: 45, returnedFlags: 0)
        XCTAssertThrowsError(try AdaptiveAstroGeometry.horizon(position: position, siderealDegrees: 0,
                                                              toleranceKm: 1e-10)) {
            XCTAssertEqual($0 as? AstroGeometryError, .toleranceBelowNumericalFloor)
        }
        // The input contract still accepts a positive tolerance; runtime resource
        // and numerical limits are geometry errors, not a silent contract change.
        _ = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545), geometryToleranceKm: 1e-10)
    }

    func testTenBodyWarmBenchmark() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/AstroMalik/Resources/ephe").path
        let engine = AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: directory))
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545))
        _ = try engine.calculate(request: request)
        var times: [Double] = []
        var vertexCounts: [Int] = []
        for _ in 0..<31 {
            let start = ProcessInfo.processInfo.systemUptime
            let result = try engine.calculate(request: request)
            times.append(ProcessInfo.processInfo.systemUptime - start)
            vertexCounts.append(result.lines.flatMap(\.segments).flatMap(\.coordinates).count)
        }
        times.sort()
        let p50 = times[15], p95 = times[29]
        print("F2 warm benchmark n=31, tolerance=1 km, p50=\(p50)s p95=\(p95)s vertices=\(vertexCounts[0])")
        XCTAssertEqual(Set(vertexCounts).count, 1)
        XCTAssertLessThan(p95, 1, "Orientative plan budget on the test host; record host/configuration when reporting.")
    }

    private func vector(_ p: GeoCoordinate) -> SIMD3<Double> {
        let lat = p.latitude * .pi / 180, lon = p.longitude * .pi / 180
        return SIMD3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
    }
    private func norm(_ v: SIMD3<Double>) -> Double { sqrt(v.x * v.x + v.y * v.y + v.z * v.z) }
    private func normalized(_ v: SIMD3<Double>) -> SIMD3<Double> { v / norm(v) }
    private func angle(_ u: SIMD3<Double>, _ v: SIMD3<Double>) -> Double {
        2 * asin(min(1, norm(u - v) / 2))
    }
    private func unwrap(_ value: Double) -> Double {
        let r = (value + 180).truncatingRemainder(dividingBy: 360)
        return (r < 0 ? r + 360 : r) - 180
    }
}
