import XCTest
@testable import AstroMalik

final class CrossPersonalNarrativeBuilderTests: XCTestCase {

    func testBuilderInjectsTemplateAndSerializesState() async throws {
        let mock = MockAnthropicHTTPClient(payload: responseJSON(markdown: "## Informe\n\nTexto determinista.", inputTokens: 120, outputTokens: 80))
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        let builder = CrossPersonalNarrativeBuilder(client: client) { "TEMPLATE_TEST" }
        let state = makeMinimalState()

        setenv("ANTHROPIC_API_KEY", "test-builder-key-1234", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }

        _ = try await builder.build(state: state)

        guard let request = mock.lastRequest, let body = request.httpBody else {
            return XCTFail("No request body capturado")
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let system = try XCTUnwrap(json["system"] as? [[String: Any]])
        XCTAssertEqual(system.first?["text"] as? String, "TEMPLATE_TEST")

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let userPayload = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(userPayload.contains("Estado astrológico cross-personal"))
        XCTAssertTrue(userPayload.contains("\"reference_date\""), "El JSON debe usar snake_case")
        XCTAssertTrue(userPayload.contains("\"chart_name\""), "El JSON debe usar snake_case")
        XCTAssertTrue(userPayload.contains("\"natal_signature\""), "El JSON debe usar snake_case")
    }

    func testBuilderProducesMarkdownAndCostEstimate() async throws {
        let mock = MockAnthropicHTTPClient(payload: responseJSON(markdown: "## Síntesis\n\nContenido redactado.", inputTokens: 1_000, outputTokens: 500))
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        let builder = CrossPersonalNarrativeBuilder(client: client) { "TEMPLATE_TEST" }

        setenv("ANTHROPIC_API_KEY", "test-builder-key-cost", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }

        let narrative = try await builder.build(state: makeMinimalState())

        XCTAssertFalse(narrative.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertGreaterThan(narrative.estimatedCostUSD, 0)
    }

    func testJoplinMarkdownIncludesTrazabilityAppendix() {
        let narrative = CrossPersonalNarrative(
            markdown: "## Informe\n\nTexto.",
            model: "claude-sonnet-4-6",
            usage: AnthropicUsage(inputTokens: 100, outputTokens: 50, cacheCreationInputTokens: 0, cacheReadInputTokens: 0),
            estimatedCostUSD: 0.00105,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000),
            chartName: "Carta Test"
        )

        let markdown = narrative.joplinMarkdown()
        XCTAssertTrue(markdown.contains("Generado por AstroMalik"))
        XCTAssertTrue(markdown.contains("Modelo:"))
        XCTAssertTrue(markdown.contains("Coste estimado:"))
    }

    // MARK: - Helpers

    private func responseJSON(markdown: String, inputTokens: Int, outputTokens: Int) -> Data {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return Data("""
        {
          "id": "msg_builder_stub",
          "type": "message",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "stop_reason": "end_turn",
          "content": [{"type":"text","text":"\(escaped)"}],
          "usage": {"input_tokens": \(inputTokens), "output_tokens": \(outputTokens)}
        }
        """.utf8)
    }

    private func makeMinimalState() -> CrossPersonalState {
        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let referenceDate = Date(timeIntervalSince1970: 1_704_320_000)
        let chartID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let signal = CrossSignal(
            id: "sig-sol-casa-10",
            layer: .annual,
            source: "Test",
            subject: .planet("SOL", label: "Sol"),
            secondarySubjects: [.house(10)],
            weight: 1.2,
            summary: "Sol activa casa 10",
            detail: "Detalle de prueba",
            startsAt: nil,
            endsAt: nil,
            exactAt: referenceDate
        )
        let topic = PriorityTopic(
            id: "topic-sol",
            title: "Vocación y visibilidad",
            subject: .planet("SOL", label: "Sol"),
            convergenceScore: 2.4,
            layerCount: 1,
            layers: [.annual],
            signalIDs: [signal.id],
            summary: "Tema prioritario de prueba"
        )
        return CrossPersonalState(
            metadata: CrossMetadata(
                generatedAt: generatedAt,
                referenceDate: referenceDate,
                chartID: chartID,
                chartName: "Carta Test",
                engineVersion: "test"
            ),
            natalSignature: CrossNatalSignature(
                sun: SignedPlacement(key: "SOL", label: "Sol", signLabel: "Aries", house: 10, degree: "10° Aries", retrograde: false),
                moon: SignedPlacement(key: "LUNA", label: "Luna", signLabel: "Tauro", house: 11, degree: "12° Tauro", retrograde: false),
                ascendant: AngularSummary(signLabel: "Cáncer", degree: "01° Cáncer"),
                mc: AngularSummary(signLabel: "Piscis", degree: "15° Piscis"),
                sect: SectInfo(isDiurnal: true, luminary: .sol, benefic: .jupiter, malefic: .saturno, contrarySectBenefic: .venus, contrarySectMalefic: .marte),
                ascendantRulerKey: "LUNA",
                ascendantRulerLabel: "Luna",
                almutenFigurisKey: "SOL",
                almutenFigurisLabel: "Sol",
                rulerOfGenitureKey: "JUPITER",
                rulerOfGenitureLabel: "Júpiter",
                prominentLots: [LotSummary(kind: .fortune, signLabel: "Leo", house: 2, rulerLabel: "Sol")],
                aspectPatterns: [PatternSummary(kind: "trine", title: "Gran trígono", planetLabels: ["Sol", "Luna", "Júpiter"], averageOrb: 2.1)],
                elementBalance: ElementBalance(fire: 3, earth: 2, air: 1, water: 4),
                modalityBalance: ModalityBalance(cardinal: 4, fixed: 3, mutable: 3),
                fixedStarContacts: [FixedStarSummary(starName: "Regulus", targetLabel: "ASC", orb: 0.4, nature: "Marte/Júpiter")]
            ),
            layers: [
                CrossLayer(kind: .annual, label: CrossLayerKind.annual.label, signals: [signal]),
                CrossLayer(kind: .mediumTerm, label: CrossLayerKind.mediumTerm.label, signals: []),
                CrossLayer(kind: .shortTerm, label: CrossLayerKind.shortTerm.label, signals: []),
                CrossLayer(kind: .lunar, label: CrossLayerKind.lunar.label, signals: [])
            ],
            topics: [topic]
        )
    }
}
