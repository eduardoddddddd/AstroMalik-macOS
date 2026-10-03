import Foundation

enum ZRNoteBuilder {
    static func noteTitle(chart: NatalChart, timeline: ZRTimeline, date: Date) -> String {
        "Zodiacal Releasing \(timeline.lot.label) — \(chart.name) — \(displayDate(date, chart: chart))"
    }

    static func markdown(chart: NatalChart, timeline: ZRTimeline, date: Date) -> String {
        let effectiveDate = max(date, timeline.birthDate)
        let currentL1 = timeline.currentL1(at: effectiveDate)
        let currentL2 = timeline.currentL2(at: effectiveDate)
        let nextEvents = timeline.upcomingHighlightedEvents(after: effectiveDate, limit: 5)
        var lines: [String] = [
            "# Zodiacal Releasing — \(timeline.lot.noteLabel) — \(chart.name)",
            "",
            "Consulta de Zodiacal Releasing según la especificación de períodos de Valens usada por AstroMalik.",
            "",
            "## Lote y secta",
            "- Lote: \(timeline.lot.noteLabel)",
            "- Posición: \(timeline.lotPoint.formatted) (\(timeline.lotPoint.signLabel))",
            "- Secta: \(timeline.sect.label)",
            "- Fecha consultada: \(displayDate(effectiveDate, chart: chart))",
            "",
            "## Períodos actuales",
        ]

        if let currentL1 {
            lines.append("- L1: \(currentL1.signLabel), \(displayDateTime(currentL1.startDate, chart: chart)) → \(displayDateTime(currentL1.endDate, chart: chart))")
        } else {
            lines.append("- L1: fuera del rango calculado")
        }
        if let currentL2 {
            let badges = badgeSummary(currentL2)
            lines.append("- L2: \(currentL2.signLabel), \(displayDateTime(currentL2.startDate, chart: chart)) → \(displayDateTime(currentL2.endDate, chart: chart))\(badges.isEmpty ? "" : " · \(badges)")")
        } else {
            lines.append("- L2: fuera del rango calculado")
        }

        lines += ["", "## Próximos eventos destacados"]
        if nextEvents.isEmpty {
            lines.append("No hay próximos cambios L1, LB o peaks dentro del rango calculado.")
        } else {
            for event in nextEvents {
                lines.append("- \(displayDateTime(event.date, chart: chart)): **\(event.kind.label)** — \(event.title). \(event.detail)")
            }
        }

        lines += ["", "## Timeline L1 → L2"]
        for l1 in timeline.periods {
            lines.append("- **L1 \(l1.signLabel)**: \(displayDateTime(l1.startDate, chart: chart)) → \(displayDateTime(l1.endDate, chart: chart)) (\(Int(l1.nominalUnits)) años)")
            for l2 in l1.children {
                let badges = badgeSummary(l2)
                lines.append("  - L2 \(l2.signLabel): \(displayDateTime(l2.startDate, chart: chart)) → \(displayDateTime(l2.endDate, chart: chart))\(badges.isEmpty ? "" : " · \(badges)")")
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt(chart: chart))*",
        ]
        return lines.joined(separator: "\n")
    }

    private static func badgeSummary(_ period: ZRPeriod) -> String {
        var badges: [String] = []
        if period.isPeak { badges.append("PEAK") }
        if let angularity = period.angularity { badges.append(angularity.badge) }
        if period.hasLoosingOfBond { badges.append("LB") }
        return badges.joined(separator: ", ")
    }

    private static func displayDate(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd").string(from: date)
    }

    private static func displayDateTime(_ date: Date, chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm").string(from: date)
    }

    private static func generatedAt(chart: NatalChart) -> String {
        formatter(chart: chart, format: "yyyy-MM-dd HH:mm").string(from: Date())
    }

    private static func formatter(chart: NatalChart, format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone.current
        formatter.dateFormat = format
        return formatter
    }
}
