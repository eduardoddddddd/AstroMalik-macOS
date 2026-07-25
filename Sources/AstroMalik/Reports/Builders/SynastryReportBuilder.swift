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
        let chartAName = displayName(reading.chartA)
        let chartBName = displayName(reading.chartB)
        return SynastryReportData(
            header: ReportHeaderData(chartName: "\(chartAName) + \(chartBName)", reportTitle: "Informe de sinastría", generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            chartAName: chartAName,
            chartBName: chartBName,
            chartADetails: chartDetails(reading.chartA),
            chartBDetails: chartDetails(reading.chartB),
            doubleWheelSVG: doubleWheel(natal: reading.chartA, secondary: reading.chartB, theme: .default, size: 700),
            aspectsAToB: aspectRows(aToB, chartAName: chartAName, chartBName: chartBName),
            aspectsBToA: aspectRows(bToA, chartAName: chartAName, chartBName: chartBName),
            housesBInA: mutualHouseRows(source: reading.chartB, target: reading.chartA, sourceName: chartBName),
            housesAInB: mutualHouseRows(source: reading.chartA, target: reading.chartB, sourceName: chartAName),
            narrative: comparativeNarrative(reading: reading, aspects: aspects)
        )
    }

    private static func displayName(_ chart: NatalChart) -> String {
        SynastryNaming.displayName(for: chart)
    }

    private static func chartDetails(_ chart: NatalChart) -> String {
        "\(chart.birthDate) \(chart.birthTime) · \(chart.placeName) · ASC \(chart.ascendant.formatted)"
    }

    private static func aspectRows(
        _ aspects: [SynastryAspect],
        chartAName: String,
        chartBName: String
    ) -> [ReportAspectRow] {
        aspects.sorted(by: editorialOrder).prefix(60).map { aspect in
            let sourceName = aspect.direction.sourceName(
                chartAName: chartAName,
                chartBName: chartBName
            )
            let targetName = aspect.direction.targetName(
                chartAName: chartAName,
                chartBName: chartBName
            )
            let text = aspect.interpretation.map {
                SynastryNaming.presentedText(
                    $0.texto,
                    direction: aspect.direction,
                    chartAName: chartAName,
                    chartBName: chartBName
                )
            }
            return ReportAspectRow(
                left: "\(aspect.sourcePlanetLabel) de \(sourceName)",
                aspect: aspect.aspectLabel,
                right: "\(aspect.targetPlanetLabel) de \(targetName)",
                orb: ReportFormatting.degree(aspect.orb),
                corpusKey: aspect.corpusClave,
                text: text ?? "Contacto de sinastría entre \(aspect.sourcePlanetLabel) de \(sourceName) y \(aspect.targetPlanetLabel) de \(targetName)."
            )
        }
    }

    private static func mutualHouseRows(
        source: NatalChart,
        target: NatalChart,
        sourceName: String
    ) -> [ReportMetricRow] {
        ChartSVGRenderingSupport.orderedBodies(source.bodies).prefix(12).map { body in
            let house = AstroEngine.planetHouse(deg: body.longitude, cusps: target.cusps)
            return ReportMetricRow(
                label: "\(body.label) de \(sourceName)",
                value: "Casa \(house)",
                detail: "\(ReportFormatting.plainPlanetName(body.label)) de \(sourceName) cae en la casa \(house) de \(displayName(target))."
            )
        }
    }

    private static func comparativeNarrative(reading: SynastryReading, aspects: [SynastryAspect]) -> [ReportTextBlock] {
        let chartAName = displayName(reading.chartA)
        let chartBName = displayName(reading.chartB)
        let contacts = SynastryContact.grouped(aspects)
        let synthesis = SynastrySynthesis.build(from: contacts)
        let exact = contacts.prefix(5).map {
            "\($0.chartAPlanetLabel) de \(chartAName) \($0.aspectLabel) \($0.chartBPlanetLabel) de \(chartBName)"
        }.joined(separator: "; ")
        let aAngular = reading.chartA.bodies.filter { [1, 4, 7, 10].contains($0.house) }.map(\.label).joined(separator: ", ")
        let bAngular = reading.chartB.bodies.filter { [1, 4, 7, 10].contains($0.house) }.map(\.label).joined(separator: ", ")
        return [
            ReportTextBlock(title: "Balance relacional", subtitle: "Síntesis ponderada", text: synthesis.balanceText, source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Clima relacional", subtitle: "Contactos prioritarios", text: exact.isEmpty ? "La comparación no muestra aspectos mayores dentro de los orbes configurados." : "Se priorizan luminarias y funciones personales antes que los contactos puramente generacionales; dentro de cada nivel pesa el orbe: \(exact).", source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Visibilidad angular", subtitle: "Planetas en casas angulares", text: "\(chartAName): \(aAngular.isEmpty ? "sin planetas angulares" : aAngular). \(chartBName): \(bAngular.isEmpty ? "sin planetas angulares" : bAngular). Lo angular tiende a sentirse de forma inmediata entre ambas personas.", source: "Síntesis AstroMalik"),
            ReportTextBlock(title: "Casas mutuas", subtitle: "Dónde activa cada persona a la otra", text: "La superposición por casas indica áreas de experiencia que se despiertan en la convivencia: cuerpo y dirección en I, recursos en II, vínculo en VII, obra pública en X, etc.", source: "Síntesis AstroMalik"),
        ]
    }

    private static func editorialOrder(_ lhs: SynastryAspect, _ rhs: SynastryAspect) -> Bool {
        if lhs.interpretivePriority != rhs.interpretivePriority {
            return lhs.interpretivePriority < rhs.interpretivePriority
        }
        return lhs.orb < rhs.orb
    }
}

struct SynastryReportInput: Codable, Equatable {
    let reading: SynastryReading
}
