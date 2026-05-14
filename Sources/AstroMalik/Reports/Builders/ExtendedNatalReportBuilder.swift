import Foundation

struct ExtendedNatalReportBuilder {
    static func generate(from chart: NatalChart, pageSize: PDFPageSize = .a4Portrait) async throws -> Data {
        let result = try NatalExtendedAnalysis.compute(chart: chart)
        let data = makeData(chart: chart, result: result)
        return try await ReportService().generate(request: ReportRequest(templateName: "extended_natal", data: data, pageSize: pageSize))
    }

    static func generate(from input: ExtendedNatalReportInput, pageSize: PDFPageSize = .a4Portrait) async throws -> Data {
        let data = makeData(chart: input.chart, result: input.result)
        return try await ReportService().generate(request: ReportRequest(templateName: "extended_natal", data: data, pageSize: pageSize))
    }

    static func makeData(chart: NatalChart, result: NatalExtendedAnalysisResult, generatedAt: Date = Date()) -> ExtendedNatalReportData {
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        return ExtendedNatalReportData(
            header: ReportHeaderData(chartName: displayName(chart), reportTitle: "Análisis natal extendido", generatedDate: generatedDate),
            cover: ReportCoverData(
                chartName: displayName(chart),
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                place: chart.placeName,
                generatedDate: generatedDate,
                ascSign: ReportFormatting.signLabel(for: chart.ascendant.longitude),
                ascGlyph: ReportFormatting.signGlyph(for: chart.ascendant.longitude)
            ),
            includeTOC: true,
            generatedDate: generatedDate,
            lotRows: result.lots.map { ReportMetricRow(label: $0.name, value: "\($0.formatted) · Casa \($0.house)", detail: "Regente/dispositor: \($0.rulerLabel). Fórmula: \($0.formulaComment)") },
            almutenRows: almutenRows(result.almutenFiguris),
            almutenPointRows: almutenPointRows(result.almutenFiguris),
            rulerRows: rulerRows(result.rulerOfGeniture),
            aspectPatternRows: aspectPatternRows(result.aspectPatterns),
            distributionBars: distributionBars(result.distribution),
            receptionRows: result.receptions.map { ReportMetricRow(label: $0.kind.label, value: "\($0.planetALabel) ↔ \($0.planetBLabel)", detail: $0.detail) },
            antisciaRows: antisciaRows(result.antiscia),
            declinationRows: declinationRows(result.declinations),
            fixedStarRows: fixedStarRows(result.fixedStars)
        )
    }

    private static func displayName(_ chart: NatalChart) -> String { chart.name.isEmpty ? "Carta natal" : chart.name }

    private static func almutenRows(_ almuten: AlmutenFigurisResult) -> [ReportMetricRow] {
        var rows = [
            ReportMetricRow(label: "Ganador", value: almuten.winnerLabel, detail: "Almuten Figuris por suma de puntos esenciales y bonos."),
            ReportMetricRow(label: "Sicigia prenatal", value: "\(almuten.prenatalSyzygy.kind.label) · \(almuten.prenatalSyzygy.formatted)", detail: "Incluida como punto de valoración tradicional."),
        ]
        rows += almuten.totalScores.map { ReportMetricRow(label: $0.planetLabel, value: "\($0.total) puntos", detail: "\($0.essentialPoints) esenciales + \($0.bonusPoints) bonos") }
        rows += almuten.bonuses.map { ReportMetricRow(label: "Bono \($0.planetLabel)", value: "+\($0.points)", detail: "\($0.kind): \($0.detail)") }
        return rows
    }

    private static func almutenPointRows(_ almuten: AlmutenFigurisResult) -> [ReportMetricRow] {
        almuten.pointScores.map { point in
            ReportMetricRow(label: point.name, value: point.formatted, detail: point.dignityAwards.map { "\($0.planetLabel) \($0.dignity) +\($0.points)" }.joined(separator: ", "))
        }
    }

    private static func rulerRows(_ ruler: RulerOfGeniture) -> [ReportMetricRow] {
        [
            ReportMetricRow(label: "Secta", value: ruler.sectLabel, detail: "La luminaria de secta ordena la evaluación."),
            ReportMetricRow(label: "Luminaria", value: "\(ruler.luminaryLabel) · \(ruler.luminaryFormatted)", detail: "Punto evaluado para extraer su regente."),
            ReportMetricRow(label: "Regente de la genitura", value: ruler.rulerLabel, detail: ruler.dignitySummary),
        ]
    }

    private static func aspectPatternRows(_ patterns: [AspectPattern]) -> [ReportMetricRow] {
        guard !patterns.isEmpty else {
            return [ReportMetricRow(label: "Configuraciones", value: "Sin patrones mayores", detail: "No se detectan configuraciones aspectuales con el orbe configurado.")]
        }
        return patterns.map { ReportMetricRow(label: $0.kind.label, value: $0.planetLabels.joined(separator: ", "), detail: "Orbe medio \(ReportFormatting.degree($0.averageOrb))") }
    }

    private static func distributionBars(_ distribution: NatalDistribution) -> [ReportDistributionBar] {
        let groups: [(String, [DistributionBucket])] = [
            ("Elementos", distribution.elements),
            ("Modalidades", distribution.modalities),
            ("Hemisferios", distribution.hemispheres),
            ("Cuadrantes", distribution.quadrants),
        ]
        return groups.flatMap { category, buckets in
            let maxCount = Double(max(1, buckets.map(\.count).max() ?? 1))
            return buckets.map { bucket in
                ReportDistributionBar(
                    category: category,
                    name: bucket.name,
                    count: "\(bucket.count)",
                    detail: bucket.planetLabels.joined(separator: ", "),
                    percent: ReportFormatting.decimal((Double(bucket.count) / maxCount) * 100, digits: 0)
                )
            }
        }
    }

    private static func antisciaRows(_ antiscia: AntisciaResult) -> [ReportMetricRow] {
        guard !antiscia.contacts.isEmpty else {
            return [ReportMetricRow(label: "Antiscia/contraantiscia", value: "Sin contactos", detail: "No hay contactos dentro del orbe configurado.")]
        }
        return antiscia.contacts.map { ReportMetricRow(label: $0.kind.label, value: "\($0.sourcePlanetLabel) → \($0.targetPlanetLabel)", detail: "Punto \($0.calculatedFormatted), orbe \(ReportFormatting.degree($0.orb))") }
    }

    private static func declinationRows(_ declinations: DeclinationResult) -> [ReportMetricRow] {
        var rows = declinations.outOfBounds.map { ReportMetricRow(label: "OOB \($0.label)", value: $0.formatted, detail: "Fuera de límites por declinación.") }
        rows += declinations.pairs.map { ReportMetricRow(label: $0.kind.label, value: "\($0.bodyALabel) / \($0.bodyBLabel)", detail: "Orbe \(ReportFormatting.degree($0.orb))") }
        if rows.isEmpty { rows.append(ReportMetricRow(label: "Declinaciones", value: "Sin pares", detail: "No hay paralelos/contraparalelos ni OOB dentro del orbe configurado.")) }
        return rows
    }

    private static func fixedStarRows(_ fixedStars: FixedStarResult) -> [ReportMetricRow] {
        var rows = [ReportMetricRow(label: "Precesión aplicada", value: ReportFormatting.degree(fixedStars.precessionAppliedDegrees, digits: 3), detail: "Ajuste usado sobre el catálogo J2000.")]
        rows += fixedStars.contacts.map { ReportMetricRow(label: $0.starName, value: "\($0.targetLabel) · \($0.starFormatted)", detail: "Orbe \(ReportFormatting.degree($0.orb)), magnitud \(ReportFormatting.decimal($0.magnitude)), naturaleza \($0.nature)") }
        if fixedStars.contacts.isEmpty { rows.append(ReportMetricRow(label: "Contactos", value: "Sin contactos", detail: "No hay conjunciones a puntos sensibles dentro del orbe configurado.")) }
        return rows
    }
}

struct ExtendedNatalReportInput: Codable, Equatable {
    let chart: NatalChart
    let result: NatalExtendedAnalysisResult
}
