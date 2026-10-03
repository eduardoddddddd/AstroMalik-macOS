import Foundation

enum SynastryNoteBuilder {
    static func markdown(reading: SynastryReading) -> String {
        let chartAName = SynastryNaming.displayName(for: reading.chartA)
        let chartBName = SynastryNaming.displayName(for: reading.chartB)
        let contacts = reading.contactsWithText
        let synthesis = SynastrySynthesis.build(from: contacts)
        var lines: [String] = [
            "# Sinastría - \(chartAName) y \(chartBName)",
            "",
            "## Cartas",
            "- \(chartAName): \(reading.chartA.birthDate) \(reading.chartA.birthTime) · \(reading.chartA.placeName)",
            "- \(chartBName): \(reading.chartB.birthDate) \(reading.chartB.birthTime) · \(reading.chartB.placeName)",
            "- Cobertura: \(reading.coverageSummary)",
            "- Lentes direccionales sin texto: \(reading.missingTextCount)",
            "",
            "## Síntesis",
            "",
            synthesis.balanceText,
            "",
        ]

        if let central = synthesis.centralContact {
            lines += [
                "### Tema central",
                "\(contactTitle(central, chartAName: chartAName, chartBName: chartBName)) (orbe \(String(format: "%.2f°", central.orb))).",
                "",
            ]
        }
        if !synthesis.doubleWhammies.isEmpty {
            lines += [
                "### Reciprocidades",
                synthesis.doubleWhammies.map(\.label).joined(separator: ", "),
                "",
            ]
        }

        lines += ["## Contactos", ""]
        for contact in contacts {
            lines += [
                "### \(contactTitle(contact, chartAName: chartAName, chartBName: chartBName))",
                "- Orbe: \(String(format: "%.2f°", contact.orb))",
                "",
            ]
            let directions = contact.distinctDirections
            for direction in directions {
                guard let aspect = contact.aspect(for: direction),
                      let copy = SynastryLensCopy.make(
                          for: aspect,
                          chartAName: chartAName,
                          chartBName: chartBName
                      ) else { continue }
                let source = direction.sourceName(
                    chartAName: chartAName,
                    chartBName: chartBName
                )
                let target = direction.targetName(
                    chartAName: chartAName,
                    chartBName: chartBName
                )
                // El encabezado direccional solo aporta cuando hay dos lecturas
                // en espejo; con una sola describiría de más.
                lines += [
                    directions.count > 1
                        ? "#### Cómo lo vive \(source) → \(target)"
                        : "#### Lectura",
                    "- Clave: `\(aspect.corpusClave)`",
                    "",
                    copy.text,
                    "",
                ]
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func contactTitle(
        _ contact: SynastryContact,
        chartAName: String,
        chartBName: String
    ) -> String {
        "\(contact.chartAPlanetLabel) de \(chartAName) \(contact.aspectLabel) \(contact.chartBPlanetLabel) de \(chartBName)"
    }
}
