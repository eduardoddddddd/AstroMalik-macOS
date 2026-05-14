import XCTest
@testable import AstroMalik

final class CrossPersonalReportTests: XCTestCase {

    // MARK: - MarkdownToHTML

    func testMarkdownConvertsHeadingsParagraphsAndLists() {
        let md = """
        # Título
        ## Subtítulo
        ### Detalle

        Un párrafo con **negrita** y *cursiva* y `código`.

        - Primero
        - Segundo
        """
        let html = MarkdownToHTML.convert(md)
        XCTAssertTrue(html.contains("<h1>Título</h1>"))
        XCTAssertTrue(html.contains("<h2>Subtítulo</h2>"))
        XCTAssertTrue(html.contains("<h3>Detalle</h3>"))
        XCTAssertTrue(html.contains("<strong>negrita</strong>"))
        XCTAssertTrue(html.contains("<em>cursiva</em>"))
        XCTAssertTrue(html.contains("<code>código</code>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Primero</li>"))
        XCTAssertTrue(html.contains("<li>Segundo</li>"))
    }

    func testMarkdownEscapesHTMLSpecialChars() {
        let html = MarkdownToHTML.convert("Texto con <script> y & ampersand.")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertTrue(html.contains("&amp;"))
    }

    func testSectionsByH2SplitsByHeadings() {
        let md = """
        ## Síntesis ejecutiva

        Primera sección.

        ## Tu firma natal

        Segunda sección con **énfasis**.
        """
        let sections = MarkdownToHTML.sectionsByH2(md)
        XCTAssertNotNil(sections["sintesis_ejecutiva"])
        XCTAssertNotNil(sections["tu_firma_natal"])
        XCTAssertTrue(sections["sintesis_ejecutiva"]!.contains("Primera sección"))
        XCTAssertTrue(sections["tu_firma_natal"]!.contains("<strong>énfasis</strong>"))
    }

    func testNormalizeStripsAccentsAndPunctuation() {
        XCTAssertEqual(MarkdownToHTML.normalize("Síntesis ejecutiva"), "sintesis_ejecutiva")
        XCTAssertEqual(MarkdownToHTML.normalize("Capa lunar — lunaciones"), "capa_lunar_lunaciones")
        XCTAssertEqual(MarkdownToHTML.normalize("¿El año en curso?"), "el_ano_en_curso")
    }

    // MARK: - Builder

    func testBuilderProducesDataWithNarrativeSectionsMapped() {
        let state = sampleState()
        let narrative = sampleNarrative(markdown: """
        # Informe astrológico personal

        ## Síntesis ejecutiva

        Tema dominante: Saturno.

        ## Tu firma natal

        Sol en Libra.

        ## El año en curso

        Profección sobre casa 2.

        ## Cierre

        Cierre breve.
        """)

        let data = CrossPersonalReportBuilder.makeData(
            state: state,
            narrative: narrative,
            scope: .complete
        )

        XCTAssertTrue(data.narrative.executiveSummary.contains("Tema dominante"))
        XCTAssertTrue(data.narrative.firmaNatal.contains("Sol en Libra"))
        XCTAssertTrue(data.narrative.yearInProgress.contains("casa 2"))
        XCTAssertTrue(data.narrative.closing.contains("Cierre breve"))
        XCTAssertTrue(data.narrative.hasContent)
        XCTAssertEqual(data.header.reportTitle, "Informe cross-personal")
        XCTAssertEqual(data.scopeLabel, "Informe completo")
    }

    func testBuilderWithoutNarrativeProducesEmptySectionsButKeepsData() {
        let state = sampleState()
        let data = CrossPersonalReportBuilder.makeData(
            state: state,
            narrative: nil,
            scope: .monthly
        )
        XCTAssertFalse(data.narrative.hasContent)
        XCTAssertEqual(data.scopeLabel, "Foco mensual")
        // Datos estructurados siempre presentes
        XCTAssertFalse(data.signature.sectLabel.isEmpty)
        XCTAssertEqual(data.trazabilityRows.first?.value, "Solo datos")
    }

    func testBuilderRendersTopicsSortedByRank() {
        let state = sampleState()
        let data = CrossPersonalReportBuilder.makeData(state: state, narrative: nil, scope: .complete)
        guard data.topics.count >= 2 else { return XCTFail("Esperaba al menos 2 topics") }
        XCTAssertEqual(data.topics[0].rank, "1")
        XCTAssertEqual(data.topics[1].rank, "2")
    }

    func testTrazabilityRowsIncludeModelAndCostWhenNarrativePresent() {
        let state = sampleState()
        let narrative = sampleNarrative(markdown: "# Hola")
        let data = CrossPersonalReportBuilder.makeData(state: state, narrative: narrative, scope: .complete)
        let labels = data.trazabilityRows.map(\.label)
        XCTAssertTrue(labels.contains("Modelo"))
        XCTAssertTrue(labels.contains("Tokens entrada"))
        XCTAssertTrue(labels.contains("Coste estimado"))
    }

    // MARK: - Fixtures

    private func sampleState() -> CrossPersonalState {
        let signature = CrossNatalSignature(
            sun: SignedPlacement(key: "SOL", label: "☉ Sol", signLabel: "♎ Libra", house: 5, degree: "18°36'", retrograde: false),
            moon: SignedPlacement(key: "LUNA", label: "☽ Luna", signLabel: "♉ Tauro", house: 12, degree: "27°41'", retrograde: false),
            ascendant: AngularSummary(signLabel: "♊ Géminis", degree: "00°32'"),
            mc: AngularSummary(signLabel: "♓ Piscis", degree: "12°10'"),
            sect: SectInfo(isDiurnal: false, luminary: .luna, benefic: .venus, malefic: .marte, contrarySectBenefic: .jupiter, contrarySectMalefic: .saturno),
            ascendantRulerKey: "MERCURIO",
            ascendantRulerLabel: "☿ Mercurio",
            almutenFigurisKey: "VENUS",
            almutenFigurisLabel: "♀ Venus",
            rulerOfGenitureKey: "VENUS",
            rulerOfGenitureLabel: "♀ Venus",
            prominentLots: [
                LotSummary(kind: .fortune, signLabel: "♓ Piscis", house: 11, rulerLabel: "♃ Júpiter"),
                LotSummary(kind: .spirit, signLabel: "♏ Escorpio", house: 7, rulerLabel: "♂ Marte"),
            ],
            aspectPatterns: [
                PatternSummary(kind: "tSquare", title: "T-cuadrada", planetLabels: ["☉ Sol", "☽ Luna", "♄ Saturno"], averageOrb: 1.2)
            ],
            elementBalance: ElementBalance(fire: 1, earth: 3, air: 2, water: 4),
            modalityBalance: ModalityBalance(cardinal: 4, fixed: 3, mutable: 3),
            fixedStarContacts: [
                FixedStarSummary(starName: "Spica", targetLabel: "MC", orb: 0.4, nature: "Venus")
            ]
        )

        let saturnoSubject = CrossSubject.planet("SATURNO", label: "♄ Saturno")
        let casa2Subject = CrossSubject.house(2)

        let annualSignals = [
            CrossSignal(id: "annual.profection.2.MERCURIO", layer: .annual, source: "profection", subject: casa2Subject,
                        secondarySubjects: [], weight: 1.0, summary: "Año en casa 2; Lord of the Year: Mercurio",
                        detail: nil, startsAt: nil, endsAt: nil, exactAt: nil),
            CrossSignal(id: "annual.firdaria.major.SATURNO", layer: .annual, source: "firdaria_major", subject: saturnoSubject,
                        secondarySubjects: [], weight: 0.85, summary: "Firdaria mayor: Saturno",
                        detail: nil, startsAt: nil, endsAt: nil, exactAt: nil),
        ]
        let mediumSignals = [
            CrossSignal(id: "medium.primary.x", layer: .mediumTerm, source: "primary_direction", subject: saturnoSubject,
                        secondarySubjects: [], weight: 0.8, summary: "PD: Saturno cuadratura Sol",
                        detail: nil, startsAt: nil, endsAt: nil, exactAt: Date())
        ]
        let shortSignals = [
            CrossSignal(id: "short.transit.x", layer: .shortTerm, source: "transit", subject: saturnoSubject,
                        secondarySubjects: [], weight: 0.7, summary: "Tránsito de Saturno",
                        detail: nil, startsAt: nil, endsAt: nil, exactAt: Date())
        ]
        let lunarSignals: [CrossSignal] = []

        let topics = [
            PriorityTopic(id: "topic.planet.SATURNO", title: "Saturno como tema",
                          subject: saturnoSubject, convergenceScore: 4.2, layerCount: 3,
                          layers: [.annual, .mediumTerm, .shortTerm], signalIDs: [], summary: "3 señales · firdaria, pd, transit"),
            PriorityTopic(id: "topic.house.CASA_2", title: "Casa 2 activada",
                          subject: casa2Subject, convergenceScore: 1.5, layerCount: 1,
                          layers: [.annual], signalIDs: [], summary: "1 señal · profection"),
        ]

        return CrossPersonalState(
            metadata: CrossMetadata(
                generatedAt: Date(),
                referenceDate: Date(),
                chartID: UUID(),
                chartName: "Eduardo",
                engineVersion: CrossPersonalEngine.engineVersion
            ),
            natalSignature: signature,
            layers: [
                CrossLayer(kind: .annual, label: CrossLayerKind.annual.label, signals: annualSignals),
                CrossLayer(kind: .mediumTerm, label: CrossLayerKind.mediumTerm.label, signals: mediumSignals),
                CrossLayer(kind: .shortTerm, label: CrossLayerKind.shortTerm.label, signals: shortSignals),
                CrossLayer(kind: .lunar, label: CrossLayerKind.lunar.label, signals: lunarSignals),
            ],
            topics: topics
        )
    }

    private func sampleNarrative(markdown: String) -> CrossPersonalNarrative {
        CrossPersonalNarrative(
            markdown: markdown,
            model: "claude-sonnet-4-6",
            usage: AnthropicUsage(inputTokens: 12_000, outputTokens: 3_500, cacheCreationInputTokens: 0, cacheReadInputTokens: 8_000),
            estimatedCostUSD: 0.085,
            generatedAt: Date(),
            referenceDate: Date(),
            chartName: "Eduardo"
        )
    }
}
