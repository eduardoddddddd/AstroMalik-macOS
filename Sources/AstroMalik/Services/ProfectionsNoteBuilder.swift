import Foundation

enum ProfectionsNoteBuilder {
    static func noteTitle(chart: NatalChart, result: ProfectionResult, date: Date) -> String {
        "Profección anual \(result.annual.age) — \(chart.name) — \(displayDate(date))"
    }

    static func markdown(chart: NatalChart, result: ProfectionResult, date: Date) -> String {
        var lines: [String] = [
            "# Profección anual — \(chart.name)",
            "",
            "Fecha consultada: \(displayDate(date))",
            "",
            "## Año profeccional",
            "- Edad: \(result.annual.age)",
            "- Casa activada: \(result.annual.house)",
            "- Signo profeccionado: \(result.annual.signLabel) (\(result.annual.cuspFormatted))",
            "- Lord of the Year: \(result.annual.lordLabel)",
            "- Periodo: \(displayDate(result.annual.startDate)) → \(displayDate(result.annual.endDate))",
            "- Planetas natales en la casa: \(result.annual.natalPlanetsInHouse.isEmpty ? "—" : result.annual.natalPlanetsInHouse.map(\.label).joined(separator: ", "))",
            "",
        ]

        lines.append("## Aspectos natales del LotY")
        if result.annual.natalAspectsByLord.isEmpty {
            lines.append("No se detectaron aspectos natales mayores del LotY a otros planetas.")
        } else {
            for aspect in result.annual.natalAspectsByLord {
                lines.append("- \(aspect.lotyLabel) \(aspect.aspectLabel) \(aspect.planetLabel), orbe \(String(format: "%.2f", aspect.orb))°")
            }
        }

        lines.append("")
        lines.append("## Profección mensual")
        for period in result.monthly {
            lines.append("- Casa \(period.house), \(period.signLabel), regente \(period.lordLabel): \(displayDate(period.startDate)) → \(displayDate(period.endDate))")
        }

        lines.append("")
        lines.append("## Profección diaria — semana actual")
        for period in result.daily {
            lines.append("- \(displayDate(period.startDate)): Casa \(period.house), \(period.signLabel), regente \(period.lordLabel)")
        }

        lines.append("")
        lines.append("## Activaciones del año")
        if result.activations.isEmpty {
            lines.append("No se detectaron activaciones por tránsito para el LotY en el año profeccional.")
        } else {
            for event in result.activations.sorted(by: activationSort).prefix(80) {
                lines.append("- \(event.exactDate): \(event.priorityStarsDisplay) **\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)** · prioridad \(event.priorityLabel), orbe \(String(format: "%.2f", event.minOrb))°")
                if !event.metricReasons.isEmpty {
                    lines.append("  Motivos: \(event.metricReasons.joined(separator: ", "))")
                }
                if let text = event.text, !text.isEmpty {
                    lines.append("  \(text)")
                }
            }
            if result.activations.count > 80 {
                lines.append("- … \(result.activations.count - 80) activaciones adicionales omitidas para mantener la nota legible.")
            }
        }

        lines += [
            "",
            "---",
            "*Generado por AstroMalik — \(generatedAt())*",
        ]
        return lines.joined(separator: "\n")
    }

    private static func activationSort(_ lhs: TransitEvent, _ rhs: TransitEvent) -> Bool {
        if lhs.exactDate != rhs.exactDate { return lhs.exactDate < rhs.exactDate }
        if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
        if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
        return lhs.minOrb < rhs.minOrb
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
