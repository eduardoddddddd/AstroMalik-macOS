import XCTest
@testable import AstroMalik

extension Reports {
    func testReportServiceRendersLayoutHTMLWithMockChartName() async throws {
        let generatedDate = "14 de mayo de 2026"
        let payload = MockReportPayload(
            header: ReportHeaderData(
                chartName: "Carta Mock de Malik",
                reportTitle: "Informe natal mock",
                generatedDate: generatedDate
            ),
            cover: ReportCoverData(
                chartName: "Carta Mock de Malik",
                birthDate: "11/10/1976",
                birthTime: "20:33",
                place: "Madrid, España",
                generatedDate: generatedDate,
                ascSign: "Géminis",
                ascGlyph: "♊︎"
            ),
            includeTOC: true,
            generatedDate: generatedDate,
            body: "<section><h2>Sección mock</h2><p>Contenido del informe.</p></section>"
        )
        let request = ReportRequest(templateName: "_layout", data: payload, pageSize: .a4Portrait, landscape: false)
        let html = try await ReportService().renderHTML(request: request)
        XCTAssertTrue(html.contains("Carta Mock de Malik"))
        XCTAssertTrue(html.contains("<main class=\"report-body\">"))
        XCTAssertTrue(html.contains("Sección mock"))
    }

    func testReportThemeCSSVariablesContainDecidedPaletteAndScale() {
        let css = ReportTheme.default.cssVariables()
        XCTAssertTrue(css.contains("--bg: #F4EEE0;"))
        XCTAssertTrue(css.contains("--primary: #1B2A4E;"))
        XCTAssertTrue(css.contains("--font-size-h1: 32pt;"))
        XCTAssertTrue(css.contains("--font-size-body: 11pt;"))
    }
}

private struct MockReportPayload: Codable, Sendable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}
