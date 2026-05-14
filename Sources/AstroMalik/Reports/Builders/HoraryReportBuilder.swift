import Foundation

struct HoraryReportBuilder {
    static func generate(from query: SavedHoraryQuery) async throws -> Data {
        let data = makeData(from: query)
        return try await ReportService().generate(request: ReportRequest(templateName: "horary", data: data))
    }

    static func generate(from response: HoraryResponse) async throws -> Data {
        let chart = try decode(HoraryChart.self, from: response.chartJSON)
        let judgement = try decode(HoraryJudgement.self, from: response.judgementJSON)
        let data = makeData(chart: chart, judgement: judgement, calculatedAt: response.calculatedAt)
        return try await ReportService().generate(request: ReportRequest(templateName: "horary", data: data))
    }

    static func makeData(from query: SavedHoraryQuery, generatedAt: Date = Date()) -> HoraryReportData {
        makeData(chart: query.chart, judgement: query.judgement, calculatedAt: query.response.calculatedAt, generatedAt: generatedAt)
    }

    static func makeData(chart: HoraryChart, judgement: HoraryJudgement, calculatedAt: String, generatedAt: Date = Date()) -> HoraryReportData {
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        return HoraryReportData(
            header: ReportHeaderData(chartName: chart.header.question, reportTitle: "Informe horario", generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            question: chart.header.question,
            placeAndTime: "\(chart.header.datetimeLocal) · \(chart.header.placeName) · \(chart.header.timezone)",
            chartSVG: wheel(chart: natalProxy(from: chart), theme: .default, size: 580),
            significators: significatorRows(judgement.significators),
            dignityRows: dignityRows(chart.dignities, chart: chart),
            verdictRows: verdictRows(judgement),
            supportingFactors: factorRows(judgement.supportingFactors, empty: "Sin factores principales a favor."),
            blockingFactors: factorRows(judgement.blockingFactors, empty: "Sin factores principales en contra."),
            technicalNotes: technicalRows(chart: chart, judgement: judgement, calculatedAt: calculatedAt),
            speculumRows: speculumRows(chart: chart),
            aspectRows: aspectRows(chart.aspects)
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func significatorRows(_ significators: HorarySignificators) -> [ReportMetricRow] {
        [
            ReportMetricRow(label: "Consultante", value: significators.querent, detail: "Regente del Ascendente y cosignificadores: \(significators.querentCosignifiers.joined(separator: ", "))"),
            ReportMetricRow(label: "Consultado", value: significators.quesited, detail: "Regente de la casa de la pregunta y cosignificadores: \(significators.quesitedCosignifiers.joined(separator: ", "))"),
            ReportMetricRow(label: "Luna", value: significators.moon, detail: "Cosignificadora general del asunto y del flujo de los acontecimientos."),
        ]
    }

    private static func dignityRows(_ dignities: [HoraryDignity], chart: HoraryChart) -> [ReportDignityRow] {
        dignities.map { dignity in
            let body = chart.body(named: dignity.name)
            return ReportDignityRow(
                planet: dignity.name,
                position: body?.formatted ?? "—",
                dignities: "Esenciales: \(dignity.essentialTags.joined(separator: ", ")); accidentales: \(dignity.accidentalTags.joined(separator: ", "))",
                score: "\(dignity.totalScore)"
            )
        }
    }

    private static func verdictRows(_ judgement: HoraryJudgement) -> [ReportMetricRow] {
        [
            ReportMetricRow(label: "Veredicto", value: renderVerdict(judgement.verdict), detail: judgement.mainReason ?? "Sin razón principal."),
            ReportMetricRow(label: "Confianza", value: judgement.confidence ?? "—", detail: judgement.radical ? "Carta radical o suficientemente legible." : "Carta con advertencias de radicalidad."),
            ReportMetricRow(label: "Perfección", value: judgement.perfectionKind, detail: routeDetail(judgement.perfectionRoute)),
            ReportMetricRow(label: "Tiempo", value: judgement.timingRange ?? judgement.timeEstimate ?? "Sin tiempo claro", detail: "Estimación emitida por el engine horario."),
        ]
    }

    private static func routeDetail(_ route: HoraryPerfectionRoute) -> String {
        var parts = ["\(route.significatorQuerent) → \(route.significatorQuesited)"]
        if let aspect = route.aspectName { parts.append("aspecto \(aspect)") }
        if let intermediary = route.intermediary { parts.append("intermediario \(intermediary)") }
        if let degrees = route.degreesToPerfect { parts.append("faltan \(ReportFormatting.degree(degrees))") }
        return parts.joined(separator: " · ")
    }

    private static func factorRows(_ factors: [String]?, empty: String) -> [ReportMetricRow] {
        let values = factors ?? []
        guard !values.isEmpty else { return [ReportMetricRow(label: "—", value: "Ninguno", detail: empty)] }
        return values.enumerated().map { index, text in ReportMetricRow(label: "Factor \(index + 1)", value: "", detail: text) }
    }

    private static func technicalRows(chart: HoraryChart, judgement: HoraryJudgement, calculatedAt: String) -> [ReportMetricRow] {
        var rows = [
            ReportMetricRow(label: "Casa de la pregunta", value: "Casa \(judgement.questionHouse)", detail: judgement.questionTopic),
            ReportMetricRow(label: "Secta", value: chart.sect, detail: "Hora planetaria: \(chart.planetaryHourRuler)."),
            ReportMetricRow(label: "ASC / MC", value: "ASC \(chart.angles.asc.formatted) · MC \(chart.angles.mc.formatted)", detail: "Casas tradicionales calculadas por el engine horario."),
            ReportMetricRow(label: "Calculado", value: calculatedAt, detail: "No se registran datos sensibles en logs."),
        ]
        rows += chart.activeConsiderations.map { ReportMetricRow(label: $0.severity, value: $0.key, detail: $0.description) }
        rows += judgement.notes.map { ReportMetricRow(label: "Nota", value: "", detail: $0) }
        rows += (judgement.technicalWarnings ?? []).map { ReportMetricRow(label: "Advertencia", value: "", detail: $0) }
        return rows
    }

    private static func speculumRows(chart: HoraryChart) -> [ReportPositionRow] {
        chart.bodies.map { body in
            ReportPositionRow(
                body: body.name,
                glyph: glyph(for: body.name),
                position: body.formatted,
                sign: body.sign,
                house: "Casa \(body.house)",
                retrograde: body.retrograde ? "℞" : body.stationary ? "Estacionario" : "Directo"
            )
        } + chart.parts.map { part in
            ReportPositionRow(body: part.name, glyph: "⊕", position: part.formatted, sign: part.sign, house: "Casa \(part.house)", retrograde: "Parte")
        }
    }

    private static func aspectRows(_ aspects: [HoraryAspect]) -> [ReportAspectRow] {
        aspects.map { aspect in
            ReportAspectRow(
                left: aspect.bodyA,
                aspect: aspect.aspectName,
                right: aspect.bodyB,
                orb: ReportFormatting.degree(aspect.distance),
                corpusKey: aspect.applying ? "aplicativo" : "separativo",
                text: "Orbe/moiety \(ReportFormatting.degree(aspect.orb)); \(aspect.applying ? "aplicativo" : "separativo")\(aspect.timeEstimate.map { "; tiempo \($0)" } ?? "")."
            )
        }
    }

    private static func renderVerdict(_ value: String?) -> String {
        switch value {
        case "si": return "Sí"
        case "no": return "No"
        case "no_todavia": return "No todavía"
        case "dudoso": return "Dudoso"
        case "requiere_mediacion": return "Requiere mediación"
        default: return value ?? "Dudoso"
        }
    }

    private static func natalProxy(from chart: HoraryChart) -> NatalChart {
        let asc = chart.angles.asc.longitude
        let cusps = (0..<12).map { SVGChartSupport.normalizedLongitude(asc + Double($0) * 30) }
        let bodies = chart.bodies.compactMap { body -> PlanetBody? in
            guard let key = planetKey(for: body.name) else { return nil }
            return PlanetBody(
                key: key,
                label: "\(glyph(for: body.name)) \(body.name)",
                longitude: body.longitude,
                formatted: body.formatted,
                house: body.house,
                retrograde: body.retrograde
            )
        }
        return NatalChart(
            name: chart.header.question,
            birthDate: String(chart.header.datetimeLocal.prefix(10)),
            birthTime: String(chart.header.datetimeLocal.dropFirst(min(11, chart.header.datetimeLocal.count)).prefix(5)),
            timezone: chart.header.timezone,
            latitude: chart.header.latitude,
            longitude: chart.header.longitude,
            placeName: chart.header.placeName,
            houseSystem: "Regiomontanus",
            ascendant: AngularPoint(longitude: asc, formatted: chart.angles.asc.formatted),
            mc: AngularPoint(longitude: chart.angles.mc.longitude, formatted: chart.angles.mc.formatted),
            cusps: cusps,
            bodies: bodies
        )
    }

    private static func planetKey(for name: String) -> String? {
        switch name {
        case "Sol": return "SOL"
        case "Luna": return "LUNA"
        case "Mercurio": return "MERCURIO"
        case "Venus": return "VENUS"
        case "Marte": return "MARTE"
        case "Jupiter", "Júpiter": return "JUPITER"
        case "Saturno": return "SATURNO"
        case "Nodo Norte": return "NODO_NORTE"
        default: return nil
        }
    }

    private static func glyph(for name: String) -> String {
        switch name {
        case "Sol": return "☉"
        case "Luna": return "☽"
        case "Mercurio": return "☿"
        case "Venus": return "♀"
        case "Marte": return "♂"
        case "Jupiter", "Júpiter": return "♃"
        case "Saturno": return "♄"
        case "Nodo Norte": return "☊"
        default: return "•"
        }
    }
}
