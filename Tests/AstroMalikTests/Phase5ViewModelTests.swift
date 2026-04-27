import XCTest
@testable import AstroMalik

// MARK: - Phase 5 ViewModel Tests

@MainActor
final class PrimaryDirectionsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeChart() -> NatalChart {
        NatalChart(
            id: UUID(),
            name: "Test",
            birthDate: "1976-10-11",
            birthTime: "20:33",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            houseSystem: "Regiomontanus",
            ascendant: AngularPoint(longitude: 60.5, formatted: "♊ Géminis 00°30'"),
            mc: AngularPoint(longitude: 330.0, formatted: "♓ Piscis 00°00'"),
            cusps: Array(repeating: 0.0, count: 12),
            bodies: [
                PlanetBody(key: "SOL", label: "☉ Sol", longitude: 197.5,
                           formatted: "♎ Libra 17°30'", house: 10, retrograde: false),
                PlanetBody(key: "LUNA", label: "☽ Luna", longitude: 60.5,
                           formatted: "♊ Géminis 00°30'", house: 4, retrograde: false),
                PlanetBody(key: "MARTE", label: "♂ Marte", longitude: 340.0,
                           formatted: "♓ Piscis 10°00'", house: 6, retrograde: false),
            ]
        )
    }

    private func makeDirection(
        promissor: String = "MARTE",
        significator: String = "ASC",
        aspect: PDaspect = .conjunction,
        estimatedAge: Double = 25.5
    ) -> PrimaryDirection {
        PrimaryDirection(
            promissor: promissor,
            promissorLabel: "♂ Marte",
            significator: significator,
            significatorLabel: significator,
            aspect: aspect,
            aspectAngle: aspect.angle,
            directionType: .direct,
            aspectPlane: .mundane,
            arc: estimatedAge * 0.9856,
            estimatedAge: estimatedAge,
            estimatedDate: Date(),
            method: .regiomontanus,
            key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 40.4168
            )
        )
    }

    private func makeEnriched(
        promissor: String = "MARTE",
        significator: String = "ASC",
        aspect: PDaspect = .conjunction,
        age: Double = 25.5,
        withInterpretation: Bool = false
    ) -> EnrichedPrimaryDirection {
        let direction = makeDirection(
            promissor: promissor, significator: significator,
            aspect: aspect, estimatedAge: age
        )
        let interp: PrimaryDirectionInterpretation? = withInterpretation
            ? PrimaryDirectionInterpretation(
                directionId: direction.id,
                clave: "\(promissor)_\(significator)_CONJUNCION",
                title: "Test",
                structuralText: "Texto de prueba",
                source: "Test source",
                sourceReference: "",
                quality: 5,
                contextualText: nil
              )
            : nil
        return EnrichedPrimaryDirection(direction: direction, interpretation: interp)
    }

    // MARK: - Initial State

    func testInitialState() {
        let vm = PrimaryDirectionsViewModel(service: PrimaryDirectionsService())
        XCTAssertNil(vm.result)
        XCTAssertTrue(vm.filteredDirections.isEmpty)
        XCTAssertNil(vm.selectedDirection)
        XCTAssertFalse(vm.isCalculating)
        XCTAssertFalse(vm.isGeneratingInterpretation)
        XCTAssertNil(vm.error)
    }

    // MARK: - Filter Tests

    func testFiltersDefaultMatchesAll() {
        let filters = PDFilters()
        let dirs = [
            makeEnriched(aspect: .conjunction, age: 25),
            makeEnriched(aspect: .trine, age: 40),
            makeEnriched(aspect: .square, age: 60),
        ]
        XCTAssertTrue(dirs.allSatisfy { filters.matches($0) }, "Default filters should match all")
    }

    func testAspectFilterExcludesNonMatching() {
        var filters = PDFilters()
        filters.aspects = [.trine]

        let conjunction = makeEnriched(aspect: .conjunction, age: 25)
        let trine = makeEnriched(aspect: .trine, age: 25)

        XCTAssertFalse(filters.matches(conjunction), "Conjunction should be excluded when only trine selected")
        XCTAssertTrue(filters.matches(trine), "Trine should pass")
    }

    func testAgeRangeFilter() {
        var filters = PDFilters()
        filters.ageRange = 30...60

        let young = makeEnriched(age: 20)
        let mid = makeEnriched(age: 45)
        let old = makeEnriched(age: 70)

        XCTAssertFalse(filters.matches(young))
        XCTAssertTrue(filters.matches(mid))
        XCTAssertFalse(filters.matches(old))
    }

    func testDirectionTypeFilter() {
        var filters = PDFilters()
        filters.directionTypes = [.converse]

        let directDir = makeEnriched()  // default direction is .direct from helper
        XCTAssertFalse(filters.matches(directDir), "Direct should be excluded when only converse selected")
    }

    func testPromissorsFilterEmpty_AllPass() {
        var filters = PDFilters()
        filters.promissors = []  // empty = all pass

        XCTAssertTrue(filters.matches(makeEnriched(promissor: "SOL")))
        XCTAssertTrue(filters.matches(makeEnriched(promissor: "LUNA")))
    }

    func testPromissorsFilterNonEmpty_OnlySelected() {
        var filters = PDFilters()
        filters.promissors = ["SOL"]

        XCTAssertTrue(filters.matches(makeEnriched(promissor: "SOL")))
        XCTAssertFalse(filters.matches(makeEnriched(promissor: "LUNA")))
        XCTAssertFalse(filters.matches(makeEnriched(promissor: "MARTE")))
    }

    func testOnlyWithCorpusFilter() {
        var filters = PDFilters()
        filters.onlyWithCorpus = true

        let withInterp = makeEnriched(withInterpretation: true)
        let withoutInterp = makeEnriched(withInterpretation: false)

        XCTAssertTrue(filters.matches(withInterp))
        XCTAssertFalse(filters.matches(withoutInterp))
    }

    func testFiltersResetRestoresDefault() {
        var filters = PDFilters()
        filters.aspects = [.conjunction]
        filters.ageRange = 20...40
        filters.onlyWithCorpus = true

        filters.reset()

        XCTAssertEqual(filters, PDFilters(), "After reset, filters should equal default")
    }

    func testFilterIsDefaultWhenUnmodified() {
        let filters = PDFilters()
        XCTAssertTrue(filters.isDefault)
    }

    func testFilterIsNotDefaultWhenModified() {
        var filters = PDFilters()
        filters.onlyWithCorpus = true
        XCTAssertFalse(filters.isDefault)
    }

    // MARK: - PDSettings Tests

    func testSettingsDefaultValues() {
        let settings = PDSettings()
        XCTAssertEqual(settings.method, .regiomontanus)
        XCTAssertEqual(settings.key, .naibod)
        XCTAssertEqual(settings.maxYears, 90)
        XCTAssertEqual(settings.aspectPlane, .mundane)
    }

    func testSettingsPersistAndLoad() {
        var settings = PDSettings()
        settings.key = .ptolemy
        settings.method = .regiomontanus
        settings.maxYears = 80
        settings.persist()

        let loaded = PDSettings.load()
        XCTAssertEqual(loaded.key, .ptolemy)
        XCTAssertEqual(loaded.maxYears, 80)

        // Cleanup
        var reset = PDSettings()
        reset.key = .naibod
        reset.maxYears = 90
        reset.persist()
    }

    func testSettingsCalculatorConfigBuilt() {
        let settings = PDSettings()
        let config = settings.calculatorConfig
        XCTAssertEqual(config.method, settings.method)
        XCTAssertEqual(config.key, settings.key)
        XCTAssertEqual(config.maxYears, settings.maxYears)
        XCTAssertEqual(config.aspectPlane, settings.aspectPlane)
    }

    // MARK: - ViewModel applyFilters

    func testApplyFiltersNoResult_EmptyArray() {
        let vm = PrimaryDirectionsViewModel(service: PrimaryDirectionsService())
        XCTAssertNil(vm.result)
        vm.applyFilters()
        XCTAssertTrue(vm.filteredDirections.isEmpty)
    }

    func testSelectedDirectionClearedOnNewLoad() async {
        let vm = PrimaryDirectionsViewModel(service: PrimaryDirectionsService())
        // Pre-select a direction
        vm.selectedDirection = makeEnriched()
        XCTAssertNotNil(vm.selectedDirection)

        // Start load — it cancels and resets
        let chart = makeChart()
        // We don't need the full calculation to complete; just verify state resets immediately
        vm.loadDirections(chart: chart, jd: 2443036.0, birthDate: Date())
        XCTAssertNil(vm.selectedDirection, "selectedDirection should be cleared when new load starts")
        XCTAssertTrue(vm.isCalculating)
        XCTAssertNil(vm.result)

        // Let it finish in background (service with no corpus returns quickly)
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertFalse(vm.isCalculating)
    }

    // MARK: - DisplaySummary and Formatted helpers

    func testDisplaySummary() {
        let enriched = makeEnriched()
        XCTAssertFalse(enriched.displaySummary.isEmpty)
        XCTAssertTrue(enriched.displaySummary.contains("Marte") || enriched.displaySummary.contains("ASC"))
    }

    func testAgeFormatted() {
        let enriched = makeEnriched(age: 25.5)
        let formatted = enriched.ageFormatted
        XCTAssertTrue(formatted.contains("25"))
        XCTAssertTrue(formatted.contains("6") || formatted.contains("meses"))
    }

    func testArcFormatted() {
        let enriched = makeEnriched(age: 25.5)
        let arc = enriched.arcFormatted
        XCTAssertFalse(arc.isEmpty)
        XCTAssertTrue(arc.contains("°"))
    }
}
