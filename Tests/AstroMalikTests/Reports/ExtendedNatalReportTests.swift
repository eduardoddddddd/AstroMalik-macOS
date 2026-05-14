import XCTest
@testable import AstroMalik

extension Reports {
    func testExtendedNatalReportGeneratesNonEmptyPDFAndExpectedSections() async throws {
        let chart = try ReportTestSupport.referenceChart()
        let result = try NatalExtendedAnalysis.compute(chart: chart)
        let payload = ExtendedNatalReportBuilder.makeData(chart: chart, result: result, generatedAt: Date(timeIntervalSince1970: 1_778_765_600))
        let service = ReportService()
        let html = try await service.renderHTML(request: ReportRequest(templateName: "extended_natal", data: payload))
        ReportTestSupport.assertHTML(html, contains: ["Análisis natal extendido", "Lotes helenísticos", "Almuten Figuris", "Regente de la genitura", "Recepciones mutuas", "Estrellas fijas"])

        let pdf = try await ExtendedNatalReportBuilder.generate(from: chart)
        ReportTestSupport.assertPDF(pdf, contains: ["Análisis natal extendido", "Referencia Madrid", "Almuten"])
    }
}
