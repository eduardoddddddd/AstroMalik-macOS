import Foundation

enum RectificationReportBuilder {
    static func generate(
        session: RectificationSession,
        result: RectificationAnalysisResult,
        narrative: RectificationNarrative?,
        pageSize: PDFPageSize = .a4Portrait
    ) async throws -> Data {
        try await ReportRenderer().render(
            html: html(session: session, result: result, narrative: narrative),
            pageSize: pageSize,
            margins: .standard
        )
    }

    static func html(session: RectificationSession, result: RectificationAnalysisResult, narrative: RectificationNarrative?) -> String {
        let candidates = result.candidates.prefix(10).enumerated().map { index, candidate in
            "<tr><td>\(index + 1)</td><td>\(escape(candidate.birthTime))</td><td>\(escape(candidate.ascendantFormatted))</td><td>\(escape(candidate.mcFormatted))</td><td>\(String(format: "%.1f", candidate.totalScore))</td></tr>"
        }.joined()
        let evidence = result.topCandidate?.evidence.prefix(30).map {
            "<tr><td>\(escape($0.technique.label))</td><td>\(escape($0.factor))</td><td>\(String(format: "%.1f", $0.score))</td><td>\(escape($0.explanation))</td></tr>"
        }.joined() ?? ""
        let warnings = result.warnings.map { "<li>\(escape($0))</li>" }.joined()
        let narrativeHTML = narrative.map { "<section><h2>Comparación narrativa opcional</h2><pre>\(escape($0.markdown))</pre><p>\(escape($0.provider.label)) · \(escape($0.model)) · \($0.inputTokens)/\($0.outputTokens) tokens</p></section>" } ?? ""
        return """
        <!doctype html><html lang="es"><head><meta charset="utf-8"><style>
        body{font-family:-apple-system,Helvetica,sans-serif;color:#202124;font-size:11pt;line-height:1.45}h1,h2{color:#234d4b}table{width:100%;border-collapse:collapse;margin:12px 0}th,td{border-bottom:1px solid #ccc;padding:6px;text-align:left;vertical-align:top}pre{white-space:pre-wrap;font-family:inherit}.notice{padding:10px;background:#fff4d6;border-left:4px solid #c68000}.meta{color:#666}
        </style></head><body>
        <h1>Rectificación natal — \(escape(session.name))</h1>
        <p class="notice">Hipótesis astrológica. No sustituye documentación oficial ni la decisión del astrólogo.</p>
        <p class="meta">Hora declarada: \(escape(session.reportedBirthTime)) · \(escape(session.birthDate)) · \(escape(session.placeName)) · Confianza: \(escape(result.overallConfidence.rawValue))</p>
        <h2>Candidatas principales</h2><table><thead><tr><th>#</th><th>Hora</th><th>ASC</th><th>MC</th><th>Score</th></tr></thead><tbody>\(candidates)</tbody></table>
        <h2>Advertencias</h2><ul>\(warnings)</ul>
        <h2>Evidencias de la candidata principal</h2><table><thead><tr><th>Técnica</th><th>Factor</th><th>Score</th><th>Explicación</th></tr></thead><tbody>\(evidence)</tbody></table>
        \(narrativeHTML)
        </body></html>
        """
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

enum RectificationNoteBuilder {
    static func markdown(session: RectificationSession, result: RectificationAnalysisResult, narrative: RectificationNarrative?) -> String {
        var lines = [
            "# Rectificación natal — \(session.name)", "",
            "> Hipótesis astrológica. No sustituye documentación oficial.", "",
            "- Hora declarada: `\(session.reportedBirthTime)`",
            "- Confianza: **\(result.overallConfidence.rawValue)**", "",
            "## Candidatas",
        ]
        for (index, candidate) in result.candidates.prefix(10).enumerated() {
            lines.append("\(index + 1). `\(candidate.birthTime)` — ASC \(candidate.ascendantFormatted), MC \(candidate.mcFormatted), score \(String(format: "%.1f", candidate.totalScore))")
        }
        lines += ["", "## Evidencias principales"]
        for evidence in result.topCandidate?.evidence.prefix(20) ?? [] {
            lines.append("- **\(evidence.technique.label)** — \(evidence.factor) (\(String(format: "%.1f", evidence.score)))")
        }
        if !result.warnings.isEmpty { lines += ["", "## Advertencias"] + result.warnings.map { "- \($0)" } }
        if let narrative { lines += ["", "## Comparación narrativa opcional", "", narrative.markdown, "", "_\(narrative.provider.label) · \(narrative.model) · \(narrative.inputTokens)/\(narrative.outputTokens) tokens_"] }
        return lines.joined(separator: "\n")
    }
}
