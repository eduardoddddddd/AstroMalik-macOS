import XCTest
@testable import AstroMalik

final class RectificationEngineTests: XCTestCase {
    func testCandidateGeneratorProducesInclusiveCoarseRangeAndFineDeduplication() async throws {
        let session = makeSession(
            birthDate: "1976-10-11",
            birthTime: "20:33:15",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            minutes: 10
        )
        let generator = RectificationCandidateGenerator()
        let coarse = try await generator.coarseCandidates(session: session, config: quickConfig())
        XCTAssertEqual(coarse.count, 5)
        XCTAssertEqual(Set(coarse.map(\.birthTime)).count, 5)
        XCTAssertTrue(coarse.allSatisfy { $0.chart.birthTime == $0.birthTime })

        let fine = try await generator.fineCandidates(
            around: Array(coarse.prefix(2)),
            session: session,
            config: quickConfig()
        )
        XCTAssertEqual(Set(fine.map(\.birthTime)).count, fine.count)
        XCTAssertTrue(fine.count > 2)
        XCTAssertTrue(fine.allSatisfy { $0.birthTime >= "20:23:15" && $0.birthTime <= "20:43:15" })
    }

    func testCandidateGeneratorHandlesMidnightWithoutLosingCalendarDate() async throws {
        let session = makeSession(
            birthDate: "2000-01-01",
            birthTime: "00:03:00",
            timezone: "UTC",
            latitude: 51.5,
            longitude: -0.12,
            minutes: 10
        )
        let candidates = try await RectificationCandidateGenerator().coarseCandidates(session: session, config: quickConfig())
        XCTAssertTrue(candidates.contains { $0.chart.birthDate == "1999-12-31" })
        XCTAssertTrue(candidates.contains { $0.chart.birthDate == "2000-01-01" })
    }

    func testFullDayGeneratorRespectsDSTCivilDayLength() async throws {
        var session = makeSession(
            birthDate: "2026-03-29",
            birthTime: "12:00:00",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            minutes: 10
        )
        session.searchRange.includeFullDayFallback = true
        session.searchRange.coarseStepSeconds = 900
        let candidates = try await RectificationCandidateGenerator().coarseCandidates(session: session, config: quickConfig())
        XCTAssertEqual(candidates.count, 92, "El día local del salto DST contiene 23 horas")
        XCTAssertFalse(candidates.contains { $0.birthTime.hasPrefix("02:") })
    }

    func testSymbolismRulesDistinguishStrongAndWeakCareerContacts() {
        let event = makeEvent(type: .promotion, title: "Ascenso", date: date("2015-04-10"))
        XCTAssertEqual(
            RectificationSymbolismRules.symbolicFit(event: event, sourceKey: "JUPITER", targetKey: "MC"),
            .strong
        )
        XCTAssertEqual(
            RectificationSymbolismRules.symbolicFit(event: event, sourceKey: "VENUS", targetKey: "ASC"),
            .weak
        )
    }

    func testEngineRanksCandidatesAndKeepsOnlyStrongestEvidencePerEventTechnique() async throws {
        let session = makeSession(
            birthDate: "1976-10-11",
            birthTime: "20:33:00",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            minutes: 10
        )
        let result = try await RectificationEngine().analyze(session: session, config: quickConfig())
        XCTAssertFalse(result.candidates.isEmpty)
        XCTAssertEqual(result.topCandidate?.id, result.candidates.first?.id)
        XCTAssertEqual(result.candidates.map(\.totalScore), result.candidates.map(\.totalScore).sorted(by: >))
        if let top = result.topCandidate {
            let keys = top.evidence.map { "\($0.eventID)|\($0.technique.rawValue)" }
            XCTAssertEqual(Set(keys).count, keys.count)
        }
        XCTAssertFalse(result.clusters.isEmpty)
    }

    func testTwoIndependentReferenceChartsCompleteDeterministicAnalysis() async throws {
        let madrid = makeSession(
            birthDate: "1976-10-11", birthTime: "20:33:00", timezone: "Europe/Madrid",
            latitude: 40.4168, longitude: -3.7038, minutes: 5
        )
        let london = makeSession(
            birthDate: "1984-03-12", birthTime: "06:45:00", timezone: "Europe/London",
            latitude: 51.5074, longitude: -0.1278, minutes: 5
        )
        let engine = RectificationEngine()
        let first = try await engine.analyze(session: madrid, config: quickConfig())
        let second = try await engine.analyze(session: london, config: quickConfig())
        XCTAssertNotNil(first.topCandidate)
        XCTAssertNotNil(second.topCandidate)
        XCTAssertNotEqual(first.topCandidate?.ascendantLongitude, second.topCandidate?.ascendantLongitude)
        XCTAssertTrue(first.computeTimeSeconds >= 0)
        XCTAssertTrue(second.computeTimeSeconds >= 0)
    }

    func testPrimaryDirectionsAndProgressionsScorersReturnAuditableEvidence() async throws {
        let session = makeSession(
            birthDate: "1976-10-11", birthTime: "20:33:00", timezone: "Europe/Madrid",
            latitude: 40.4168, longitude: -3.7038, minutes: 5
        )
        let candidate = try await RectificationCandidateGenerator().coarseCandidates(session: session, config: fullConfig()).first!
        let pd = try PrimaryDirectionRectificationScorer().evidence(candidate: candidate, session: session, config: fullConfig())
        let progressions = try ProgressionRectificationScorer().evidence(candidate: candidate, session: session, config: fullConfig())
        XCTAssertTrue(pd.allSatisfy { $0.technique == .primaryDirections && !$0.debugData.isEmpty })
        XCTAssertTrue(progressions.allSatisfy { $0.technique == .secondaryProgressions && !$0.debugData.isEmpty })
    }

    private func makeSession(
        birthDate: String,
        birthTime: String,
        timezone: String,
        latitude: Double,
        longitude: Double,
        minutes: Int
    ) -> RectificationSession {
        RectificationSession(
            name: "Caso de referencia",
            birthDate: birthDate,
            reportedBirthTime: birthTime,
            timezone: timezone,
            latitude: latitude,
            longitude: longitude,
            placeName: "Referencia",
            searchRange: RectificationSearchRange(
                centerTime: birthTime,
                minutesBefore: minutes,
                minutesAfter: minutes,
                coarseStepSeconds: 300,
                fineStepSeconds: 60
            ),
            events: [
                makeEvent(type: .careerStart, title: "Inicio profesional", date: date("2001-05-10")),
                makeEvent(type: .relocation, title: "Mudanza", date: date("2010-09-01")),
                makeEvent(type: .marriage, title: "Relación", date: date("2018-06-15")),
            ]
        )
    }

    private func makeEvent(type: RectificationEventType, title: String, date: Date) -> RectificationEvent {
        RectificationEvent(type: type, title: title, dateStart: date, precision: .exactDay, importance: 4)
    }

    private func quickConfig() -> RectificationConfig {
        var config = RectificationConfig.default
        config.enabledTechniques = [.solarArc, .transitsToAngles]
        return config
    }

    private func fullConfig() -> RectificationConfig {
        .default
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
