import Foundation

enum SolarReturnNoteBuilder {
    static func markdown(reading: SolarReturnReading) -> String {
        var lines: [String] = [
            "# Revolución Solar \(reading.year) - \(srDisplayName(reading.natalChart))",
            "",
            "## Tema del año",
            "**\(reading.yearThemeTitle)** (ASC RS en casa natal \(reading.natalHouseForSolarAsc))",
            "", reading.yearThemeText,
            "",
            "## Tono del año",
            "ASC RS en \(reading.ascSignLabel)",
            "", reading.yearToneText,
            "",
            "## Regente del ASC de revolución",
            "\(reading.rulerLabel) en casa natal \(reading.rulerNatalHouse)",
            "", reading.rulerText,
            "",
            "## Luna de revolución",
            "\(reading.moonFormatted) · Casa \(reading.moonHouse)",
            "", reading.moonText,
            "",
            "## Datos",
            "- Carta natal: \(srDisplayName(reading.natalChart)) · \(reading.natalChart.birthDate) \(reading.natalChart.birthTime) · \(reading.natalChart.placeName)",
            "- Lugar de revolución: \(reading.placeName)",
            "- Zona: \(reading.timezone)",
            "- Retorno exacto: \(reading.exactLocalDateTime)",
            "- UTC: \(reading.exactUTCDateTime)",
            "- ASC revolución: \(reading.solarChart.ascendant.formatted) · Casa natal \(reading.natalHouseForSolarAsc)",
            "- MC revolución: \(reading.solarChart.mc.formatted) · Casa natal \(reading.natalHouseForSolarMC)",
            "",
            "## Planetas de revolución en casas natales",
        ]

        for placement in reading.solarPlanetsInNatalHouses {
            lines.append("- \(placement.planetLabel): casa natal \(placement.natalHouse), casa solar \(placement.solarHouse), \(placement.formatted)")
        }

        if !reading.interpretations.isEmpty {
            lines += ["", "## Textos principales"]
            for interpretation in reading.interpretations.prefix(8) {
                lines.append("- \(interpretation.titulo): \(interpretation.texto)")
            }
        }

        lines += ["", "## Aspectos dominantes"]
        for aspect in reading.dominantAspects.prefix(8) {
            lines.append("- \(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB), orbe \(String(format: "%.2f°", aspect.orb))")
        }

        if !reading.angularPlanets.isEmpty {
            lines += ["", "## Planetas en casas angulares"]
            for planet in reading.angularPlanets {
                lines.append("- \(planet.planetLabel): casa solar \(planet.solarHouse), casa natal \(planet.natalHouse)")
            }
        }

        if !reading.natalRepetitions.isEmpty {
            lines += ["", "## Repeticiones natal–solar"]
            for rep in reading.natalRepetitions {
                lines.append("- \(rep.planetLabel): casa \(rep.house)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
