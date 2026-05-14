import Foundation

func dailyEphemeris(month: EphemerisMonth, theme: ReportTheme) -> String {
    let columns: [(key: String, title: String)] = [
        ("SOL", "☉ Sol"),
        ("LUNA", "☽ Luna"),
        ("MERCURIO", "☿ Mercurio"),
        ("VENUS", "♀ Venus"),
        ("MARTE", "♂ Marte"),
        ("JUPITER", "♃ Júpiter"),
        ("SATURNO", "♄ Saturno"),
        ("URANO", "⛢ Urano"),
        ("NEPTUNO", "♆ Neptuno"),
        ("PLUTON", "♇ Plutón"),
        ("NODO_NORTE", "☊ Nodo Norte"),
    ]

    var html: [String] = []
    html.append("""
    <style>
      .ephemeris-table { width: 100%; border-collapse: collapse; font-family: \(theme.typography.uiFamily); font-size: 8.4pt; color: \(theme.palette.ink); }
      .ephemeris-table th { background: \(theme.palette.primary); color: \(theme.palette.background); padding: 5px 4px; border: 1px solid \(theme.palette.primary); white-space: nowrap; }
      .ephemeris-table td { padding: 4px 4px; border: 1px solid \(theme.palette.neutralRule); vertical-align: top; white-space: nowrap; }
      .ephemeris-table tbody tr:nth-child(even) { background: \(theme.palette.tableStripe); }
      .ephemeris-table .date-cell { font-weight: 700; color: \(theme.palette.primary); }
      .ephemeris-table .speed { font-size: 0.68em; color: \(theme.palette.inkSoft); margin-left: 2px; }
      .ephemeris-table .retrograde { color: \(theme.palette.gold); font-style: italic; }
      .ephemeris-table .moon-phase { font-size: 1.05em; margin-left: 3px; color: \(theme.palette.primary); }
    </style>
    <table class="ephemeris-table" data-ephemeris-month="\(month.year)-\(String(format: "%02d", month.month))">
      <thead>
        <tr><th scope="col">Fecha</th>
    """)

    for column in columns {
        html.append("<th scope=\"col\">\(escapeHTML(column.title))</th>")
    }
    html.append("</tr></thead><tbody>")

    for row in month.dailyRows.sorted(by: { $0.date < $1.date }) {
        let positions = Dictionary(uniqueKeysWithValues: row.positions.map { ($0.planetKey, $0) })
        html.append("<tr data-day=\"\(escapeHTML(row.date))\"><td class=\"date-cell\">\(escapeHTML(dayLabel(row.date)))</td>")
        for column in columns {
            if let position = positions[column.key] {
                let phaseGlyph = column.key == "LUNA" ? lunarPhaseGlyph(angle: row.lunarPhaseAngle) : nil
                html.append("<td>\(positionCell(position, phaseGlyph: phaseGlyph))</td>")
            } else {
                html.append("<td>—</td>")
            }
        }
        html.append("</tr>")
    }

    html.append("</tbody></table>")
    return html.joined(separator: "\n")
}

private func positionCell(_ position: PlanetDailyPosition, phaseGlyph: String?) -> String {
    let formatted = escapeHTML(position.formatted)
    let speed = String(format: "%.2f", position.speed)
    let value = position.retrograde
        ? "<em class=\"retrograde\">\(formatted) ℞</em>"
        : formatted
    let phase = phaseGlyph.map { "<span class=\"moon-phase\" title=\"fase lunar\">\(escapeHTML($0))</span>" } ?? ""
    return "\(value)\(phase)<sup class=\"speed\">\(escapeHTML(speed))</sup>"
}

private func lunarPhaseGlyph(angle: Double) -> String {
    let normalized = SVGChartSupport.normalizedLongitude(angle)
    switch normalized {
    case 337.5...360, 0..<22.5: return "🌑"
    case 22.5..<67.5: return "🌒"
    case 67.5..<112.5: return "🌓"
    case 112.5..<157.5: return "🌔"
    case 157.5..<202.5: return "🌕"
    case 202.5..<247.5: return "🌖"
    case 247.5..<292.5: return "🌗"
    default: return "🌘"
    }
}

private func dayLabel(_ isoDate: String) -> String {
    let suffix = isoDate.suffix(2)
    return String(suffix)
}

private func escapeHTML(_ value: String) -> String {
    SVGChartSupport.escapeText(value)
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
