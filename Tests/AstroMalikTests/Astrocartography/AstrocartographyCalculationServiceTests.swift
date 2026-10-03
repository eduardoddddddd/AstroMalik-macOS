import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstrocartographyCalculationServiceTests: XCTestCase {
    func testCacheUsesActualInputsAndBoundedLRU() async throws {
        let calculator = ControlledCalculator()
        let service = try AstrocartographyCalculationService(calculator: calculator, ephemerisRevision: "fixture-v1",
                                                              maximumEntries: 2)
        let a = try request(), b = try request(jd: 2451546), c = try request(tolerance: 0.5)
        let first = try await service.calculate(request: a)
        _ = try await service.calculate(request: b)
        let cached = try await service.calculate(request: a)
        XCTAssertEqual(first, cached)
        _ = try await service.calculate(request: c) // B is least recently used.
        _ = try await service.calculate(request: a)
        _ = try await service.calculate(request: b)
        let stats = await service.cacheStatistics()
        XCTAssertEqual(stats.hits, 2)
        XCTAssertEqual(stats.misses, 4)
        XCTAssertEqual(stats.evictions, 2)
        XCTAssertEqual(stats.entries, 2)
        XCTAssertEqual(calculator.calls, 4)
        let differentBodies = try request(bodies: [.moon])
        _ = try await service.calculate(request: differentBodies)
        XCTAssertEqual(calculator.calls, 5)
        await service.invalidateCache()
        let state = await service.state
        XCTAssertEqual(state, .idle)
        _ = try await service.calculate(request: a)
        XCTAssertEqual(calculator.calls, 6)
    }

    func testCacheVertexBudgetAndDisabledCache() async throws {
        let calculator = ControlledCalculator()
        let service = try AstrocartographyCalculationService(calculator: calculator, ephemerisRevision: "v1",
                                                              maximumEntries: 8, maximumVertices: 4)
        _ = try await service.calculate(request: request())
        _ = try await service.calculate(request: request(jd: 2451546))
        let stats = await service.cacheStatistics()
        XCTAssertEqual(stats.vertices, 3)
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.evictions, 1)
        let disabled = try AstrocartographyCalculationService(calculator: calculator, ephemerisRevision: "v2",
                                                               maximumVertices: 2)
        _ = try await disabled.calculate(request: request())
        _ = try await disabled.calculate(request: request())
        let disabledStats = await disabled.cacheStatistics()
        XCTAssertEqual(disabledStats.entries, 0)
        XCTAssertEqual(disabledStats.misses, 2)
    }

    func testLateNonCooperativeResultCannotOverwriteNewerOrPopulateCache() async throws {
        let gate = Gate()
        let calculator = ControlledCalculator(gates: [2451545: gate])
        let service = try AstrocartographyCalculationService(calculator: calculator, ephemerisRevision: "fixture")
        let a = try request(), b = try request(jd: 2451546)
        let old = Task { try await service.calculate(request: a) }
        defer { gate.release.signal() }
        await fulfillment(of: [gate.entered], timeout: 5)
        let fresh = try await service.calculate(request: b)
        gate.release.signal()
        await assertCancelled(old)
        let state = await service.state
        XCTAssertEqual(state, .ready(fresh))
        let stats = await service.cacheStatistics()
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.misses, 2)
    }

    func testRapidChartEditsLatestWinsEvenWhenEveryCalculatorIgnoresCancellation() async throws {
        let gates = Dictionary(uniqueKeysWithValues: (0..<20).map { (2451545.0 + Double($0), Gate()) })
        let service = try AstrocartographyCalculationService(calculator: ControlledCalculator(gates: gates), ephemerisRevision: "fixture")
        var tasks: [Task<AstrocartographyResult, Error>] = []
        defer { gates.values.forEach { $0.release.signal() } }
        for index in 0..<20 {
            let jd = 2451545.0 + Double(index)
            let r = try request(jd: jd)
            tasks.append(Task { try await service.calculate(request: r) })
            await fulfillment(of: [gates[jd]!.entered], timeout: 5)
            if index > 0 { gates[jd - 1]!.release.signal() }
        }
        gates[2451564]!.release.signal()
        for task in tasks.dropLast() { await assertCancelled(task) }
        let newest = try await tasks.last!.value
        XCTAssertEqual(newest.snapshot.request.instant.julianDay, 2451564)
        let state = await service.state
        XCTAssertEqual(state, .ready(newest))
        let stats = await service.cacheStatistics()
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.misses, 20)
    }

    func testExplicitAndCallerCancellationAndInvalidationDiscardLateResults() async throws {
        for mode in 0..<3 {
            let gate = Gate()
            let service = try AstrocartographyCalculationService(calculator: ControlledCalculator(gates: [2451545: gate]),
                                                                  ephemerisRevision: "fixture")
            let r = try request()
            let pending = Task { try await service.calculate(request: r) }
            defer { gate.release.signal() }
            await fulfillment(of: [gate.entered], timeout: 5)
            if mode == 0 { await service.cancel() }
            if mode == 1 { pending.cancel() }
            if mode == 2 { await service.invalidateCache() }
            gate.release.signal()
            await assertCancelled(pending)
            let stats = await service.cacheStatistics()
            XCTAssertEqual(stats.entries, 0)
            let state = await service.state
            XCTAssertEqual(state, mode == 2 ? .idle : .cancelled)
        }
    }

    func testFailedOrMismatchedCalculationNeverCachesAndCanRetry() async throws {
        for failure in [ControlledCalculator.Failure.error, .mismatchedRequest] {
            let service = try AstrocartographyCalculationService(calculator: ControlledCalculator(failure: failure),
                                                                  ephemerisRevision: "fixture")
            for _ in 0..<2 {
                do { _ = try await service.calculate(request: request()); XCTFail("Expected failure") }
                catch { XCTAssertFalse(error is CancellationError) }
            }
            let stats = await service.cacheStatistics()
            XCTAssertEqual(stats.entries, 0)
            XCTAssertEqual(stats.misses, 2)
            let state = await service.state
            guard case .failed = state else { return XCTFail("Expected failed state") }
        }
    }

    func testEngineHonorsCancellationAfterNonCooperativeSnapshot() async throws {
        let gate = Gate()
        let request = try request()
        let engine = AstrocartographyEngine(ephemeris: GatedEphemeris(gate: gate))
        let task = Task.detached { try engine.calculate(request: request) }
        defer { gate.release.signal() }
        await fulfillment(of: [gate.entered], timeout: 5)
        task.cancel()
        gate.release.signal()
        await assertCancelled(task)
    }

    private func assertCancelled(_ task: Task<AstrocartographyResult, Error>, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await task.value; XCTFail("Expected CancellationError", file: file, line: line) }
        catch { XCTAssertTrue(error is CancellationError, "\(error)", file: file, line: line) }
    }
    private func request(jd: Double = 2451545, tolerance: Double = 1, bodies: [AstroBody] = [.sun]) throws -> AstrocartographyRequest {
        try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd), bodies: bodies, geometryToleranceKm: tolerance)
    }
}

private final class Gate: @unchecked Sendable {
    let entered = XCTestExpectation(description: "Synchronous calculator entered")
    let release = DispatchSemaphore(value: 0)
    func wait() throws {
        entered.fulfill()
        guard release.wait(timeout: .now() + 10) == .success else { throw TestFailure.timedOut }
    }
}
private enum TestFailure: Error { case expected, timedOut }

/// Deliberately DOES NOT cooperate with Task cancellation, to exercise generation
/// checks rather than merely trusting the production engine's cancellation points.
private final class ControlledCalculator: AstrocartographyCalculating, @unchecked Sendable {
    enum Failure { case error, mismatchedRequest }
    let gates: [Double: Gate]
    let failure: Failure?
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    init(gates: [Double: Gate] = [:], failure: Failure? = nil) { self.gates = gates; self.failure = failure }
    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        lock.lock(); count += 1; lock.unlock()
        try gates[request.instant.julianDay]?.wait()
        if failure == .error { throw TestFailure.expected }
        let effective = failure == .mismatchedRequest
            ? try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: request.instant.julianDay + 1), bodies: request.bodies)
            : request
        return AstrocartographyResult(snapshot: try testSnapshot(effective), lines: [
            AstroLine(id: AstroLineID(body: request.bodies[0], angle: .mc), segments: [
                AstroLineSegment(coordinates: try [-45.0, 0, 45].map { try GeoCoordinate(latitude: $0, longitude: 0) })
            ], diagnostics: [])
        ])
    }
}
private struct GatedEphemeris: AstrocartographyEphemerisProviding {
    let gate: Gate
    func snapshot(for request: AstrocartographyRequest) throws -> EquatorialSnapshot {
        try gate.wait()
        return try testSnapshot(request)
    }
}
private func testSnapshot(_ request: AstrocartographyRequest) throws -> EquatorialSnapshot {
    try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 0,
        positions: request.bodies.map { try AstroEquatorialPosition(body: $0, rightAscensionDegrees: 0,
                                                                   declinationDegrees: 30, returnedFlags: 0) },
        provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
}
