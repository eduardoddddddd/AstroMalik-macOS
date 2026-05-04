import Foundation

enum MonthlySummaryNoteBuilder {
    static func markdown(summary: MonthlySummary, monthTitle: String) -> String {
        var lines: [String] = [
            "# Resumen Predictivo — \(monthTitle)",
            "",
            "## Para \(summary.chartName)",
            "",
            "### Clima del mes",
            summary.climateSummary,
            "",
        ]

        lines.append("### Lunaciones")
        if summary.lunationHits.isEmpty {
            lines.append("No se detectaron lunaciones principales en este mes.")
        } else {
            for hit in summary.lunationHits {
                lines.append("\(icon(for: hit.event.kind)) **\(hit.event.title)** — \(hit.event.dateLocal)")
                lines.append("Casa natal: \(hit.natalHouse)")
                lines.append(hit.narrative)
                if let conjunction = hit.conjunctPlanet {
                    lines.append("Activación directa: \(conjunction.planetLabel) natal · orbe \(String(format: "%.1f", conjunction.orb))°")
                }
                lines.append("")
            }
        }

        lines.append("### Eclipses")
        if summary.eclipseHits.isEmpty {
            lines.append("No hay eclipses personalizados destacados este mes.")
        } else {
            for hit in summary.eclipseHits {
                lines.append("\(icon(for: hit.event.kind)) **\(hit.event.title)** — \(hit.event.dateLocal)")
                lines.append("Casa natal: \(hit.natalHouse)\(hit.isAngular ? " · eje angular" : "")")
                lines.append(hit.narrative)
                if !hit.conjunctPlanets.isEmpty {
                    lines.append("Planetas tocados: " + hit.conjunctPlanets.map { "\($0.planetLabel) (\(String(format: "%.1f", $0.orb))°)" }.joined(separator: ", "))
                }
                lines.append("")
            }
        }

        lines.append("### Estaciones sobre tu carta")
        if summary.stationHits.isEmpty {
            lines.append("No hay estaciones planetarias exactas sobre planetas natales con orbe ≤ 3°.")
        } else {
            for hit in summary.stationHits {
                lines.append("🪐 **\(hit.event.title)** — \(hit.event.dateLocal)")
                lines.append("Toca: \(hit.natalPlanetLabel) natal en casa \(hit.natalHouse) · orbe \(String(format: "%.1f", hit.orb))°")
                lines.append(hit.narrative)
                lines.append("")
            }
        }

        lines.append("### Tránsitos activos principales")
        if summary.activeTransits.isEmpty {
            lines.append("No se detectaron tránsitos principales activos para el filtro mensual.")
        } else {
            for (index, transit) in summary.activeTransits.enumerated() {
                lines.append("\(index + 1). \(transit.priorityStarsDisplay) **\(transit.transitLabel) \(transit.aspectLabel) \(transit.natalLabel)** — \(transit.fromDate)–\(transit.toDate) — Prioridad \(transit.priorityLabel)")
                if let text = transit.text, !text.isEmpty {
                    lines.append("   \(text)")
                }
                if !transit.metricReasons.isEmpty {
                    lines.append("   Motivos: \(transit.metricReasons.joined(separator: ", "))")
                }
            }
            lines.append("")
        }

        lines.append("### Ingresos por casa natal")
        if summary.houseIngresses.isEmpty {
            lines.append("No se detectaron ingresos por casa natal de planetas lentos este mes.")
        } else {
            for ingress in summary.houseIngresses {
                lines.append("- **\(ingress.transitLabel)** ingresa en casa \(ingress.house) — \(ingress.date) (desde casa \(ingress.fromHouse))")
                if let text = ingress.text, !text.isEmpty {
                    lines.append("  \(text)")
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

    private static func icon(for kind: CelestialEventKind) -> String {
        switch kind {
        case .newMoon: return "🌑"
        case .fullMoon: return "🌕"
        case .solarEclipse: return "🌞"
        case .lunarEclipse: return "🌚"
        default: return "✦"
        }
    }

    private static func generatedAt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
