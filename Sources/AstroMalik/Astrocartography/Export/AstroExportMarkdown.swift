import Foundation

/// Markdown for Joplin notes and `--format markdown`. Pure: it only formats the
/// document, so it carries no date. The Joplin note adds its own title.
enum AstroExportMarkdown {
    static func title(_ document: AstroExportDocument) -> String {
        let chart = document.chart.name.isEmpty ? "Carta \(document.chart.birthDate)" : document.chart.name
        if let place = document.place { return "Astrocartografía — \(chart) — \(place.name)" }
        return "Astrocartografía — \(chart)"
    }

    /// Tags for the Joplin note: useful, few, stable.
    static func tags(_ document: AstroExportDocument) -> [String] {
        var tags = ["astrocartografía", "astromalik"]
        if document.place != nil { tags.append("lugar") }
        return tags
    }

    static func render(_ document: AstroExportDocument) -> String {
        var out: [String] = []
        func line(_ text: String = "") { out.append(text) }
        let chart = document.chart
        line("# \(title(document))")
        line()
        line("- **Carta:** \(chart.name.isEmpty ? "sin nombre" : chart.name) · \(chart.birthDate) \(chart.birthTime) · \(chart.timezone) · \(chart.placeName)")
        line(String(format: "- **Instante natal:** JD %.9f (%@)", document.instant.julianDay, document.instant.timeScale))
        line("- **Convención:** \(document.method.convention) · efemérides \(document.method.ephemerisSource) \(document.method.ephemerisLibraryVersion)")
        line("- **Umbrales del programa:** cerca ≤ \(num(document.policy.nearKm)) km · regional ≤ \(num(document.policy.regionalKm)) km")
        if let editorial = document.editorial { line("- **Textos:** \(editorial.version) (\(editorial.reviewStatus))") }
        if let place = document.place {
            line()
            line("## \(place.name)")
            line()
            line(String(format: "φ %.6f° · λ %.6f° E · zona %@%@", place.latitude, place.longitude, place.timeZone,
                        place.timeZoneVerified ? "" : " (no verificada; solo presentación)"))
            line()
            line("**\(place.headline)**")
            if !place.themes.isEmpty {
                line()
                line("### Temas con líneas cerca")
                line()
                for theme in place.themes {
                    var counts: [String] = []
                    if theme.nearCount > 0 { counts.append("\(theme.nearCount) cerca") }
                    if theme.regionalCount > 0 { counts.append("\(theme.regionalCount) regional") }
                    line("- \(theme.title): \(counts.joined(separator: ", "))")
                }
                line()
                line("_Los temas ordenan por cercanía de sus líneas; no puntúan ni predicen._")
            }
            if !place.readings.isEmpty {
                line()
                line("## Lecturas de las líneas cercanas")
                for reading in place.readings {
                    line()
                    line("### \(reading.title)")
                    line()
                    line("\(reading.band) · \(distance(reading.distanceKm)) · `\(reading.key)`")
                    line()
                    line("**Qué suele activar.** \(reading.mechanism)")
                    line()
                    line("**Potencial.** \(reading.potential)")
                    line()
                    line("**Sombra.** \(reading.shadow)")
                    line()
                    line("**Cómo trabajarlo.** \(reading.practice)")
                }
            }
            if let relocation = place.relocation {
                line()
                line("## Carta relocada")
                line()
                line("Mismo instante natal; solo cambian casas y ángulos. Sistema \(relocation.houseSystem).")
                line()
                line(String(format: "- ASC %.4f° (natal %.4f°)", relocation.ascendantDegrees, document.chart.natalAscendantDegrees))
                line(String(format: "- MC %.4f° (natal %.4f°)", relocation.mcDegrees, document.chart.natalMCDegrees))
                line()
                line("| Casa | Cúspide relocada | Cúspide natal |")
                line("|---:|---:|---:|")
                for (index, cusp) in relocation.cuspsDegrees.enumerated() {
                    let natal = index < document.chart.natalCuspsDegrees.count ? String(format: "%.4f°", document.chart.natalCuspsDegrees[index]) : "—"
                    line(String(format: "| %d | %.4f° | %@ |", index + 1, cusp, natal))
                }
                line()
                line("| Cuerpo | Longitud (sin cambio) | Casa relocada |")
                line("|---|---:|---:|")
                for body in relocation.bodies { line(String(format: "| %@ | %.4f° | %d |", body.body, body.longitudeDegrees, body.house)) }
            } else if let error = place.relocationError {
                line()
                line("## Carta relocada")
                line()
                line("No disponible: \(error)")
            }
            line()
            line("## Distancias a las 40 líneas")
            line()
            line("| Línea | Distancia | ± | Banda | Punto más próximo |")
            line("|---|---:|---:|---|---|")
            for entry in place.lines {
                line(String(format: "| %@ | %@ | %.6f km | %@%@ | %.4f°, %.4f° E |", entry.key, distance(entry.distanceKm), entry.estimatedErrorKm,
                            entry.band, entry.crossesBoundary ? " *" : "", entry.nearestLatitude, entry.nearestLongitude))
            }
            line()
            line("_* la cota de error cruza un umbral de banda._")
        }
        line()
        line("## Líneas de la carta")
        line()
        line("| Línea | AR | Declinación | Flags Swiss | Con trazo |")
        line("|---|---:|---:|---:|---|")
        for item in document.chartLines {
            line(String(format: "| %@ | %.6f° | %.6f° | %d | %@ |", item.key, item.rightAscensionDegrees, item.declinationDegrees,
                        item.returnedFlags, item.hasTrace ? "sí" : "no"))
        }
        line()
        line("## Método y límites")
        line()
        line(String(format: "- Geometría: %@ · distancias: %@%@ · tolerancia %.1f km · esfera R = %.4f km.",
                    document.method.linesAlgorithm, document.method.distanceAlgorithm,
                    document.method.relocationAlgorithm.map { " · relocación: \($0)" } ?? "",
                    document.method.geometryToleranceKm, document.method.sphereRadiusKm))
        for warning in document.warnings { line("- ⚠ \(warning)") }
        line("- \(document.disclaimer)")
        return out.joined(separator: "\n") + "\n"
    }

    static func distance(_ km: Double) -> String { AstroPlaceSummaryBuilder.distance(km) }
    private static func num(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(value) }
}
