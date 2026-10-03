import Foundation

enum ExtendedAnalysisNoteBuilder {
    static func noteTitle(chart: NatalChart) -> String {
        "Análisis extendido natal — \(chart.name.isEmpty ? "Carta" : chart.name)"
    }

    static func markdown(chart: NatalChart, result: NatalExtendedAnalysisResult) -> String {
        var lines: [String] = [
            "# Análisis extendido natal — \(chart.name.isEmpty ? "Carta" : chart.name)",
            "",
            "- Fecha: \(chart.birthDate) \(chart.birthTime)",
            "- Lugar: \(chart.placeName)",
            "- Zona: \(chart.timezone)",
            "- ASC: \(chart.ascendant.formatted)",
            "- MC: \(chart.mc.formatted)",
            "",
            "## 1. Lotes helenísticos",
        ]
        for lot in result.lots {
            lines.append("- **\(lot.name)**: \(lot.formatted), casa \(lot.house), regente/dispositor \(lot.rulerLabel). Fórmula: \(lot.formulaComment)")
        }

        lines += ["", "## 2. Almuten Figuris"]
        lines.append("- Ganador: **\(result.almutenFiguris.winnerLabel)**")
        lines.append("- Sicigia prenatal: \(result.almutenFiguris.prenatalSyzygy.kind.label), \(result.almutenFiguris.prenatalSyzygy.formatted)")
        for score in result.almutenFiguris.totalScores {
            lines.append("- \(score.planetLabel): \(score.total) puntos (\(score.essentialPoints) esenciales + \(score.bonusPoints) bonos)")
        }

        lines += ["", "## 3. Regente de la Genitura"]
        lines.append("- Secta: \(result.rulerOfGeniture.sectLabel)")
        lines.append("- Luminaria: \(result.rulerOfGeniture.luminaryLabel) \(result.rulerOfGeniture.luminaryFormatted)")
        lines.append("- Regente: \(result.rulerOfGeniture.rulerLabel)")
        lines.append("- Dignidades: \(result.rulerOfGeniture.dignitySummary)")

        lines += ["", "## 4. Configuraciones aspectuales"]
        if result.aspectPatterns.isEmpty { lines.append("- Ninguna dentro del orbe configurado.") }
        for pattern in result.aspectPatterns {
            lines.append("- **\(pattern.title)**: \(pattern.planetLabels.joined(separator: ", ")) · orbe medio \(String(format: "%.2f°", pattern.averageOrb))")
        }

        lines += ["", "## 5. Conteos y distribución"]
        appendBuckets(result.distribution.elements, title: "Elementos", lines: &lines)
        appendBuckets(result.distribution.modalities, title: "Modalidades", lines: &lines)
        appendBuckets(result.distribution.hemispheres, title: "Hemisferios", lines: &lines)
        appendBuckets(result.distribution.quadrants, title: "Cuadrantes", lines: &lines)
        if !result.distribution.singletons.isEmpty {
            lines.append("### Singletons")
            for singleton in result.distribution.singletons {
                lines.append("- \(singleton.planetLabel): único en \(singleton.category.label.lowercased()) \(singleton.bucketName)")
            }
        }

        lines += ["", "## 6. Recepciones mutuas natales"]
        if result.receptions.isEmpty { lines.append("- Ninguna.") }
        for reception in result.receptions { lines.append("- **\(reception.kind.label)**: \(reception.detail)") }

        lines += ["", "## 7. Antiscia y contraantiscia"]
        if result.antiscia.contacts.isEmpty { lines.append("- Sin contactos dentro de 1°.") }
        for contact in result.antiscia.contacts {
            lines.append("- \(contact.kind.label): \(contact.sourcePlanetLabel) → \(contact.targetPlanetLabel), punto \(contact.calculatedFormatted), orbe \(String(format: "%.2f°", contact.orb))")
        }

        lines += ["", "## 8. Declinaciones y out of bounds"]
        if result.declinations.outOfBounds.isEmpty { lines.append("- Out of bounds: ninguno.") }
        else {
            lines.append("### Out of bounds")
            for body in result.declinations.outOfBounds { lines.append("- \(body.label): \(body.formatted)") }
        }
        lines.append("### Paralelos/contraparalelos")
        if result.declinations.pairs.isEmpty { lines.append("- Ninguno dentro de 1°.") }
        for pair in result.declinations.pairs {
            lines.append("- \(pair.kind.label): \(pair.bodyALabel) / \(pair.bodyBLabel), orbe \(String(format: "%.2f°", pair.orb))")
        }

        lines += ["", "## 9. Estrellas fijas"]
        lines.append("- Precesión simple aplicada: \(String(format: "%.3f°", result.fixedStars.precessionAppliedDegrees))")
        if result.fixedStars.contacts.isEmpty { lines.append("- Sin conjunciones dentro de 1°.") }
        for contact in result.fixedStars.contacts {
            lines.append("- **\(contact.starName)** con \(contact.targetLabel): \(contact.starFormatted), orbe \(String(format: "%.2f°", contact.orb)), magnitud \(String(format: "%.2f", contact.magnitude)), naturaleza \(contact.nature)")
        }

        return lines.joined(separator: "\n")
    }

    private static func appendBuckets(_ buckets: [DistributionBucket], title: String, lines: inout [String]) {
        lines.append("### \(title)")
        for bucket in buckets {
            lines.append("- \(bucket.name): \(bucket.count) — \(bucket.planetLabels.joined(separator: ", "))")
        }
    }
}
