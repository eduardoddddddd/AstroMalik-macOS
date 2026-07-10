import Foundation

struct RectificationNarrative: Codable, Equatable {
    let markdown: String
    let provider: LLMProvider
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double?
    let generatedAt: Date
}

enum RectificationNarrativeError: LocalizedError {
    case missingTemplate
    case encoding(String)
    var errorDescription: String? {
        switch self {
        case .missingTemplate: return "No se encontró rectification_prompt.md."
        case .encoding(let detail): return "No se pudo serializar el análisis: \(detail)"
        }
    }
}

struct RectificationNarrativeBuilder {
    let service: any LLMCompleting
    let templateLoader: () throws -> String

    init(
        service: any LLMCompleting = UnifiedLLMService(),
        templateLoader: @escaping () throws -> String = {
            guard let url = AppResources.bundle.url(forResource: "rectification_prompt", withExtension: "md") else {
                throw RectificationNarrativeError.missingTemplate
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
    ) {
        self.service = service
        self.templateLoader = templateLoader
    }

    func build(result: RectificationAnalysisResult, session: RectificationSession, provider: LLMProvider) async throws -> RectificationNarrative {
        let prompt = try templateLoader()
        let payload = try makePayload(result: result, session: session)
        let response = try await service.complete(.init(provider: provider, systemPrompt: prompt, userPayload: payload))
        return RectificationNarrative(
            markdown: response.text, provider: response.provider, model: response.model,
            inputTokens: response.inputTokens, outputTokens: response.outputTokens,
            estimatedCostUSD: response.estimatedCostUSD, generatedAt: Date()
        )
    }

    func makePayload(result: RectificationAnalysisResult, session: RectificationSession) throws -> String {
        let payload = RectificationNarrativePayload(
            schemaVersion: 1,
            disclaimer: "Hipótesis astrológica; no sustituye documentación oficial.",
            sessionName: session.name,
            reportedBirthTime: session.reportedBirthTime,
            events: session.events,
            overallConfidence: result.overallConfidence,
            warnings: result.warnings,
            candidates: result.candidates.prefix(5).map { candidate in
                .init(
                    birthTime: candidate.birthTime, score: candidate.totalScore,
                    ascendant: candidate.ascendantFormatted, mc: candidate.mcFormatted,
                    techniqueScores: candidate.techniqueScores,
                    eventScores: candidate.eventScores,
                    evidence: Array(candidate.evidence.prefix(12))
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        do {
            let data = try encoder.encode(payload)
            guard let json = String(data: data, encoding: .utf8) else { throw RectificationNarrativeError.encoding("UTF-8") }
            return "Análisis determinista de rectificación (JSON):\n\(json)"
        } catch let error as RectificationNarrativeError { throw error }
        catch { throw RectificationNarrativeError.encoding(error.localizedDescription) }
    }
}

private struct RectificationNarrativePayload: Codable {
    let schemaVersion: Int
    let disclaimer: String
    let sessionName: String
    let reportedBirthTime: String
    let events: [RectificationEvent]
    let overallConfidence: RectificationConfidenceBand
    let warnings: [String]
    let candidates: [Candidate]

    struct Candidate: Codable {
        let birthTime: String
        let score: Double
        let ascendant: String
        let mc: String
        let techniqueScores: [RectificationTechnique: Double]
        let eventScores: [UUID: Double]
        let evidence: [RectificationEvidence]
    }
}
