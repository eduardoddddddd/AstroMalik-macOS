import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case anthropic
    case openRouter
    var id: String { rawValue }
    var label: String { self == .anthropic ? "Anthropic" : "OpenRouter" }
}

struct LLMRequest: Equatable, Sendable {
    let provider: LLMProvider
    let systemPrompt: String
    let userPayload: String
}

struct LLMResponse: Equatable, Sendable {
    let text: String
    let provider: LLMProvider
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double?
}

protocol LLMCompleting: Sendable {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

struct UnifiedLLMService: LLMCompleting {
    let anthropic: AnthropicClient
    let openRouter: OpenRouterClient

    init(anthropic: AnthropicClient = AnthropicClient(), openRouter: OpenRouterClient = OpenRouterClient()) {
        self.anthropic = anthropic
        self.openRouter = openRouter
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        switch request.provider {
        case .anthropic:
            let response = try await anthropic.send(systemPrompt: request.systemPrompt, userPayload: request.userPayload)
            return LLMResponse(
                text: response.combinedText, provider: .anthropic, model: response.model,
                inputTokens: response.usage.inputTokens, outputTokens: response.usage.outputTokens,
                estimatedCostUSD: response.usage.estimatedCostUSD(model: response.model)
            )
        case .openRouter:
            let response = try await openRouter.completeDetailed(systemPrompt: request.systemPrompt, userPrompt: request.userPayload)
            return LLMResponse(
                text: response.text, provider: .openRouter, model: response.model,
                inputTokens: response.inputTokens, outputTokens: response.outputTokens,
                estimatedCostUSD: nil
            )
        }
    }
}
