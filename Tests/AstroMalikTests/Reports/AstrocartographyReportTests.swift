#if canImport(PDFKit)
import PDFKit
#endif
import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

extension Reports {
    /// Real WebKit PDF, offline: no base map is requested, so the report must say so
    /// and still contain every section. Never touches the network.
    #if canImport(WebKit)
    func testAstrocartographyReportGeneratesPDFWithExplicitMaplessFallback() async throws {
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545))
        let positions = try AstroBody.allCases.enumerated().map {
            try AstroEquatorialPosition(body: $0.element, rightAscensionDegrees: Double($0.offset) * 31 + 10,
                                        declinationDegrees: Double($0.offset) * 4 - 15, returnedFlags: 0)
        }
        let snapshot = try EquatorialSnapshot(request: request, greenwichSiderealDegrees: 100, positions: positions,
            provenance: AstroProvenance(source: .syntheticFixture, libraryVersion: "test", algorithmVersion: "test", diagnostics: []))
        let curves = try AstrocartographyEngine(ephemeris: StaticAstrocartographyEphemeris(fixture: snapshot)).calculate(request: request)
        let place = try AstroPlace(name: "Lugar de prueba", coordinate: GeoCoordinate(latitude: 20, longitude: 60), origin: .manual,
                                   timeZone: AstroDestinationTimeZone())
        let calculation = AstroLocationCalculation(analysis: try AstroLocationAnalyzer.analyze(location: place.coordinate, result: curves),
                                                   relocation: nil, relocationError: "polo de prueba", curveSnapshot: snapshot)
        let chart = AstroExportDocument.Chart(id: UUID(), name: "Carta PDF", birthDate: "2000-01-01", birthTime: "12:00:00", timezone: "UTC",
            placeName: "Greenwich", houseSystem: "Placidus", natalAscendantDegrees: 10, natalMCDegrees: 280,
            natalCuspsDegrees: (0..<12).map { Double($0) * 30 + 10 })
        let document = try AstroExportDocumentBuilder.build(chart: chart, curves: curves, place: place, calculation: calculation,
                                                            policy: try AstroProximityPolicy(nearKm: 2000, regionalKm: 6000), catalog: .bundled())
        let input = AstrocartographyReportInput(document: document, curves: curves, placeCoordinate: place.coordinate)

        let failing: AstroBaseMapProvider = { .unavailable("sin conexión.") }
        #if canImport(WebKit)
        let pdf = try await AstrocartographyReportBuilder.generate(input: input, baseMap: failing)
        ReportTestSupport.assertPDF(pdf, contains: ["Informe de astrocartografía", "Carta PDF", "Lugar de prueba"])
        #endif
        let text = PDFDocument(data: pdf)?.string ?? ""
        XCTAssertTrue(text.contains("Sin mapa base"), "the figure must state the fallback")
        XCTAssertFalse(text.contains("Apple Maps"), "no Apple attribution when the base map is not used")
        XCTAssertTrue(text.contains("Distancias a las 40 líneas"))
        XCTAssertTrue(text.contains("Método y límites"))
    }
    #endif
}
