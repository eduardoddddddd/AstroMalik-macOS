import XCTest
@testable import AstroMalik

final class HoraryFoundryClientTests: XCTestCase {
    func testDecodeInterpretationOutputAcceptsCleanJSON() throws {
        let interpretation = try HoraryFoundryClient.decodeInterpretationOutput(Self.sampleJSON)

        XCTAssertEqual(interpretation.schemaVersion, "horary-foundry-v1")
        XCTAssertEqual(interpretation.model, "qwen2.5-7b")
        XCTAssertEqual(interpretation.answer, "si")
        XCTAssertEqual(interpretation.technicalReading, ["Hay perfeccion valida."])
    }

    func testDecodeInterpretationOutputIgnoresFoundryNoiseAroundJSON() throws {
        let noisy = """
        [foundry-local] Native libraries found
        [foundry-local] Foundry.Local.Core initialized successfully
        \(Self.sampleJSON)
        OGA Error: tokenizer cleanup warning
        """

        let interpretation = try HoraryFoundryClient.decodeInterpretationOutput(noisy)

        XCTAssertEqual(interpretation.title, "Lectura local")
        XCTAssertEqual(interpretation.cautions, ["Mantener cautela."])
    }

    private static let sampleJSON = """
    {"schemaVersion":"horary-foundry-v1","model":"qwen2.5-7b","answer":"si","confidence":"alta","title":"Lectura local","summary":"Resumen breve.","interpretation":"Texto interpretativo.","technicalReading":["Hay perfeccion valida."],"cautions":["Mantener cautela."],"generatedAt":"2026-04-30T00:00:00Z","rawModelOutput":"{}"}
    """
}
