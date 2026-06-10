import XCTest
@testable import AstroMalik

// MARK: - Fixtures

enum ReadingFixtures {

    /// Carta sintética con geometría controlada:
    ///  - SOL ♑ 280° casa 10 · LUNA ♋ 100° casa 4 (oposición partil de luminarias)
    ///  - MARTE ♈ 10° casa 1 (regente del ASC Aries, angular, domicilio)
    ///  - SATURNO ♑ 282° casa 10 (conjunción al Sol, domicilio)
    ///  - Distribución: tierra 4, fuego 3, aire 2, agua 1 · cardinal 5, fijo 3, mutable 2
    ///  - Diurna (Sol en casa 10) · Casas vacías: 3, 8 y 12.
    static func chart(
        ascLongitude: Double = 15.0,
        extraBodies: [PlanetBody] = []
    ) -> NatalChart {
        var bodies: [PlanetBody] = [
            body("SOL", "☉ Sol", 280.0, house: 10),
            body("LUNA", "☽ Luna", 100.0, house: 4),
            body("MERCURIO", "☿ Mercurio", 255.0, house: 9),
            body("VENUS", "♀ Venus", 310.0, house: 11),
            body("MARTE", "♂ Marte", 10.0, house: 1),
            body("JUPITER", "♃ Júpiter", 130.0, house: 5),
            body("SATURNO", "♄ Saturno", 282.0, house: 10),
            body("URANO", "⛢ Urano", 45.0, house: 2),
            body("NEPTUNO", "♆ Neptuno", 200.0, house: 7),
            body("PLUTON", "♇ Plutón", 160.0, house: 6),
        ]
        bodies.append(contentsOf: extraBodies)
        return NatalChart(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            name: "Fixture Lectura",
            birthDate: "1990-01-01",
            birthTime: "12:00",
            timezone: "Europe/Madrid",
            latitude: 37.18,
            longitude: -3.6,
            placeName: "Granada",
            ascendant: AngularPoint(longitude: ascLongitude, formatted: AstroEngine.degToSign(ascLongitude)),
            mc: AngularPoint(longitude: 280.0, formatted: AstroEngine.degToSign(280.0)),
            cusps: [15, 45, 75, 105, 135, 165, 195, 225, 255, 285, 315, 345],
            bodies: bodies
        )
    }

    static func body(_ key: String, _ label: String, _ longitude: Double, house: Int, retro: Bool = false) -> PlanetBody {
        PlanetBody(
            key: key,
            label: label,
            longitude: longitude,
            formatted: AstroEngine.degToSign(longitude),
            house: house,
            retrograde: retro
        )
    }

    static func interp(_ clave: String, tipo: InterpretationType, titulo: String = "", texto: String) -> Interpretation {
        Interpretation(clave: clave, tipo: tipo, titulo: titulo, texto: texto, fuente: "Fixture", orden: 0)
    }

    /// Corpus mínimo: tríada completa + regente + un aspecto estructural.
    static func corpus() -> [Interpretation] {
        [
            interp("SOL_CAPRICORNIO", tipo: .natalPlanetaSigno, titulo: "Sol en Capricornio", texto: "Texto Sol en Capricornio.\n\nSegundo párrafo solar."),
            interp("SOL_CASA_10", tipo: .natalPlanetaCasa, titulo: "Sol en Casa 10", texto: "Texto Sol en casa diez."),
            interp("LUNA_CANCER", tipo: .natalPlanetaSigno, titulo: "Luna en Cáncer", texto: "Texto Luna en Cáncer."),
            interp("LUNA_CASA_4", tipo: .natalPlanetaCasa, titulo: "Luna en Casa 4", texto: "Texto Luna en casa cuatro."),
            interp("ASC_ARIES", tipo: .natalPlanetaSigno, titulo: "Ascendente en Aries", texto: "Texto ASC Aries."),
            interp("ASC_CASA_1", tipo: .natalPlanetaCasa, titulo: "Ascendente en Casa 1", texto: "Texto ASC casa uno."),
            interp("MARTE_ARIES", tipo: .natalPlanetaSigno, titulo: "Marte en Aries", texto: "Texto Marte en Aries."),
            interp("MARTE_CASA_1", tipo: .natalPlanetaCasa, titulo: "Marte en Casa 1", texto: "Texto Marte en casa uno."),
            interp("SOL_LUNA_OPOSICION", tipo: .aspectoNatal, titulo: "Sol oposición Luna", texto: "Texto oposición de luminarias."),
            interp("SATURNO_ASC_CONJUNCION", tipo: .aspectoNatal, titulo: "Saturno conjunción ASC", texto: "Texto Saturno sobre el Ascendente."),
        ]
    }
}

// MARK: - Composer

final class NatalReadingComposerTests: XCTestCase {

    private func compose(
        ascLongitude: Double = 15.0,
        extraBodies: [PlanetBody] = [],
        corpus: [Interpretation]? = nil,
        density: ReadingDensity = .essential
    ) -> NatalReading {
        NatalReadingComposer.compose(.init(
            chart: ReadingFixtures.chart(ascLongitude: ascLongitude, extraBodies: extraBodies),
            interpretations: corpus ?? ReadingFixtures.corpus(),
            extended: nil,
            density: density
        ))
    }

    // MARK: Determinismo y orden

    func testComposeIsDeterministic() {
        let first = compose(density: .complete)
        let second = compose(density: .complete)
        XCTAssertEqual(first, second)
    }

    func testChaptersFollowCanonicalOrder() {
        let reading = compose(density: .complete)
        let canonical = ReadingChapterKind.allCases
        let indices = reading.chapters.compactMap { chapter in
            canonical.firstIndex(of: chapter.id)
        }
        XCTAssertEqual(indices, indices.sorted(), "Los capítulos deben seguir el orden canónico")
        XCTAssertEqual(reading.chapters.first?.id, .portrait)
        XCTAssertEqual(reading.chapters.last?.id, .synthesis)
    }

    func testEmptyChartProducesEmptyReading() {
        let reading = NatalReadingComposer.compose(.init(
            chart: .placeholder,
            interpretations: [],
            extended: nil,
            density: .essential
        ))
        XCTAssertTrue(reading.chapters.isEmpty)
        XCTAssertTrue(reading.synthesisDraft.isEmpty)
    }

    // MARK: Retrato

    func testPortraitContainsTemperamentAndChips() {
        let reading = compose()
        guard let portrait = reading.chapters.first(where: { $0.id == .portrait }) else {
            return XCTFail("Falta capítulo de retrato")
        }
        let hasLead = portrait.blocks.contains { block in
            if case .lead(let text) = block.kind {
                return text.contains("tierra") && text.contains("cardinal")
            }
            return false
        }
        XCTAssertTrue(hasLead, "El lead debe reflejar dominante tierra-cardinal")

        let chips: [ReadingChip] = portrait.blocks.compactMap { block in
            if case .chips(let chips) = block.kind { return chips }
            return nil
        }.flatMap { $0 }
        XCTAssertEqual(chips.first(where: { $0.label == "Tierra" })?.value.hasSuffix("4"), true)
        XCTAssertEqual(chips.first(where: { $0.label == "Cardinal" })?.value, "5")
        XCTAssertEqual(chips.first(where: { $0.label == "Secta" })?.value, "Diurna")
    }

    // MARK: Tríada

    func testTriadHasThreeHeadersAndCorpusTexts() {
        let reading = compose()
        guard let triad = reading.chapters.first(where: { $0.id == .triad }) else {
            return XCTFail("Falta capítulo de tríada")
        }
        let headerKeys: [String] = triad.blocks.compactMap { block in
            if case .pointHeader(let data) = block.kind { return data.key }
            return nil
        }
        XCTAssertEqual(headerKeys, ["SOL", "LUNA", "ASC"])

        let corpusCount = triad.blocks.filter { block in
            if case .corpus = block.kind { return true }
            return false
        }.count
        // SOL signo+casa, LUNA signo+casa, ASC signo+casa = 6 bloques con el corpus fixture.
        XCTAssertEqual(corpusCount, 6)
    }

    func testCorpusParagraphsAreSplit() {
        let reading = compose()
        guard let triad = reading.chapters.first(where: { $0.id == .triad }) else {
            return XCTFail("Falta tríada")
        }
        let solSigno = triad.blocks.first { $0.id.contains("SOL_CAPRICORNIO") }
        guard case .corpus(_, let paragraphs, let source)? = solSigno?.kind else {
            return XCTFail("Falta bloque de corpus de Sol en Capricornio")
        }
        XCTAssertEqual(paragraphs.count, 2, "El texto con doble salto debe partirse en dos párrafos")
        XCTAssertEqual(source, "Fixture")
    }

    // MARK: Regente del ASC

    func testAscRulerChapterForMars() {
        let reading = compose()
        guard let chapter = reading.chapters.first(where: { $0.id == .ascRuler }) else {
            return XCTFail("Falta capítulo de regente")
        }
        let header: PointHeaderData? = chapter.blocks.compactMap { block in
            if case .pointHeader(let data) = block.kind { return data }
            return nil
        }.first
        XCTAssertEqual(header?.key, "MARTE")
        XCTAssertEqual(header?.badges.contains("Angular"), true)
        XCTAssertEqual(header?.badges.contains("Domicilio"), true)
        let hasLead = chapter.blocks.contains { block in
            if case .lead(let text) = block.kind { return text.contains("casa 1") }
            return false
        }
        XCTAssertTrue(hasLead)
    }

    func testAscRulerLuminaryDoesNotRepeatCorpus() {
        // ASC en Leo (135°) → regente SOL, ya leído en la tríada.
        let reading = compose(ascLongitude: 135.0)
        guard let chapter = reading.chapters.first(where: { $0.id == .ascRuler }) else {
            return XCTFail("Falta capítulo de regente")
        }
        let corpusBlocks = chapter.blocks.filter { block in
            if case .corpus = block.kind { return true }
            return false
        }
        XCTAssertTrue(corpusBlocks.isEmpty, "Si el regente es una luminaria no se repite su corpus")
        let hasLuminaryLead = chapter.blocks.contains { block in
            if case .lead(let text) = block.kind { return text.contains("tríada") }
            return false
        }
        XCTAssertTrue(hasLuminaryLead)
    }

    func testAscendantRulerKeyForAllTwelveSigns() {
        let expected = [
            "MARTE", "VENUS", "MERCURIO", "LUNA", "SOL", "MERCURIO",
            "VENUS", "MARTE", "JUPITER", "SATURNO", "SATURNO", "JUPITER",
        ]
        for (index, ruler) in expected.enumerated() {
            let chart = ReadingFixtures.chart(ascLongitude: Double(index) * 30.0 + 15.0)
            XCTAssertEqual(
                NatalReadingComposer.ascendantRulerKey(chart: chart),
                ruler,
                "Regente incorrecto para signo \(index)"
            )
        }
    }

    // MARK: Aspectos

    func testStructuralAspectUsesCorpusText() {
        let reading = compose()
        guard let aspects = reading.chapters.first(where: { $0.id == .aspects }) else {
            return XCTFail("Falta capítulo de aspectos")
        }
        let opposition = aspects.blocks.first { $0.id == "aspect.SOL_LUNA_OPOSICION" }
        guard case .corpus(let title, let paragraphs, _)? = opposition?.kind else {
            return XCTFail("La oposición de luminarias debe ser bloque estructural con texto")
        }
        XCTAssertEqual(title?.contains("orbe"), true)
        XCTAssertEqual(paragraphs.first, "Texto oposición de luminarias.")
    }

    func testAngleAspectInterpretationIncluded() {
        let reading = compose()
        guard let aspects = reading.chapters.first(where: { $0.id == .aspects }) else {
            return XCTFail("Falta capítulo de aspectos")
        }
        let angleBlock = aspects.blocks.first { $0.id == "aspect.angle.SATURNO_ASC_CONJUNCION" }
        XCTAssertNotNil(angleBlock, "Los aspectos a ASC/MC presentes en el corpus deben incluirse")
    }

    func testEssentialDensityLimitsStructuralBlocks() {
        let essential = compose(density: .essential)
        let complete = compose(density: .complete)
        func corpusAspectCount(_ reading: NatalReading) -> Int {
            reading.chapters.first(where: { $0.id == .aspects })?.blocks.filter { block in
                block.id.hasPrefix("aspect.") && !block.id.hasPrefix("aspect.compact.")
            }.count ?? 0
        }
        XCTAssertLessThanOrEqual(corpusAspectCount(essential), corpusAspectCount(complete))
    }

    // MARK: Casas

    func testHousesChapterListsEmptyHousesWithRulers() {
        let reading = compose()
        guard let houses = reading.chapters.first(where: { $0.id == .houses }) else {
            return XCTFail("Falta capítulo de casas")
        }
        guard let emptyBlock = houses.blocks.first(where: { $0.id == "houses.empty" }),
              case .groupedList(_, let items) = emptyBlock.kind else {
            return XCTFail("Falta la lista de casas vacías")
        }
        // Vacías: 3 (Géminis → Mercurio), 8 (Escorpio → Marte), 12 (Piscis → Júpiter).
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items[0].contains("Casa 3") && items[0].contains("Mercurio"))
        XCTAssertTrue(items[1].contains("Casa 8") && items[1].contains("Marte"))
        XCTAssertTrue(items[2].contains("Casa 12") && items[2].contains("Júpiter"))
    }

    func testTriadHouseTextsAreNotRepeatedInHousesChapter() {
        let reading = compose(density: .complete)
        guard let houses = reading.chapters.first(where: { $0.id == .houses }) else {
            return XCTFail("Falta capítulo de casas")
        }
        let repeated = houses.blocks.contains { $0.id.contains("SOL_CASA_10") || $0.id.contains("LUNA_CASA_4") }
        XCTAssertFalse(repeated, "Los textos de casa ya usados en la tríada no deben repetirse")
    }

    // MARK: Corpus faltante

    func testMissingCorpusKeysAreReported() {
        let reading = compose(density: .complete)
        XCTAssertTrue(
            reading.missingKeys.contains("VENUS_CASA_11"),
            "Una clave solicitada y ausente debe quedar registrada"
        )
        // Las claves presentes nunca aparecen como faltantes.
        XCTAssertFalse(reading.missingKeys.contains("SOL_CAPRICORNIO"))
    }

    // MARK: Stellium

    func testStelliumDetectedInPortraitAndDraft() {
        // Mercurio trasladado a ♑ 285° casa 10 → stellium Capricornio (Sol, Saturno, Mercurio).
        var bodies = ReadingFixtures.chart().bodies
        bodies.removeAll { $0.key == "MERCURIO" }
        let chart = NatalChart(
            id: UUID(),
            name: "Stellium",
            birthDate: "1990-01-01",
            birthTime: "12:00",
            timezone: "Europe/Madrid",
            latitude: 37.18,
            longitude: -3.6,
            placeName: "Granada",
            ascendant: AngularPoint(longitude: 15, formatted: AstroEngine.degToSign(15)),
            mc: AngularPoint(longitude: 280, formatted: AstroEngine.degToSign(280)),
            cusps: [15, 45, 75, 105, 135, 165, 195, 225, 255, 285, 315, 345],
            bodies: bodies + [ReadingFixtures.body("MERCURIO", "☿ Mercurio", 285.0, house: 10)]
        )
        let dist = ChartDistribution.compute(chart: chart)
        XCTAssertEqual(dist.stelliums.count, 1)
        if case .sign(let signKey)? = dist.stelliums.first?.scope {
            XCTAssertEqual(signKey, "CAPRICORNIO")
        } else {
            XCTFail("El stellium debe reportarse por signo")
        }

        let reading = NatalReadingComposer.compose(.init(
            chart: chart,
            interpretations: ReadingFixtures.corpus(),
            extended: nil,
            density: .essential
        ))
        XCTAssertTrue(reading.synthesisDraft.contains { $0.contains("Stellium") })
    }

    // MARK: Borrador de síntesis

    func testSynthesisDraftContainsHardFacts() {
        let reading = compose()
        XCTAssertTrue(reading.synthesisDraft.contains { $0.contains("tierra-cardinal") })
        XCTAssertTrue(reading.synthesisDraft.contains { $0.contains("Sol en") && $0.contains("Luna en") })
        XCTAssertTrue(reading.synthesisDraft.contains { $0.contains("Regente del ASC") })
    }
}

// MARK: - Distribución

final class ChartDistributionTests: XCTestCase {

    func testElementAndModalityCounts() {
        let dist = ChartDistribution.compute(chart: ReadingFixtures.chart())
        XCTAssertEqual(dist.elementCounts[.earth], 4)
        XCTAssertEqual(dist.elementCounts[.fire], 3)
        XCTAssertEqual(dist.elementCounts[.air], 2)
        XCTAssertEqual(dist.elementCounts[.water], 1)
        XCTAssertEqual(dist.modalityCounts[.cardinal], 5)
        XCTAssertEqual(dist.modalityCounts[.fixed], 3)
        XCTAssertEqual(dist.modalityCounts[.mutable], 2)
        XCTAssertEqual(dist.dominantElement, .earth)
        XCTAssertEqual(dist.dominantModality, .cardinal)
        XCTAssertTrue(dist.missingElements.isEmpty)
        XCTAssertTrue(dist.isDiurnal)
    }

    func testMissingElementDetected() {
        // Carta sin agua: Luna trasladada a Leo.
        var bodies = ReadingFixtures.chart().bodies
        bodies.removeAll { $0.key == "LUNA" }
        let chart = ReadingFixtures.chart(extraBodies: [])
        let waterless = NatalChart(
            id: UUID(),
            name: "Sin agua",
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezone: chart.timezone,
            latitude: chart.latitude,
            longitude: chart.longitude,
            placeName: chart.placeName,
            ascendant: chart.ascendant,
            mc: chart.mc,
            cusps: chart.cusps,
            bodies: bodies + [ReadingFixtures.body("LUNA", "☽ Luna", 140.0, house: 5)]
        )
        let dist = ChartDistribution.compute(chart: waterless)
        XCTAssertEqual(dist.missingElements, [.water])
    }
}

// MARK: - Relevancia

final class ReadingRelevanceTests: XCTestCase {

    func testLuminaryPartilOutscoresLooseTrine() {
        let chart = ReadingFixtures.chart()
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(key: body.key, label: body.label, deg: body.longitude, speed: 1, retro: false))
        })
        let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)

        guard let sunMoon = aspects.first(where: { $0.corpusClave == "SOL_LUNA_OPOSICION" }) else {
            return XCTFail("La fixture debe producir Sol oposición Luna")
        }
        guard let mercuryJupiter = aspects.first(where: { $0.corpusClave == "MERCURIO_JUPITER_TRIGONO" }) else {
            return XCTFail("La fixture debe producir Mercurio trígono Júpiter")
        }

        let sunMoonScore = ReadingRelevance.aspectScore(sunMoon, chart: chart, ascRulerKey: "MARTE")
        let looseScore = ReadingRelevance.aspectScore(mercuryJupiter, chart: chart, ascRulerKey: "MARTE")
        XCTAssertGreaterThan(sunMoonScore, looseScore)
        // Oposición partil de luminarias angulares: 3 + 2 + 2 + 1 = 8.
        XCTAssertEqual(sunMoonScore, 8.0, accuracy: 0.001)
        // Trígono suelto entre cadentes sin luminarias: 0.
        XCTAssertEqual(looseScore, 0.0, accuracy: 0.001)
    }

    func testRankedAspectsAreTotallyOrderedAndDeterministic() {
        let chart = ReadingFixtures.chart()
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(key: body.key, label: body.label, deg: body.longitude, speed: 1, retro: false))
        })
        let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
        let first = ReadingRelevance.rankedAspects(aspects, chart: chart, ascRulerKey: "MARTE")
        let second = ReadingRelevance.rankedAspects(aspects.shuffled(), chart: chart, ascRulerKey: "MARTE")
        XCTAssertEqual(first.map(\.aspect.id), second.map(\.aspect.id), "El ranking debe ser un orden total determinista")
    }

    func testDominantPlanetIsMars() {
        let chart = ReadingFixtures.chart()
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(key: body.key, label: body.label, deg: body.longitude, speed: 1, retro: false))
        })
        let aspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
        // MARTE: angular casa 1 (+3), domicilio en Aries (+5), cuadraturas a Sol y Luna (+2) = 10.
        // SATURNO empata (10); gana MARTE por orden canónico de PLANET_LIST.
        XCTAssertEqual(
            ReadingRelevance.dominantPlanet(chart: chart, aspects: aspects, isDiurnal: true),
            "MARTE"
        )
    }
}
