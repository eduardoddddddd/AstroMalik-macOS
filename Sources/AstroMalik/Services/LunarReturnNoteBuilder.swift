import Foundation

enum LunarReturnNoteBuilder {
    static func markdown(reading: LunarReturnReading, selectedEvent: LunarReturnEvent) -> String {
        var lines: [String] = [
            "# Revolución Lunar - \(lrDisplayName(reading.natalChart))",
            "",
            "## Datos",
            "- Carta natal: \(lrDisplayName(reading.natalChart)) · \(reading.natalChart.birthDate) \(reading.natalChart.birthTime) · \(reading.natalChart.placeName)",
            "- Lugar del retorno: \(reading.placeName)",
            "- Zona: \(reading.timezone)",
            "- Fecha base: \(noteDate(reading.startDate))",
            "- Luna natal: \(reading.natalMoon.formatted) · Casa \(reading.natalMoon.house)",
            "- Retornos calculados: \(reading.events.count)",
            "- Intensidad media: \(RevolutionTemplates.intensityStars(Int(reading.statistics.averageIntensity.rounded())))",
            "",
            "## Retorno seleccionado — #\(selectedEvent.index)",
            "",
            "**\(selectedEvent.intensityLabel)** \(RevolutionTemplates.intensityStars(selectedEvent.intensityScore))",
            "",
            selectedEvent.miniNarrative,
            "",
            "### Foco emocional",
            selectedEvent.moonFocusText,
            "",
            "### Tono del mes",
            selectedEvent.ascToneText,
            "",
            "### Datos del retorno",
            "- Fecha local: \(selectedEvent.exactLocalDateTime)",
            "- Fecha UTC: \(selectedEvent.exactUTCDateTime)",
            "- Luna: \(selectedEvent.moon.formatted) · Casa \(selectedEvent.moon.house)",
            "- ASC retorno: \(selectedEvent.returnChart.ascendant.formatted) (\(selectedEvent.ascSignLabel)) · Casa natal \(selectedEvent.natalHouseForReturnAsc)",
            "- MC retorno: \(selectedEvent.returnChart.mc.formatted) · Casa natal \(selectedEvent.natalHouseForReturnMC)",
            "",
            "## Tabla de retornos",
            "| # | Fecha | Luna | Casa | ASC retorno | Intensidad |",
            "| --- | --- | --- | --- | --- | --- |",
        ]

        for event in reading.events {
            lines.append(
                "| \(event.index) | \(event.exactLocalDateTime) | \(event.moon.formatted) | \(event.moon.house) | \(event.returnChart.ascendant.formatted) | \(RevolutionTemplates.intensityStars(event.intensityScore)) |"
            )
        }

        lines += [
            "",
            "## Aspectos dominantes",
        ]

        for aspect in selectedEvent.dominantAspects.prefix(10) {
            lines.append("- \(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB), orbe \(String(format: "%.2f°", aspect.orb))")
        }

        lines += ["", "## Planetas del retorno en casas natales"]
        for placement in selectedEvent.returnPlanetsInNatalHouses {
            lines.append("- \(placement.planetLabel): casa natal \(placement.natalHouse), casa retorno \(placement.returnHouse), \(placement.formatted)")
        }

        return lines.joined(separator: "\n")
    }

    private static func noteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

func lrDisplayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}
