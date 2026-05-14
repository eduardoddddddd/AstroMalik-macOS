import XCTest
@testable import AstroMalik

extension Reports {
    func testHoraryReportGeneratesNonEmptyPDFAndExpectedSections() async throws {
        let request = HoraryRequest(
            question: "¿Prospera el proyecto AstroMalik?",
            datetimeLocal: "1976-10-11T20:33:00",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            questionHouse: 10,
            includeFortune: true
        )
        let response = try await HoraryEngine.calculate(request)
        let query = try SavedHoraryQuery(request: request, response: response)
        let payload = HoraryReportBuilder.makeData(from: query, generatedAt: Date(timeIntervalSince1970: 1_778_765_600))
        let service = ReportService()
        let html = try await service.renderHTML(request: ReportRequest(templateName: "horary", data: payload))
        ReportTestSupport.assertHTML(html, contains: ["Informe horario", "¿Prospera el proyecto AstroMalik?", "Carta horaria", "Significadores", "Veredicto estructurado", "Espéculo completo", "☉"])

        let pdf = try await HoraryReportBuilder.generate(from: query)
        ReportTestSupport.assertPDF(pdf, contains: ["Informe horario", "AstroMalik", "Veredicto"])
    }
}
