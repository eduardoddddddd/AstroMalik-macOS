import XCTest
@testable import AstroMalik

final class RectificationNarrativeBuilderTests: XCTestCase {
    func testPayloadIsVersionedCompactAndContainsNoFullChart() throws {
        let fixture = makeFixture()
        let builder = RectificationNarrativeBuilder(service: MockLLMService()) { "PROMPT" }
        let payload = try builder.makePayload(result: fixture.result, session: fixture.session)
        XCTAssertTrue(payload.contains("\"schema_version\":1"))
        XCTAssertTrue(payload.contains("\"candidates\""))
        XCTAssertFalse(payload.contains("\"bodies\""))
        XCTAssertTrue(payload.contains("Hipótesis astrológica"))
    }

    func testBuilderUsesSelectedProviderAndReturnsTraceability() async throws {
        let fixture = makeFixture()
        let mock = MockLLMService()
        let builder = RectificationNarrativeBuilder(service: mock) { "NO INVENTAR CÁLCULOS" }
        let narrative = try await builder.build(result: fixture.result, session: fixture.session, provider: .openRouter)
        XCTAssertEqual(narrative.provider, .openRouter)
        XCTAssertEqual(narrative.model, "mock-model")
        XCTAssertEqual(narrative.inputTokens, 123)
        XCTAssertTrue(narrative.markdown.contains("Comparación"))
        let request = await mock.request
        XCTAssertEqual(request?.systemPrompt, "NO INVENTAR CÁLCULOS")
        XCTAssertEqual(request?.provider, .openRouter)
    }

    private func makeFixture() -> (session: RectificationSession, result: RectificationAnalysisResult) {
        let event = RectificationEvent(type: .careerStart, title: "Trabajo", dateStart: Date(timeIntervalSince1970: 1_600_000_000), precision: .exactDay)
        let session = RectificationSession(name: "Test", birthDate: "1980-01-01", reportedBirthTime: "12:00", timezone: "UTC", latitude: 0, longitude: 0, placeName: "Test", searchRange: .init(centerTime: "12:00"), events: [event])
        let chart = NatalChart.placeholder
        let candidate = RectificationCandidate(id: UUID(), birthTime: "12:01:00", chart: chart, ascendantLongitude: 0, mcLongitude: 90, ascendantFormatted: "Aries", mcFormatted: "Cáncer", totalScore: 42, confidenceBand: .medium, techniqueScores: [.solarArc: 42], eventScores: [event.id: 42], evidence: [], warnings: [])
        let result = RectificationAnalysisResult(schemaVersion: 1, sessionID: session.id, candidates: [candidate], topCandidate: candidate, overallConfidence: .medium, clusters: [], eventCoverage: [event.id: 1], sectCrossingDetected: false, warnings: [], analysisDate: Date(), configUsed: .default, computeTimeSeconds: 1)
        return (session, result)
    }
}

private actor MockLLMService: LLMCompleting {
    private(set) var request: LLMRequest?
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        self.request = request
        return LLMResponse(text: "## Comparación", provider: request.provider, model: "mock-model", inputTokens: 123, outputTokens: 45, estimatedCostUSD: nil)
    }
}
