import XCTest
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

extension Reports {
    func testNatalReportGeneratesNonEmptyPDFAndExpectedSections() async throws {
        let chart = try ReportTestSupport.referenceChart()
        let payload = try NatalReportBuilder.makeData(from: chart, generatedAt: Date(timeIntervalSince1970: 1_778_765_600))
        let service = ReportService()
        let html = try await service.renderHTML(request: ReportRequest(templateName: "natal", data: payload))
        ReportTestSupport.assertHTML(html, contains: ["Informe natal", "Referencia Madrid", "Rueda natal SVG", "☉", "Lectura guiada", "Apéndice: dignidades esenciales"])

        #if canImport(WebKit)
        let pdf = try await NatalReportBuilder.generate(from: chart)
        ReportTestSupport.assertPDF(pdf, contains: ["Informe natal", "Referencia Madrid", "☉"])
        #endif
    }
}
