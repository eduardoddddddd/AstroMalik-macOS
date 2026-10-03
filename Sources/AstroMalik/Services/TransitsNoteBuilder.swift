import Foundation

enum TransitsNoteBuilder {
    static func markdown(
        natalChart: NatalChart,
        fromDate: Date,
        toDate: Date,
        excludeMoon: Bool,
        focusFilter: TransitFocusFilter,
        visibleEvents: [TransitEvent],
        allEvents: [TransitEvent],
        houseIngresses: [TransitHouseIngress]
    ) -> String {
        let from = displayDate(fromDate)
        let to = displayDate(toDate)
        var lines: [String] = [
            "# Tránsitos — \(natalChart.name)",
            "",
            "Consulta de tránsitos generada desde AstroMalik.",
            "",
            "## Consulta",
            "- Carta: \(natalChart.name)",
            "- Periodo: \(from) → \(to)",
            "- Filtro visible: \(focusFilter.label)",
            "- Luna transitante excluida: \(excludeMoon ? "sí" : "no")",
            "- Tránsitos calculados: \(allEvents.count)",
            "- Tránsitos exportados según filtro actual: \(visibleEvents.count)",
            "- Ingresos por casa: \(houseIngresses.count)",
            "",
            "## Tránsitos visibles"
        ]

        if visibleEvents.isEmpty {
            lines.append("No hay tránsitos visibles con el filtro actual.")
        } else {
            for (index, event) in visibleEvents.enumerated() {
                lines.append("\(index + 1). \(event.priorityStarsDisplay) **\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)** — \(event.fromDate) → \(event.toDate)")
                lines.append("   - Prioridad: \(event.priorityLabel) · \(String(format: "%.1f", event.priorityScore))")
                lines.append("   - Técnica: \(event.technicalStarsDisplay) · \(String(format: "%.1f", event.technicalScore))")
                lines.append("   - Personal: \(event.personalRelevanceStarsDisplay) · ×\(String(format: "%.2f", event.personalRelevance))")
                lines.append("   - Impacto temporal: \(event.temporalImpactStarsDisplay) · ×\(String(format: "%.2f", event.temporalImpact))")
                lines.append("   - Orbe exacto: \(String(format: "%.2f", event.minOrb))° · exacto: \(event.exactDate)\(event.retrogradeOnExact ? " · retrógrado" : "")")
                if !event.metricReasons.isEmpty {
                    lines.append("   - Motivos: \(event.metricReasons.joined(separator: ", "))")
                }
                if let text = event.text, !text.isEmpty {
                    lines.append("")
                    lines.append("   \(text)")
                }
                if let source = event.source, !source.isEmpty {
                    lines.append("   Fuente: \(source)")
                }
                lines.append("")
            }
        }

        lines.append("## Ingresos por casa natal")
        if houseIngresses.isEmpty {
            lines.append("No se detectaron ingresos por casa en esta consulta.")
        } else {
            for ingress in houseIngresses {
                lines.append("- \(String(repeating: "★", count: ingress.stars)) **\(ingress.transitLabel)** ingresa en Casa \(ingress.house) — \(ingress.date) (desde Casa \(ingress.fromHouse))")
                if let text = ingress.text, !text.isEmpty {
                    lines.append("  \(text)")
                }
                if let source = ingress.source, !source.isEmpty {
                    lines.append("  Fuente: \(source)")
                }
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt())*",
        ]

        return lines.joined(separator: "\n")
    }

    static func noteTitle(natalChart: NatalChart, fromDate: Date, toDate: Date) -> String {
        "Tránsitos — \(natalChart.name) — \(displayDate(fromDate)) a \(displayDate(toDate))"
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func generatedAt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
