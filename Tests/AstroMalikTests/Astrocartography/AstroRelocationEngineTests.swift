import XCTest
import CSwissEph
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstroRelocationEngineTests: XCTestCase {
    private var directory: String {
        AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")!.deletingLastPathComponent().path
    }
    private func natal(system: Character = "P", name: String = "Placidus") throws -> NatalChart {
        try SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: directory)
            var c = try AstroEngine.computeNatalChart(jd: 2451545, lat: 40.4, lon: -3.7, houseSystem: system)
            c.birthDate = "2000-01-01"; c.birthTime = "12:00:00"; c.timezone = "UTC"; c.houseSystem = name
            return c
        }
    }
    func testNatalCitySameHousesAndGeocentricPositionsAndOriginalIntact() throws {
        let original = try natal(), before = original
        let source = try AstroRelocationSource(chart: original, instant: AstroNatalInstant(julianDay: 2451545))
        let calculation = try AstroRelocationEngine(ephemerisDirectory: directory).relocate(source: source,
            destination: GeoCoordinate(latitude: original.latitude, longitude: original.longitude))
        XCTAssertEqual(calculation.chart.cuspsDegrees, original.cusps)
        XCTAssertEqual(calculation.chart.ascendantDegrees, original.ascendant.longitude)
        XCTAssertEqual(calculation.chart.mcDegrees, original.mc.longitude)
        for b in calculation.chart.bodies {
            let natal = try XCTUnwrap(original.bodies.first { $0.key == b.body.rawValue })
            XCTAssertEqual(b.longitudeDegrees, natal.longitude); XCTAssertEqual(b.house, natal.house)
        }
        XCTAssertEqual(original, before); XCTAssertEqual(calculation.source, source)
        XCTAssertEqual(calculation.destinationTimeZone.identifier, "UTC")
    }
    func testRemoteDestinationsAndZonesNeverChangeJDOrBodies() throws {
        let original = try natal()
        let source = try AstroRelocationSource(chart: original, instant: AstroNatalInstant(julianDay: 2451545))
        let engine = AstroRelocationEngine(ephemerisDirectory: directory)
        for (lat, lon, zone) in [(35.6,139.6,"Asia/Tokyo"), (-33.9,151.2,"Australia/Sydney"), (0.0,-180.0,"UTC")] {
            let result = try engine.relocate(source: source, destination: GeoCoordinate(latitude: lat, longitude: lon),
                                            timeZone: AstroDestinationTimeZone(verifiedIdentifier: zone))
            XCTAssertEqual(result.chart.instant, source.instant)
            XCTAssertEqual(result.chart.bodies.map(\.longitudeDegrees), source.bodies.map(\.longitudeDegrees))
            XCTAssertNotEqual(result.chart.cuspsDegrees, original.cusps)
            XCTAssertEqual(result.destinationTimeZone.identifier, zone)
            XCTAssertTrue(result.chart.bodies.allSatisfy { (1...12).contains($0.house) })
        }
        XCTAssertThrowsError(try AstroDestinationTimeZone(verifiedIdentifier: "Invalid/Zone"))
    }
    func testPolarFailureDoesNotSilentlyFallbackAndSupportedHouseSystems() throws {
        let engine = AstroRelocationEngine(ephemerisDirectory: directory)
        let original = try natal()
        let source = try AstroRelocationSource(chart: original, instant: AstroNatalInstant(julianDay: 2451545))
        XCTAssertThrowsError(try engine.relocate(source: source, destination: GeoCoordinate(latitude: 90, longitude: 0)))
        XCTAssertThrowsError(try AstroRelocationEngine.houseCode("Made up"))
        XCTAssertThrowsError(try AstroRelocationSource(natalChartID: UUID(), instant: source.instant, houseSystem: "Placidus", bodies: []))
        for (code, name) in [(Character("R"),"Regiomontanus"), ("W","Whole Sign"), ("K","Koch")] {
            let c = try natal(system: code, name: name)
            let s = try AstroRelocationSource(chart: c, instant: source.instant)
            let r = try engine.relocate(source: s, destination: GeoCoordinate(latitude: 40.4, longitude: -3.7))
            XCTAssertEqual(r.chart.cuspsDegrees, c.cusps)
        }
    }
    func testRelocatedAnglesAgainstIndependentEquatorialHorizonIdentities() throws {
        let original = try natal()
        var maximumResidual = 0.0
        for jd in [2451545.0,2451545.123456,2461314.5] {
            let bodies = try SwissEphemerisAccess.transaction {
                AstroEngine.configure(ephePath: directory)
                let planets = try AstroEngine.calcPlanets(jd: jd)
                return AstroBody.allCases.map { AstroNatalBody(body: $0, longitudeDegrees: planets[$0.rawValue]!.deg) }
            }
            let source = try AstroRelocationSource(natalChartID: original.id, instant: AstroNatalInstant(julianDay: jd),
                houseSystem: "Placidus", bodies: bodies)
            for (lat,lon) in [(-60.0,-179.9),(-33.9,151.2),(0.0,0.0),(40.4,-3.7),(60.0,179.9)] {
                let result = try AstroRelocationEngine(ephemerisDirectory: directory).relocate(source: source,
                    destination: GeoCoordinate(latitude: lat, longitude: lon))
                let (eps, theta) = try SwissEphemerisAccess.transaction {
                    AstroEngine.configure(ephePath: directory)
                    var e = [Double](repeating: 0,count: 6), error = [CChar](repeating: 0,count: 256)
                    guard SwissEphemerisAccess.swe_calc_ut(jd, SE_ECL_NUT, 0, &e, &error) >= 0 else { throw AstrocartographyError.ephemerisFailure("obliquity") }
                    return (e[0] * .pi/180, (SwissEphemerisAccess.swe_sidtime(jd)*15+lon) * .pi/180)
                }
                let mc = result.chart.mcDegrees * .pi/180
                // MC ecliptic point has the local sidereal right ascension.
                let mcRA = atan2(sin(mc)*cos(eps),cos(mc))
                let meridian = abs(atan2(sin(mcRA-theta),cos(mcRA-theta)))
                XCTAssertLessThan(meridian, 1e-8)
                let asc = result.chart.ascendantDegrees * .pi/180, phi = lat * .pi/180
                // Horizon dot-product, including ecliptic-to-equatorial obliquity.
                let altitudeSine = cos(phi)*cos(theta)*cos(asc) +
                    (cos(phi)*sin(theta)*cos(eps)+sin(phi)*sin(eps))*sin(asc)
                let risingDerivative = cos(phi)*(-sin(theta)*cos(asc)+cos(theta)*sin(asc)*cos(eps))
                maximumResidual = max(maximumResidual,abs(altitudeSine),meridian)
                XCTAssertLessThan(abs(altitudeSine),1e-8); XCTAssertGreaterThan(risingDerivative,0)
            }
        }
        print("F4 relocated ASC/MC independent identity max residual: \(maximumResidual)")
    }

    func testBenchmarkTenBodiesDistanceAndRelocationWithoutCache() throws {
        let c = try natal(), source = try AstroRelocationSource(chart: c, instant: AstroNatalInstant(julianDay: 2451545))
        let request = try AstrocartographyRequest(instant: source.instant, geometryToleranceKm: 0.9)
        let curves = try AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: directory)).calculate(request: request)
        let calculator = AstroLocationCalculator(relocator: AstroRelocationEngine(ephemerisDirectory: directory))
        let input = try AstroLocationCalculationRequest(curves: curves, source: source, sourceError: nil,
            destination: GeoCoordinate(latitude: -33.9, longitude: 151.2), timeZone: AstroDestinationTimeZone())
        _ = try calculator.calculate(input)
        var times: [Double] = []
        for _ in 0..<31 {
            let start = DispatchTime.now().uptimeNanoseconds
            let result = try calculator.calculate(input)
            times.append(Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000)
            XCTAssertEqual(result.analysis.proximities.count, 40); XCTAssertNotNil(result.relocation)
        }
        times.sort()
        print("F4 debug ten-body distance+relocation 31 samples ms p50=\(times[15]) p95=\(times[29]); vertices=\(curves.lines.flatMap(\.segments).reduce(0) { $0+$1.coordinates.count })")
    }

    func testConcurrentRelocationAndSnapshotMatchSerial() async throws {
        let source = try AstroRelocationSource(chart: natal(), instant: AstroNatalInstant(julianDay: 2451545))
        let engine = AstroRelocationEngine(ephemerisDirectory: directory)
        let location = try GeoCoordinate(latitude: -33, longitude: 151)
        let serial = try engine.relocate(source: source, destination: location)
        let request = try AstrocartographyRequest(instant: source.instant)
        let provider = SwissAstrocartographyEphemeris(ephemerisDirectory: directory)
        let snapshot = try provider.snapshot(for: request)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 {
                group.addTask {
                    if i % 2 == 0 { XCTAssertEqual(try engine.relocate(source: source, destination: location), serial) }
                    else { XCTAssertEqual(try provider.snapshot(for: request), snapshot) }
                }
            }
            try await group.waitForAll()
        }
    }
}
