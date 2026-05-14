import Foundation
import AppKit

enum ReportSmoke {
    struct Payload: Codable, Sendable {
        let header: ReportHeaderData
        let cover: ReportCoverData
        let includeTOC: Bool
        let generatedDate: String
        let body: String
    }

    static func runIfRequestedFromEnvironment() {
        guard ProcessInfo.processInfo.environment["ASTROMALIK_REPORT_SMOKE"] == "1" else { return }
        Task {
            do {
                let url = try await renderDummyPDF()
                await MainActor.run {
                    _ = NSWorkspace.shared.open(url)
                }
            } catch {
                fputs("[ReportSmoke] Error generando PDF: \(error)\n", stderr)
            }
        }
    }

    static func renderDummyPDF() async throws -> URL {
        let generated = DateFormatter.reportSmoke.string(from: Date())
        let payload = Payload(
            header: ReportHeaderData(
                chartName: "Carta de prueba",
                reportTitle: "Informe PDF de prueba",
                generatedDate: generated
            ),
            cover: ReportCoverData(
                chartName: "Carta de prueba",
                birthDate: "11/10/1976",
                birthTime: "20:33",
                place: "Madrid, España",
                generatedDate: generated,
                ascSign: "Géminis",
                ascGlyph: "♊︎"
            ),
            includeTOC: true,
            generatedDate: generated,
            body: """
            <section>
              <h2>Resumen ejecutivo</h2>
              <p>Esta página valida la infraestructura HTML+CSS → WKWebView.createPDF con tema claro, portada, cabecera, pie y tablas.</p>
              <h3>Prioridades</h3>
              <p><span class=\"badge priority-medium\">medium</span> Señal de ejemplo para comprobar badges y composición tipográfica.</p>
              <table>
                <thead><tr><th>Planeta</th><th>Glifo</th><th>Lectura</th></tr></thead>
                <tbody>
                  <tr><td>Sol</td><td><span class=\"glyph\">☉</span></td><td>Centro de voluntad y claridad.</td></tr>
                  <tr><td>Luna</td><td><span class=\"glyph\">☽</span></td><td>Memoria corporal y fluctuación.</td></tr>
                </tbody>
              </table>
            </section>
            """
        )
        let request = ReportRequest(templateName: "_layout", data: payload, pageSize: .a4Portrait, landscape: false)
        let pdf = try await ReportService().generate(request: request)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AstroMalik-ReportSmoke")
            .appendingPathExtension("pdf")
        try pdf.write(to: url, options: .atomic)
        return url
    }
}

private extension DateFormatter {
    static let reportSmoke: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
}
