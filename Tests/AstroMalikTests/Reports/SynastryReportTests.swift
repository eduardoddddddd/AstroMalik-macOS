import XCTest
@testable import AstroMalik

extension Reports {
    func testSynastryReportGeneratesNonEmptyPDFAndExpectedSections() async throws {
        let chartA = try ReportTestSupport.referenceChart(name: "Referencia A")
        let chartB = try ReportTestSupport.referenceChart(name: "Referencia B", birthTime: "21:03")
        let reading = SynastryReading(chartA: chartA, chartB: chartB, aspects: AstroEngine.computeSynastryAspects(chartA: chartA, chartB: chartB))
        let payload = SynastryReportBuilder.makeData(from: reading, generatedAt: Date(timeIntervalSince1970: 1_778_765_600))
        let service = ReportService()
        let html = try await service.renderHTML(request: ReportRequest(templateName: "synastry", data: payload))
        ReportTestSupport.assertHTML(html, contains: ["Informe de sinastría", "Referencia A", "Referencia B", "Rueda doble SVG", "Aspectos A→B", "Casas mutuas"])

        let pdf = try await SynastryReportBuilder.generate(from: reading)
        ReportTestSupport.assertPDF(pdf, contains: ["Informe de sinastría", "Referencia A", "Referencia B"])
    }
}
