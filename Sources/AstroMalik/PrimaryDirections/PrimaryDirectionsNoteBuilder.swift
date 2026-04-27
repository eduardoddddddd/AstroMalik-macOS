import Foundation

enum PrimaryDirectionsNoteBuilder {
    static func singleDirectionMarkdown(
        chart: NatalChart,
        enriched: EnrichedPrimaryDirection,
        contextual: ContextualInterpretation?
    ) -> String {
        let direction = enriched.direction
        var lines: [String] = [
            "# Dirección Primaria - \(chartDisplayName(chart))",
            "",
            "## Carta",
            "- Nombre: \(chartDisplayName(chart))",
            "- Nacimiento: \(chart.birthDate) \(chart.birthTime) · \(chart.placeName)",
            "- Método: \(direction.method.rawValue)",
            "- Clave temporal: \(direction.key.rawValue)",
            "- Plano: \(direction.aspectPlane.displayName)",
            "",
            "## Dirección seleccionada",
            "- Resumen: \(enriched.displaySummary)",
            "- Clave de corpus: `\(corpusClave(for: direction))`",
            "- Edad estimada: \(enriched.ageFormatted)",
            "- Arco: \(enriched.arcFormatted)",
            "- Tipo: \(direction.directionType == .direct ? "Directa" : "Conversa")",
            "- Activación estimada: \(dateLabel(direction.estimatedDate))",
            "",
            "## Lectura tradicional",
            ""
        ]

        if let interpretation = enriched.interpretation {
            lines += [
                interpretation.structuralText,
                "",
                "- Fuente: \(interpretation.source)",
                "- Referencia: \(interpretation.sourceReference.isEmpty ? "Sin referencia detallada" : interpretation.sourceReference)",
                ""
            ]
        } else {
            lines += [
                "_Sin texto de corpus todavía. Esta clave sigue pendiente de curación manual verificable._",
                ""
            ]
        }

        lines += ["## Lectura contextual", ""]
        if let contextual {
            lines += [
                "### \(contextual.tituloPrincipal)",
                "",
                contextual.textoEstructural,
                "",
                "- Intensidad: \(contextual.intensidad)/10",
                "- Polaridad: \(contextual.polaridad)",
                "- Prompt: v\(contextual.promptVersion)",
                ""
            ]
        } else {
            lines += [
                "_Sin interpretación contextual guardada._",
                ""
            ]
        }

        lines += [
            "## Datos técnicos",
            "- RA promissor: \(String(format: "%.4f", direction.technicalData.promissorRA))°",
            "- RA significador: \(String(format: "%.4f", direction.technicalData.significatorRA))°",
            "- Declinación promissor: \(String(format: "%.4f", direction.technicalData.promissorDeclination))°",
            "- Polo del significador: \(String(format: "%.4f", direction.technicalData.significatorPole))°",
            "- RAMC: \(String(format: "%.4f", direction.technicalData.ramc))°",
        ]

        return lines.joined(separator: "\n")
    }

    static func filteredReportMarkdown(
        chart: NatalChart,
        settings: PDSettings,
        visibleDirections: [EnrichedPrimaryDirection],
        selectedDirection: EnrichedPrimaryDirection?,
        cachedContextualIDs: Set<UUID>
    ) -> String {
        var lines: [String] = [
            "# Informe de Direcciones Primarias - \(chartDisplayName(chart))",
            "",
            "## Resumen técnico",
            "- Carta: \(chartDisplayName(chart)) · \(chart.birthDate) \(chart.birthTime) · \(chart.placeName)",
            "- Método: \(settings.method.rawValue)",
            "- Clave temporal: \(settings.key.rawValue)",
            "- Plano: \(settings.aspectPlane.displayName)",
            "- Direcciones visibles: \(visibleDirections.count)",
            "- Con corpus: \(visibleDirections.filter(\.hasInterpretation).count)",
            "- Con contextual en caché: \(visibleDirections.filter { cachedContextualIDs.contains($0.id) }.count)",
            ""
        ]

        if let selectedDirection {
            lines += [
                "## Dirección destacada",
                "- \(selectedDirection.displaySummary)",
                "- Edad: \(selectedDirection.ageFormatted)",
                "- Arco: \(selectedDirection.arcFormatted)",
                "- Clave: `\(corpusClave(for: selectedDirection.direction))`",
                ""
            ]
        }

        lines += ["## Direcciones visibles", ""]
        if visibleDirections.isEmpty {
            lines += ["_Los filtros dejaron el conjunto vacío._", ""]
        } else {
            for enriched in visibleDirections {
                let direction = enriched.direction
                let corpusBadge = enriched.hasInterpretation ? "corpus" : "sin corpus"
                let contextualBadge = cachedContextualIDs.contains(enriched.id) ? "contextual" : "sin contextual"
                lines += [
                    "### \(enriched.displaySummary)",
                    "- Edad: \(enriched.ageFormatted)",
                    "- Arco: \(enriched.arcFormatted)",
                    "- Tipo: \(direction.directionType == .direct ? "Directa" : "Conversa")",
                    "- Lecturas: \(corpusBadge), \(contextualBadge)",
                    "- Clave: `\(corpusClave(for: direction))`",
                    ""
                ]

                if let interpretation = enriched.interpretation {
                    lines += [interpretation.structuralText, ""]
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func corpusClave(for direction: PrimaryDirection) -> String {
        let aspectKey: String
        switch direction.aspect {
        case .conjunction:
            aspectKey = "CONJUNCION"
        case .sextile:
            aspectKey = "SEXTIL"
        case .square:
            aspectKey = "CUADRATURA"
        case .trine:
            aspectKey = "TRIGONO"
        case .opposition:
            aspectKey = "OPOSICION"
        }
        return "\(direction.promissor)_\(direction.significator)_\(aspectKey)"
    }

    private static func chartDisplayName(_ chart: NatalChart) -> String {
        chart.name.isEmpty ? chart.birthDate : chart.name
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
