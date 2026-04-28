import XCTest
@testable import AstroMalik

final class HoraryParityTests: XCTestCase {

    func testNativeContratoCaseProducesStructuredJudgement() async throws {
        let query = try await runCase(
            question: "contrato",
            datetimeLocal: "2026-04-22T17:45:00",
            timezone: "Europe/Madrid",
            latitude: 36.8988,
            longitude: -3.4205,
            placeName: "Órgiva, Granada, España",
            questionHouse: 10
        )

        XCTAssertFalse(query.response.chartJSON.isEmpty)
        XCTAssertFalse(query.response.judgementJSON.isEmpty)
        XCTAssertEqual(query.judgement.questionHouse, 10)
        XCTAssertNotNil(query.judgement.verdict)
        XCTAssertNotNil(query.judgement.confidence)
        XCTAssertNotNil(query.judgement.mainReason)
        XCTAssertFalse(query.judgement.perfectionKind.isEmpty)
        XCTAssertNotNil(query.chart.body(named: "Luna"))
        XCTAssertNotNil(query.chart.body(named: "Saturno"))
    }

    func testMudanzaCase() async throws {
        let query = try await runCase(
            question: "mudanza",
            datetimeLocal: "2026-04-01T12:52:00",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid, España",
            questionHouse: 4
        )

        XCTAssertEqual(query.judgement.perfectionKind, "aplicativo_directo")
        XCTAssertEqual(query.judgement.perfectionRoute.aspectName, "trigono")
        XCTAssertTrue(query.judgement.perfectionRoute.usesCosignifier)
        XCTAssertEqual(query.judgement.perfectionRoute.significatorQuerent, "Jupiter")
        XCTAssertEqual(query.judgement.perfectionRoute.significatorQuesited, "Mercurio")
        XCTAssertTrue(query.judgement.significators.querentCosignifiers.contains("Jupiter"))
        XCTAssertEqual(query.judgement.verdict, "si")
        XCTAssertNotNil(query.judgement.timingRange)
    }

    func testStolenFishHistoricalCase() async throws {
        let query = try await runCase(
            question: "¿Dónde está mi pescado? ¿Podré recuperar al menos parte?",
            datetimeLocal: "1638-02-20T09:00:00",
            timezone: "UTC",
            latitude: 51.389,
            longitude: -0.386,
            placeName: "Hersham, Inglaterra",
            questionHouse: 2
        )

        XCTAssertFalse(query.response.chartJSON.isEmpty)
        XCTAssertFalse(query.response.judgementJSON.isEmpty)
        XCTAssertEqual(query.judgement.questionHouse, 2)
        XCTAssertFalse(query.judgement.perfectionKind.isEmpty)
        XCTAssertNotNil(query.judgement.verdict)
    }

    func testSinPerfeccionWithVoidMoonDoesNotReturnCleanYes() async throws {
        let query = try await runCase(
            question: "capgemini",
            datetimeLocal: "2026-04-23T13:14:00",
            timezone: "Europe/Madrid",
            latitude: 36.8988,
            longitude: -3.4205,
            placeName: "Órgiva, Granada, España",
            questionHouse: 10
        )

        XCTAssertEqual(query.judgement.perfectionKind, "sin_perfeccion")
        XCTAssertTrue(query.judgement.activeConsiderationKeys.contains("asc_temprano"))
        XCTAssertTrue(query.judgement.activeConsiderationKeys.contains("luna_vacia"))
        XCTAssertNotEqual(query.judgement.verdict, "si")
        XCTAssertEqual(query.judgement.significators.querent, "Sol")
        XCTAssertEqual(query.judgement.significators.quesited, "Marte")
    }

    func testVoidMoonAtEndOfSignCannotPerfectAfterSignChange() async throws {
        let query = try await runCase(
            question: "Puedes ser mustaquima mi esposa?",
            datetimeLocal: "2026-04-28T10:41:08",
            timezone: "Europe/Madrid",
            latitude: 36.8988,
            longitude: -3.4205,
            placeName: "Órgiva, Granada, España",
            questionHouse: 7
        )

        XCTAssertTrue(query.judgement.activeConsiderationKeys.contains("luna_vacia"))
        XCTAssertEqual(query.judgement.significators.querent, "Luna")
        XCTAssertEqual(query.judgement.significators.quesited, "Saturno")
        XCTAssertFalse(
            query.judgement.perfectionKind == "aplicativo_directo"
                && query.judgement.perfectionRoute.significatorQuerent == "Luna"
                && query.judgement.perfectionRoute.significatorQuesited == "Saturno",
            "La Luna no debe perfeccionar con Saturno después de salir de Virgo."
        )
        XCTAssertNotEqual(query.judgement.verdict, "si")
    }

    func testLegacyJudgementJSONDecodesWithoutStructuredFields() throws {
        let json = """
        {
          "question": "legacy",
          "radical": true,
          "perfectionKind": "sin_perfeccion",
          "timeEstimate": null,
          "questionHouse": 7,
          "questionTopic": "el matrimonio o la contraparte",
          "significators": {
            "querent": "Marte",
            "quesited": "Venus",
            "moon": "Luna",
            "querentCosignifiers": [],
            "quesitedCosignifiers": []
          },
          "perfectionRoute": {
            "kind": "sin_perfeccion",
            "significatorQuerent": "Marte",
            "significatorQuesited": "Venus",
            "intermediary": null,
            "aspectName": null,
            "usesCosignifier": false
          },
          "activeConsiderationKeys": ["luna_vacia"],
          "notes": []
        }
        """

        let judgement = try JSONDecoder().decode(HoraryJudgement.self, from: Data(json.utf8))
        XCTAssertNil(judgement.verdict)
        XCTAssertNil(judgement.perfectionRoute.degreesToPerfect)
        XCTAssertEqual(judgement.perfectionKind, "sin_perfeccion")
    }

    func testCurrentSavedQuestionGoldenSetCalculatesNatively() async throws {
        let savedQuestions: [(String, String, Int)] = [
            ("Puedes ser mustaquima mi esposa?", "2026-04-28T10:41:08", 7),
            ("vamos de verdad a ser pareja?", "2026-04-26T20:37:54", 7),
            ("1 tendre pareja pronto? En cuanto tiempo?", "2026-04-25T23:57:46", 7),
            ("tendre pareja pronto? En cuanto tiempo?", "2026-04-25T23:57:41", 10),
            ("cuando empezare a trabajar de nuevo?", "2026-04-24T12:26:34", 10),
            ("cuando saldre de este encierrro?", "2026-04-24T02:46:19", 12),
            ("tendre hijos alguna vez?", "2026-04-24T01:30:34", 5),
            ("tendra valor comercial este programa?", "2026-04-23T13:56:23", 10),
        ]

        for (question, datetimeLocal, house) in savedQuestions {
            let query = try await runCase(
                question: question,
                datetimeLocal: datetimeLocal,
                timezone: "Europe/Madrid",
                latitude: 36.8988,
                longitude: -3.4205,
                placeName: "Órgiva, Granada, España",
                questionHouse: house
            )
            XCTAssertEqual(query.request.question, question)
            XCTAssertEqual(query.judgement.questionHouse, house)
            XCTAssertNotNil(query.judgement.verdict)
            XCTAssertNotNil(query.judgement.mainReason)
            XCTAssertFalse(query.chart.bodies.isEmpty)
            XCTAssertFalse(query.chart.dignities.isEmpty)
        }
    }

    private func runCase(
        question: String,
        datetimeLocal: String,
        timezone: String,
        latitude: Double,
        longitude: Double,
        placeName: String,
        questionHouse: Int
    ) async throws -> SavedHoraryQuery {
        let request = HoraryRequest(
            question: question,
            datetimeLocal: datetimeLocal,
            timezone: timezone,
            latitude: latitude,
            longitude: longitude,
            placeName: placeName,
            questionHouse: questionHouse,
            includeFortune: true
        )
        let response = try await HoraryEngine.calculate(request)
        return try SavedHoraryQuery(request: request, response: response)
    }
}
