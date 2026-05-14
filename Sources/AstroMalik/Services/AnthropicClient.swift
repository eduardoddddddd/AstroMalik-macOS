import Foundation
import Security

// MARK: - HTTP Client Protocol

protocol AnthropicHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AnthropicHTTPClient {}

// MARK: - Errors

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int, String)
    case decodingError(String)
    case emptyResponse
    case unauthorized
    case rateLimited
    case overloaded
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Falta la API key de Anthropic. Defínela en Keychain (servicio com.astromalik.anthropic) o en la variable de entorno ANTHROPIC_API_KEY."
        case .invalidResponse:
            return "Respuesta no reconocible de la API de Anthropic."
        case .httpError(let code, let body):
            return "Anthropic HTTP \(code): \(body)"
        case .decodingError(let detail):
            return "Error decodificando respuesta de Anthropic: \(detail)"
        case .emptyResponse:
            return "Anthropic no devolvió contenido."
        case .unauthorized:
            return "API key de Anthropic rechazada (401). Revisa la key o regenérala en console.anthropic.com."
        case .rateLimited:
            return "Anthropic está limitando el ritmo de llamadas (429). Espera antes de reintentar."
        case .overloaded:
            return "Anthropic sobrecargado (529). Reintenta más tarde."
        case .keychainError(let status):
            return "Error de Keychain: \(status)."
        }
    }
}

// MARK: - Credential Source

enum AnthropicCredentialSource: String, Codable {
    case keychain
    case environment
}

// MARK: - Request / Response Models

struct AnthropicCacheControl: Codable, Equatable {
    let type: String
    static let ephemeral = AnthropicCacheControl(type: "ephemeral")
}

struct AnthropicSystemBlock: Codable, Equatable {
    var type: String
    var text: String
    var cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case cacheControl = "cache_control"
    }
}

struct AnthropicMessage: Codable, Equatable {
    var role: String
    var content: String
}

struct AnthropicMessageRequest: Codable, Equatable {
    var model: String
    var maxTokens: Int
    var system: [AnthropicSystemBlock]
    var messages: [AnthropicMessage]
    var temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case temperature
    }
}

struct AnthropicContentBlock: Codable, Equatable {
    var type: String
    var text: String?
}

struct AnthropicUsage: Codable, Equatable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheCreationInputTokens: Int?
    var cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    /// Coste estimado en USD para Sonnet 4.6.
    /// Input estándar $3/M, cache hit $0.30/M, cache write $3.75/M, output $15/M.
    func estimatedCostUSD(model: String) -> Double {
        let pricing = AnthropicPricing.forModel(model)
        let cacheRead = Double(cacheReadInputTokens ?? 0) * pricing.cacheReadUSDPerMillionTokens / 1_000_000
        let cacheWrite = Double(cacheCreationInputTokens ?? 0) * pricing.cacheWriteUSDPerMillionTokens / 1_000_000
        let inputNonCached = Double(inputTokens) * pricing.inputUSDPerMillionTokens / 1_000_000
        let output = Double(outputTokens) * pricing.outputUSDPerMillionTokens / 1_000_000
        return cacheRead + cacheWrite + inputNonCached + output
    }
}

struct AnthropicMessageResponse: Codable, Equatable {
    var id: String
    var type: String
    var role: String
    var content: [AnthropicContentBlock]
    var model: String
    var stopReason: String?
    var usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    /// Concatena los bloques de texto del response.
    var combinedText: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined(separator: "\n\n")
    }
}

// MARK: - Pricing

struct AnthropicPricing {
    let inputUSDPerMillionTokens: Double
    let cacheReadUSDPerMillionTokens: Double
    let cacheWriteUSDPerMillionTokens: Double
    let outputUSDPerMillionTokens: Double

    static let sonnet46 = AnthropicPricing(
        inputUSDPerMillionTokens: 3.0,
        cacheReadUSDPerMillionTokens: 0.30,
        cacheWriteUSDPerMillionTokens: 3.75,
        outputUSDPerMillionTokens: 15.0
    )

    static let opus47 = AnthropicPricing(
        inputUSDPerMillionTokens: 15.0,
        cacheReadUSDPerMillionTokens: 1.50,
        cacheWriteUSDPerMillionTokens: 18.75,
        outputUSDPerMillionTokens: 75.0
    )

    static let haiku45 = AnthropicPricing(
        inputUSDPerMillionTokens: 1.0,
        cacheReadUSDPerMillionTokens: 0.10,
        cacheWriteUSDPerMillionTokens: 1.25,
        outputUSDPerMillionTokens: 5.0
    )

    static func forModel(_ model: String) -> AnthropicPricing {
        if model.contains("opus") { return .opus47 }
        if model.contains("haiku") { return .haiku45 }
        return .sonnet46
    }
}

// MARK: - Client

/// Cliente HTTP para la API de Anthropic Messages.
/// API key: Keychain (servicio com.astromalik.anthropic) → variable ANTHROPIC_API_KEY.
/// NUNCA en código fuente, NUNCA escrita a disco dentro del repo.
actor AnthropicClient {

    struct Config: Sendable {
        var model: String
        var temperature: Double?
        var maxTokens: Int
        var timeoutSeconds: Double
        var keychainService: String
        var keychainAccount: String
        var environmentVariableName: String
        var anthropicVersion: String

        static let `default` = Config(
            model: "claude-sonnet-4-6",
            temperature: 0.4,
            maxTokens: 4096,
            timeoutSeconds: 120,
            keychainService: "com.astromalik.anthropic",
            keychainAccount: "api_key",
            environmentVariableName: "ANTHROPIC_API_KEY",
            anthropicVersion: "2023-06-01"
        )

        static let opusLong = Config(
            model: "claude-opus-4-7",
            temperature: 0.4,
            maxTokens: 8000,
            timeoutSeconds: 240,
            keychainService: "com.astromalik.anthropic",
            keychainAccount: "api_key",
            environmentVariableName: "ANTHROPIC_API_KEY",
            anthropicVersion: "2023-06-01"
        )
    }

    private let httpClient: AnthropicHTTPClient
    private var config: Config
    nonisolated private let keychainService: String
    nonisolated private let keychainAccount: String
    nonisolated private let environmentVariableName: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(config: Config = .default, httpClient: AnthropicHTTPClient = URLSession.shared) {
        self.config = config
        self.httpClient = httpClient
        self.keychainService = config.keychainService
        self.keychainAccount = config.keychainAccount
        self.environmentVariableName = config.environmentVariableName
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    // MARK: - Configuration

    func setModel(_ model: String) {
        self.config.model = model
    }

    func currentConfig() -> Config { config }

    // MARK: - API Key Resolution

    func resolveAPIKey() throws -> String {
        if let key = readFromKeychain() { return key }
        if let key = ProcessInfo.processInfo.environment[environmentVariableName],
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        throw AnthropicError.missingAPIKey
    }

    nonisolated func credentialSource() -> AnthropicCredentialSource? {
        if readFromKeychain() != nil { return .keychain }
        if let key = ProcessInfo.processInfo.environment[environmentVariableName],
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .environment
        }
        return nil
    }

    nonisolated func hasAPIKey() -> Bool { credentialSource() != nil }

    /// Devuelve los 4 últimos caracteres de la key para mostrarlos en UI sin filtrar.
    nonisolated func maskedKeyTail() -> String? {
        if let key = readFromKeychain() ?? ProcessInfo.processInfo.environment[environmentVariableName],
           key.count > 4 {
            return String(key.suffix(4))
        }
        return nil
    }

    nonisolated func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: keychainService,
                kSecAttrAccount: keychainAccount,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw AnthropicError.keychainError(status)
        }
    }

    nonisolated func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Messages

    /// Envía una petición a la Messages API con prompt caching del system prompt.
    /// - Parameters:
    ///   - systemPrompt: bloque fijo (instrucciones del astrólogo). Se marca cacheable.
    ///   - userPayload: contenido variable (estado astrológico serializado).
    /// - Returns: respuesta completa con usage y coste estimado.
    func send(
        systemPrompt: String,
        userPayload: String
    ) async throws -> AnthropicMessageResponse {
        let apiKey = try resolveAPIKey()
        let body = AnthropicMessageRequest(
            model: config.model,
            maxTokens: config.maxTokens,
            system: [
                AnthropicSystemBlock(
                    type: "text",
                    text: systemPrompt,
                    cacheControl: .ephemeral
                )
            ],
            messages: [
                AnthropicMessage(role: "user", content: userPayload)
            ],
            temperature: config.temperature
        )

        let url = baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url, timeoutInterval: config.timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(config.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "user-agent")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(AnthropicMessageResponse.self, from: data)
            } catch {
                throw AnthropicError.decodingError(error.localizedDescription)
            }
        case 401:
            throw AnthropicError.unauthorized
        case 429:
            throw AnthropicError.rateLimited
        case 529:
            throw AnthropicError.overloaded
        case let code:
            let body = String(data: data, encoding: .utf8) ?? "<vacío>"
            throw AnthropicError.httpError(code, body)
        }
    }

    // MARK: - Private

    private nonisolated func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return key
    }
}
