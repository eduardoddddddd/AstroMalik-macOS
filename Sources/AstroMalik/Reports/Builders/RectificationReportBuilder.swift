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
        let clusters = result.clusters.prefix(10).map {
            "<tr><td>\(escape($0.timeRange))</td><td>\(escape($0.ascendantSign))</td><td>\(String(format: "%.1f", $0.averageScore))</td><td>\($0.candidateIDs.count)</td></tr>"
        }.joined()
        let diagnostics = result.topCandidate?.overfittingDiagnostics.map {
            "<p>Score bruto \(String(format: "%.1f", $0.rawScore)); penalización \(String(format: "%.1f", $0.penalty)); evento dominante \(Int($0.dominantEventShare * 100)) %; técnica dominante \(Int($0.dominantTechniqueShare * 100)) %.</p>"
        } ?? ""
        let questionnaire = session.ascendantQuestionnaire?.preliminarySignLabel.map {
            "<p>Hipótesis preliminar del cuestionario: <strong>Ascendente en \(escape($0))</strong>. Señal orientativa de baja ponderación.</p>"
        } ?? ""
        let coverage = session.events.map { event in
            let techniques = Array(Set(result.topCandidate?.evidence.filter { $0.eventID == event.id }.map(\.technique) ?? []))
                .sorted { $0.label < $1.label }
            return "<tr><td>\(escape(event.title))</td><td>\(escape(event.confidence.label))</td><td>\(result.eventCoverage[event.id, default: 0])</td><td>\(escape(techniques.map(\.label).joined(separator: ", ")))</td></tr>"
        }.joined()
        let houseSystems = result.resolvedHouseSystemEvaluations.map {
            "<tr><td>\(escape($0.houseSystem.label))</td><td>\(escape($0.topBirthTime))</td><td>\(String(format: "%.1f", $0.topScore))</td><td>\(escape($0.confidence.rawValue))</td></tr>"
        }.joined()
        let houseSystemSection = houseSystems.isEmpty ? "" : """
        <h2>Comparación de sistemas de casas</h2><table><thead><tr><th>Sistema</th><th>Hora</th><th>Score</th><th>Confianza</th></tr></thead><tbody>\(houseSystems)</tbody></table>
        """
        let narrativeHTML = narrative.map { "<section><h2>Comparación narrativa opcional</h2><pre>\(escape($0.markdown))</pre><p>\(escape($0.provider.label)) · \(escape($0.model)) · \($0.inputTokens)/\($0.outputTokens) tokens</p></section>" } ?? ""
        return """
        <!doctype html><html lang="es"><head><meta charset="utf-8"><style>
        body{font-family:-apple-system,Helvetica,sans-serif;color:#202124;font-size:11pt;line-height:1.45}h1,h2{color:#234d4b}table{width:100%;border-collapse:collapse;margin:12px 0}th,td{border-bottom:1px solid #ccc;padding:6px;text-align:left;vertical-align:top}pre{white-space:pre-wrap;font-family:inherit}.notice{padding:10px;background:#fff4d6;border-left:4px solid #c68000}.meta{color:#666}
        </style></head><body>
        <h1>Rectificación natal — \(escape(session.name))</h1>
        <p class="notice">Hipótesis astrológica. No sustituye documentación oficial ni la decisión del astrólogo.</p>
        <p class="meta">Hora declarada: \(escape(session.reportedBirthTime)) · \(escape(session.birthDate)) · \(escape(session.placeName)) · Confianza: \(escape(result.overallConfidence.rawValue)) · Escuela: \(escape(result.configUsed.resolvedSchool.label))</p>
        \(questionnaire)
        <h2>Candidatas principales</h2><table><thead><tr><th>#</th><th>Hora</th><th>ASC</th><th>MC</th><th>Score</th></tr></thead><tbody>\(candidates)</tbody></table>
        <h2>Clusters horarios</h2><table><thead><tr><th>Rango</th><th>ASC</th><th>Media</th><th>Candidatas</th></tr></thead><tbody>\(clusters)</tbody></table>
        <h2>Control anti-overfitting</h2>\(diagnostics)
        <h2>Cobertura por evento</h2><table><thead><tr><th>Evento</th><th>Fiabilidad</th><th>Técnicas</th><th>Detalle</th></tr></thead><tbody>\(coverage)</tbody></table>
        \(houseSystemSection)
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
            "- Escuela: **\(result.configUsed.resolvedSchool.label)**",
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
        if !result.clusters.isEmpty {
            lines += ["", "## Clusters horarios"] + result.clusters.prefix(10).map { "- `\($0.timeRange)` — \($0.ascendantSign), media \(String(format: "%.1f", $0.averageScore)), \($0.candidateIDs.count) candidatas" }
        }
        if let diagnostics = result.topCandidate?.overfittingDiagnostics {
            lines += ["", "## Control anti-overfitting", "- Score bruto: \(String(format: "%.1f", diagnostics.rawScore))", "- Penalización: \(String(format: "%.1f", diagnostics.penalty))", "- Evento dominante: \(Int(diagnostics.dominantEventShare * 100)) %", "- Técnica dominante: \(Int(diagnostics.dominantTechniqueShare * 100)) %"]
        }
        lines += ["", "## Cobertura por evento"]
        for event in session.events {
            let techniques = Array(Set(result.topCandidate?.evidence.filter { $0.eventID == event.id }.map(\.technique) ?? []))
                .sorted { $0.label < $1.label }
            let detail = techniques.isEmpty ? "sin cobertura" : techniques.map(\.label).joined(separator: ", ")
            lines.append("- **\(event.title)** — \(event.confidence.label), \(result.eventCoverage[event.id, default: 0]) técnicas: \(detail)")
        }
        if !result.resolvedHouseSystemEvaluations.isEmpty {
            lines += ["", "## Comparación de sistemas de casas"]
            lines += result.resolvedHouseSystemEvaluations.map {
                "- **\($0.houseSystem.label)** — `\($0.topBirthTime)`, score \(String(format: "%.1f", $0.topScore)), confianza \($0.confidence.rawValue)"
            }
        }
        if let sign = session.ascendantQuestionnaire?.preliminarySignLabel {
            lines += ["", "## Cuestionario preliminar", "- Hipótesis orientativa: **Ascendente en \(sign)**"]
        }
        if let narrative { lines += ["", "## Comparación narrativa opcional", "", narrative.markdown, "", "_\(narrative.provider.label) · \(narrative.model) · \(narrative.inputTokens)/\(narrative.outputTokens) tokens_"] }
        return lines.joined(separator: "\n")
    }
}
