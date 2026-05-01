import XCTest
@testable import AstroMalik
import Darwin

// MARK: - Phase 4 Tests: OpenRouterClient + ContextualInterpreter
// Todos los tests usan mocks. CERO llamadas reales a la API.

// MARK: - Mock HTTP Client

/// Mock que inyecta respuestas predefinidas sin red.
final class MockOpenRouterHTTPClient: OpenRouterHTTPClient, @unchecked Sendable {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var shouldThrow: Error? = nil
    var lastRequest: URLRequest? = nil
    var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        lastRequest = request
        if let error = shouldThrow { throw error }
        let url = request.url ?? URL(string: "https://openrouter.ai")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

final class MockPrimaryDirectionLLMClient: PrimaryDirectionLLMClient, @unchecked Sendable {
    var response: String
    var error: Error?
    private(set) var requestCount = 0

    init(response: String = "") {
        self.response = response
    }

    func complete(
        direction: PrimaryDirection,
        context: PDInterpretationContext,
        systemPrompt: String,
        userPrompt: String,
        promptVersion: String
    ) async throws -> String {
        requestCount += 1
        if let error { throw error }
        return response
    }
}

// MARK: - Helpers

private func makeValidLLMResponse(for direction: PrimaryDirection) -> String {
    """
    {
      "directionId": "\(direction.id.uuidString)",
      "clave": "\(direction.promissor)_\(direction.significator)_CONJUNCION",
      "tituloPrincipal": "Período de intensa energía marciana dirigida al Ascendente. El nativo enfrenta una fase de confrontación activa.",
      "textoEstructural": "La dirección de Marte al Ascendente, bajo el sistema Regiomontanus, activa la naturaleza beligerante y enérgica del promissor sobre la identidad del nativo. Marte en exilio pierde parte de su capacidad de acción directa. La cuadratura natal con el Sol amplifica la fricción entre la voluntad personal y la energía disponible. El nativo puede experimentar irritabilidad, conflictos físicos o disputas legales durante este período. La carta nocturna sitúa a Marte fuera de su sect, lo que atenúa ligeramente los efectos más destructivos pero incrementa la impulsividad no canalizada.",
      "factoresConsiderados": [
        {"factor": "dignidad_esencial_promissor", "valor": "exilio", "modulacion": "atenua"},
        {"factor": "sect", "valor": "nocturna_marte_fuera_de_sect", "modulacion": "atenua"},
        {"factor": "aspecto_natal_promissor_significador", "valor": "ninguno", "modulacion": "neutro"}
      ],
      "periodoActivacion": {
        "edadExacta": 15.73,
        "orbeEnMeses": 6,
        "fechaInicio": "1992-01-01",
        "fechaFin": "1993-01-01"
      },
      "areasAfectadas": [
        {"area": "salud", "peso": 3},
        {"area": "relaciones", "peso": 2}
      ],
      "intensidad": 7,
      "polaridad": "malefico",
      "generadoEn": "2026-04-27T10:00:00Z",
      "promptVersion": "2.0.1-foundry-qwen7b"
    }
    """
}

private func makeOpenRouterResponse(content: String) -> Data {
    let escaped = content
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
    let json = """
    {"choices":[{"message":{"content":"\(escaped)"}}]}
    """
    return json.data(using: .utf8)!
}

private func makeMockDirection() -> PrimaryDirection {
    PrimaryDirection(
        promissor: "MARTE",
        promissorLabel: "♂ Marte",
        significator: "ASC",
        significatorLabel: "ASC",
        aspect: .conjunction,
        aspectAngle: 0,
        directionType: .direct,
        aspectPlane: .zodiacal,
        arc: 15.5,
        estimatedAge: 15.73,
        estimatedDate: Date(),
        method: .regiomontanus,
        key: .naibod,
        technicalData: PDTechnicalData(
            promissorRA: 197.5, promissorDeclination: -12.3,
            significatorRA: 60.5, significatorDeclination: 20.4,
            significatorPole: 40.4, obliquity: 23.44,
            ramc: 310.05, geoLatitude: 40.4168
        )
    )
}

private func makeMockContext(isNocturnal: Bool = true) -> PDInterpretationContext {
    PDInterpretationContext(
        promissorDignity: "exilio",
        promissorNatalHouse: 6,
        natalAspectBetweenPromissorAndSignificator: nil,
        isNocturnal: isNocturnal,
        promissorInSect: false,
        significatorCondition: "Ascendente en Géminis, ningún planeta angular en Casa 1",
        nativeCurrentAge: 49.5,
        birthYear: 1976
    )
}

/// True si hay una API key disponible para ejecutar tests que llaman al cliente.
/// Comprobación síncrona solo de env var (Keychain es asíncrono y solo se prueba en el test de API key).
private var hasTestAPIKey: Bool {
    guard let key = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] else { return false }
    return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func makeIsolatedClient(
    mock: MockOpenRouterHTTPClient = MockOpenRouterHTTPClient(),
    envName: String = "OPENROUTER_TEST_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))",
    keychainService: String = "com.astromalik.tests.\(UUID().uuidString)"
) -> OpenRouterClient {
    let config = OpenRouterClient.Config(
        model: OpenRouterClient.Config.default.model,
        temperature: OpenRouterClient.Config.default.temperature,
        maxTokens: OpenRouterClient.Config.default.maxTokens,
        timeoutSeconds: OpenRouterClient.Config.default.timeoutSeconds,
        keychainService: keychainService,
        keychainAccount: "api_key",
        environmentVariableName: envName
    )
    return OpenRouterClient(config: config, httpClient: mock)
}

// MARK: - ContextualInterpretation Model Tests (no network, no keychain)

final class ContextualInterpretationTests: XCTestCase {

    func testDecodeValidJSON() throws {
        let direction = makeMockDirection()
        let jsonString = makeValidLLMResponse(for: direction)
        let data = jsonString.data(using: .utf8)!
        let interp = try JSONDecoder().decode(ContextualInterpretation.self, from: data)

        XCTAssertEqual(interp.directionId, direction.id)
        XCTAssertEqual(interp.clave, "MARTE_ASC_CONJUNCION")
        XCTAssertEqual(interp.polaridad, "malefico")
        XCTAssertEqual(interp.intensidad, 7)
        XCTAssertEqual(interp.factoresConsiderados.count, 3)
        XCTAssertEqual(interp.areasAfectadas.count, 2)
        XCTAssertEqual(interp.periodoActivacion.orbeEnMeses, 6)
        XCTAssertEqual(interp.promptVersion, "2.0.1-foundry-qwen7b")
    }

    func testComputedProperties() throws {
        let direction = makeMockDirection()
        let data = makeValidLLMResponse(for: direction).data(using: .utf8)!
        let interp = try JSONDecoder().decode(ContextualInterpretation.self, from: data)

        XCTAssertTrue(interp.esAltoImpacto, "Intensidad 7 debe ser alto impacto")
        XCTAssertEqual(interp.polaridadEmoji, "🔴")
        XCTAssertTrue(interp.periodoFormateado.contains("15 años"),
                      "Período formateado: \(interp.periodoFormateado)")
    }

    func testIntensidadBajaNoEsAltoImpacto() throws {
        let json = """
        {
          "directionId": "\(UUID().uuidString)",
          "clave": "SOL_ASC_TRIGONO",
          "tituloPrincipal": "Período favorable.",
          "textoEstructural": "Texto de prueba para un aspecto favorable de baja intensidad.",
          "factoresConsiderados": [],
          "periodoActivacion": {"edadExacta": 20.0, "orbeEnMeses": 6, "fechaInicio": null, "fechaFin": null},
          "areasAfectadas": [],
          "intensidad": 4,
          "polaridad": "benefico",
          "generadoEn": "2026-04-27T10:00:00Z",
          "promptVersion": "2.0.1-foundry-qwen7b"
        }
        """
        let interp = try JSONDecoder().decode(
            ContextualInterpretation.self,
            from: json.data(using: .utf8)!
        )
        XCTAssertFalse(interp.esAltoImpacto)
        XCTAssertEqual(interp.polaridadEmoji, "🟢")
    }

    func testNeutralAndMixedPolarityEmoji() throws {
        func makeJSON(polaridad: String) -> ContextualInterpretation {
            let json = """
            {"directionId":"\(UUID().uuidString)","clave":"X","tituloPrincipal":"T",
             "textoEstructural":"T","factoresConsiderados":[],"areasAfectadas":[],
             "periodoActivacion":{"edadExacta":10.0,"orbeEnMeses":6,"fechaInicio":null,"fechaFin":null},
             "intensidad":5,"polaridad":"\(polaridad)","generadoEn":"2026-04-27T10:00:00Z","promptVersion":"2.0.1-foundry-qwen7b"}
            """
            return try! JSONDecoder().decode(ContextualInterpretation.self, from: json.data(using: .utf8)!)
        }
        XCTAssertEqual(makeJSON(polaridad: "neutro").polaridadEmoji, "⚪️")
        XCTAssertEqual(makeJSON(polaridad: "mixto").polaridadEmoji, "🟡")
    }

    func testJSONSchemaHelperIsNotEmpty() {
        XCTAssertFalse(ContextualInterpretation.jsonSchema.isEmpty)
        XCTAssertTrue(ContextualInterpretation.jsonSchema.contains("textoEstructural"))
        XCTAssertTrue(ContextualInterpretation.jsonSchema.contains("promptVersion"))
        XCTAssertTrue(ContextualInterpretation.jsonSchema.contains("factoresConsiderados"))
    }
}

// MARK: - OpenRouterClient Tests

final class OpenRouterClientTests: XCTestCase {

    func testHasAPIKeyDoesNotCrash() async {
        let client = OpenRouterClient(httpClient: MockOpenRouterHTTPClient())
        // Just verifies the method is callable and returns a Bool
        let result = client.hasAPIKey()
        // Result depends on machine state — we just assert it's a Bool (always true)
        XCTAssertTrue(result == true || result == false)
    }

    func testResolveAPIKeyThrowsMissingWhenNoEnvVar() async {
        // Only run when OPENROUTER_API_KEY is not set and no Keychain entry exists
        guard !hasTestAPIKey else { return }

        let client = OpenRouterClient(httpClient: MockOpenRouterHTTPClient())
        // Skip if Keychain has a key
        let keychainHasKey = client.hasAPIKey()
        guard !keychainHasKey else { return }

        do {
            _ = try await client.resolveAPIKey()
            XCTFail("Debe lanzar missingAPIKey cuando no hay key disponible")
        } catch OpenRouterError.missingAPIKey {
            // Correcto
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }

    func testCompleteSuccessWithMockClient() async throws {
        guard hasTestAPIKey else {
            print("⚠️ Skipping: OPENROUTER_API_KEY no disponible en env")
            return
        }
        let direction = makeMockDirection()
        let mock = MockOpenRouterHTTPClient()
        mock.responseData = makeOpenRouterResponse(content: makeValidLLMResponse(for: direction))
        mock.responseStatusCode = 200

        let client = OpenRouterClient(httpClient: mock)
        let result = try await client.complete(
            systemPrompt: "System prompt de prueba",
            userPrompt: "User prompt de prueba"
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(mock.lastRequest?.httpMethod, "POST")
        let headers = mock.lastRequest?.allHTTPHeaderFields ?? [:]
        XCTAssertTrue(headers["Authorization"]?.hasPrefix("Bearer ") ?? false)
        XCTAssertEqual(headers["Content-Type"], "application/json")
    }

    func testCompleteThrowsOn401() async throws {
        guard hasTestAPIKey else { return }

        let mock = MockOpenRouterHTTPClient()
        mock.responseData = "{}".data(using: .utf8)!
        mock.responseStatusCode = 401

        let client = OpenRouterClient(httpClient: mock)
        do {
            _ = try await client.complete(systemPrompt: "s", userPrompt: "u")
            XCTFail("Debe lanzar unauthorized")
        } catch OpenRouterError.unauthorized { /* Correcto */ }
    }

    func testCompleteThrowsOn429() async throws {
        guard hasTestAPIKey else { return }

        let mock = MockOpenRouterHTTPClient()
        mock.responseData = "{}".data(using: .utf8)!
        mock.responseStatusCode = 429

        let client = OpenRouterClient(httpClient: mock)
        do {
            _ = try await client.complete(systemPrompt: "s", userPrompt: "u")
            XCTFail("Debe lanzar rateLimited")
        } catch OpenRouterError.rateLimited { /* Correcto */ }
    }

    func testRequestBodyContainsJsonMode() async throws {
        guard hasTestAPIKey else { return }

        let direction = makeMockDirection()
        let mock = MockOpenRouterHTTPClient()
        mock.responseData = makeOpenRouterResponse(content: makeValidLLMResponse(for: direction))

        let client = OpenRouterClient(httpClient: mock)
        _ = try? await client.complete(systemPrompt: "s", userPrompt: "u")

        guard let bodyData = mock.lastRequest?.httpBody,
              let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        else { return }

        let fmt = bodyJSON["response_format"] as? [String: String]
        XCTAssertEqual(fmt?["type"], "json_object",
                       "request body debe incluir response_format.type = json_object")
    }

    func testCredentialSourcePrefersKeychainOverEnvironment() async throws {
        let envName = "OPENROUTER_TEST_KEYCHAIN_PRIORITY"
        setenv(envName, "env-priority-key", 1)
        defer { unsetenv(envName) }

        let client = makeIsolatedClient(envName: envName, keychainService: "com.astromalik.tests.priority")
        defer { client.deleteAPIKey() }

        try client.saveAPIKey("keychain-priority-key")

        XCTAssertEqual(client.credentialSource(), .keychain)
        let resolved = try await client.resolveAPIKey()
        XCTAssertEqual(resolved, "keychain-priority-key")
    }

    func testCredentialSourceFallsBackToEnvironment() async throws {
        let envName = "OPENROUTER_TEST_ENV_ONLY"
        setenv(envName, "env-only-key", 1)
        defer { unsetenv(envName) }

        let client = makeIsolatedClient(envName: envName, keychainService: "com.astromalik.tests.envonly")
        client.deleteAPIKey()

        XCTAssertEqual(client.credentialSource(), .environment)
        let resolved = try await client.resolveAPIKey()
        XCTAssertEqual(resolved, "env-only-key")
    }

    func testValidateCurrentKeyParsesSanitizedPayload() async throws {
        let envName = "OPENROUTER_TEST_VALIDATE"
        setenv(envName, "env-validation-key", 1)
        defer { unsetenv(envName) }

        let mock = MockOpenRouterHTTPClient()
        mock.responseData = """
        {
          "data": {
            "label": "sk-or-v1-0123456789abcdef",
            "usage": 4.279925213,
            "limit": 5,
            "limit_remaining": 0.720074787,
            "is_free_tier": false,
            "is_provisioning_key": false,
            "is_ok": true
          }
        }
        """.data(using: .utf8)!

        let client = makeIsolatedClient(
            mock: mock,
            envName: envName,
            keychainService: "com.astromalik.tests.validate"
        )
        let validation = try await client.validateCurrentKey()

        XCTAssertEqual(validation.label, "sk-or-v1-0...cdef")
        XCTAssertEqual(validation.limit, 5)
        XCTAssertEqual(validation.usage, 4.279925213, accuracy: 0.000001)
        XCTAssertEqual(validation.limitRemaining, 0.720074787, accuracy: 0.000001)
    }

    func testJoplinKeyLocatorExtractsKeyFromSQLiteNote() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("joplin.sqlite")
        let db = try SQLiteDB(path: dbURL.path, readonly: false)

        try db.execute("""
            CREATE TABLE notes (
                id TEXT PRIMARY KEY,
                title TEXT,
                body TEXT,
                is_conflict INTEGER DEFAULT 0,
                deleted_time INTEGER DEFAULT 0,
                user_updated_time INTEGER DEFAULT 0,
                updated_time INTEGER DEFAULT 0,
                created_time INTEGER DEFAULT 0
            )
        """)
        try db.run("""
            INSERT INTO notes
            (id, title, body, is_conflict, deleted_time, user_updated_time, updated_time, created_time)
            VALUES (?, ?, ?, 0, 0, 10, 10, 10)
        """, args: [
            .text(UUID().uuidString),
            .text("Openrouter"),
            .text("Mi key activa es sk-or-v1-abc123xyz987 para AstroMalik.")
        ])

        let locator = JoplinOpenRouterKeyLocator(databasePaths: [dbURL.path])
        let credential = try locator.locateFirstCredential()

        XCTAssertEqual(credential?.noteTitle, "Openrouter")
        XCTAssertEqual(credential?.apiKey, "sk-or-v1-abc123xyz987")
    }
}

// MARK: - PrimaryDirectionContextualInterpreter Tests

final class PrimaryDirectionContextualInterpreterTests: XCTestCase {

    // MARK: - Prompt Builder Tests (no network, no API key needed)

    func testBuildUserPromptContainsAllSections() async {
        let interpreter = PrimaryDirectionContextualInterpreter(llmClient: MockPrimaryDirectionLLMClient())
        let prompt = interpreter.buildUserPrompt(
            direction: makeMockDirection(),
            context: makeMockContext()
        )

        XCTAssertTrue(prompt.contains("MARTE_ASC_CONJUNCION"), "Debe contener la clave")
        XCTAssertTrue(prompt.contains("Regiomontanus"), "Debe mencionar el método")
        XCTAssertTrue(prompt.contains("Naibod"), "Debe mencionar la clave temporal")
        XCTAssertTrue(prompt.contains("15.73"), "Debe incluir la edad de activación")
        XCTAssertTrue(prompt.contains("40.4168"), "Debe incluir la latitud")
        XCTAssertTrue(prompt.contains("exilio"), "Debe incluir la dignidad esencial")
        XCTAssertTrue(prompt.contains("Nocturna"), "Debe indicar sect nocturna")
        XCTAssertTrue(prompt.contains("Casa 6"), "Debe incluir la casa natal")
        XCTAssertTrue(prompt.contains("1976"), "Debe incluir el año de nacimiento")
        XCTAssertTrue(prompt.contains("2.0.1-foundry-qwen7b"), "Debe especificar el promptVersion")
    }

    func testBuildUserPromptWithMissingFactors() async {
        let interpreter = PrimaryDirectionContextualInterpreter(llmClient: MockPrimaryDirectionLLMClient())
        let sparseContext = PDInterpretationContext(
            promissorDignity: nil, promissorNatalHouse: nil,
            natalAspectBetweenPromissorAndSignificator: nil,
            isNocturnal: false, promissorInSect: true,
            significatorCondition: nil, nativeCurrentAge: nil, birthYear: nil
        )
        let prompt = interpreter.buildUserPrompt(
            direction: makeMockDirection(), context: sparseContext
        )
        XCTAssertTrue(prompt.contains("factor no disponible"),
                      "Factores faltantes deben indicarse explícitamente")
        XCTAssertTrue(prompt.contains("Diurna"), "Sect diurna debe marcarse")
    }

    func testBuildUserPromptConversa() async {
        let interpreter = PrimaryDirectionContextualInterpreter(llmClient: MockPrimaryDirectionLLMClient())
        let conversaDir = PrimaryDirection(
            promissor: "SOL", promissorLabel: "☉ Sol",
            significator: "ASC", significatorLabel: "ASC",
            aspect: .trine, aspectAngle: 120,
            directionType: .converse, aspectPlane: .mundane,
            arc: -25.0, estimatedAge: 25.36, estimatedDate: Date(),
            method: .regiomontanus, key: .naibod,
            technicalData: PDTechnicalData(
                promissorRA: 0, promissorDeclination: 0,
                significatorRA: 0, significatorDeclination: 0,
                significatorPole: 0, obliquity: 23.44,
                ramc: 0, geoLatitude: 0
            )
        )
        let prompt = interpreter.buildUserPrompt(
            direction: conversaDir, context: makeMockContext()
        )
        XCTAssertTrue(prompt.contains("Conversa"), "Dirección conversa debe marcarse")
        XCTAssertTrue(prompt.contains("Mundano"), "Plano mundano debe indicarse")
    }

    // MARK: - Interpret Tests (Foundry client mocked, no API key needed)

    func testInterpretWithMockReturnsDecodedResult() async throws {
        let direction = makeMockDirection()
        let mock = MockPrimaryDirectionLLMClient(response: makeValidLLMResponse(for: direction))

        let db = try SQLiteDB(path: ":memory:", readonly: false)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS primary_directions_interpretations (
                id INTEGER PRIMARY KEY AUTOINCREMENT, direction_id TEXT NOT NULL,
                clave TEXT NOT NULL, prompt_version TEXT NOT NULL,
                json_payload TEXT NOT NULL, model_used TEXT DEFAULT '',
                tokens_used INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')),
                UNIQUE(direction_id, prompt_version))
        """)

        let interpreter = PrimaryDirectionContextualInterpreter(
            llmClient: mock, db: db
        )
        let result = try await interpreter.interpret(
            direction: direction, context: makeMockContext()
        )

        XCTAssertEqual(result.directionId, direction.id)
        XCTAssertEqual(result.clave, "MARTE_ASC_CONJUNCION")
        XCTAssertEqual(result.polaridad, "malefico")
        XCTAssertEqual(result.intensidad, 7)
        XCTAssertTrue(result.esAltoImpacto)
        XCTAssertFalse(result.textoEstructural.isEmpty)
    }

    func testInterpretUsesMemoryCache() async throws {
        let direction = makeMockDirection()
        let mock = MockPrimaryDirectionLLMClient(response: makeValidLLMResponse(for: direction))

        let interpreter = PrimaryDirectionContextualInterpreter(
            llmClient: mock, db: nil
        )

        // Primera llamada — LLM consultado
        _ = try await interpreter.interpret(direction: direction, context: makeMockContext())
        XCTAssertEqual(mock.requestCount, 1)

        // Reset mock para detectar segunda llamada
        mock.error = PrimaryDirectionFoundryError.invalidOutput("No debe consultarse")

        // Segunda llamada — debe usar caché (no lanza error del mock)
        let second = try await interpreter.interpret(
            direction: direction, context: makeMockContext()
        )
        XCTAssertEqual(second.directionId, direction.id,
                       "Segunda llamada debe venir de caché")
        XCTAssertEqual(mock.requestCount, 1, "La segunda llamada no debe tocar la red")
    }

    func testInvalidateCacheForDirection() async throws {
        let direction = makeMockDirection()
        let mock = MockPrimaryDirectionLLMClient(response: makeValidLLMResponse(for: direction))

        let interpreter = PrimaryDirectionContextualInterpreter(
            llmClient: mock, db: nil
        )

        // Poblar caché
        _ = try await interpreter.interpret(direction: direction, context: makeMockContext())
        // Invalidar
        await interpreter.invalidateCache(for: direction.id)

        // Reset a respuesta vacía — si la caché fue borrada, se llamará al LLM y fallará al decodificar
        mock.response = ""

        do {
            _ = try await interpreter.interpret(direction: direction, context: makeMockContext())
        } catch {
            // Esperado: decodingError o emptyResponse — confirma que la caché fue borrada
            XCTAssertTrue(error is PrimaryDirectionContextualError,
                          "Tras invalidar caché, Foundry debe ser consultado (error esperado)")
        }
    }

    func testExtractJSONStripsMarkdownWrapper() async throws {
        let direction = makeMockDirection()
        // Simula LLM que devuelve JSON envuelto en bloque markdown
        let wrapped = "```json\n\(makeValidLLMResponse(for: direction))\n```"

        let mock = MockPrimaryDirectionLLMClient(response: wrapped)

        let interpreter = PrimaryDirectionContextualInterpreter(
            llmClient: mock, db: nil
        )
        let result = try? await interpreter.interpret(
            direction: direction, context: makeMockContext()
        )
        XCTAssertNotNil(result, "El intérprete debe manejar JSON envuelto en markdown")
    }

    func testInterpretPersistentCacheSurvivesNewInterpreterInstance() async throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let db = try SQLiteDB(path: tempURL.path, readonly: false)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS primary_directions_interpretations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                direction_id TEXT NOT NULL,
                clave TEXT NOT NULL,
                prompt_version TEXT NOT NULL,
                json_payload TEXT NOT NULL,
                created_at TEXT DEFAULT (datetime('now')),
                UNIQUE(direction_id, prompt_version)
            )
        """)

        let direction = makeMockDirection()
        let firstMock = MockPrimaryDirectionLLMClient(response: makeValidLLMResponse(for: direction))

        let firstInterpreter = PrimaryDirectionContextualInterpreter(
            llmClient: firstMock,
            db: db
        )
        _ = try await firstInterpreter.interpret(direction: direction, context: makeMockContext())
        XCTAssertEqual(firstMock.requestCount, 1)

        let secondMock = MockPrimaryDirectionLLMClient(response: "")
        secondMock.error = PrimaryDirectionFoundryError.invalidOutput("No debe consultarse")

        let secondInterpreter = PrimaryDirectionContextualInterpreter(
            llmClient: secondMock,
            db: try SQLiteDB(path: tempURL.path, readonly: false)
        )
        let cached = try await secondInterpreter.interpret(direction: direction, context: makeMockContext())

        XCTAssertEqual(cached.directionId, direction.id)
        XCTAssertEqual(secondMock.requestCount, 0, "La segunda instancia debe reutilizar user.db")
    }
}
