import XCTest
@testable import AstroMalik

final class ZodiacalReleasingEngineTests: XCTestCase {
    private let expectedFortunaLongitude = 201.4569171995368
    private let expectedSpiritLongitude = 279.6286350582686

    override func setUp() {
        super.setUp()
        AstroEngine.configure(ephePath: nil)
    }

    func testReferenceLotsUseNocturnalFormula() throws {
        let chart = try zrReferenceChart()
        let fortune = try HellenisticLots.fortune(chart: chart)
        let spirit = try HellenisticLots.spirit(chart: chart)

        XCTAssertFalse(SectEngine.sect(of: chart).isDiurnal)

        // Constantes de referencia para la carta 1976-10-11 20:33 Europe/Madrid.
        // En carta nocturna: Fortuna = ASC + Sol - Luna; Espíritu = ASC + Luna - Sol.
        XCTAssertEqual(fortune.longitude, expectedFortunaLongitude, accuracy: 0.0001)
        XCTAssertEqual(fortune.signIndex, 6)
        XCTAssertEqual(fortune.formatted, "♎ Libra 21°27'")

        XCTAssertEqual(spirit.longitude, expectedSpiritLongitude, accuracy: 0.0001)
        XCTAssertEqual(spirit.signIndex, 9)
        XCTAssertEqual(spirit.formatted, "♑ Capricornio 09°37'")
    }

    func testFirstL1StartsOnLotSign() throws {
        let chart = try zrReferenceChart()
        let engine = ZodiacalReleasingEngine()
        let fortuneTimeline = engine.zr(chart: chart, lot: .fortune, depth: 2)
        let spiritTimeline = engine.zr(chart: chart, lot: .spirit, depth: 2)

        XCTAssertEqual(fortuneTimeline.periods.first?.signIndex, fortuneTimeline.lotPoint.signIndex)
        XCTAssertEqual(fortuneTimeline.periods.first?.signLabel, "♎ Libra")
        XCTAssertEqual(spiritTimeline.periods.first?.signIndex, spiritTimeline.lotPoint.signIndex)
        XCTAssertEqual(spiritTimeline.periods.first?.signLabel, "♑ Capricornio")
    }

    func testInitialL2MatchesItsL1Sign() throws {
        let chart = try zrReferenceChart()
        let timeline = ZodiacalReleasingEngine().zr(chart: chart, lot: .fortune, depth: 2)
        let firstL1 = try XCTUnwrap(timeline.periods.first)
        let firstL2 = try XCTUnwrap(firstL1.children.first)

        XCTAssertEqual(firstL2.level, .l2)
        XCTAssertEqual(firstL2.signIndex, firstL1.signIndex)
        XCTAssertEqual(firstL2.signLabel, firstL1.signLabel)
        XCTAssertTrue(firstL2.isPeak)
        XCTAssertEqual(firstL2.angularity, .angular)
    }

    func testLoosingOfBondInFirstFortuneL1JumpsToOppositeOfL1Start() throws {
        let chart = try zrReferenceChart()
        let timeline = ZodiacalReleasingEngine().zr(chart: chart, lot: .fortune, depth: 2)
        let firstL1 = try XCTUnwrap(timeline.periods.first)
        let lbIndex = try XCTUnwrap(firstL1.children.firstIndex { $0.hasLoosingOfBond })
        let lbPeriod = firstL1.children[lbIndex]
        let nextPeriod = try XCTUnwrap(firstL1.children[safe: lbIndex + 1])

        XCTAssertEqual(firstL1.signLabel, "♎ Libra")
        XCTAssertEqual(lbPeriod.signLabel, "♑ Capricornio")
        XCTAssertEqual(nextPeriod.signLabel, "♈ Aries")
        XCTAssertTrue(lbPeriod.events.contains { $0.kind == .loosingOfBond })
        XCTAssertTrue(timeline.highlightedEvents.contains { $0.kind == .loosingOfBond && $0.date == lbPeriod.endDate })
    }

    func testAge49ExpectedL1Chapters() throws {
        let chart = try zrReferenceChart()
        let date = zrLocalDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        let engine = ZodiacalReleasingEngine()

        let fortuneL1 = try XCTUnwrap(engine.zr(chart: chart, lot: .fortune, depth: 2).currentL1(at: date))
        let spiritL1 = try XCTUnwrap(engine.zr(chart: chart, lot: .spirit, depth: 2).currentL1(at: date))

        XCTAssertEqual(fortuneL1.signLabel, "♑ Capricornio")
        XCTAssertEqual(fortuneL1.startDate, zrLocalDate(year: 2011, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
        XCTAssertEqual(fortuneL1.endDate, zrLocalDate(year: 2038, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))

        XCTAssertEqual(spiritL1.signLabel, "♒ Acuario")
        XCTAssertEqual(spiritL1.startDate, zrLocalDate(year: 2003, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
        XCTAssertEqual(spiritL1.endDate, zrLocalDate(year: 2033, month: 10, day: 11, hour: 20, minute: 33, timezoneName: "Europe/Madrid"))
    }

    func testDepthThreeAndFourExposeNestedLevelsWithoutChangingDefaultUIContract() throws {
        let chart = try zrReferenceChart()
        let engine = ZodiacalReleasingEngine()
        let depth3 = engine.zr(chart: chart, lot: .fortune, depth: 3)
        let depth4 = engine.zr(chart: chart, lot: .fortune, depth: 4)

        let l3 = try XCTUnwrap(depth3.periods.first?.children.first?.children.first)
        XCTAssertEqual(l3.level, .l3)
        XCTAssertFalse(l3.children.contains { $0.level == .l4 })

        let l4 = try XCTUnwrap(depth4.periods.first?.children.first?.children.first?.children.first)
        XCTAssertEqual(l4.level, .l4)
    }

    func testJoplinClipperCreatesZodiacalReleasingNotePayload() async throws {
        let chart = try zrReferenceChart()
        let date = zrLocalDate(year: 2026, month: 5, day: 14, hour: 12, timezoneName: "Europe/Madrid")
        let timeline = ZodiacalReleasingEngine().zr(chart: chart, lot: .fortune, depth: 2)
        let title = ZRNoteBuilder.noteTitle(chart: chart, timeline: timeline, date: date)
        let body = ZRNoteBuilder.markdown(chart: chart, timeline: timeline, date: date)
        let client = ZRMockJoplinHTTPClient(responses: [
            #"{"items":[{"id":"folder-1","title":"codex"}],"has_more":false}"#,
            #"{"id":"note-1"}"#,
        ])
        let service = JoplinClipperService(
            settings: JoplinClipperSettings(
                host: "127.0.0.1",
                port: 41184,
                token: "secret",
                notebook: "codex"
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
        XCTAssertTrue(body.contains("## Próximos eventos destacados"))
        XCTAssertTrue(body.contains("LB"))
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class ZRMockJoplinHTTPClient: JoplinHTTPClient {
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

private func zrReferenceChart() throws -> NatalChart {
    let jdResult = try julianDayFromLocal(
        birthDate: "1976-10-11",
        birthTime: "20:33",
        timezoneName: "Europe/Madrid"
    )
    var chart = try AstroEngine.computeNatalChart(
        jd: jdResult.jd,
        lat: 40.4168,
        lon: -3.7038
    )
    chart.name = "Referencia"
    chart.birthDate = "1976-10-11"
    chart.birthTime = "20:33"
    chart.timezone = "Europe/Madrid"
    chart.placeName = "Madrid"
    return chart
}

private func zrLocalDate(
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
