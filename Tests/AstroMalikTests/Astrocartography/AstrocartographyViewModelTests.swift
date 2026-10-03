import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

@MainActor
final class AstrocartographyViewModelTests: XCTestCase {
    #if canImport(SwiftUI)
    func testEmptyReadyFiltersEditsErrorsAndCancel() async throws {
        let service = try AstrocartographyCalculationService(calculator: UIAstroCalculator(), ephemerisRevision: "test")
        let model = AstrocartographyViewModel(factory: { service })
        await model.load(nil)
        XCTAssertEqual(model.state, .empty)
        var chart = NatalChart.placeholder
        chart.birthDate = "2000-01-01"; chart.birthTime = "12:00:00"
        await model.load(AstroChartInput(chart))
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.visibleLines.count, 40)
        XCTAssertEqual(model.presentation?.result.snapshot.request.instant.julianDay, 2451545)
        model.selectedLine = AstroLineID(body: .sun, angle: .mc)
        model.bodies = [.moon]; model.reconcileSelection()
        XCTAssertNil(model.selectedLine); XCTAssertEqual(model.visibleLines.count, 4)
        model.angles = [.asc]; XCTAssertEqual(model.visibleLines.count, 1)
        chart.birthTime = "12:00:01" // Same UUID, actual input changes.
        await model.load(AstroChartInput(chart))
        XCTAssertNotEqual(model.presentation?.result.snapshot.request.instant.julianDay, 2451545)
        let stats = await service.cacheStatistics(); XCTAssertEqual(stats.misses, 2)
        chart.timezone = "Invalid/Zone"
        await model.load(AstroChartInput(chart))
        guard case .failed = model.state else { return XCTFail("Expected explicit error") }
        XCTAssertNil(model.presentation)
        model.cancel(); XCTAssertEqual(model.state, .cancelled)
        await model.load(nil); XCTAssertEqual(model.state, .empty)
    }
    #endif

    #if canImport(SwiftUI)
    func testRapidLatestWinsAndExplicitCancellation() async throws {
        let entered = expectation(description: "old calculation entered")
        let release = DispatchSemaphore(value: 0)
        let service = try AstrocartographyCalculationService(
            calculator: UIAstroCalculator(entered: entered, release: release), ephemerisRevision: "gate")
        let model = AstrocartographyViewModel(factory: { service })
        var first = NatalChart.placeholder; first.birthDate = "2000-01-01"; first.birthTime = "12:00"
        let old = Task { await model.load(AstroChartInput(first)) }
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(model.state, .working)
        model.cancel()
        XCTAssertEqual(model.state, .cancelled)
        for day in 2...21 {
            var chart = first; chart.birthDate = String(format: "2000-01-%02d", day)
            await model.load(AstroChartInput(chart))
        }
        release.signal(); await old.value
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.presentation?.result.snapshot.request.instant.julianDay, 2451565)
        XCTAssertEqual(model.visibleLines.count, 40)
    }
    #endif

    #if canImport(SwiftUI)
    func testCancelledCallerAndNilChartDoNotPublishOldResult() async throws {
        let entered = expectation(description: "entered")
        let release = DispatchSemaphore(value: 0)
        let service = try AstrocartographyCalculationService(calculator: UIAstroCalculator(entered: entered, release: release), ephemerisRevision: "gate")
        let model = AstrocartographyViewModel(factory: { service })
        var chart = NatalChart.placeholder; chart.birthDate = "2000-01-01"; chart.birthTime = "12:00"
        let task = Task { await model.load(AstroChartInput(chart)) }
        await fulfillment(of: [entered], timeout: 5)
        task.cancel()
        await model.load(nil)
        release.signal(); await task.value
        XCTAssertEqual(model.state, .empty); XCTAssertNil(model.presentation)
    }
    #endif

    #if canImport(SwiftUI)
    func testRevisionUsesFileContentAndRealBundledService() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("sample.se1")
        try Data("aaa".utf8).write(to: file)
        let before = try AstrocartographyViewModel.resourceRevision(directory: directory)
        try Data("bbb".utf8).write(to: file)
        XCTAssertNotEqual(before, try AstrocartographyViewModel.resourceRevision(directory: directory))
        let model = AstrocartographyViewModel()
        var chart = NatalChart.placeholder; chart.birthDate = "2000-01-01"; chart.birthTime = "12:00"
        await model.load(AstroChartInput(chart))
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.visibleLines.count, 40)
        XCTAssertEqual(model.presentation?.result.snapshot.provenance.source, .swissEphemeris)
        XCTAssertEqual(model.presentation?.result.snapshot.request.geometryToleranceKm, 0.9)
    }
    #endif

    func testNavigationIdentitiesAreUniqueAndRouteIsolated() {
        XCTAssertEqual(NavItem.astrocartografia.label, "Astrocartografía")
        XCTAssertEqual(DetailRoute.astrocartography.viewIdentity, "astrocartography")
        XCTAssertEqual(Set(NavItem.allCases.map(\.id)).count, NavItem.allCases.count)
        XCTAssertNotEqual(DetailRoute.astrocartography, .reading)
    }
}

private struct UIAstroCalculator: AstrocartographyCalculating {
    var entered: XCTestExpectation? = nil
    var release: DispatchSemaphore? = nil
    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        if request.instant.julianDay == 2451545, let release {
            entered?.fulfill(); _ = release.wait(timeout: .now() + 10) // Deliberately noncooperative.
        }
        let positions = try request.bodies.map {
            try AstroEquatorialPosition(body: $0, rightAscensionDegrees: 150, declinationDegrees: 23, returnedFlags: 0)
        }
        let snapshot = try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 100, positions: positions,
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        return try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: request)
    }
}
