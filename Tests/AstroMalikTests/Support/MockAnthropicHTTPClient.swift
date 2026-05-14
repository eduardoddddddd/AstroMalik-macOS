import Foundation
@testable import AstroMalik

final class MockAnthropicHTTPClient: AnthropicHTTPClient, @unchecked Sendable {
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

extension AnthropicClient.Config {
    static func isolatedForTests() -> AnthropicClient.Config {
        var config = AnthropicClient.Config.default
        config.keychainService = "com.astromalik.anthropic.tests.\(UUID().uuidString)"
        return config
    }
}
