import Foundation

// MARK: - NatalReadingComposer
// Motor puro de composición de la lectura natal.
// Entrada: carta + interpretaciones del corpus (+ análisis extendido opcional).
// Salida: NatalReading (documento de capítulos ordenados).
//
// Reglas duras:
//  - Determinista: misma entrada → mismo documento.
//  - Sin Swiss Ephemeris, sin async, sin stores: todo lo astronómico ya
//    está en NatalChart; los aspectos se derivan con geometría pura
//    (AstroEngine.computeNatalAspects sobre longitudes residentes).
//  - La doctrina vive aquí, no en las vistas.
// Ver docs/LECTURA_NATAL_REFACTOR_ARQUITECTURA.md.

/// Densidad de la lectura.
enum ReadingDensity: Equatable {
    case essential
    case complete
}

enum NatalReadingComposer {

    struct Input {
        let chart: NatalChart
        let interpretations: [Interpretation]
        let extended: NatalExtendedAnalysisResult?
        let density: ReadingDensity

        init(
            chart: NatalChart,
            interpretations: [Interpretation],
            extended: NatalExtendedAnalysisResult? = nil,
            density: ReadingDensity = .essential
        ) {
            self.chart = chart
            self.interpretations = interpretations
            self.extended = extended
            self.density = density
        }
    }

    // MARK: - API principal

    static func compose(_ input: Input) -> NatalReading {
        let chart = input.chart
        guard !chart.bodies.isEmpty else {
            return NatalReading(
                chartId: chart.id.uuidString,
                chapters: [],
                synthesisDraft: [],
                missingKeys: []
            )
        }

        var context = Context(input: input)

        var chapters: [ReadingChapter] = []
        if let chapter = portraitChapter(&context) { chapters.append(chapter) }
        if let chapter = triadChapter(&context) { chapters.append(chapter) }
        if let chapter = ascRulerChapter(&context) { chapters.append(chapter) }
        if let chapter = dominantsChapter(&context) { chapters.append(chapter) }
        if let chapter = aspectsChapter(&context) { chapters.append(chapter) }
        if let chapter = housesChapter(&context) { chapters.append(chapter) }
        chapters.append(synthesisChapter(&context))

        return NatalReading(
            chartId: chart.id.uuidString,
            chapters: chapters,
            synthesisDraft: synthesisDraft(context),
            missingKeys: context.orderedMissingKeys
        )
    }

    // MARK: - Contexto de composición

    private struct Context {
        let chart: NatalChart
        let extended: NatalExtendedAnalysisResult?
        let density: ReadingDensity
        let distribution: ChartDistributionResult
        let corpus: [String: Interpretation]
        let aspects: [NatalAspect]
        let rankedAspects: [(aspect: NatalAspect, score: Double)]
        let angleAspectInterps: [Interpretation]
        let ascRulerKey: String?
        let dominantKey: String?

        var usedClaves: Set<String> = []
        var missing: Set<String> = []
        var orderedMissing: [String] = []

        var orderedMissingKeys: [String] { orderedMissing }

        init(input: Input) {
            self.chart = input.chart
            self.extended = input.extended
            self.density = input.density
            self.distribution = ChartDistribution.compute(chart: input.chart)

            var index: [String: Interpretation] = [:]
            var angleInterps: [Interpretation] = []
            for interp in input.interpretations {
                if index[interp.clave] == nil {
                    index[interp.clave] = interp
                }
                if interp.tipo == .aspectoNatal,
                   interp.clave.contains("_ASC_") || interp.clave.contains("_MC_") {
                    angleInterps.append(interp)
                }
            }
            self.corpus = index
            self.angleAspectInterps = angleInterps.sorted { $0.clave < $1.clave }

            let rawPlanets = Dictionary(uniqueKeysWithValues: input.chart.bodies.map { body in
                (body.key, AstroEngine.RawPlanet(
                    key: body.key,
                    label: body.label,
                    deg: body.longitude,
                    speed: body.retrograde ? -1 : 1,
                    retro: body.retrograde
                ))
            })
            let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
            self.aspects = aspects

            let ruler = NatalReadingComposer.ascendantRulerKey(chart: input.chart)
            self.ascRulerKey = ruler

            let almutenKey = input.extended?.almutenFiguris.winnerKey
            self.rankedAspects = ReadingRelevance.rankedAspects(
                aspects,
                chart: input.chart,
                ascRulerKey: ruler,
                almutenKey: almutenKey
            )
            self.dominantKey = ReadingRelevance.dominantPlanet(
                chart: input.chart,
                aspects: aspects,
                isDiurnal: ChartDistribution.compute(chart: input.chart).isDiurnal
            )
        }

        /// Busca una clave en el corpus; registra ausencia si falta.
        mutating func lookup(_ clave: String) -> Interpretation? {
            if let found = corpus[clave] { return found }
            if !missing.contains(clave) {
                missing.insert(clave)
                orderedMissing.append(clave)
            }
            return nil
        }

        mutating func markUsed(_ clave: String) {
            usedClaves.insert(clave)
        }

        func body(_ key: String) -> PlanetBody? {
            chart.bodies.first(where: { $0.key == key })
        }
    }

    // MARK: - Capítulo 0: Retrato inmediato

    private static func portraitChapter(_ ctx: inout Context) -> ReadingChapter? {
        var blocks: [ReadingBlock] = []
        let dist = ctx.distribution

        var leadParts: [String] = []
        if let element = dist.dominantElement, let modality = dist.dominantModality {
            leadParts.append(ReadingTemplates.temperament(element: element, modality: modality))
        }
        leadParts.append(ReadingTemplates.sect(isDiurnal: dist.isDiurnal))
        if let hemis = ReadingTemplates.hemispheres(
            aboveHorizon: dist.aboveHorizonCount,
            eastern: dist.easternCount,
            total: dist.totalBodies
        ) {
            leadParts.append(hemis)
        }
        blocks.append(ReadingBlock(
            id: "portrait.lead",
            kind: .lead(text: leadParts.joined(separator: " ")),
            emphasis: .primary
        ))

        for element in dist.missingElements {
            blocks.append(ReadingBlock(
                id: "portrait.missing.\(element.label)",
                kind: .lead(text: ReadingTemplates.missingElement(element))
            ))
        }

        for stellium in dist.stelliums {
            blocks.append(ReadingBlock(
                id: "portrait.stellium.\(stelliumId(stellium))",
                kind: .lead(text: ReadingTemplates.stellium(stellium)),
                emphasis: .primary
            ))
        }

        blocks.append(ReadingBlock(id: "portrait.chips", kind: .chips(portraitChips(ctx))))

        return ReadingChapter(
            id: .portrait,
            title: ReadingChapterKind.portrait.defaultTitle,
            subtitle: nil,
            blocks: blocks
        )
    }

    private static func stelliumId(_ stellium: ChartStellium) -> String {
        switch stellium.scope {
        case .sign(let key): return "sign.\(key)"
        case .house(let house): return "house.\(house)"
        }
    }

    private static func portraitChips(_ ctx: Context) -> [ReadingChip] {
        let dist = ctx.distribution
        var chips: [ReadingChip] = []
        let tints: [ChartElement: ReadingChip.ChipTint] = [
            .fire: .fire, .earth: .earth, .air: .air, .water: .water,
        ]
        for element in ChartElement.allCases {
            chips.append(ReadingChip(
                label: element.label,
                value: "\(element.symbol) \(dist.elementCounts[element] ?? 0)",
                tint: tints[element] ?? .neutral
            ))
        }
        for modality in ChartModality.allCases {
            chips.append(ReadingChip(
                label: modality.label,
                value: "\(dist.modalityCounts[modality] ?? 0)",
                tint: .neutral
            ))
        }
        chips.append(ReadingChip(
            label: "Secta",
            value: dist.isDiurnal ? "Diurna" : "Nocturna",
            tint: .accent
        ))
        let ascIdx = EssentialDignityEngine.signIndex(ctx.chart.ascendant.longitude)
        chips.append(ReadingChip(
            label: "ASC",
            value: SIGN_LABELS[max(0, min(11, ascIdx))],
            tint: .accent
        ))
        return chips
    }

    // MARK: - Capítulo 1: La tríada

    private static func triadChapter(_ ctx: inout Context) -> ReadingChapter? {
        var blocks: [ReadingBlock] = []

        for key in ["SOL", "LUNA"] {
            guard let body = ctx.body(key) else { continue }
            blocks.append(pointHeaderBlock(prefix: "triad", body: body, ctx: ctx))
            blocks.append(contentsOf: corpusBlocksForBody(prefix: "triad", body: body, ctx: &ctx))
        }

        // Ascendente
        let ascSignKey = AstroEngine.degToSignKey(ctx.chart.ascendant.longitude)
        let ascIdx = EssentialDignityEngine.signIndex(ctx.chart.ascendant.longitude)
        blocks.append(ReadingBlock(
            id: "triad.ASC.header",
            kind: .pointHeader(PointHeaderData(
                key: "ASC",
                title: "Ascendente en \(SIGN_LABELS[max(0, min(11, ascIdx))])",
                detail: ctx.chart.ascendant.formatted,
                badges: []
            )),
            emphasis: .primary
        ))
        for clave in ["ASC_\(ascSignKey)", "ASC_CASA_1"] {
            if let interp = ctx.lookup(clave) {
                ctx.markUsed(clave)
                blocks.append(corpusBlock(id: "triad.ASC.\(clave)", interp: interp))
            }
        }

        guard blocks.contains(where: { if case .pointHeader = $0.kind { return true } else { return false } }) else {
            return nil
        }
        return ReadingChapter(
            id: .triad,
            title: ReadingChapterKind.triad.defaultTitle,
            subtitle: "Sol, Luna y Ascendente: voluntad, alma y máscara",
            blocks: blocks
        )
    }

    // MARK: - Capítulo 2: Regente del Ascendente

    private static func ascRulerChapter(_ ctx: inout Context) -> ReadingChapter? {
        guard let rulerKey = ctx.ascRulerKey, let body = ctx.body(rulerKey) else { return nil }

        var blocks: [ReadingBlock] = []
        if rulerKey == "SOL" || rulerKey == "LUNA" {
            blocks.append(ReadingBlock(
                id: "ascRuler.luminary",
                kind: .lead(text: ReadingTemplates.ascRulerIsLuminary(rulerLabel: body.label)),
                emphasis: .primary
            ))
            blocks.append(pointHeaderBlock(prefix: "ascRuler", body: body, ctx: ctx))
        } else {
            blocks.append(ReadingBlock(
                id: "ascRuler.lead",
                kind: .lead(text: ReadingTemplates.ascRulerInHouse(body.house)),
                emphasis: .primary
            ))
            blocks.append(pointHeaderBlock(prefix: "ascRuler", body: body, ctx: ctx))
            blocks.append(contentsOf: corpusBlocksForBody(prefix: "ascRuler", body: body, ctx: &ctx))
        }

        return ReadingChapter(
            id: .ascRuler,
            title: ReadingChapterKind.ascRuler.defaultTitle,
            subtitle: nil,
            blocks: blocks
        )
    }

    // MARK: - Capítulo 3: Dominantes

    private static func dominantsChapter(_ ctx: inout Context) -> ReadingChapter? {
        var blocks: [ReadingBlock] = []

        if let extended = ctx.extended {
            let almuten = extended.almutenFiguris
            let points = almuten.totalScores.first?.total ?? 0
            blocks.append(ReadingBlock(
                id: "dominants.almuten",
                kind: .lead(text: "Almutén Figuris: \(almuten.winnerLabel) con \(points) puntos — el planeta con mayor autoridad acumulada sobre los lugares vitales de la carta."),
                emphasis: .primary
            ))
        }

        if let dominantKey = ctx.dominantKey, let body = ctx.body(dominantKey) {
            if dominantKey == "SOL" || dominantKey == "LUNA" {
                blocks.append(ReadingBlock(
                    id: "dominants.luminary",
                    kind: .lead(text: "El cuerpo dominante por angularidad, dignidad y aspectos es \(body.label), ya leído en la tríada: la carta se concentra en su luminaria.")
                ))
            } else {
                blocks.append(pointHeaderBlock(prefix: "dominants", body: body, ctx: ctx))
                blocks.append(contentsOf: corpusBlocksForBody(prefix: "dominants", body: body, ctx: &ctx))
            }
        }

        return blocks.isEmpty ? nil : ReadingChapter(
            id: .dominants,
            title: ReadingChapterKind.dominants.defaultTitle,
            subtitle: nil,
            blocks: blocks
        )
    }

    // MARK: - Capítulo 4: Aspectos estructurales

    private static func aspectsChapter(_ ctx: inout Context) -> ReadingChapter? {
        guard !ctx.rankedAspects.isEmpty || !ctx.angleAspectInterps.isEmpty else { return nil }

        var blocks: [ReadingBlock] = []
        let structuralLimit = ctx.density == .essential ? 5 : 8

        var structural: [(aspect: NatalAspect, score: Double)] = []
        var compact: [(aspect: NatalAspect, score: Double)] = []
        for (index, ranked) in ctx.rankedAspects.enumerated() {
            let isLuminaryPartil = ranked.aspect.orb <= 1.0 &&
                ([ranked.aspect.keyA, ranked.aspect.keyB].contains("SOL") ||
                 [ranked.aspect.keyA, ranked.aspect.keyB].contains("LUNA"))
            if index < structuralLimit || isLuminaryPartil {
                structural.append(ranked)
            } else {
                compact.append(ranked)
            }
        }

        for ranked in structural {
            let aspect = ranked.aspect
            let title = "\(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB) · orbe \(formatOrb(aspect.orb))"
            if let interp = ctx.lookup(aspect.corpusClave) {
                ctx.markUsed(aspect.corpusClave)
                blocks.append(ReadingBlock(
                    id: "aspect.\(aspect.corpusClave)",
                    kind: .corpus(
                        title: title,
                        paragraphs: paragraphs(from: interp.texto),
                        source: interp.fuente
                    ),
                    emphasis: .primary
                ))
            } else {
                // Sin texto de corpus: degradar a línea compacta (queda registrado en missingKeys).
                blocks.append(ReadingBlock(
                    id: "aspect.line.\(aspect.corpusClave)",
                    kind: .aspectLine(AspectLineData(
                        id: aspect.corpusClave,
                        text: title,
                        score: ranked.score
                    ))
                ))
            }
        }

        // Aspectos a ASC/MC presentes en el corpus.
        for interp in ctx.angleAspectInterps where !ctx.usedClaves.contains(interp.clave) {
            ctx.markUsed(interp.clave)
            blocks.append(ReadingBlock(
                id: "aspect.angle.\(interp.clave)",
                kind: .corpus(
                    title: interp.titulo,
                    paragraphs: paragraphs(from: interp.texto),
                    source: interp.fuente
                )
            ))
        }

        if !compact.isEmpty {
            for ranked in compact {
                let aspect = ranked.aspect
                blocks.append(ReadingBlock(
                    id: "aspect.compact.\(aspect.corpusClave)",
                    kind: .aspectLine(AspectLineData(
                        id: aspect.corpusClave,
                        text: "\(aspect.labelA) \(aspect.aspLabel) \(aspect.labelB) · \(formatOrb(aspect.orb))",
                        score: ranked.score
                    )),
                    emphasis: .secondary
                ))
            }
        }

        return ReadingChapter(
            id: .aspects,
            title: ReadingChapterKind.aspects.defaultTitle,
            subtitle: "Ordenados por relevancia: luminarias, angularidad y orbe",
            blocks: blocks
        )
    }

    // MARK: - Capítulo 5: Las casas

    private static func housesChapter(_ ctx: inout Context) -> ReadingChapter? {
        var blocks: [ReadingBlock] = []
        let angularOrder = [1, 10, 7, 4]
        let occupiedHouses = Set(ctx.chart.bodies.map(\.house))

        // Angulares primero, en orden doctrinal.
        for house in angularOrder {
            let bodies = ctx.chart.bodies.filter { $0.house == house }
            for body in bodies {
                let clave = "\(body.key)_CASA_\(body.house)"
                if ctx.usedClaves.contains(clave) { continue }
                blocks.append(pointHeaderBlock(prefix: "houses", body: body, ctx: ctx))
                if let interp = ctx.lookup(clave) {
                    ctx.markUsed(clave)
                    blocks.append(corpusBlock(id: "houses.\(clave)", interp: interp))
                }
            }
        }

        // Resto de casas ocupadas.
        let otherHouses = (1...12).filter { !angularOrder.contains($0) && occupiedHouses.contains($0) }
        if ctx.density == .complete {
            for house in otherHouses {
                for body in ctx.chart.bodies.filter({ $0.house == house }) {
                    let clave = "\(body.key)_CASA_\(body.house)"
                    if ctx.usedClaves.contains(clave) { continue }
                    blocks.append(pointHeaderBlock(prefix: "houses", body: body, ctx: ctx))
                    if let interp = ctx.lookup(clave) {
                        ctx.markUsed(clave)
                        blocks.append(corpusBlock(id: "houses.\(clave)", interp: interp))
                    }
                }
            }
        } else {
            var items: [String] = []
            for house in otherHouses {
                for body in ctx.chart.bodies.filter({ $0.house == house }) {
                    items.append("\(body.label) en casa \(house)")
                }
            }
            if !items.isEmpty {
                blocks.append(ReadingBlock(
                    id: "houses.compact",
                    kind: .groupedList(title: "Otras posiciones", items: items),
                    emphasis: .secondary
                ))
            }
        }

        // Casas vacías y sus regentes.
        let emptyHouses = (1...12).filter { !occupiedHouses.contains($0) }
        if !emptyHouses.isEmpty, ctx.chart.cusps.count == 12 {
            blocks.append(ReadingBlock(
                id: "houses.empty.lead",
                kind: .lead(text: ReadingTemplates.emptyHousesLead()),
                emphasis: .secondary
            ))
            var items: [String] = []
            for house in emptyHouses {
                let cusp = ctx.chart.cusps[house - 1]
                let signIdx = EssentialDignityEngine.signIndex(cusp)
                let rulerKey = EssentialDignityEngine.domicileRuler(of: signIdx)
                let signLabel = SIGN_LABELS[max(0, min(11, signIdx))]
                if let rulerBody = ctx.body(rulerKey) {
                    items.append("Casa \(house) (\(signLabel)): regente \(rulerBody.label) en casa \(rulerBody.house)")
                } else {
                    items.append("Casa \(house) (\(signLabel))")
                }
            }
            blocks.append(ReadingBlock(
                id: "houses.empty",
                kind: .groupedList(title: "Casas vacías", items: items),
                emphasis: .secondary
            ))
        }

        return blocks.isEmpty ? nil : ReadingChapter(
            id: .houses,
            title: ReadingChapterKind.houses.defaultTitle,
            subtitle: nil,
            blocks: blocks
        )
    }

    // MARK: - Capítulo 6: Síntesis

    private static func synthesisChapter(_ ctx: inout Context) -> ReadingChapter {
        ReadingChapter(
            id: .synthesis,
            title: ReadingChapterKind.synthesis.defaultTitle,
            subtitle: nil,
            blocks: [
                ReadingBlock(
                    id: "synthesis.lead",
                    kind: .lead(text: ReadingTemplates.synthesisLead()),
                    emphasis: .secondary
                ),
            ]
        )
    }

    private static func synthesisDraft(_ ctx: Context) -> [String] {
        var draft: [String] = []
        let dist = ctx.distribution

        if let element = dist.dominantElement, let modality = dist.dominantModality {
            draft.append("Dominante \(element.label.lowercased())-\(modality.label.lowercased()), carta \(dist.isDiurnal ? "diurna" : "nocturna").")
        }
        if let sun = ctx.body("SOL"), let moon = ctx.body("LUNA") {
            let ascIdx = EssentialDignityEngine.signIndex(ctx.chart.ascendant.longitude)
            draft.append("Sol en \(signName(sun.signIndex)) (casa \(sun.house)) · Luna en \(signName(moon.signIndex)) (casa \(moon.house)) · ASC \(signName(ascIdx)).")
        }
        if let rulerKey = ctx.ascRulerKey, let ruler = ctx.body(rulerKey) {
            draft.append("Regente del ASC: \(ruler.label) en \(signName(ruler.signIndex)), casa \(ruler.house).")
        }
        if let dominantKey = ctx.dominantKey, let dominant = ctx.body(dominantKey), dominantKey != ctx.ascRulerKey {
            draft.append("Dominante por angularidad y dignidad: \(dominant.label).")
        }
        if let top = ctx.rankedAspects.first {
            draft.append("Aspecto estructural principal: \(top.aspect.labelA) \(top.aspect.aspLabel) \(top.aspect.labelB) (orbe \(formatOrb(top.aspect.orb))).")
        }
        for stellium in dist.stelliums {
            draft.append(ReadingTemplates.stellium(stellium))
        }
        return draft
    }

    // MARK: - Helpers

    /// Regente clásico del signo del Ascendente.
    static func ascendantRulerKey(chart: NatalChart) -> String? {
        guard !chart.bodies.isEmpty else { return nil }
        let signIdx = EssentialDignityEngine.signIndex(chart.ascendant.longitude)
        return EssentialDignityEngine.domicileRuler(of: signIdx)
    }

    private static func pointHeaderBlock(prefix: String, body: PlanetBody, ctx: Context) -> ReadingBlock {
        ReadingBlock(
            id: "\(prefix).\(body.key).header",
            kind: .pointHeader(PointHeaderData(
                key: body.key,
                title: "\(body.label) en \(signName(body.signIndex))",
                detail: "\(body.formatted) · Casa \(body.house)",
                badges: badges(for: body, isDiurnal: ctx.distribution.isDiurnal)
            )),
            emphasis: .primary
        )
    }

    /// Bloques de corpus signo + casa para un cuerpo, marcando claves usadas.
    private static func corpusBlocksForBody(prefix: String, body: PlanetBody, ctx: inout Context) -> [ReadingBlock] {
        var blocks: [ReadingBlock] = []
        let signKey = AstroEngine.degToSignKey(body.longitude)
        for clave in ["\(body.key)_\(signKey)", "\(body.key)_CASA_\(body.house)"] {
            if ctx.usedClaves.contains(clave) { continue }
            if let interp = ctx.lookup(clave) {
                ctx.markUsed(clave)
                blocks.append(corpusBlock(id: "\(prefix).\(clave)", interp: interp))
            }
        }
        return blocks
    }

    private static func corpusBlock(id: String, interp: Interpretation) -> ReadingBlock {
        ReadingBlock(
            id: id,
            kind: .corpus(
                title: interp.titulo.isEmpty ? nil : interp.titulo,
                paragraphs: paragraphs(from: interp.texto),
                source: interp.fuente
            )
        )
    }

    private static func badges(for body: PlanetBody, isDiurnal: Bool) -> [String] {
        var badges: [String] = []
        if ReadingRelevance.angularHouses.contains(body.house) {
            badges.append("Angular")
        }
        if body.retrograde {
            badges.append("℞")
        }
        let traditional: Set<String> = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO"]
        if traditional.contains(body.key) {
            let dignity = EssentialDignityEngine.primaryDignity(
                planet: body.key,
                longitude: body.longitude,
                isDiurnal: isDiurnal
            )
            badges.append(dignity.dignity.rawValue.capitalized)
        }
        return badges
    }

    private static func paragraphs(from text: String) -> [String] {
        let parts = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : parts
    }

    private static func signName(_ signIndex: Int) -> String {
        SIGN_LABELS[max(0, min(11, signIndex))]
    }

    private static func formatOrb(_ orb: Double) -> String {
        let degrees = Int(orb)
        let minutes = Int(((orb - Double(degrees)) * 60).rounded())
        if minutes >= 60 {
            return "\(degrees + 1)°00'"
        }
        return "\(degrees)°\(String(format: "%02d", minutes))'"
    }
}
