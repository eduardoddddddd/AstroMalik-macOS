import Foundation

enum ReadingNoteBuilder {
    static func markdown(chart: NatalChart, reading: NatalReading, synthesis: String) -> String {
        let chartTitle = chart.name.isEmpty ? "Carta natal" : chart.name
        var lines: [String] = [
            "# Lectura natal - \(chartTitle)",
            "",
            "- Fecha: \(chart.birthDate) \(chart.birthTime)",
            "- Lugar: \(chart.placeName)",
            "- Zona: \(chart.timezone)",
            "- ASC: \(chart.ascendant.formatted)",
            "- MC: \(chart.mc.formatted)",
            ""
        ]

        for chapter in reading.chapters where chapter.id != .synthesis {
            lines.append("## \(chapter.title)")
            if let subtitle = chapter.subtitle, !subtitle.isEmpty {
                lines.append("_\(subtitle)_")
                lines.append("")
            }
            for block in chapter.blocks {
                append(block: block, to: &lines)
            }
            lines.append("")
        }

        lines.append("## Síntesis")
        let cleanSynthesis = synthesis.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanSynthesis.isEmpty {
            lines.append("_Pendiente de completar._")
        } else {
            lines.append(cleanSynthesis)
        }

        if !reading.synthesisDraft.isEmpty {
            lines.append("")
            lines.append("### Borrador automático")
            for item in reading.synthesisDraft {
                lines.append("- \(item)")
            }
        }

        if !reading.missingKeys.isEmpty {
            lines.append("")
            lines.append("### Auditoría de corpus")
            lines.append("Claves sin texto: \(reading.missingKeys.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
    }

    static func markdown(chart: NatalChart, interpretations: [Interpretation], synthesis: String) -> String {
        let reading = NatalReadingComposer.compose(.init(chart: chart, interpretations: interpretations, density: .complete))
        return markdown(chart: chart, reading: reading, synthesis: synthesis)
    }

    private static func append(block: ReadingBlock, to lines: inout [String]) {
        switch block.kind {
        case .lead(let text):
            lines.append(text)
            lines.append("")
        case .pointHeader(let data):
            lines.append("### \(data.title)")
            var detail = data.detail
            if !data.badges.isEmpty { detail += " · " + data.badges.joined(separator: " · ") }
            lines.append("_\(detail)_")
            lines.append("")
        case .corpus(let title, let paragraphs, let source):
            if let title, !title.isEmpty { lines.append("**\(title)**") }
            for paragraph in paragraphs { lines.append(paragraph) }
            if !source.isEmpty { lines.append("_Fuente: \(source)_") }
            lines.append("")
        case .chips(let chips):
            let text = chips.map { "\($0.label): \($0.value)" }.joined(separator: " · ")
            lines.append(text)
            lines.append("")
        case .aspectLine(let data):
            lines.append("- \(data.text) — score \(String(format: "%.1f", data.score))")
        case .groupedList(let title, let items):
            lines.append("**\(title):** \(items.joined(separator: " · "))")
            lines.append("")
        }
    }
}
