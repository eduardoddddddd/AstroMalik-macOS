import XCTest
@testable import AstroMalik

extension Reports {
    func testReportRendererProducesPDFMagicBytes() async throws {
        let html = """
        <!doctype html>
        <html lang="es">
        <head><meta charset="utf-8"><style>body { font-family: serif; }</style></head>
        <body><h1>Informe mínimo</h1><p>AstroMalik PDF smoke.</p></body>
        </html>
        """
        let data = try await ReportRenderer(timeout: 15).render(html: html)
        let prefix = String(decoding: data.prefix(5), as: UTF8.self)
        XCTAssertEqual(prefix, "%PDF-")
    }
}
