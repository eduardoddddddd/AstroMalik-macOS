import XCTest
@testable import AstroMalik

final class RectificationProfessionalTests: XCTestCase {
    func testQuestionnaireProducesDeterministicPreliminarySign() {
        let questionnaire = AscendantQuestionnaire(answers: [
            "presence": "direct", "reaction": "lead", "pace": "fast",
            "focus": "action", "conflict": "confront",
        ])
        XCTAssertEqual(questionnaire.preliminarySignIndex, 0)
        XCTAssertEqual(questionnaire.preliminarySignLabel, "♈ Aries")
        XCTAssertEqual(questionnaire.completion, 1)
    }

    func testQuestionnaireScorerFavoursMatchingAscendant() throws {
        let event = RectificationEvent(type: .identityShift, title: "Cambio", dateStart: Date(timeIntervalSince1970: 1_000_000), precision: .exactDay)
        let questionnaire = AscendantQuestionnaire(answers: ["presence": "direct", "reaction": "lead", "pace": "fast", "focus": "action", "conflict": "confront"])
        let session = makeSession(events: [event], questionnaire: questionnaire)
        let scorer = AscendantQuestionnaireScorer()
        let matching = try scorer.evidence(candidate: makeCandidate(ascendant: 1), session: session, config: .default)
        let different = try scorer.evidence(candidate: makeCandidate(ascendant: 91), session: session, config: .default)
        XCTAssertGreaterThan(matching[0].score, different[0].score)
    }

    func testProfectionConfirmationUsesActivatedEventHouse() throws {
        let event = RectificationEvent(type: .identityShift, title: "Identidad", dateStart: Date(timeIntervalSince1970: 86_400), precision: .exactDay)
        let session = makeSession(events: [event])
        let evidence = try ProfectionRectificationScorer().evidence(candidate: makeCandidate(ascendant: 1), session: session, config: .default)
        XCTAssertEqual(evidence.first?.technique, .profections)
        XCTAssertEqual(evidence.first?.debugData["house"], "1")
    }

    func testSchoolPresetsShiftTechniquePriorities() {
        var config = RectificationConfig.default
        config.applySchoolPreset(.traditional)
        XCTAssertGreaterThan(config.techniqueWeights[.primaryDirections]!, config.techniqueWeights[.transitsToAngles]!)
        config.applySchoolPreset(.modern)
        XCTAssertGreaterThan(config.techniqueWeights[.solarArc]!, config.techniqueWeights[.firdaria]!)
    }

    func testAntiOverfittingCalibrationCorpusPenalizesConcentrationAndComplexity() {
        let url = Bundle.module.url(forResource: "RectificationCalibrationCases", withExtension: "json")!
        let cases = try! JSONDecoder().decode([CalibrationCase].self, from: Data(contentsOf: url))
        XCTAssertEqual(cases.count, 3)
        for fixture in cases {
            let eventScores = Dictionary(uniqueKeysWithValues: fixture.eventScores.map { (UUID(), $0) })
            let techniques = Array(RectificationTechnique.allCases.prefix(fixture.techniqueScores.count))
            let techniqueScores = Dictionary(uniqueKeysWithValues: zip(techniques, fixture.techniqueScores).map { ($0, $1) })
            let diagnostics = RectificationOverfittingAnalyzer.diagnostics(
                rawScore: fixture.rawScore,
                eventScores: eventScores,
                techniqueScores: techniqueScores,
                enabledTechniqueCount: fixture.enabledTechniqueCount,
                config: .default
            )
            if fixture.expectedPenalty == "none" { XCTAssertEqual(diagnostics.penalty, 0, fixture.id) }
            else { XCTAssertGreaterThan(diagnostics.penalty, 0, fixture.id) }
        }
    }

    func testVersionOneJSONWithoutProfessionalFieldsStillDecodes() throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let original = makeSession(events: [])
        var sessionJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(original)) as? [String: Any])
        sessionJSON.removeValue(forKey: "ascendantQuestionnaire")
        let decodedSession = try decoder.decode(RectificationSession.self, from: JSONSerialization.data(withJSONObject: sessionJSON))
        XCTAssertNil(decodedSession.ascendantQuestionnaire)

        var configJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(RectificationConfig.default)) as? [String: Any])
        configJSON.removeValue(forKey: "school")
        configJSON.removeValue(forKey: "overfittingPenaltyStrength")
        let decodedConfig = try decoder.decode(RectificationConfig.self, from: JSONSerialization.data(withJSONObject: configJSON))
        XCTAssertEqual(decodedConfig.resolvedSchool, .balanced)
        XCTAssertEqual(decodedConfig.resolvedOverfittingPenaltyStrength, 0.35)
    }

    func testProfessionalConfigurationAndQuestionnaireValidation() throws {
        var config = RectificationConfig.default
        config.overfittingPenaltyStrength = 1.2
        XCTAssertThrowsError(try config.validate())
        let invalid = AscendantQuestionnaire(answers: ["presence": "invented"])
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertNoThrow(try AscendantQuestionnaire(answers: ["presence": "direct"]).validate())
    }

    func testProfessionalConfirmationScorersExecuteOnReferenceChart() throws {
        let chart = try ReportTestSupport.referenceChart()
        let event = RectificationEvent(
            type: .careerStart, title: "Trabajo",
            dateStart: ISO8601DateFormatter().date(from: "2010-06-15T12:00:00Z")!,
            precision: .exactDay
        )
        let session = RectificationSession(
            name: "Referencia", birthDate: chart.birthDate, reportedBirthTime: chart.birthTime,
            timezone: chart.timezone, latitude: chart.latitude, longitude: chart.longitude,
            placeName: chart.placeName, searchRange: .init(centerTime: chart.birthTime), events: [event]
        )
        let candidate = RectificationCandidate(
            id: UUID(), birthTime: chart.birthTime, chart: chart,
            ascendantLongitude: chart.ascendant.longitude, mcLongitude: chart.mc.longitude,
            ascendantFormatted: chart.ascendant.formatted, mcFormatted: chart.mc.formatted,
            totalScore: 0, confidenceBand: .inconclusive, techniqueScores: [:], eventScores: [:], evidence: [], warnings: []
        )
        let scorers: [any RectificationTechniqueScorer] = [
            FirdariaRectificationScorer(), ZodiacalReleasingRectificationScorer(),
            LotsRectificationScorer(), SolarReturnRectificationScorer(),
        ]
        for scorer in scorers {
            let evidence = try scorer.evidence(candidate: candidate, session: session, config: .default)
            XCTAssertTrue(evidence.allSatisfy { $0.technique == scorer.technique })
        }
    }

    private func makeSession(events: [RectificationEvent], questionnaire: AscendantQuestionnaire? = nil) -> RectificationSession {
        RectificationSession(
            name: "Profesional", birthDate: "1970-01-01", reportedBirthTime: "00:00",
            timezone: "UTC", latitude: 0, longitude: 0, placeName: "Test",
            searchRange: .init(centerTime: "00:00"), events: events,
            ascendantQuestionnaire: questionnaire,
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeCandidate(ascendant: Double) -> RectificationCandidate {
        var chart = NatalChart.placeholder
        chart.birthDate = "1970-01-01"; chart.birthTime = "00:00"; chart.timezone = "UTC"
        chart.ascendant = .init(longitude: ascendant, formatted: AstroEngine.degToSign(ascendant))
        chart.createdAt = Date(timeIntervalSince1970: 0)
        return RectificationCandidate(
            id: UUID(), birthTime: "00:00:00", chart: chart,
            ascendantLongitude: ascendant, mcLongitude: 270,
            ascendantFormatted: AstroEngine.degToSign(ascendant), mcFormatted: AstroEngine.degToSign(270),
            totalScore: 0, confidenceBand: .inconclusive, techniqueScores: [:], eventScores: [:], evidence: [], warnings: []
        )
    }

    private struct CalibrationCase: Decodable {
        let id: String
        let rawScore: Double
        let eventScores: [Double]
        let techniqueScores: [Double]
        let enabledTechniqueCount: Int
        let expectedPenalty: String
    }
}
