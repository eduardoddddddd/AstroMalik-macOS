import XCTest
@testable import AstroMalik

final class AstrocartographyReadingTests: XCTestCase {
    // MARK: Resource and editorial policy (F5.1/F5.2)

    func testBundledLibraryHasAll40UniqueOriginalReadings() throws {
        let library = try AstrocartographyReadingLibrary.bundled()
        XCTAssertEqual(library.entries.count, 40)
        XCTAssertEqual(library.entries.map(\.key), AstrocartographyReadingLibrary.expectedKeys)
        XCTAssertEqual(Set(library.entries.map(\.key)).count, 40)
        XCTAssertEqual(library.editorialVersion, "astrocartography-readings-v1")
        for body in AstroBody.allCases {
            for angle in AstroAngle.allCases {
                let entry = try XCTUnwrap(library.entry(for: AstroLineID(body: body, angle: angle)))
                XCTAssertEqual(entry.lineID, AstroLineID(body: body, angle: angle))
                XCTAssertGreaterThanOrEqual(entry.characterCount, AstrocartographyReadingLibrary.minimumCharacters, entry.key)
                XCTAssertFalse(entry.sourceReferences.isEmpty, entry.key)
            }
        }
        // No layer or title may be copy-pasted between lines.
        let layers = library.entries.flatMap(\.layers) + library.entries.map(\.title)
        XCTAssertEqual(Set(layers).count, layers.count)
    }

    func testReviewStatusRecordsHumanEditorialReview() throws {
        let library = try AstrocartographyReadingLibrary.bundled()
        XCTAssertEqual(library.reviewStatus, "revisado-por-el-usuario-2026-10-02")
        XCTAssertFalse(library.reviewStatus.contains("pendiente"))
    }

    func testTitlesUseRealPlanetAndAngleNamesNotMarkers() throws {
        let names: [AstroBody: String] = [.sun: "Sol", .moon: "Luna", .mercury: "Mercurio", .venus: "Venus", .mars: "Marte",
            .jupiter: "Júpiter", .saturn: "Saturno", .uranus: "Urano", .neptune: "Neptuno", .pluto: "Plutón"]
        let angles: [AstroAngle: String] = [.asc: "Ascendente", .dsc: "Descendente", .mc: "Medio Cielo", .ic: "Fondo del Cielo"]
        for entry in try AstrocartographyReadingLibrary.bundled().entries {
            XCTAssertTrue(entry.title.contains(try XCTUnwrap(names[entry.body])), entry.title)
            XCTAssertTrue(entry.title.contains(try XCTUnwrap(angles[entry.angle])), entry.title)
        }
    }

    func testEditorialPolicyMatchesGeneratorAndRejectsForbiddenLanguage() throws {
        let object = try documentObject()
        XCTAssertEqual(object["forbiddenPatterns"] as? [String], AstrocartographyReadingLibrary.forbiddenPatterns)
        XCTAssertEqual(object["minimumCharacters"] as? Int, AstrocartographyReadingLibrary.minimumCharacters)
        for phrase in ["ahora", "hoy", "siempre", "nunca", "destino", "garantiza el éxito", "es inevitable", "sufrirás"] {
            var doc = object
            var readings = try XCTUnwrap(doc["readings"] as? [[String: Any]])
            readings[0]["practice"] = (readings[0]["practice"] as! String) + " Esto \(phrase) sucede."
            doc["readings"] = readings
            XCTAssertThrowsError(try AstrocartographyReadingLibrary(data: JSONSerialization.data(withJSONObject: doc)), phrase) {
                guard case AstroReadingError.editorialViolation(let key, _) = $0 else { return XCTFail("\($0)") }
                XCTAssertEqual(key, "SOL:ASC")
            }
        }
    }

    func testStructuralValidationRejectsIncompleteDuplicateMismatchedAndShort() throws {
        let object = try documentObject()
        let readings = try XCTUnwrap(object["readings"] as? [[String: Any]])
        func library(_ mutate: (inout [String: Any], inout [[String: Any]]) -> Void) throws -> AstrocartographyReadingLibrary {
            var doc = object, items = readings
            mutate(&doc, &items); doc["readings"] = items
            return try AstrocartographyReadingLibrary(data: JSONSerialization.data(withJSONObject: doc))
        }
        XCTAssertThrowsError(try library { _, r in r.removeLast() }) {
            XCTAssertEqual($0 as? AstroReadingError, .incompleteCoverage(["PLUTON:IC"]))
        }
        XCTAssertThrowsError(try library { _, r in r[1] = r[0] }) {
            XCTAssertEqual($0 as? AstroReadingError, .duplicateKey("SOL:ASC"))
        }
        XCTAssertThrowsError(try library { _, r in r.append(r[0]) }) {
            XCTAssertEqual($0 as? AstroReadingError, .duplicateKey("SOL:ASC"))
        }
        XCTAssertThrowsError(try library { _, r in r[3]["key"] = "SOL:MC" }) {
            XCTAssertEqual($0 as? AstroReadingError, .keyMismatch("SOL:MC"))
        }
        XCTAssertThrowsError(try library { _, r in r[5]["shadow"] = "Breve." ; r[5]["mechanism"] = "Corto." ; r[5]["potential"] = "Corto." ; r[5]["practice"] = "Corto." }) {
            guard case AstroReadingError.editorialViolation(let key, let reason) = $0 else { return XCTFail("\($0)") }
            XCTAssertEqual(key, "LUNA:DSC"); XCTAssertTrue(reason.contains("longitud"))
        }
        XCTAssertThrowsError(try library { _, r in r[0]["sourceReferences"] = [String]() }) {
            guard case AstroReadingError.editorialViolation(_, let reason) = $0 else { return XCTFail("\($0)") }
            XCTAssertTrue(reason.contains("fuentes"))
        }
        XCTAssertThrowsError(try library { d, _ in d["schemaVersion"] = 2 }) {
            XCTAssertEqual($0 as? AstroReadingError, .unsupportedSchema(2))
        }
        XCTAssertThrowsError(try AstrocartographyReadingLibrary(data: Data("{".utf8))) {
            guard case AstroReadingError.malformed = $0 else { return XCTFail("\($0)") }
        }
    }

    func testContractProjectionKeepsFrozenReadingDTO() throws {
        let library = try AstrocartographyReadingLibrary.bundled()
        let id = AstroLineID(body: .venus, angle: .dsc)
        let reading = try XCTUnwrap(library.reading(for: id))
        XCTAssertEqual(reading.lineID, id)
        XCTAssertEqual(reading.text, try XCTUnwrap(library.entry(for: id)).fullText)
        XCTAssertEqual(reading.editorialVersion, library.editorialVersion)
        XCTAssertFalse(reading.sourceReferences.isEmpty)
        let round = try JSONDecoder().decode(AstrocartographyReading.self, from: JSONEncoder().encode(reading))
        XCTAssertEqual(round, reading)
    }

    // MARK: Place connection (F5.3)

    func testPlaceReadingsAreOrderedBandedCoveredAndKeepHiddenLinesGlobal() throws {
        let catalog = try loadedCatalog()
        let analysis = try syntheticAnalysis([
            (.sun, .mc, 20), (.moon, .asc, 99.9995), (.venus, .dsc, 250), (.mars, .ic, 301), (.pluto, .mc, 900),
        ])
        let policy = try AstroProximityPolicy(nearKm: 100, regionalKm: 300)
        let all = AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog)
        XCTAssertEqual(all.items.map(\.id), ["SOL:MC", "LUNA:ASC", "VENUS:DSC"].map { "\(AstrocartographyContract.convention):\($0)" })
        XCTAssertEqual(all.items.map(\.band), [.near, .near, .regional])
        XCTAssertEqual(all.omittedDistantCount, 2)
        XCTAssertEqual(all.coverage, AstroReadingCoverage(total: 5, covered: 5, missing: []))
        XCTAssertTrue(all.items.allSatisfy { $0.lookup.entry != nil })
        XCTAssertEqual(all.items[1].crossesBoundary, true) // 99.9995 within error of 100
        XCTAssertEqual(all.items[0].crossesBoundary, false)
        // Distance data is carried untouched, separate from the text.
        XCTAssertEqual(all.items[0].proximity, analysis.proximities[0])

        let withDistant = AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog, includeDistant: true)
        XCTAssertEqual(withDistant.items.count, 5); XCTAssertEqual(withDistant.omittedDistantCount, 0)

        let filtered = AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog,
                                                      bodies: [.sun], angles: Set(AstroAngle.allCases), onlyVisible: true)
        XCTAssertEqual(filtered.items.map { $0.proximity.lineID.body }, [.sun])
        XCTAssertEqual(filtered.coverage.total, 5) // hidden lines still count globally
        let hiddenShown = AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog, bodies: [.sun])
        XCTAssertEqual(hiddenShown.items.filter { !$0.isVisibleByFilters }.count, 2)

        XCTAssertEqual(AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog), all) // deterministic
    }

    func testMissingOrUnavailableEditorialTextShowsVisibleFallbackAndKeepsDistances() throws {
        let analysis = try syntheticAnalysis([(.sun, .asc, 10), (.moon, .mc, 50)])
        let set = AstroPlaceReadingBuilder.build(analysis: analysis, policy: try AstroProximityPolicy(),
                                                 catalog: .unavailable("recurso ausente."))
        XCTAssertEqual(set.items.count, 2)
        XCTAssertEqual(set.coverage.covered, 0); XCTAssertFalse(set.coverage.isComplete)
        XCTAssertNil(set.editorialVersion)
        for item in set.items {
            guard case .missing(let id, let reason) = item.lookup else { return XCTFail("expected fallback") }
            XCTAssertEqual(id, item.proximity.lineID)
            XCTAssertTrue(reason.contains("recurso ausente")); XCTAssertTrue(reason.contains("distancias"))
        }
        XCTAssertEqual(set.items.map(\.proximity), analysis.proximities)
    }

    func testCatalogBundledMatchesLibraryAndReportsMissingResource() throws {
        guard case .loaded(let library) = AstroReadingCatalog.bundled() else { return XCTFail("bundled catalog must load") }
        XCTAssertEqual(library.entries.count, 40)
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        XCTAssertThrowsError(try AstrocartographyReadingLibrary.bundled(bundle: try XCTUnwrap(Bundle(url: empty)))) {
            XCTAssertEqual($0 as? AstroReadingError, .resourceMissing)
        }
    }

    @MainActor
    func testViewModelRealOfflinePlaceReadingsFiltersAndSelectedLine() async throws {
        let model = AstrocartographyViewModel()
        XCTAssertNil(model.placeReadings(onlyVisible: false))
        XCTAssertNil(model.selectedLineReading)
        await model.load(AstroChartInput(try natal()))
        await model.search(query: "Madrid", online: false)
        model.select(try XCTUnwrap(model.searchResults.first))
        await model.analyzePlace()
        let set = try XCTUnwrap(model.placeReadings(onlyVisible: false, includeDistant: true))
        XCTAssertEqual(set.items.count, 40)
        XCTAssertEqual(set.coverage, AstroReadingCoverage(total: 40, covered: 40, missing: []))
        XCTAssertEqual(set.items.map(\.proximity), model.placeCalculation?.analysis.proximities)
        XCTAssertTrue(set.items.allSatisfy { $0.lookup.entry != nil })

        model.bodies = []
        let hidden = try XCTUnwrap(model.placeReadings(onlyVisible: true, includeDistant: true))
        XCTAssertTrue(hidden.items.isEmpty); XCTAssertEqual(hidden.coverage.total, 40)
        model.bodies = Set(AstroBody.allCases)

        model.selectedLine = AstroLineID(body: .saturn, angle: .ic)
        XCTAssertEqual(model.selectedLineReading?.entry?.key, "SATURNO:IC")
        model.addComparison()
        let comparison = try XCTUnwrap(model.comparisons.first)
        XCTAssertEqual(model.placeReadings(for: comparison).coverage.total, 40)

        let degraded = AstrocartographyViewModel(readingCatalog: .unavailable("sin recurso."))
        degraded.selectedLine = AstroLineID(body: .sun, angle: .mc)
        guard case .missing? = degraded.selectedLineReading else { return XCTFail("fallback expected") }
    }

    // MARK: Helpers

    private func loadedCatalog() throws -> AstroReadingCatalog { .loaded(try AstrocartographyReadingLibrary.bundled()) }

    private func documentObject() throws -> [String: Any] {
        let url = try XCTUnwrap(AppResources.bundle.url(forResource: "readings_v1", withExtension: "json", subdirectory: "Astrocartography"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func syntheticAnalysis(_ lines: [(AstroBody, AstroAngle, Double)]) throws -> LocationAnalysis {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545))
        let location = try GeoCoordinate(latitude: 40, longitude: -3)
        let proximities = try lines.map {
            AstroLineProximity(lineID: AstroLineID(body: $0.0, angle: $0.1), distanceKm: $0.2,
                               nearestPoint: location, estimatedErrorKm: 0.001)
        }
        return LocationAnalysis(request: request, location: location, proximities: proximities, sphereRadiusKm: AstroLocationAnalyzer.sphereRadiusKm)
    }

    private func natal() throws -> NatalChart {
        try SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")!.deletingLastPathComponent().path)
            var c = try AstroEngine.computeNatalChart(jd: 2451545, lat: 40.4, lon: -3.7)
            c.birthDate = "2000-01-01"; c.birthTime = "12:00:00"; c.timezone = "UTC"
            return c
        }
    }
}
