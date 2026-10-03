import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstrocartographyExportTests: XCTestCase {
    // MARK: Document (F6.1/F6.4 shared model)

    func testDocumentIsDeterministicCompleteAndTimestampFree() throws {
        let f = try fixture()
        let a = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation, catalog: f.catalog)
        let b = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation, catalog: f.catalog)
        XCTAssertEqual(a, b)
        let json = try AstroExportDocumentBuilder.json(a)
        XCTAssertEqual(json, try AstroExportDocumentBuilder.json(b))
        XCTAssertFalse(json.lowercased().contains("generatedat"))
        XCTAssertEqual(a.schemaVersion, 1); XCTAssertEqual(a.kind, "astromalik.astrocartography")
        XCTAssertEqual(a.chartLines.count, 40)
        XCTAssertEqual(a.chartLines.map(\.key), AstrocartographyReadingLibrary.expectedKeys)
        let place = try XCTUnwrap(a.place)
        XCTAssertEqual(place.lines.count, 40)
        XCTAssertEqual(place.lines.map(\.distanceKm), place.lines.map(\.distanceKm).sorted())
        let nearby = place.lines.filter { $0.band != "Lejos" }.map(\.key)
        XCTAssertEqual(place.readings.map(\.key), nearby, "readings = near+regional lines, in distance order")
        XCTAssertTrue(place.missingReadings.isEmpty)
        XCTAssertEqual(a.method.sphereRadiusKm, 6371.0088)
        XCTAssertEqual(a.method.ephemerisSource, "syntheticFixture")
        XCTAssertEqual(a.editorial?.reviewStatus, "revisado-por-el-usuario-2026-10-02")
        XCTAssertTrue(a.warnings.contains { $0.contains("no verificada") })
        XCTAssertTrue(a.warnings.contains { $0.contains("Carta relocada no disponible") })
        // JSON round trip keeps the document identical.
        let decoded = try JSONDecoder().decode(AstroExportDocument.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, a)
        // Stored values are the real analysis values, not rounded for display.
        XCTAssertEqual(place.lines[0].distanceKm, f.calculation.analysis.proximities[0].distanceKm)
    }

    func testDocumentWithoutPlaceHasOnlyChartLinesAndRejectsInconsistentInput() throws {
        let f = try fixture()
        let chartOnly = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, catalog: f.catalog)
        XCTAssertNil(chartOnly.place); XCTAssertEqual(chartOnly.chartLines.count, 40)
        XCTAssertThrowsError(try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, catalog: f.catalog))
        XCTAssertThrowsError(try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, calculation: f.calculation, catalog: f.catalog))
        let other = try fixture(jd: 2451546)
        XCTAssertThrowsError(try AstroExportDocumentBuilder.build(chart: f.chart, curves: other.curves, place: f.place,
                                                                  calculation: f.calculation, catalog: f.catalog)) {
            XCTAssertEqual($0 as? AstrocartographyError, .snapshotMismatch)
        }
    }

    func testMissingEditorialTextIsVisibleInDocumentAndNeverInvented() throws {
        let f = try fixture()
        let document = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation,
                                                            catalog: .unavailable("recurso ausente."))
        let place = try XCTUnwrap(document.place)
        XCTAssertTrue(place.readings.isEmpty)
        XCTAssertFalse(place.missingReadings.isEmpty)
        XCTAssertNil(document.editorial)
        XCTAssertTrue(document.warnings.contains { $0.contains("Lecturas no disponibles") })
        XCTAssertTrue(document.warnings.contains { $0.contains("Sin lectura editorial") })
        let noReadings = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation,
                                                              catalog: f.catalog, includeReadings: false)
        XCTAssertTrue(try XCTUnwrap(noReadings.place).readings.isEmpty)
        XCTAssertTrue(try XCTUnwrap(noReadings.place).missingReadings.isEmpty)
    }

    // MARK: Markdown (F6.3 body)

    func testMarkdownHasTitleReadingsDistancesMethodAndDisclaimer() throws {
        let f = try fixture()
        let document = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation, catalog: f.catalog)
        let markdown = AstroExportMarkdown.render(document)
        XCTAssertEqual(markdown, AstroExportMarkdown.render(document))
        XCTAssertEqual(AstroExportMarkdown.title(document), "Astrocartografía — Carta de prueba — Lugar de prueba")
        XCTAssertEqual(AstroExportMarkdown.tags(document), ["astrocartografía", "astromalik", "lugar"])
        XCTAssertTrue(markdown.hasPrefix("# Astrocartografía — Carta de prueba — Lugar de prueba"))
        XCTAssertTrue(markdown.contains(try XCTUnwrap(document.place).headline))
        let firstReading = try XCTUnwrap(document.place?.readings.first)
        XCTAssertTrue(markdown.contains("### \(firstReading.title)"))
        XCTAssertTrue(markdown.contains(firstReading.practice))
        XCTAssertEqual(markdown.components(separatedBy: "\n").filter { $0.hasPrefix("| SOL:") || $0.hasPrefix("| LUNA:") || $0.hasPrefix("| PLUTON:") }.count, 3 * 4 * 2,
                       "4 angles per body, in both the distance table and the chart-lines table")
        XCTAssertTrue(markdown.contains("## Distancias a las 40 líneas"))
        XCTAssertTrue(markdown.contains("## Método y límites"))
        XCTAssertTrue(markdown.contains(AstroExportDocument.disclaimerText))
        XCTAssertTrue(markdown.contains("no verificada"))
        XCTAssertEqual(AstroExportMarkdown.tags(try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, catalog: f.catalog)), ["astrocartografía", "astromalik"])
    }

    // MARK: SVG figure (F6.2)

    func testSVGProjectionEmphasisDashesPinAndFallbackBackground() throws {
        XCTAssertEqual(AstroMapSVGRenderer.x(-180), 0, accuracy: 1e-9)
        XCTAssertEqual(AstroMapSVGRenderer.x(180), 1000, accuracy: 1e-9)
        XCTAssertEqual(AstroMapSVGRenderer.y(0), 500, accuracy: 1e-9)
        XCTAssertEqual(AstroMapSVGRenderer.y(AstroMercatorGeometry.latitudeLimit), 0, accuracy: 1e-6)
        XCTAssertEqual(AstroMapSVGRenderer.y(90), AstroMapSVGRenderer.y(AstroMercatorGeometry.latitudeLimit)) // clamped, never infinite
        let f = try fixture()
        let lines = try f.curves.lines.map { try AstroMercatorGeometry.prepare($0) }
        let sun = AstroLineID(body: .sun, angle: .mc)
        let svg = AstroMapSVGRenderer.render(lines: lines, emphasized: [sun], place: f.place.coordinate, placeName: "A & <B>", baseImageDataURI: nil)
        XCTAssertEqual(svg, AstroMapSVGRenderer.render(lines: lines, emphasized: [sun], place: f.place.coordinate, placeName: "A & <B>", baseImageDataURI: nil))
        XCTAssertTrue(svg.contains("A &amp; &lt;B&gt;"))
        XCTAssertFalse(svg.contains("<image"))
        XCTAssertTrue(svg.contains("fill=\"#EFE8D6\""))
        let sunLine = try XCTUnwrap(svg.components(separatedBy: "\n").first { $0.contains("data-line=\"SOL:MC\"") })
        XCTAssertTrue(sunLine.contains("stroke-width=\"4.0\"")); XCTAssertFalse(sunLine.contains("stroke-dasharray"))
        let dimmed = try XCTUnwrap(svg.components(separatedBy: "\n").first { $0.contains("data-line=\"SOL:IC\"") })
        XCTAssertTrue(dimmed.contains("stroke-width=\"1.2\"")); XCTAssertTrue(dimmed.contains("stroke-dasharray=\"9 5\""))
        XCTAssertTrue(svg.contains("stroke-dasharray=\"2 4\"")); XCTAssertTrue(svg.contains("stroke-dasharray=\"9 4 2 4\""))
        let order = svg.components(separatedBy: "\n").filter { $0.contains("data-line") }
        XCTAssertTrue(order.last?.contains("data-line=\"SOL:MC\"") ?? false, "emphasized lines are drawn last, on top")
        XCTAssertTrue(svg.contains("<circle"))
        let plain = AstroMapSVGRenderer.render(lines: lines, emphasized: nil, place: nil, placeName: nil, baseImageDataURI: "data:image/png;base64,AAAA")
        XCTAssertTrue(plain.contains("<image href=\"data:image/png;base64,AAAA\""))
        XCTAssertFalse(plain.contains("<circle"))
        XCTAssertTrue(plain.contains("stroke-width=\"2.2\""))
        XCTAssertEqual(Set(AstroBody.allCases.map(AstroMapSVGRenderer.bodyHex)).count, 10)
    }

    // MARK: Report data and template (F6.1/F6.2)

    func testReportDataStatesBaseMapOrExplicitFallbackAndKeepsEveryNumber() throws {
        let f = try fixture()
        let document = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation, catalog: f.catalog)
        let input = AstrocartographyReportInput(document: document, curves: f.curves, placeCoordinate: f.place.coordinate)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let none = AstrocartographyReportBuilder.makeData(input: input, baseMap: nil, generatedAt: date)
        XCTAssertTrue(none.mapNote.contains("sin mapa base"), none.mapNote.lowercased())
        XCTAssertFalse(none.mapSVG.contains("<image"))
        let failed = AstrocartographyReportBuilder.makeData(input: input, baseMap: .unavailable("sin conexión."), generatedAt: date)
        XCTAssertTrue(failed.mapNote.contains("Sin mapa base: sin conexión.")); XCTAssertTrue(failed.mapNote.contains("cuadrícula"))
        let ok = AstrocartographyReportBuilder.makeData(input: input, baseMap: AstroBaseMapResult(dataURI: "data:image/png;base64,AAAA", failure: nil), generatedAt: date)
        XCTAssertTrue(ok.mapNote.contains(AstroBaseMapSnapshot.attribution)); XCTAssertTrue(ok.mapSVG.contains("<image"))
        XCTAssertEqual(none.distances.count, 40); XCTAssertEqual(none.chartLines.count, 40)
        XCTAssertEqual(none.readings.count, try XCTUnwrap(document.place).readings.count)
        XCTAssertEqual(none.hasReadings, !none.readings.isEmpty)
        XCTAssertFalse(none.hasRelocation); XCTAssertEqual(none.relocationNote, "polo de prueba")
        XCTAssertEqual(none.legendBodies.count, 10); XCTAssertEqual(none.legendAngles.count, 4)
        XCTAssertTrue(none.hasWarnings)
        XCTAssertEqual(none, AstrocartographyReportBuilder.makeData(input: input, baseMap: nil, generatedAt: date))
    }

    func testTemplateRendersAllSectionsWithoutUnresolvedPlaceholders() async throws {
        let f = try fixture()
        let document = try AstroExportDocumentBuilder.build(chart: f.chart, curves: f.curves, place: f.place, calculation: f.calculation, catalog: f.catalog)
        let data = AstrocartographyReportBuilder.makeData(
            input: AstrocartographyReportInput(document: document, curves: f.curves, placeCoordinate: f.place.coordinate),
            baseMap: .unavailable("sin conexión."), generatedAt: Date(timeIntervalSince1970: 1_790_000_000))
        let html = try await ReportService().renderHTML(request: ReportRequest(templateName: "astrocartography", data: data))
        for expected in ["Informe de astrocartografía", "Carta de prueba", "Lugar de prueba", "Mapa de líneas", "Resumen",
                         "Distancias a las 40 líneas", "Método y límites", "<svg", "Sin mapa base: sin conexión.",
                         try XCTUnwrap(document.place?.readings.first).title, "Carta relocada", AstroExportDocument.disclaimerText] {
            XCTAssertTrue(html.contains(expected), expected)
        }
        XCTAssertFalse(html.contains("{{")); XCTAssertFalse(html.contains("}}"))
        XCTAssertEqual(html.components(separatedBy: "<tr><td>Sol · ").count - 1, 4 * 2 /* 4 angles, distances + chart lines */)
        XCTAssertFalse(html.contains("<td>SOL:"), "the PDF shows names, not machine keys")
    }

    func testHumanLineNames() {
        XCTAssertEqual(AstroExportDocumentBuilder.humanName("JUPITER:ASC"), "Júpiter en el Ascendente")
        XCTAssertEqual(AstroExportDocumentBuilder.tableName("PLUTON:IC"), "Plutón · Fondo del Cielo")
        XCTAssertEqual(AstroExportDocumentBuilder.humanName("???"), "???")
    }

    // MARK: Joplin (F6.3)

    func testJoplinExportCreatesNoteWithDedupedTagsOnlyWhenCalled() async throws {
        let client = MockJoplin(responses: [
            #"{"items":[{"id":"folder-1","title":"codex"}],"has_more":false}"#,
            #"{"id":"note-1"}"#,
            #"{"items":[{"id":"tag-existing","title":"Astromalik"}],"has_more":false}"#, // astromalik exists (case-insensitive)
        ])
        // Order: folders, note, then per tag: list tags (+ create if missing) + attach.
        let service = JoplinClipperService(settings: JoplinClipperSettings(host: "127.0.0.1", port: 41184, token: "t", notebook: "codex"), client: client)
        XCTAssertTrue(client.requests.isEmpty, "constructing the service sends nothing")
        let id = try await service.createNoteReturningID(title: "T", body: "B", tags: ["astromalik", "ASTROMALIK", " ", "lugar"])
        XCTAssertEqual(id, "note-1")
        let paths = client.requests.map { "\($0.httpMethod ?? "?") \($0.url?.path ?? "")" }
        XCTAssertEqual(paths[0], "GET /folders"); XCTAssertEqual(paths[1], "POST /notes")
        XCTAssertEqual(paths[2], "GET /tags"); XCTAssertEqual(paths[3], "POST /tags/tag-existing/notes")
        XCTAssertEqual(paths[4], "GET /tags") // "lugar": next default response has no items → created
        XCTAssertTrue(paths.contains { $0 == "POST /tags" }, paths.joined(separator: ", "))
        XCTAssertEqual(paths.filter { $0.hasSuffix("/notes") && $0.contains("/tags/") }.count, 2, "two distinct tags attached")
        let notePayload = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(client.requests[1].httpBody)) as? [String: Any])
        XCTAssertEqual(notePayload["parent_id"] as? String, "folder-1")
        let attach = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(client.requests[3].httpBody)) as? [String: Any])
        XCTAssertEqual(attach["id"] as? String, "note-1")
    }

    #if canImport(SwiftUI)
    @MainActor
    func testViewModelJoplinExportNeedsAnAnalysedPlaceAndSendsTheDocumentMarkdown() async throws {
        let model = AstrocartographyViewModel()
        let client = MockJoplin(responses: [])
        do {
            _ = try await model.exportToJoplin(settings: .default, client: client)
            XCTFail("must refuse without an analysed place")
        } catch { XCTAssertEqual(error as? AstrocartographyError, .invalidValue("exportNeedsAnalysedPlace")) }
        XCTAssertTrue(client.requests.isEmpty, "nothing is sent when there is nothing to export")
        XCTAssertNil(try model.makeExportDocument()); XCTAssertNil(try model.makeReportInput())

        await model.load(AstroChartInput(try realNatal()))
        await model.search(query: "Madrid", online: false)
        model.select(try XCTUnwrap(model.searchResults.first))
        await model.analyzePlace()
        let document = try XCTUnwrap(try model.makeExportDocument())
        XCTAssertEqual(document.place?.lines.count, 40)
        XCTAssertEqual(document.method.ephemerisSource, "swissEphemeris")
        let id = try await model.exportToJoplin(settings: JoplinClipperSettings(host: "127.0.0.1", port: 41184, token: "t", notebook: "codex"), client: client)
        XCTAssertFalse(id.isEmpty)
        let note = try XCTUnwrap(client.requests.first { $0.url?.path == "/notes" })
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(note.httpBody)) as? [String: Any])
        XCTAssertEqual(payload["body"] as? String, AstroExportMarkdown.render(document))
        XCTAssertEqual(payload["title"] as? String, AstroExportMarkdown.title(document))
        let input = try XCTUnwrap(try model.makeReportInput())
        XCTAssertEqual(input.document, document)
    }
    #endif

    // MARK: Helpers

    private struct Fixture {
        let chart: AstroExportDocument.Chart
        let curves: AstrocartographyResult
        let place: AstroPlace
        let calculation: AstroLocationCalculation
        let catalog: AstroReadingCatalog
    }

    private func fixture(jd: Double = 2451545) throws -> Fixture {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd))
        let positions = try AstroBody.allCases.enumerated().map {
            try AstroEquatorialPosition(body: $0.element, rightAscensionDegrees: Double($0.offset) * 31 + 10, declinationDegrees: Double($0.offset) * 4 - 15, returnedFlags: 0)
        }
        let snapshot = try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 100, positions: positions,
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        let curves = try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: request)
        let place = try AstroPlace(name: "Lugar de prueba", coordinate: GeoCoordinate(latitude: 20, longitude: 60), origin: .manual, timeZone: AstroDestinationTimeZone())
        let analysis = try AstroLocationAnalyzer.analyze(location: place.coordinate, result: curves)
        let calculation = AstroLocationCalculation(analysis: analysis, relocation: nil, relocationError: "polo de prueba", curveSnapshot: snapshot)
        let chart = AstroExportDocument.Chart(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Carta de prueba",
            birthDate: "2000-01-01", birthTime: "12:00:00", timezone: "UTC", placeName: "Greenwich", houseSystem: "Placidus",
            natalAscendantDegrees: 10, natalMCDegrees: 280, natalCuspsDegrees: (0..<12).map { Double($0) * 30 + 10 })
        return Fixture(chart: chart, curves: curves, place: place, calculation: calculation, catalog: .bundled())
    }

    private func realNatal() throws -> NatalChart {
        try SwissEphemerisAccess.transaction {
            AstroEngine.configure(ephePath: AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")!.deletingLastPathComponent().path)
            var c = try AstroEngine.computeNatalChart(jd: 2451545, lat: 40.4, lon: -3.7)
            c.birthDate = "2000-01-01"; c.birthTime = "12:00:00"; c.timezone = "UTC"
            return c
        }
    }
}

private final class MockJoplin: JoplinHTTPClient {
    private var responses: [Data]
    private(set) var requests: [URLRequest] = []
    init(responses: [String]) { self.responses = responses.map { Data($0.utf8) } }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let data: Data
        if !responses.isEmpty { data = responses.removeFirst() }
        else if path == "/folders" && request.httpMethod == "GET" { data = Data(#"{"items":[{"id":"folder-1","title":"codex"}],"has_more":false}"#.utf8) }
        else if path == "/tags" && request.httpMethod == "GET" { data = Data(#"{"items":[],"has_more":false}"#.utf8) }
        else { data = Data(#"{"id":"generated-id","title":"x"}"#.utf8) }
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
