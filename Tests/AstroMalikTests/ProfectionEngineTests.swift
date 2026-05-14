import XCTest
import CSwissEph
@testable import AstroMalik

final class ProfectionEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testAge49AnnualProfectionActivatesHouse2() async throws {
        let chart = try referenceChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())

        let result = try await engine.profections(
            for: chart,
            at: localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        )

        XCTAssertEqual(result.annual.age, 49)
        XCTAssertEqual(result.annual.house, 2)
        XCTAssertEqual(result.annual.house, ((49 % 12) + 1))
        let expected = wholeSignHouseForTest(ascLongitude: chart.ascendant.longitude, age: 49)
        XCTAssertEqual(result.annual.signKey, SIGN_KEYS[expected.signIndex])
        XCTAssertEqual(
            result.annual.lordKey,
            EssentialDignityEngine.domicileRuler(of: expected.signIndex)
        )
    }

    func testAge0UsesHouse1AndAscendantRuler() async throws {
        let chart = try referenceChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())
        let birthInstant = localDate(
            year: 1976,
            month: 10,
            day: 11,
            hour: 20,
            minute: 33,
            timezoneName: "Europe/Madrid"
        )

        let result = try await engine.profections(for: chart, at: birthInstant)
        let ascSign = Int(chart.ascendant.longitude / 30.0)
        let ascRuler = EssentialDignityEngine.domicileRuler(of: ascSign)

        XCTAssertEqual(result.annual.age, 0)
        XCTAssertEqual(result.annual.house, 1)
        XCTAssertEqual(result.annual.lordKey, ascRuler)
        XCTAssertEqual(result.annual.signKey, AstroEngine.degToSignKey(chart.ascendant.longitude))
    }

    func testAnnualMonthlyDailyProfectionsAreCoherent() async throws {
        let chart = try referenceChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())

        let result = try await engine.profections(
            for: chart,
            at: localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        )

        XCTAssertEqual(result.monthly.count, 4)
        XCTAssertEqual(result.daily.count, 7)
        XCTAssertTrue(result.monthly.allSatisfy { $0.age == result.annual.age })
        XCTAssertTrue(result.daily.allSatisfy { $0.age == result.annual.age })
        XCTAssertTrue(result.monthly.allSatisfy { (1...12).contains($0.house) })
        XCTAssertTrue(result.daily.allSatisfy { (1...12).contains($0.house) })

        for period in [result.annual] + result.monthly + result.daily {
            let step = period.kind == .annual ? result.annual.age : result.annual.age + period.sequence
            let expected = wholeSignHouseForTest(ascLongitude: chart.ascendant.longitude, age: step)
            XCTAssertEqual(period.house, expected.house)
            XCTAssertEqual(period.signKey, SIGN_KEYS[expected.signIndex])
            let expectedLord = EssentialDignityEngine.domicileRuler(of: expected.signIndex)
            XCTAssertEqual(period.lordKey, expectedLord)
        }

        let firstMonthly = try XCTUnwrap(result.monthly.first)
        XCTAssertEqual(
            firstMonthly.house,
            wholeSignHouseForTest(ascLongitude: chart.ascendant.longitude, age: result.annual.age + firstMonthly.sequence).house
        )
        let firstDaily = try XCTUnwrap(result.daily.first)
        XCTAssertEqual(
            firstDaily.house,
            wholeSignHouseForTest(ascLongitude: chart.ascendant.longitude, age: result.annual.age + firstDaily.sequence).house
        )
    }

    func testWholeSignProfectionDiffersFromQuadrantWhenAscIsLateInSign() async throws {
        let chart = lateGeminiAscendantChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())

        let result = try await engine.profections(
            for: chart,
            at: localDate(year: 2001, month: 6, day: 1, hour: 12, timezoneName: "UTC")
        )

        XCTAssertEqual(result.annual.age, 1)
        XCTAssertEqual(result.annual.house, 2)
        XCTAssertEqual(result.annual.signKey, "CANCER")
        XCTAssertEqual(result.annual.signLabel, SIGN_LABELS[3])
        XCTAssertEqual(result.annual.cuspLongitude, 90.0, accuracy: 0.0001)
        XCTAssertEqual(result.annual.lordKey, "LUNA")
        XCTAssertTrue(result.annual.natalPlanetsInHouse.contains { $0.key == "LUNA" })
        XCTAssertFalse(result.annual.natalPlanetsInHouse.contains { $0.key == "SOL" })
    }

    func testCurrentYearContainsLotYTransitActivation() async throws {
        let chart = try referenceChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())

        let result = try await engine.profections(
            for: chart,
            at: localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        )

        XCTAssertFalse(result.activations.isEmpty)
        XCTAssertTrue(result.activations.contains { event in
            event.transitKey == result.annual.lordKey || event.natalKey == result.annual.lordKey
        })
        XCTAssertTrue(result.activations.allSatisfy { event in
            event.transitKey == result.annual.lordKey || event.natalKey == result.annual.lordKey
        })
    }

    func testJoplinClipperCreatesProfectionNotePayload() async throws {
        let chart = try referenceChart()
        let engine = ProfectionEngine(corpusStore: try referenceCorpusStore())
        let date = localDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        let result = try await engine.profections(for: chart, at: date)
        let title = ProfectionsNoteBuilder.noteTitle(chart: chart, result: result, date: date)
        let body = ProfectionsNoteBuilder.markdown(chart: chart, result: result, date: date)

        let client = ProfectionMockJoplinHTTPClient(responses: [
            #"{"items":[{"id":"folder-1","title":"AstroMalik"}],"has_more":false}"#,
            #"{"id":"note-1"}"#,
        ])
        let service = JoplinClipperService(
            settings: JoplinClipperSettings(
                host: "127.0.0.1",
                port: 41184,
                token: "secret",
                notebook: "AstroMalik"
            ),
            client: client
        )

        try await service.createNote(title: title, body: body)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[1].url?.path, "/notes")
        let payloadData = try XCTUnwrap(client.requests[1].httpBody)
        let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        XCTAssertEqual(payload?["title"] as? String, title)
        XCTAssertEqual(payload?["body"] as? String, body)
        XCTAssertEqual(payload?["parent_id"] as? String, "folder-1")
        XCTAssertTrue(body.contains("# Profección anual"))
        XCTAssertTrue(body.contains("Lord of the Year"))
        XCTAssertTrue(body.contains("Activaciones del año"))
    }
}

private func referenceChart(
    birthDate: String = "1976-10-11",
    birthTime: String = "20:33",
    timezoneName: String = "Europe/Madrid",
    lat: Double = 40.4168,
    lon: Double = -3.7038
) throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: birthDate,
        birthTime: birthTime,
        timezoneName: timezoneName
    )
    var chart = try AstroEngine.computeNatalChart(
        jd: jdResult.jd,
        lat: lat,
        lon: lon
    )
    chart.name = "Referencia"
    chart.birthDate = birthDate
    chart.birthTime = birthTime
    chart.timezone = timezoneName
    return chart
}

private func referenceCorpusStore() throws -> CorpusStore {
    try CorpusStore(path: referenceCorpusURL().path)
}

private func referenceCorpusURL() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let repoRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return repoRoot
        .appendingPathComponent("Sources/AstroMalik/Resources/corpus.db")
}

private func localDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int = 0,
    timezoneName: String
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timezoneName) ?? TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    )) ?? Date()
}

private func wholeSignHouseForTest(ascLongitude: Double, age: Int) -> (house: Int, signIndex: Int) {
    let ascSign = Int(((ascLongitude.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)) / 30.0)
    let offset = ((age % 12) + 12) % 12
    return (offset + 1, (ascSign + offset) % 12)
}

private func lateGeminiAscendantChart() -> NatalChart {
    NatalChart(
        name: "ASC Géminis tardío",
        birthDate: "2000-06-01",
        birthTime: "12:00",
        timezone: "UTC",
        latitude: 40.0,
        longitude: 0.0,
        placeName: "Test",
        houseSystem: "Placidus",
        ascendant: AngularPoint(longitude: 88.0, formatted: AstroEngine.degToSign(88.0)),
        mc: AngularPoint(longitude: 330.0, formatted: AstroEngine.degToSign(330.0)),
        cusps: [
            88.0, 120.0, 150.0, 180.0, 210.0, 240.0,
            268.0, 300.0, 330.0, 0.0, 30.0, 60.0,
        ],
        bodies: [
            PlanetBody(
                key: "LUNA",
                label: "☽ Luna",
                longitude: 102.0,
                formatted: AstroEngine.degToSign(102.0),
                house: 1,
                retrograde: false
            ),
            PlanetBody(
                key: "SOL",
                label: "☉ Sol",
                longitude: 125.0,
                formatted: AstroEngine.degToSign(125.0),
                house: 2,
                retrograde: false
            ),
        ]
    )
}

private final class ProfectionMockJoplinHTTPClient: JoplinHTTPClient {
    private var responses: [Data]
    private(set) var requests: [URLRequest] = []

    init(responses: [String]) {
        self.responses = responses.map { Data($0.utf8) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let data = responses.isEmpty ? Data(#"{"id":"ok"}"#.utf8) : responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
