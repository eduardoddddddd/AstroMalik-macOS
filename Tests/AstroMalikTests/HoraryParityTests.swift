import XCTest
@testable import AstroMalik

final class HoraryParityTests: XCTestCase {

    func testContratoCase() async throws {
        let query = try await runCase(
            question: "contrato",
            datetimeLocal: "2026-04-22T17:45:00",
            timezone: "Europe/Madrid",
            latitude: 36.8988,
            longitude: -3.4205,
            placeName: "Órgiva, Granada, España",
            questionHouse: 10
        )

        XCTAssertEqual(query.judgement.perfectionKind, "coleccion")
        XCTAssertEqual(query.judgement.significators.querent, "Mercurio")
        XCTAssertEqual(query.judgement.significators.quesited, "Mercurio")
        XCTAssertEqual(query.judgement.perfectionRoute.intermediary, "Jupiter")
        XCTAssertTrue(query.judgement.significators.quesitedCosignifiers.contains("Jupiter"))
        XCTAssertEqual(query.chart.body(named: "Jupiter")?.house, 10)
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
    }

    func testCapgeminiCase() async throws {
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
        XCTAssertEqual(Set(query.judgement.activeConsiderationKeys), Set(["asc_temprano", "luna_vacia"]))
        XCTAssertEqual(query.judgement.significators.querent, "Sol")
        XCTAssertEqual(query.judgement.significators.quesited, "Marte")
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
