import Foundation

struct NatalReportBuilder {
    static func generate(from chart: NatalChart, pageSize: PDFPageSize = .a4Portrait) async throws -> Data {
        let data = try makeData(from: chart)
        return try await ReportService().generate(request: ReportRequest(templateName: "natal", data: data, pageSize: pageSize))
    }

    static func makeData(from chart: NatalChart, generatedAt: Date = Date()) throws -> NatalReportData {
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        let ascSign = ReportFormatting.signLabel(for: chart.ascendant.longitude)
        let interpretations = corpusInterpretations(for: chart)
        let aspects = ChartSVGRenderingSupport.natalAspects(for: chart)
        let isDiurnal = SectEngine.sect(of: chart).isDiurnal

        return NatalReportData(
            header: ReportHeaderData(chartName: displayName(chart), reportTitle: "Informe natal", generatedDate: generatedDate),
            cover: ReportCoverData(
                chartName: displayName(chart),
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                place: chart.placeName,
                generatedDate: generatedDate,
                ascSign: ascSign,
                ascGlyph: ReportFormatting.signGlyph(for: chart.ascendant.longitude)
            ),
            includeTOC: true,
            generatedDate: generatedDate,
            wheelSVG: wheel(chart: chart, theme: .default, size: 620),
            technicalRows: positionRows(chart.bodies),
            signInterpretations: interpretationBlocks(interpretations, type: .natalPlanetaSigno, fallback: signFallbacks(chart)),
            houseInterpretations: interpretationBlocks(interpretations, type: .natalPlanetaCasa, fallback: houseFallbacks(chart)),
            aspectRows: aspectRows(aspects, interpretations: interpretations),
            guidedReading: guidedReading(chart: chart, aspects: aspects),
            dignityRows: dignityRows(chart: chart, isDiurnal: isDiurnal)
        )
    }

    private static func displayName(_ chart: NatalChart) -> String { chart.name.isEmpty ? "Carta natal" : chart.name }

    private static func corpusInterpretations(for chart: NatalChart) -> [Interpretation] {
        guard let url = AppResources.bundle.url(forResource: "corpus", withExtension: "db") else { return [] }
        guard let store = try? CorpusStore(path: url.path) else { return [] }
        return store.buildNatalInterpretations(chart: chart)
    }

    private static func interpretationBlocks(_ interpretations: [Interpretation], type: InterpretationType, fallback: [ReportTextBlock]) -> [ReportTextBlock] {
        let blocks = interpretations
            .filter { $0.tipo == type }
            .map { ReportTextBlock(title: $0.titulo, subtitle: $0.clave, text: $0.texto, source: $0.fuente) }
        return blocks.isEmpty ? fallback : blocks
    }

    private static func positionRows(_ bodies: [PlanetBody]) -> [ReportPositionRow] {
        ChartSVGRenderingSupport.orderedBodies(bodies).map { body in
            ReportPositionRow(
                body: ReportFormatting.plainPlanetName(body.label),
                glyph: body.label.split(separator: " ").first.map(String.init) ?? "",
                position: body.formatted,
                sign: ReportFormatting.signLabel(for: body.longitude),
                house: "Casa \(body.house)",
                retrograde: body.retrograde ? "℞" : "Directo"
            )
        }
    }

    private static func signFallbacks(_ chart: NatalChart) -> [ReportTextBlock] {
        ChartSVGRenderingSupport.orderedBodies(chart.bodies).prefix(12).map { body in
            let sign = ReportFormatting.signLabel(for: body.longitude)
            return ReportTextBlock(
                title: "\(body.label) en \(sign)",
                subtitle: "\(body.key)_\(AstroEngine.degToSignKey(body.longitude))",
                text: "El planeta se expresa a través de la cualidad de \(sign), modulando su función natal por elemento, modalidad y regencia del signo.",
                source: "Síntesis AstroMalik"
            )
        }
    }

    private static func houseFallbacks(_ chart: NatalChart) -> [ReportTextBlock] {
        ChartSVGRenderingSupport.orderedBodies(chart.bodies).prefix(12).map { body in
            ReportTextBlock(
                title: "\(body.label) en Casa \(body.house)",
                subtitle: "\(body.key)_CASA_\(body.house)",
                text: "La función de \(ReportFormatting.plainPlanetName(body.label)) se concreta en los temas de la casa \(body.house), indicando dónde se manifiesta con mayor visibilidad en la biografía.",
                source: "Síntesis AstroMalik"
            )
        }
    }

    private static func aspectRows(_ aspects: [NatalAspect], interpretations: [Interpretation]) -> [ReportAspectRow] {
        let byKey = Dictionary(uniqueKeysWithValues: interpretations.map { ($0.clave, $0) })
        return aspects.prefix(40).map { aspect in
            let text = byKey[aspect.corpusClave]?.texto ?? "Aspecto natal entre \(aspect.labelA) y \(aspect.labelB); integra sus funciones con un orbe de \(ReportFormatting.degree(aspect.orb))."
            return ReportAspectRow(
                left: aspect.labelA,
                aspect: aspect.aspLabel,
                right: aspect.labelB,
                orb: ReportFormatting.degree(aspect.orb),
                corpusKey: aspect.corpusClave,
                text: text
            )
        }
    }

    private static func guidedReading(chart: NatalChart, aspects: [NatalAspect]) -> [ReportTextBlock] {
        let map = Dictionary(uniqueKeysWithValues: chart.bodies.map { ($0.key, $0) })
        let sun = map["SOL"]
        let moon = map["LUNA"]
        let ascRuler = EssentialDignityEngine.domicileRuler(of: SVGChartSupport.signIndex(for: chart.ascendant.longitude))
        let angular = chart.bodies.filter { [1, 4, 7, 10].contains($0.house) }.map(\.label).joined(separator: ", ")
        let dominant = aspects.prefix(5).map { "\($0.labelA) \($0.aspLabel) \($0.labelB)" }.joined(separator: "; ")
        return [
            ReportTextBlock(title: "Tríada Sol/Luna/Ascendente", subtitle: "Identidad, necesidad y entrada al mundo", text: "Sol: \(sun?.formatted ?? "sin dato"). Luna: \(moon?.formatted ?? "sin dato"). Ascendente: \(chart.ascendant.formatted). Esta tríada ordena propósito, hábito emocional y modo de encarnar la carta.", source: "Lectura guiada AstroMalik"),
            ReportTextBlock(title: "Regente del Ascendente", subtitle: ascRuler, text: "El regente del Ascendente es \(ExtendedAstro.planetLabel(for: ascRuler)); su posición describe el hilo conductor de la carta y el lugar donde la natividad busca dirección.", source: "Lectura guiada AstroMalik"),
            ReportTextBlock(title: "Casas angulares", subtitle: "I, IV, VII, X", text: angular.isEmpty ? "No hay planetas en casas angulares; los ángulos y sus regentes toman prioridad interpretativa." : "Planetas angulares: \(angular). Lo angular vuelve visible y operativo lo que toca.", source: "Lectura guiada AstroMalik"),
            ReportTextBlock(title: "Aspectos dominantes", subtitle: "Menor orbe primero", text: dominant.isEmpty ? "No se detectan aspectos mayores con los orbes configurados." : dominant, source: "Lectura guiada AstroMalik"),
            ReportTextBlock(title: "Síntesis", subtitle: "Integración", text: "La lectura combina dignidad, casa y aspectos: primero se atiende lo que sostiene la carta, después sus tensiones y finalmente los caminos de integración práctica.", source: "Lectura guiada AstroMalik"),
        ]
    }

    private static func dignityRows(chart: NatalChart, isDiurnal: Bool) -> [ReportDignityRow] {
        ChartSVGRenderingSupport.orderedBodies(chart.bodies).filter { ExtendedAstro.traditionalPlanetKeys.contains($0.key) }.map { body in
            let dignities = EssentialDignityEngine.dignities(planet: body.key, longitude: body.longitude, isDiurnal: isDiurnal)
            let total = dignities.reduce(0) { $0 + $1.score }
            return ReportDignityRow(
                planet: body.label,
                position: body.formatted,
                dignities: dignities.map { "\($0.dignity.rawValue) \($0.score >= 0 ? "+" : "")\($0.score)" }.joined(separator: ", "),
                score: "\(total)"
            )
        }
    }
}
