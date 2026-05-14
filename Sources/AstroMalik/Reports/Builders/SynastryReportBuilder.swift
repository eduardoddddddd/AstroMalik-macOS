import Foundation

struct SynastryReportBuilder {
    static func generate(from reading: SynastryReading, pageSize: PDFPageSize = .a4Portrait) async throws -> Data {
        let data = makeData(from: reading)
        return try await ReportService().generate(request: ReportRequest(templateName: "synastry", data: data, pageSize: pageSize))
    }

    static func generate(from input: SynastryReportInput, pageSize: PDFPageSize = .a4Portrait) async throws -> Data {
        try await generate(from: input.reading, pageSize: pageSize)
    }

    static func makeData(from reading: SynastryReading, generatedAt: Date = Date()) -> SynastryReportData {
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        let aspects = reading.aspects.isEmpty ? AstroEngine.computeSynastryAspects(chartA: reading.chartA, chartB: reading.chartB) : reading.aspects
        let aToB = aspects.filter { $0.direction == .aToB }
        let bToA = aspects.filter { $0.direction == .bToA }
        return SynastryReportData(
            header: ReportHeaderData(chartName: "\(displayName(reading.chartA)) + \(displayName(reading.chartB))", reportTitle: "Informe de sinastría", generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            chartAName: displayName(reading.chartA),
            chartBName: displayName(reading.chartB),
            chartADetails: chartDetails(reading.chartA),
            chartBDetails: chartDetails(reading.chartB),
            doubleWheelSVG: doubleWheel(natal: reading.chartA, secondary: reading.chartB, theme: .default, size: 700),
            aspectsAToB: aspectRows(aToB),
            aspectsBToA: aspectRows(bToA),
            housesBInA: mutualHouseRows(source: reading.chartB, target: reading.chartA, label: "B en A"),
            housesAInB: mutualHouseRows(source: reading.chartA, target: reading.chartB, label: "A en B"),
            narrative: comparativeNarrative(reading: reading, aspects: aspects)
        )
    }

    private static func displayName(_ chart: NatalChart) -> String { chart.name.isEmpty ? "Carta" : chart.name }

    private static func chartDetails(_ chart: NatalChart) -> String {
        "\(chart.birthDate) \(chart.birthTime) · \(chart.placeName) · ASC \(chart.ascendant.formatted)"
    }

    private static func aspectRows(_ aspects: [SynastryAspect]) -> [ReportAspectRow] {
        aspects.prefix(60).map { aspect in
            ReportAspectRow(
                left: aspect.sourcePlanetLabel,
                aspect: aspect.aspectLabel,
                right: aspect.targetPlanetLabel,
                orb: ReportFormatting.degree(aspect.orb),
                corpusKey: aspect.corpusClave,
                text: aspect.interpretation?.texto ?? "Contacto de sinastría: \(aspect.sourcePlanetLabel) de la carta \(aspect.direction.sourceInitial) en \(aspect.aspectLabel) a \(aspect.targetPlanetLabel) de la carta \(aspect.direction.targetInitial)."
            )
        }
    }

    private static func mutualHouseRows(source: NatalChart, target: NatalChart, label: String) -> [ReportMetricRow] {
        ChartSVGRenderingSupport.orderedBodies(source.bodies).prefix(12).map { body in
            let house = AstroEngine.planetHouse(deg: body.longitude, cusps: target.cusps)
            return ReportMetricRow(
                label: body.label,
                value: "Casa \(house)",
                detail: "\(label): \(ReportFormatting.plainPlanetName(body.label)) cae en la casa \(house) de \(displayName(target))."
            )
        }
    }

    private static func comparativeNarrative(reading: SynastryReading, aspects: [SynastryAspect]) -> [ReportTextBlock] {
        let exact = aspects.sorted { $0.orb < $1.orb }.prefix(5).map { "\($0.sourcePlanetLabel) \($0.aspectLabel) \($0.targetPlanetLabel)" }.joined(separator: "; ")
        let aAngular = reading.chartA.bodies.filter { [1, 4, 7, 10].contains($0.house) }.map(\.label).joined(separator: ", ")
        let bAngular = reading.chartB.bodies.filter { [1, 4, 7, 10].contains($0.house) }.map(\.label).joined(separator: ", ")
        return [
            ReportTextBlock(title: "Clima relacional", subtitle: "Aspectos exactos", text: exact.isEmpty ? "La comparación no muestra aspectos mayores dentro de los orbes configurados." : "Los contactos de menor orbe marcan el tono de entrada: \(exact).", source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Visibilidad angular", subtitle: "Planetas en casas angulares", text: "Carta A: \(aAngular.isEmpty ? "sin planetas angulares" : aAngular). Carta B: \(bAngular.isEmpty ? "sin planetas angulares" : bAngular). Lo angular tiende a sentirse de forma inmediata entre las personas.", source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Casas mutuas", subtitle: "Dónde activa cada persona a la otra", text: "La superposición por casas indica áreas de experiencia que se despiertan en la convivencia: cuerpo y dirección en I, recursos en II, vínculo en VII, obra pública en X, etc.", source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Síntesis comparativa", subtitle: "Integración", text: "La lectura compara atracción, fricción y cooperación. Se ponderan primero los contactos luminares y personales, después los angulares y finalmente los patrones repetidos por casa.", source: "Síntesis AstroMalik"),
        ]
    }
}

struct SynastryReportInput: Codable, Equatable {
    let reading: SynastryReading
}
