import Foundation

enum SolarArcNoteBuilder {
    static func filteredReportMarkdown(
        chart: NatalChart,
        mode: SolarArcMode,
        ageStart: Double,
        ageEnd: Double,
        minimumWeight: PDWeight,
        preset: PDFilterPreset?,
        directions: [SolarArcDirection]
    ) -> String {
        var lines: [String] = [
            "# Direcciones por Arco Solar — \(chart.name.isEmpty ? chart.birthDate : chart.name)",
            "",
            "Consulta generada desde AstroMalik.",
            "",
            "Etiquetas: #astromalik #direcciones #arco-solar #astrologia-predictiva",
            "",
            "## Consulta",
            "- Carta: \(chart.name.isEmpty ? chart.birthDate : chart.name)",
            "- Nacimiento: \(chart.birthDate) \(chart.birthTime) \(chart.timezone)",
            "- Lugar: \(chart.placeName.isEmpty ? "—" : chart.placeName)",
            "- Ventana de edad: \(formatAge(ageStart)) → \(formatAge(ageEnd))",
            "- Modo: \(mode.label)",
            "- Peso mínimo: \(minimumWeight.label)",
            "- Preset: \(preset?.rawValue ?? "Personalizado")",
            "- Direcciones exportadas: \(directions.count)",
            "",
            "## Aspectos exactos"
        ]

        if directions.isEmpty {
            lines.append("No hay direcciones por arco solar con los filtros actuales.")
        } else {
            for (index, direction) in directions.enumerated() {
                lines.append("\(index + 1). \(direction.weight.glyph) **\(direction.displaySummary)** — \(date(direction.exactDate))")
                lines.append("   - Edad: \(direction.ageFormatted) · Arco solar: \(direction.arcFormatted)")
                lines.append("   - Punto dirigido: \(direction.directedPointLabel) natal \(AstroEngine.degToSign(direction.directedNatalLongitude)) → dirigido \(AstroEngine.degToSign(direction.directedLongitude))")
                lines.append("   - Punto natal receptor: \(direction.natalPointLabel) \(AstroEngine.degToSign(direction.natalLongitude))")
                lines.append("   - Polaridad técnica: \(direction.polarity.label) · Peso: \(direction.weight.label)")
                lines.append("")
            }
        }

        lines += [
            "---",
            "*Generado por AstroMalik — \(generatedAt())*",
        ]
        return lines.joined(separator: "\n")
    }

    static func noteTitle(chart: NatalChart, ageStart: Double, ageEnd: Double) -> String {
        "Arco Solar — \(chart.name.isEmpty ? chart.birthDate : chart.name) — \(formatAge(ageStart)) a \(formatAge(ageEnd))"
    }

    private static func formatAge(_ age: Double) -> String {
        String(format: "%.2f años", age)
    }

    private static func date(_ date: Date) -> String {
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
