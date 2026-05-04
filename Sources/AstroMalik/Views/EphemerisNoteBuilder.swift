import Foundation

enum EphemerisNoteBuilder {
    static func markdown(month: EphemerisMonth, monthTitle: String) -> String {
        var lines: [String] = [
            "# Efemérides — \(monthTitle)",
            "",
            "Calendario astrológico general calculado con Swiss Ephemeris desde AstroMalik.",
            "",
            "## Resumen",
            "- Eventos del mes: \(month.events.count)",
            "- Filas de efeméride diaria: \(month.dailyRows.count)",
            "- Hora de efeméride diaria: 00:00 UTC",
            "",
            "## Eventos del mes"
        ]

        if month.events.isEmpty {
            lines.append("No se encontraron eventos para este mes.")
        } else {
            for event in month.events {
                lines.append("- **\(event.dateLocal)** — \(event.title)\(event.subtitle.map { " · \($0)" } ?? "")")
            }
        }

        appendSection("Lunaciones", kinds: [.newMoon, .fullMoon, .firstQuarter, .lastQuarter], month: month, lines: &lines)
        appendSection("Eclipses", kinds: [.solarEclipse, .lunarEclipse], month: month, lines: &lines)
        appendSection("Estaciones", kinds: [.stationRetrograde, .stationDirect], month: month, lines: &lines)
        appendSection("Ingresos en signo", kinds: [.signIngress], month: month, lines: &lines)
        appendSection("Luna vacía de curso", kinds: [.voidOfCourse, .voidOfCourseEnd], month: month, lines: &lines)
        appendSection("Aspectos mundanos", kinds: [.mundaneAspect], month: month, lines: &lines)

        lines += [
            "",
            "## Mini efeméride diaria",
            "| Día | ☉ | ☽ | ☿ | ♀ | ♂ | ♃ | ♄ | ⛢ | ♆ | ♇ | ☊ | Fase |",
            "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
        ]
        for row in month.dailyRows {
            let values = row.positions.map { $0.formatted.replacingOccurrences(of: "|", with: "/") }
            lines.append("| \(row.date) | \(values.joined(separator: " | ")) | \(row.lunarPhaseLabel) |")
        }

        return lines.joined(separator: "\n")
    }

    private static func appendSection(
        _ title: String,
        kinds: Set<CelestialEventKind>,
        month: EphemerisMonth,
        lines: inout [String]
    ) {
        let events = month.events.filter { kinds.contains($0.kind) }
        guard !events.isEmpty else { return }
        lines += ["", "## \(title)"]
        for event in events {
            lines.append("- \(event.dateLocal): \(event.title)")
        }
    }
}
