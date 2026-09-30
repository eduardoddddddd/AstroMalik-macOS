import XCTest
@testable import AstroMalik

final class AstroPlaceWorkflowTests: XCTestCase {
    func testOfflineAccentSearchDoesNotRequireNetworkAndUnknownZoneIsUTC() async throws {
        let service = try AstroPlaceSearchService(data: Data("[{\"label\":\"Málaga, España\",\"lat\":36.7,\"lon\":-4.4},{\"label\":\"Tokyo\",\"lat\":35.6,\"lon\":139.6}]".utf8))
        let r = try await service.search(query: "  MALAGA  ", online: false)
        XCTAssertEqual(r.places.count, 1); XCTAssertEqual(r.places[0].origin, .localCatalog)
        XCTAssertEqual(r.places[0].timeZone.identifier, "UTC"); XCTAssertFalse(r.places[0].timeZone.isVerified)
        XCTAssertNil(r.warning)
        let empty = try await service.search(query: " ", online: false); XCTAssertTrue(empty.places.isEmpty)
        let unknown = try await service.search(query: "NoSuchCity", online: false); XCTAssertTrue(unknown.places.isEmpty)
        let bundled = try await AstroPlaceSearchService().search(query: "Madrid", online: false)
        XCTAssertFalse(bundled.places.isEmpty)
    }
    func testLocationServiceLatestWinsAndCacheActualInputs() async throws {
        let entered = expectation(description: "old entered"), release = DispatchSemaphore(value: 0)
        let calculator = WorkflowCalculator(entered: entered, release: release)
        let service = try AstroLocationCalculationService(calculator: calculator, revision: "test", maximumEntries: 2)
        let first = try request(longitude: 0), second = try request(longitude: 10)
        let old = Task { try await service.calculate(first) }
        await fulfillment(of: [entered], timeout: 5)
        let recent = try await service.calculate(second)
        release.signal()
        do { _ = try await old.value; XCTFail("old must cancel") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(recent.analysis.location.longitude, 10)
        _ = try await service.calculate(second)
        let hits = await service.hits; XCTAssertEqual(hits, 1)
        let differentJD = try request(longitude: 10, jd: 2451546)
        _ = try await service.calculate(differentJD)
        let changedZone = AstroLocationCalculationRequest(curves: second.curves, source: second.source, sourceError: second.sourceError,
            destination: second.destination, timeZone: try AstroDestinationTimeZone(verifiedIdentifier: "Asia/Tokyo"))
        _ = try await service.calculate(changedZone)
        let misses = await service.misses; XCTAssertEqual(misses, 4)
        await service.invalidateCache()
        _ = try await service.calculate(changedZone)
        let lastMisses = await service.misses; XCTAssertEqual(lastMisses, 5)
    }
    func testCallerCancellationInvalidationAndNoStaleCache() async throws {
        let entered = expectation(description: "entered"), release = DispatchSemaphore(value: 0)
        let service = try AstroLocationCalculationService(calculator: WorkflowCalculator(entered: entered, release: release), revision: "test")
        let first = try request(longitude: 0)
        let task = Task { try await service.calculate(first) }
        await fulfillment(of: [entered], timeout: 5)
        task.cancel(); await service.invalidateCache(); release.signal()
        do { _ = try await task.value; XCTFail("cancelled") } catch { XCTAssertTrue(error is CancellationError) }
        let hits = await service.hits; XCTAssertEqual(hits, 0)
    }
    func testPolarRelocationFailureRetainsDistances() throws {
        let r = try request(longitude: 0)
        let calculator = AstroLocationCalculator(relocator: UnavailableRelocator())
        let bodies = AstroBody.allCases.map { AstroNatalBody(body: $0, longitudeDegrees: 20) }
        let s = try AstroRelocationSource(natalChartID: UUID(), instant: r.curves.snapshot.request.instant, houseSystem: "Placidus", bodies: bodies)
        let actual = AstroLocationCalculationRequest(curves: r.curves, source: s, sourceError: nil,
            destination: r.destination, timeZone: r.timeZone)
        let calculation = try calculator.calculate(actual)
        XCTAssertFalse(calculation.analysis.proximities.isEmpty)
        XCTAssertNil(calculation.relocation); XCTAssertEqual(calculation.relocationError, "polar test")
    }
    @MainActor
    func testViewModelRealOfflineSelectionRelocationComparisonAndNatalEdits() async throws {
        let chart = try natal()
        let model = AstrocartographyViewModel()
        await model.load(AstroChartInput(chart))
        XCTAssertEqual(model.state, .ready)
        await model.search(query: "Madrid", online: false)
        model.select(try XCTUnwrap(model.searchResults.first))
        await model.analyzePlace()
        XCTAssertEqual(model.placeState, .ready)
        XCTAssertNotNil(model.placeCalculation?.relocation)
        XCTAssertEqual(model.placeCalculation?.curveSnapshot, model.presentation?.result.snapshot)
        XCTAssertEqual(model.placeCalculation?.analysis.proximities.count, 40)
        model.addComparison(); XCTAssertEqual(model.comparisons.count, 1)
        model.bodies = []; XCTAssertTrue(model.visibleProximities.isEmpty)
        XCTAssertEqual(model.placeCalculation?.analysis.proximities.count, 40)
        for lon in 1...7 {
            model.select(try AstroPlace(name: "manual \(lon)", coordinate: GeoCoordinate(latitude: 10, longitude: Double(lon)), origin: .manual, timeZone: AstroDestinationTimeZone()))
            await model.analyzePlace(); model.addComparison()
        }
        XCTAssertEqual(model.comparisons.count, 6)
        var edited = chart; edited.latitude += 1 // same ID/time but actual natal record edited
        XCTAssertNotEqual(AstroChartInput(edited), AstroChartInput(chart))
        await model.load(AstroChartInput(edited))
        XCTAssertNil(model.placeCalculation); XCTAssertTrue(model.comparisons.isEmpty); XCTAssertNil(model.selectedPlace)
        model.cancel(); XCTAssertEqual(model.placeState, .empty)
    }
    @MainActor
    func testViewModelOldLocationCannotPublishAndSearchLatestWins() async throws {
        let entered = expectation(description: "old location"), release = DispatchSemaphore(value: 0)
        let service = try AstroLocationCalculationService(calculator: WorkflowCalculator(entered: entered, release: release), revision: "test")
        let searchEntered = expectation(description: "old search"), gate = SearchGate()
        let model = AstrocartographyViewModel(locationFactory: { service }, placeSearch: { query, _ in
            if query == "old" { searchEntered.fulfill(); await gate.wait() }
            return AstroPlaceSearchResult(places: [try AstroPlace(name: query, coordinate: GeoCoordinate(latitude: 0, longitude: 1), origin: .localCatalog, timeZone: AstroDestinationTimeZone())], warning: nil)
        })
        await model.load(AstroChartInput(try natal()))
        model.selectedPlace = try GeoCoordinate(latitude: 0, longitude: 0)
        let old = Task { await model.analyzePlace() }
        await fulfillment(of: [entered], timeout: 5)
        model.selectedPlace = try GeoCoordinate(latitude: 0, longitude: 10)
        XCTAssertNil(model.placeCalculation)
        await model.analyzePlace(); release.signal(); await old.value
        XCTAssertEqual(model.placeCalculation?.analysis.location.longitude, 10)
        let oldSearch = Task { await model.search(query: "old", online: false) }
        await fulfillment(of: [searchEntered], timeout: 5)
        await model.search(query: "new", online: false); await gate.resume(); await oldSearch.value
        XCTAssertEqual(model.searchResults.first?.name, "new")
    }
    func testFingerprintIncludesChartFieldsAndHouseSystem() throws {
        let chart = try natal(); let base = try AstroNatalFingerprint.make(chart)
        var changed = chart; changed.name = "renamed"; XCTAssertNotEqual(base, try AstroNatalFingerprint.make(changed))
        changed = chart; changed.houseSystem = "Koch"; XCTAssertNotEqual(base, try AstroNatalFingerprint.make(changed))
        changed = chart; changed.bodies[0].longitude += 0.01; XCTAssertNotEqual(base, try AstroNatalFingerprint.make(changed))
        XCTAssertEqual(base, try AstroNatalFingerprint.make(chart))
    }
    private func natal() throws -> NatalChart {
        try SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")!.deletingLastPathComponent().path)
            var c = try AstroEngine.computeNatalChart(jd: 2451545, lat: 40.4, lon: -3.7)
            c.birthDate = "2000-01-01"; c.birthTime = "12:00:00"; c.timezone = "UTC"
            return c
        }
    }
    private func request(longitude: Double, jd: Double = 2451545) throws -> AstroLocationCalculationRequest {
        let req = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd), bodies: [.sun])
        let snapshot = try EquatorialSnapshot(request: req, greenwichSiderealDegrees: 0,
            positions: [AstroEquatorialPosition(body: .sun, rightAscensionDegrees: 20, declinationDegrees: 23, returnedFlags: 0)],
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        let curves = try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: req)
        return try AstroLocationCalculationRequest(curves: curves, source: nil, sourceError: "test no source",
            destination: GeoCoordinate(latitude: 0, longitude: longitude), timeZone: AstroDestinationTimeZone())
    }
}
private struct WorkflowCalculator: AstroLocationCalculating {
    let entered: XCTestExpectation?
    let release: DispatchSemaphore?
    func calculate(_ request: AstroLocationCalculationRequest) throws -> AstroLocationCalculation {
        if request.destination.longitude == 0, let release {
            entered?.fulfill(); _ = release.wait(timeout: .now() + 10)
        }
        // Intentionally ignores cancellation; the service must still reject old completion.
        // Analyzer cooperates, but both before/after checks are exercised by service tests.
        return AstroLocationCalculation(analysis: try AstroLocationAnalyzer.analyze(location: request.destination, result: request.curves), relocation: nil, relocationError: "test")
    }
}
private struct UnavailableRelocator: AstroRelocationCalculating {
    func relocate(source: AstroRelocationSource, destination: GeoCoordinate, timeZone: AstroDestinationTimeZone) throws -> AstroRelocationCalculation {
        throw AstrocartographyError.housesUnavailable("polar test")
    }
}
private actor SearchGate {
    private var continuation: CheckedContinuation<Void,Never>?
    func wait() async { await withCheckedContinuation { continuation = $0 } }
    func resume() { continuation?.resume(); continuation = nil }
}
