import Foundation
import Security

// MARK: - OpenRouter HTTP Client Protocol

/// Protocolo de abstracción sobre URLSession para facilitar tests con mock.
/// Mismo patrón que JoplinHTTPClient en JoplinClipperService.swift.
protocol OpenRouterHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: OpenRouterHTTPClient {}

// MARK: - OpenRouter Client

/// Cliente HTTP para la API de OpenRouter (https://openrouter.ai/api/v1).
/// La API key se obtiene en orden: Keychain → variable de entorno.
/// NUNCA se incluye hardcoded en el código fuente.
///
/// Concurrencia: actor para serializar acceso al estado mutable (model, timeout).
actor OpenRouterClient {

    // MARK: - Configuration

    struct Config: Sendable {
        /// Modelo a usar. Preferir modelos con soporte de JSON mode.
        /// Default: claude-sonnet-4-5 vía OpenRouter.
        var model: String
        /// Temperatura (0.0 = determinista, 1.0 = creativo). Default 0.3 para astrología.
        var temperature: Double
        /// Tokens máximos en la respuesta.
        var maxTokens: Int
        /// Timeout de la request en segundos.
        var timeoutSeconds: Double
        /// Nombre del servicio en Keychain.
        var keychainService: String
        /// Cuenta dentro del servicio de Keychain.
        var keychainAccount: String
        /// Variable de entorno de fallback.
        var environmentVariableName: String

        static let `default` = Config(
            model: "anthropic/claude-sonnet-4-5",
            temperature: 0.3,
            maxTokens: 1200,
            timeoutSeconds: 30,
            keychainService: "com.astromalik.openrouter",
            keychainAccount: "api_key",
            environmentVariableName: "OPENROUTER_API_KEY"
        )
    }

    // MARK: - State

    private let httpClient: OpenRouterHTTPClient
    private let config: Config
    nonisolated private let keychainService: String
    nonisolated private let keychainAccount: String
    nonisolated private let environmentVariableName: String
    private let baseURL = URL(string: "https://openrouter.ai/api/v1")!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Init

    init(config: Config = .default, httpClient: OpenRouterHTTPClient = URLSession.shared) {
        self.config = config
        self.httpClient = httpClient
        self.keychainService = config.keychainService
        self.keychainAccount = config.keychainAccount
        self.environmentVariableName = config.environmentVariableName
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    // MARK: - API Key Management

    /// Recupera la API key. Orden: Keychain → env var.
    /// Lanza `OpenRouterError.missingAPIKey` si no se encuentra en ningún sitio.
    func resolveAPIKey() throws -> String {
        // 1. Intentar Keychain
        if let key = readFromKeychain() {
            return key
        }
        // 2. Fallback a variable de entorno (útil para CI y desarrollo local)
        if let key = ProcessInfo.processInfo.environment[environmentVariableName],
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        throw OpenRouterError.missingAPIKey
    }

    /// Devuelve la fuente efectiva de la key de runtime.
    nonisolated func credentialSource() -> OpenRouterCredentialSource? {
        if readFromKeychain() != nil {
            return .keychain
        }
        if let key = ProcessInfo.processInfo.environment[environmentVariableName],
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .environment
        }
        return nil
    }

    /// Guarda la API key en el Keychain del usuario (acceso solo para esta app).
    /// Llamar desde Settings cuando el usuario introduce la key por primera vez.
    nonisolated func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        // Intentar actualizar primero
        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)

        if status == errSecItemNotFound {
            // No existe: crear nueva entrada
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
            throw OpenRouterError.keychainError(status)
        }
    }

    /// Elimina la API key del Keychain.
    nonisolated func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// True si hay una API key disponible (Keychain o env var).
    nonisolated func hasAPIKey() -> Bool {
        if readFromKeychain() != nil { return true }
        if let key = ProcessInfo.processInfo.environment[environmentVariableName],
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    /// Valida la key actualmente resoluble contra OpenRouter.
    func validateCurrentKey() async throws -> OpenRouterKeyValidation {
        let apiKey = try resolveAPIKey()
        let url = baseURL.appendingPathComponent("key")
        var request = URLRequest(url: url, timeoutInterval: config.timeoutSeconds)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://astromalik.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "X-Title")

        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            let payload = try decoder.decode(KeyValidationEnvelope.self, from: data)
            guard payload.data?.isOk == true, let info = payload.data else {
                throw OpenRouterError.invalidResponse
            }
            return OpenRouterKeyValidation(
                label: Self.sanitizeLabel(info.label),
                usage: info.usage,
                limit: info.limit,
                limitRemaining: info.limitRemaining,
                isFreeTier: info.isFreeTier,
                isProvisioningKey: info.isProvisioningKey
            )
        case 401:
            throw OpenRouterError.unauthorized
        case 429:
            throw OpenRouterError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? "<vacío>"
            throw OpenRouterError.httpError(http.statusCode, body)
        }
    }

    // MARK: - Core Completion

    /// Envía un prompt al LLM y devuelve el texto de respuesta crudo.
    /// - Parameters:
    ///   - systemPrompt: Instrucciones del sistema (doctrina morinista).
    ///   - userPrompt: Datos específicos de la dirección a interpretar.
    /// - Returns: Texto de respuesta del LLM (JSON estructurado esperado).
    func complete(systemPrompt: String, userPrompt: String) async throws -> String {
        let apiKey = try resolveAPIKey()

        let requestBody = ChatCompletionRequest(
            model: config.model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user",   content: userPrompt)
            ],
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            responseFormat: .init(type: "json_object")
        )

        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url, timeoutInterval: config.timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)",        forHTTPHeaderField: "Authorization")
        urlRequest.setValue("https://astromalik.app", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "X-Title")
        urlRequest.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await httpClient.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw OpenRouterError.unauthorized
        case 429:
            throw OpenRouterError.rateLimited
        case let code:
            let body = String(data: data, encoding: .utf8) ?? "<vacío>"
            throw OpenRouterError.httpError(code, body)
        }

        let completion = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw OpenRouterError.emptyResponse
        }
        return content
    }

    // MARK: - Private Keychain helper

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

    private static func sanitizeLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 10 else { return trimmed }
        let prefix = trimmed.prefix(10)
        let suffix = trimmed.suffix(4)
        if trimmed.contains("...") {
            return trimmed
        }
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Request / Response Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
    }
}

private struct KeyValidationEnvelope: Decodable {
    let data: KeyValidationData?

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

private struct KeyValidationData: Decodable {
    let label: String
    let usage: Double
    let limit: Double
    let limitRemaining: Double
    let isFreeTier: Bool
    let isProvisioningKey: Bool
    let isOk: Bool

    private enum CodingKeys: String, CodingKey {
        case label
        case usage
        case limit
        case limitRemaining = "limit_remaining"
        case isFreeTier = "is_free_tier"
        case isProvisioningKey = "is_provisioning_key"
        case isOk = "is_ok"
    }
}

enum OpenRouterCredentialSource: String, Sendable {
    case keychain = "Keychain"
    case environment = "OPENROUTER_API_KEY"

    var label: String { rawValue }
}

struct OpenRouterKeyValidation: Equatable, Sendable {
    let label: String
    let usage: Double
    let limit: Double
    let limitRemaining: Double
    let isFreeTier: Bool
    let isProvisioningKey: Bool
}

// MARK: - Errors

enum OpenRouterError: LocalizedError, Equatable {
    case missingAPIKey
    case keychainError(OSStatus)
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int, String)
    case emptyResponse
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No se encontró la API key de OpenRouter. Configúrala en Ajustes o en la variable de entorno OPENROUTER_API_KEY."
        case .keychainError(let status):
            return "Error de Keychain al guardar la API key (OSStatus \(status))."
        case .invalidResponse:
            return "OpenRouter devolvió una respuesta inválida."
        case .unauthorized:
            return "API key de OpenRouter inválida o expirada (401). Revisa la key en Ajustes."
        case .rateLimited:
            return "Límite de peticiones de OpenRouter alcanzado (429). Espera un momento."
        case .httpError(let code, let body):
            return "OpenRouter respondió con HTTP \(code): \(body.prefix(200))"
        case .emptyResponse:
            return "OpenRouter devolvió una respuesta vacía."
        case .decodingError(let detail):
            return "No se pudo decodificar la respuesta del LLM: \(detail)"
        }
    }

    // Equatable manual para los casos con String
    static func == (lhs: OpenRouterError, rhs: OpenRouterError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.rateLimited, .rateLimited),
             (.emptyResponse, .emptyResponse): return true
        case (.keychainError(let a), .keychainError(let b)): return a == b
        case (.httpError(let a, _), .httpError(let b, _)):   return a == b
        case (.decodingError(let a), .decodingError(let b)): return a == b
        default: return false
        }
    }
}
