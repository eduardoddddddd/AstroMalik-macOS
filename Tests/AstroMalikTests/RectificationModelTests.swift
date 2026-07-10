import XCTest
@testable import AstroMalik

final class RectificationModelTests: XCTestCase {
    func testValidSessionAndDefaultConfigurationPassValidation() throws {
        let session = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        XCTAssertNoThrow(try session.validate(config: .default))
    }

    func testSessionAndConfigurationRoundTripWithoutLosingSchema() throws {
        let session = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let sessionData = try encoder.encode(session)
        let decodedSession = try decoder.decode(RectificationSession.self, from: sessionData)
        XCTAssertEqual(decodedSession, session)
        XCTAssertEqual(decodedSession.schemaVersion, RectificationSession.currentSchemaVersion)

        let configData = try encoder.encode(RectificationConfig.default)
        let decodedConfig = try decoder.decode(RectificationConfig.self, from: configData)
        XCTAssertEqual(decodedConfig, .default)
        XCTAssertEqual(decodedConfig.schemaVersion, RectificationConfig.currentSchemaVersion)
    }

    func testValidationRejectsInsufficientEvents() {
        let session = makeSession(events: [makeEvent(0), makeEvent(1)])
        XCTAssertThrowsError(try session.validate(config: .default)) { error in
            XCTAssertEqual(
                error as? RectificationValidationError,
                .insufficientEvents(required: 3, actual: 2)
            )
        }
    }

    func testApproximateQuarterAndYearDoNotSatisfyMinimumReliableDataset() {
        var events = [makeEvent(0), makeEvent(1), makeEvent(2)]
        events[1].precision = .approximateQuarter
        events[2].precision = .approximateYear
        let session = makeSession(events: events)
        XCTAssertThrowsError(try session.validate(config: .default)) { error in
            XCTAssertEqual(
                error as? RectificationValidationError,
                .insufficientEvents(required: 3, actual: 1)
            )
        }
    }

    func testValidationRejectsInvalidFineStepAndExcessCandidateCount() {
        var wrongOrder = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        wrongOrder.searchRange.fineStepSeconds = 600
        XCTAssertThrowsError(try wrongOrder.validate(config: .default))

        var excessive = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        excessive.searchRange = RectificationSearchRange(
            centerTime: "12:00:00",
            minutesBefore: 1_440,
            minutesAfter: 1_440,
            coarseStepSeconds: 1,
            fineStepSeconds: 1
        )
        XCTAssertThrowsError(try excessive.validate(config: .default))
    }

    func testDateRangeEventRequiresOrderedEndDate() {
        var event = makeEvent(0)
        event.precision = .dateRange
        event.dateEnd = nil
        XCTAssertThrowsError(try event.validate())

        event.dateEnd = event.dateStart.addingTimeInterval(-1)
        XCTAssertThrowsError(try event.validate())

        event.dateEnd = event.dateStart.addingTimeInterval(86_400)
        XCTAssertNoThrow(try event.validate())
    }

    func testHouseSystemCodesAndCandidateEstimateAreDeterministic() {
        XCTAssertEqual(RectificationHouseSystem.placidus.swissEphemerisCode, "P")
        XCTAssertEqual(RectificationHouseSystem.wholeSign.swissEphemerisCode, "W")
        let range = RectificationSearchRange(
            centerTime: "12:00",
            minutesBefore: 60,
            minutesAfter: 60,
            coarseStepSeconds: 300,
            fineStepSeconds: 60
        )
        XCTAssertEqual(range.coarseCandidateEstimate, 25)
    }

    func testUnsupportedSchemaAndInvalidCoordinatesAreRejected() {
        var session = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        session.schemaVersion = 99
        XCTAssertThrowsError(try session.validate(config: .default)) { error in
            XCTAssertEqual(error as? RectificationValidationError, .unsupportedSessionSchema(99))
        }

        session.schemaVersion = RectificationSession.currentSchemaVersion
        session.latitude = 91
        XCTAssertThrowsError(try session.validate(config: .default)) { error in
            XCTAssertEqual(error as? RectificationValidationError, .invalidCoordinates)
        }
    }

    func testEventsBeforeBirthOrAfterAnalysisDateAreRejected() {
        var beforeBirth = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        beforeBirth.events[0].dateStart = Date(timeIntervalSince1970: 0)
        XCTAssertThrowsError(try beforeBirth.validate(
            config: .default,
            now: Date(timeIntervalSince1970: 2_000_000_000)
        ))

        var future = makeSession(events: [makeEvent(0), makeEvent(1), makeEvent(2)])
        future.events[0].dateStart = Date(timeIntervalSince1970: 2_100_000_000)
        XCTAssertThrowsError(try future.validate(
            config: .default,
            now: Date(timeIntervalSince1970: 2_000_000_000)
        ))
    }

    private func makeSession(events: [RectificationEvent]) -> RectificationSession {
        RectificationSession(
            name: "Sesión de prueba",
            birthDate: "1976-10-11",
            reportedBirthTime: "20:33:15",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            searchRange: RectificationSearchRange(centerTime: "20:33:15"),
            events: events,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeEvent(_ offset: Int) -> RectificationEvent {
        RectificationEvent(
            type: offset == 0 ? .marriage : (offset == 1 ? .relocation : .careerStart),
            title: "Evento \(offset)",
            dateStart: Date(timeIntervalSince1970: 1_000_000_000 + Double(offset * 31_536_000)),
            precision: .exactDay,
            importance: 4
        )
    }
}
