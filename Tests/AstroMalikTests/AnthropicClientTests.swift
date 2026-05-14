import XCTest
@testable import AstroMalik

final class AnthropicClientTests: XCTestCase {

    // MARK: - Pricing

    func testSonnetPricingMatchesPublicSchedule() {
        let usage = AnthropicUsage(
            inputTokens: 1_000_000,
            outputTokens: 0,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0
        )
        XCTAssertEqual(usage.estimatedCostUSD(model: "claude-sonnet-4-6"), 3.0, accuracy: 0.0001)
    }

    func testOpusPricingMatchesPublicSchedule() {
        let usage = AnthropicUsage(
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0
        )
        let cost = usage.estimatedCostUSD(model: "claude-opus-4-7")
        XCTAssertEqual(cost, 15.0 + 75.0, accuracy: 0.0001)
    }

    func testCacheReadReducesCost() {
        let withoutCache = AnthropicUsage(inputTokens: 1_000_000, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
        let withCache = AnthropicUsage(inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 1_000_000)
        XCTAssertLessThan(
            withCache.estimatedCostUSD(model: "claude-sonnet-4-6"),
            withoutCache.estimatedCostUSD(model: "claude-sonnet-4-6")
        )
    }

    // MARK: - Request envelope

    func testRequestIncludesPromptCachingOnSystemBlock() async throws {
        let mock = MockAnthropicClient(payload: stubResponseJSON())
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)

        // Inyectamos clave por variable de entorno temporal del test
        setenv("ANTHROPIC_API_KEY", "sk-ant-test-key-1234", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }

        _ = try await client.send(systemPrompt: "INSTRUCTIONS", userPayload: "PAYLOAD")

        guard let request = mock.lastRequest, let body = request.httpBody else {
            return XCTFail("No request body capturado")
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
        let systemArray = try XCTUnwrap(json["system"] as? [[String: Any]])
        XCTAssertEqual(systemArray.count, 1)
        XCTAssertEqual(systemArray[0]["text"] as? String, "INSTRUCTIONS")
        let cache = try XCTUnwrap(systemArray[0]["cache_control"] as? [String: Any])
        XCTAssertEqual(cache["type"] as? String, "ephemeral")

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "PAYLOAD")
    }

    func testRequestUsesAnthropicVersionHeaderAndXApiKey() async throws {
        let mock = MockAnthropicClient(payload: stubResponseJSON())
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        setenv("ANTHROPIC_API_KEY", "sk-ant-test-key-5678", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }

        _ = try await client.send(systemPrompt: "x", userPayload: "y")

        guard let request = mock.lastRequest else { return XCTFail("No request capturado") }
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test-key-5678")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Error mapping

    func testHTTP401IsMappedToUnauthorized() async {
        let mock = MockAnthropicClient(statusCode: 401, payload: Data(#"{"error":"unauthorized"}"#.utf8))
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        setenv("ANTHROPIC_API_KEY", "sk-ant-test-key-401", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }
        do {
            _ = try await client.send(systemPrompt: "x", userPayload: "y")
            XCTFail("Esperaba unauthorized")
        } catch AnthropicError.unauthorized {
            // OK
        } catch {
            XCTFail("Tipo de error inesperado: \(error)")
        }
    }

    func testHTTP429IsMappedToRateLimited() async {
        let mock = MockAnthropicClient(statusCode: 429, payload: Data(#"{"error":"rate_limited"}"#.utf8))
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        setenv("ANTHROPIC_API_KEY", "sk-ant-test-key-429", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }
        do {
            _ = try await client.send(systemPrompt: "x", userPayload: "y")
            XCTFail("Esperaba rateLimited")
        } catch AnthropicError.rateLimited {
            // OK
        } catch {
            XCTFail("Tipo de error inesperado: \(error)")
        }
    }

    func testMissingAPIKeyThrows() async {
        let mock = MockAnthropicClient(payload: stubResponseJSON())
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        unsetenv("ANTHROPIC_API_KEY")
        // Sin Keychain (test puro): debe fallar.
        do {
            _ = try await client.send(systemPrompt: "x", userPayload: "y")
            XCTFail("Esperaba missingAPIKey")
        } catch AnthropicError.missingAPIKey {
            // OK
        } catch {
            XCTFail("Tipo de error inesperado: \(error)")
        }
    }

    // MARK: - Response parsing

    func testResponseCombinesTextBlocks() async throws {
        let mock = MockAnthropicClient(payload: Data("""
        {
          "id": "msg_test",
          "type": "message",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "stop_reason": "end_turn",
          "content": [
            {"type":"text","text":"Hola"},
            {"type":"text","text":"mundo"}
          ],
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """.utf8))
        let client = AnthropicClient(config: .isolatedForTests(), httpClient: mock)
        setenv("ANTHROPIC_API_KEY", "sk-ant-test-combine", 1)
        defer { unsetenv("ANTHROPIC_API_KEY") }

        let response = try await client.send(systemPrompt: "x", userPayload: "y")
        XCTAssertEqual(response.combinedText, "Hola\n\nmundo")
        XCTAssertEqual(response.usage.inputTokens, 10)
        XCTAssertEqual(response.usage.outputTokens, 5)
    }

    // MARK: - Helpers

    private func stubResponseJSON() -> Data {
        Data("""
        {
          "id": "msg_stub",
          "type": "message",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "stop_reason": "end_turn",
          "content": [{"type":"text","text":"OK"}],
          "usage": {"input_tokens": 1, "output_tokens": 1}
        }
        """.utf8)
    }
}

// MARK: - Mock HTTP

private final class MockAnthropicClient: AnthropicHTTPClient, @unchecked Sendable {
    let statusCode: Int
    let payload: Data
    private(set) var lastRequest: URLRequest?

    init(statusCode: Int = 200, payload: Data) {
        self.statusCode = statusCode
        self.payload = payload
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.anthropic.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (payload, response)
    }
}
