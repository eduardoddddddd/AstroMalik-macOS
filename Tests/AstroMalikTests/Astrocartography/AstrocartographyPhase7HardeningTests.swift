import Darwin
import XCTest
@testable import AstroMalik

/// Independent F7 checks: they compare astrocartography with a serial baseline and
/// with natal output, instead of trusting the tests written alongside each phase.
final class AstrocartographyPhase7HardeningTests: XCTestCase {
    func testBurstOfChartChangesNeverMixesSnapshots() async throws {
        let engine = try makeEngine()
        let service = try AstrocartographyCalculationService(
            calculator: DelayingCalculator(inner: engine, nanoseconds: 30_000_000),
            ephemerisRevision: "f7-burst",
            maximumEntries: 4
        )
        let dates = stride(from: 2_451_545.0, through: 2_451_545.0 + 120, by: 15).map { $0 }
        let requests = try dates.map { try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: $0)) }
        try await withThrowingTaskGroup(of: AstrocartographyResult?.self) { group in
            for request in requests {
                group.addTask {
                    do { return try await service.calculate(request: request) }
                    catch is CancellationError { return nil }
                    catch { throw error }
                }
            }
            for try await accepted in group {
                guard let accepted else { continue }
                let serial = try engine.calculate(request: accepted.snapshot.request)
                XCTAssertEqual(accepted, serial)
            }
        }
        let settledRequest = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2_459_000.5))
        let settled = try await service.calculate(request: settledRequest)
        XCTAssertEqual(settled, try engine.calculate(request: settledRequest))
    }

    func testExplicitCancelDropsTheInFlightChart() async throws {
        let engine = try makeEngine()
        let entered = expectation(description: "stale in flight")
        let replacementEntered = expectation(description: "replacement started")
        let release = DispatchSemaphore(value: 0)
        let service = try AstrocartographyCalculationService(
            calculator: GatedCalculator(inner: engine, staleJulianDay: 2_451_545, entered: entered,
                                        replacementEntered: replacementEntered, release: release),
            ephemerisRevision: "f7-cancel"
        )
        let stale = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2_451_545))
        let replacement = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2_452_000))
        let old = Task { try await service.calculate(request: stale) }
        await fulfillment(of: [entered], timeout: 5)
        let recent = Task { try await service.calculate(request: replacement) }
        await fulfillment(of: [replacementEntered], timeout: 5)
        release.signal()
        do {
            _ = try await old.value
            XCTFail("la carta sustituida no puede publicarse")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let published = try await recent.value
        XCTAssertEqual(published.snapshot.request, replacement)
        XCTAssertEqual(published, try engine.calculate(request: replacement))
    }

    func testConcurrentNatalAndAstrocartographyMatchSerialBaselines() async throws {
        let directory = ephemerisDirectory()
        AstroEngine.configure(ephePath: directory)
        let samples: [(jd: Double, lat: Double, lon: Double)] = [
            (2_451_545.0, 0, 0),
            (2_451_545.0, 51.477, 0),
            (2_451_545.0, -33.8688, 151.2093),
            (2_460_000.5, 64.1466, -21.9426),
            (2_390_000.5, -54.8, -68.3)
        ]
        let natalBaseline = try samples.map { try AstroEngine.computeNatalChart(jd: $0.jd, lat: $0.lat, lon: $0.lon) }
        let engine = AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: directory))
        let requests = try samples.map { try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: $0.jd)) }
        let astroBaseline = try requests.map { try engine.calculate(request: $0) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                let sample = samples[index % samples.count]
                let expectedNatal = natalBaseline[index % samples.count]
                let request = requests[index % samples.count]
                let expectedAstro = astroBaseline[index % samples.count]
                group.addTask {
                    let chart = try AstroEngine.computeNatalChart(jd: sample.jd, lat: sample.lat, lon: sample.lon)
                    guard abs(chart.ascendant.longitude - expectedNatal.ascendant.longitude) < 1e-8,
                          abs(chart.mc.longitude - expectedNatal.mc.longitude) < 1e-8,
                          chart.bodies.count == expectedNatal.bodies.count else {
                        throw Phase7Mismatch.natalAngles
                    }
                    for body in chart.bodies {
                        guard let base = expectedNatal.bodies.first(where: { $0.key == body.key }),
                              abs(body.longitude - base.longitude) < 1e-8,
                              body.house == base.house,
                              body.retrograde == base.retrograde else {
                            throw Phase7Mismatch.natalBody
                        }
                    }
                }
                group.addTask {
                    let result = try engine.calculate(request: request)
                    guard result == expectedAstro else { throw Phase7Mismatch.astrocartography }
                }
            }
            try await group.waitForAll()
        }
    }

    func testSyntheticInstantsKeepMeridianOppositionAndBounds() throws {
        let engine = try makeEngine()
        let dates = [2_378_496.5, 2_415_020.0, 2_451_545.0, 2_488_069.5, 2_600_000.0, 2_816_787.0]
        for julianDay in dates {
            let result = try engine.calculate(request: AstrocartographyRequest(
                instant: AstroNatalInstant(julianDay: julianDay)))
            XCTAssertEqual(result.snapshot.positions.count, AstroBody.allCases.count)
            XCTAssertEqual(result.lines.count, AstroBody.allCases.count * AstroAngle.allCases.count)
            XCTAssertEqual(result.snapshot.provenance.source, .swissEphemeris)
            XCTAssertTrue((0..<360).contains(result.snapshot.greenwichSiderealDegrees))
            for body in AstroBody.allCases {
                let mc = try XCTUnwrap(result.lines.first { $0.id.body == body && $0.id.angle == .mc })
                let ic = try XCTUnwrap(result.lines.first { $0.id.body == body && $0.id.angle == .ic })
                let mcLongitude = try XCTUnwrap(mc.segments.first?.coordinates.first?.longitude)
                let icLongitude = try XCTUnwrap(ic.segments.first?.coordinates.first?.longitude)
                XCTAssertEqual(oppositeSeparation(mcLongitude, icLongitude), 180, accuracy: 1e-6)
                XCTAssertTrue(mc.segments.allSatisfy { segment in
                    segment.coordinates.allSatisfy { $0.longitude == mcLongitude && (-90...90).contains($0.latitude) }
                })
            }
            for line in result.lines {
                for coordinate in line.segments.flatMap(\.coordinates) {
                    XCTAssertTrue(coordinate.latitude.isFinite && coordinate.longitude.isFinite)
                    XCTAssertTrue((-90...90).contains(coordinate.latitude))
                    XCTAssertTrue((-180..<180).contains(coordinate.longitude))
                }
            }
        }
        let early = try engine.calculate(request: AstrocartographyRequest(
            instant: AstroNatalInstant(julianDay: 2_378_496.5)))
        XCTAssertTrue(early.snapshot.provenance.diagnostics.contains {
            $0.code == SwissAstrocartographyEphemeris.fallbackDiagnosticCode && $0.message.contains("SOL")
        })
    }

    func testTenBodyWarmBudgetOnThisHost() throws {
        let engine = try makeEngine()
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2_451_545))
        _ = try engine.calculate(request: request)
        var times: [Double] = []
        var vertexCount = 0
        for _ in 0..<31 {
            let start = ProcessInfo.processInfo.systemUptime
            let result = try engine.calculate(request: request)
            times.append(ProcessInfo.processInfo.systemUptime - start)
            vertexCount = result.lines.flatMap(\.segments).flatMap(\.coordinates).count
        }
        times.sort()
        let p50 = times[15]
        let p95 = times[29]
        print("F7 warm benchmark model=\(machineModel()) os=\(ProcessInfo.processInfo.operatingSystemVersionString) config=debug n=31 jd=2451545 tolerance=1km p50=\(p50)s p95=\(p95)s vertices=\(vertexCount)")
        XCTAssertLessThan(p95, 1)
        XCTAssertGreaterThan(vertexCount, 0)
    }

    private func makeEngine() throws -> AstrocartographyEngine {
        AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: ephemerisDirectory()))
    }

    private func ephemerisDirectory() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AstroMalik/Resources/ephe").path
    }

    private func oppositeSeparation(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(raw, 360 - raw)
    }

    private func machineModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 1 else { return "desconocido" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}

private enum Phase7Mismatch: Error {
    case natalAngles
    case natalBody
    case astrocartography
}

/// Delays inside the detached calculation so a newer chart can supersede it.
private struct DelayingCalculator: AstrocartographyCalculating {
    let inner: AstrocartographyEngine
    let nanoseconds: UInt64

    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        try Task.checkCancellation()
        Thread.sleep(forTimeInterval: Double(nanoseconds) / 1_000_000_000)
        try Task.checkCancellation()
        return try inner.calculate(request: request)
    }
}

/// Blocks the first request until the test has started its replacement.
private struct GatedCalculator: AstrocartographyCalculating {
    let inner: AstrocartographyEngine
    let staleJulianDay: Double
    let entered: XCTestExpectation
    let replacementEntered: XCTestExpectation
    let release: DispatchSemaphore

    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        if request.instant.julianDay == staleJulianDay {
            entered.fulfill()
            _ = release.wait(timeout: .now() + 10)
        } else {
            replacementEntered.fulfill()
        }
        try Task.checkCancellation()
        return try inner.calculate(request: request)
    }
}
