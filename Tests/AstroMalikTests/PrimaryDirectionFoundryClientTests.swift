import XCTest
@testable import AstroMalik

final class PrimaryDirectionFoundryClientTests: XCTestCase {
    func testDecodeCompletionOutputAcceptsCleanJSON() throws {
        let output = try PrimaryDirectionFoundryClient.decodeCompletionOutput(Self.sampleJSON)
        let interpretation = try JSONDecoder().decode(ContextualInterpretation.self, from: Data(output.utf8))

        XCTAssertEqual(interpretation.clave, "MARTE_ASC_CONJUNCION")
        XCTAssertEqual(interpretation.promptVersion, "2.0.1-foundry-qwen7b")
    }

    func testDecodeCompletionOutputIgnoresFoundryNoiseAroundJSON() throws {
        let noisy = """
        [foundry-local] Native libraries found
        [foundry-local] Foundry.Local.Core initialized successfully
        \(Self.sampleJSON)
        OGA Warning: tokenizer cleanup
        """

        let output = try PrimaryDirectionFoundryClient.decodeCompletionOutput(noisy)
        let interpretation = try JSONDecoder().decode(ContextualInterpretation.self, from: Data(output.utf8))

        XCTAssertEqual(interpretation.tituloPrincipal, "Lectura local")
        XCTAssertEqual(interpretation.intensidad, 7)
    }

    func testCompleteThrowsWhenPythonIsMissing() async throws {
        let client = PrimaryDirectionFoundryClient(
            pythonPath: "/definitely/missing/python",
            scriptPath: "/definitely/missing/script.py"
        )

        do {
            _ = try await client.complete(
                direction: Self.sampleDirection,
                context: Self.sampleContext,
                systemPrompt: "system",
                userPrompt: "user",
                promptVersion: "2.0.1-foundry-qwen7b"
            )
            XCTFail("Debe lanzar pythonNotFound")
        } catch PrimaryDirectionFoundryError.pythonNotFound {
            // Correcto
        }
    }

    func testCompleteThrowsWhenScriptIsMissing() async throws {
        let client = PrimaryDirectionFoundryClient(
            pythonPath: "/bin/sh",
            scriptPath: "/definitely/missing/foundry_primary_direction_once.py"
        )

        do {
            _ = try await client.complete(
                direction: Self.sampleDirection,
                context: Self.sampleContext,
                systemPrompt: "system",
                userPrompt: "user",
                promptVersion: "2.0.1-foundry-qwen7b"
            )
            XCTFail("Debe lanzar scriptNotFound")
        } catch PrimaryDirectionFoundryError.scriptNotFound {
            // Correcto
        }
    }

    func testCompleteTimesOut() async throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pd-foundry-timeout-\(UUID().uuidString).sh")
        let script = "#!/bin/sh\nsleep 1\n"
        FileManager.default.createFile(atPath: tempURL.path, contents: Data(script.utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = PrimaryDirectionFoundryClient(
            pythonPath: "/bin/sh",
            scriptPath: tempURL.path,
            timeoutNanoseconds: 50_000_000
        )

        do {
            _ = try await client.complete(
                direction: Self.sampleDirection,
                context: Self.sampleContext,
                systemPrompt: "system",
                userPrompt: "user",
                promptVersion: "2.0.1-foundry-qwen7b"
            )
            XCTFail("Debe lanzar timeout")
        } catch PrimaryDirectionFoundryError.timeout {
            // Correcto
        }
    }

    private static let sampleJSON = """
    {"directionId":"00000000-0000-0000-0000-000000000001","clave":"MARTE_ASC_CONJUNCION","tituloPrincipal":"Lectura local","textoEstructural":"Texto interpretativo.","factoresConsiderados":[{"factor":"sect","valor":"nocturna","modulacion":"neutro"}],"periodoActivacion":{"edadExacta":15.73,"orbeEnMeses":6,"fechaInicio":null,"fechaFin":null},"areasAfectadas":[{"area":"salud","peso":3}],"intensidad":7,"polaridad":"malefico","generadoEn":"2026-04-30T00:00:00Z","promptVersion":"2.0.1-foundry-qwen7b"}
    """

    private static let sampleDirection = PrimaryDirection(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        promissor: "MARTE",
        promissorLabel: "Marte",
        significator: "ASC",
        significatorLabel: "ASC",
        aspect: .conjunction,
        aspectAngle: 0,
        directionType: .direct,
        aspectPlane: .zodiacal,
        arc: 15.5,
        estimatedAge: 15.73,
        estimatedDate: Date(timeIntervalSince1970: 0),
        method: .regiomontanus,
        key: .naibod,
        technicalData: PDTechnicalData(
            promissorRA: 1,
            promissorDeclination: 2,
            significatorRA: 3,
            significatorDeclination: 4,
            significatorPole: 5,
            obliquity: 23.44,
            ramc: 6,
            geoLatitude: 40.4
        )
    )

    private static let sampleContext = PDInterpretationContext(
        promissorDignity: "exilio",
        promissorNatalHouse: 6,
        natalAspectBetweenPromissorAndSignificator: nil,
        isNocturnal: true,
        promissorInSect: false,
        significatorCondition: "ASC en Geminis",
        nativeCurrentAge: 49.5,
        birthYear: 1976
    )
}
