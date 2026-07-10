import XCTest
@testable import AstroMalik

final class RectificationPersistenceTests: XCTestCase {
    func testBundledMigrationCreatesRectificationTables() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rect-migration-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let userURL = directory.appendingPathComponent("user.db")
        let result = try MigrationRunner.applyAll(config: .init(
            corpusWritableURL: directory.appendingPathComponent("corpus.db"),
            userDBURL: userURL,
            resourceBundle: AppResources.bundle
        ))
        XCTAssertTrue(result.applied.contains("007_rectification_sessions.sql"))
        XCTAssertTrue(result.failed.isEmpty)
        let db = try SQLiteDB(path: userURL.path, readonly: true)
        let tables = try db.query("SELECT name FROM sqlite_master WHERE type='table'").compactMap { $0["name"]?.string }
        XCTAssertTrue(tables.contains("rectification_sessions"))
        XCTAssertTrue(tables.contains("rectification_analysis_versions"))
    }

    func testStoreRoundTripVersionsAndDelete() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rectification-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try RectificationSessionStore(path: url.path)
        let fixture = makeFixture()
        XCTAssertEqual(try store.save(session: fixture.session, result: fixture.result, narrative: fixture.narrative), 1)
        XCTAssertEqual(try store.save(session: fixture.session, result: fixture.result, narrative: fixture.narrative), 1)
        var changed = fixture.result
        changed.computeTimeSeconds = 2
        XCTAssertEqual(try store.save(session: fixture.session, result: changed, narrative: fixture.narrative), 2)
        let list = try store.list()
        XCTAssertEqual(list.first?.versionCount, 2)
        XCTAssertTrue(list.first?.hasResult == true)
        let loaded = try store.load(id: fixture.session.id)
        XCTAssertEqual(loaded.session, fixture.session)
        XCTAssertEqual(loaded.result, changed)
        XCTAssertEqual(loaded.narrative, fixture.narrative)
        try store.delete(id: fixture.session.id)
        XCTAssertTrue(try store.list().isEmpty)
    }

    func testVersionedJSONExportImport() throws {
        let firstURL = FileManager.default.temporaryDirectory.appendingPathComponent("rect-a-\(UUID()).sqlite")
        let secondURL = FileManager.default.temporaryDirectory.appendingPathComponent("rect-b-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: firstURL); try? FileManager.default.removeItem(at: secondURL) }
        let fixture = makeFixture(); let first = try RectificationSessionStore(path: firstURL.path)
        _ = try first.save(session: fixture.session, result: fixture.result, narrative: fixture.narrative)
        let data = try first.exportArchive(id: fixture.session.id)
        let second = try RectificationSessionStore(path: secondURL.path)
        let imported = try second.importArchive(data)
        XCTAssertEqual(imported.session.id, fixture.session.id)
        XCTAssertEqual(try second.list().count, 1)
    }

    func testReportHTMLAndJoplinMarkdownContainTraceability() {
        let fixture = makeFixture()
        let html = RectificationReportBuilder.html(session: fixture.session, result: fixture.result, narrative: fixture.narrative)
        XCTAssertTrue(html.contains("Hipótesis astrológica"))
        XCTAssertTrue(html.contains("12:01:00"))
        XCTAssertTrue(html.contains("Comparación narrativa"))
        let markdown = RectificationNoteBuilder.markdown(session: fixture.session, result: fixture.result, narrative: fixture.narrative)
        XCTAssertTrue(markdown.contains("# Rectificación natal"))
        XCTAssertTrue(markdown.contains("mock-model"))
    }

    @MainActor
    func testRectificationReportGeneratesPDF() async throws {
        let fixture = makeFixture()
        let data = try await RectificationReportBuilder.generate(
            session: fixture.session,
            result: fixture.result,
            narrative: fixture.narrative
        )
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1_000)
    }

    private func makeFixture() -> (session: RectificationSession, result: RectificationAnalysisResult, narrative: RectificationNarrative) {
        let event = RectificationEvent(type: .careerStart, title: "Trabajo", dateStart: Date(timeIntervalSince1970: 1_600_000_000), precision: .exactDay)
        let session = RectificationSession(id: UUID(), name: "Persistencia", birthDate: "1980-01-01", reportedBirthTime: "12:00", timezone: "UTC", latitude: 0, longitude: 0, placeName: "Test", searchRange: .init(centerTime: "12:00"), events: [event], createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        var chart = NatalChart.placeholder
        chart.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let candidate = RectificationCandidate(id: UUID(), birthTime: "12:01:00", chart: chart, ascendantLongitude: 0, mcLongitude: 90, ascendantFormatted: "Aries", mcFormatted: "Cáncer", totalScore: 42, confidenceBand: .medium, techniqueScores: [.solarArc: 42], eventScores: [event.id: 42], evidence: [], warnings: [])
        let result = RectificationAnalysisResult(schemaVersion: 1, sessionID: session.id, candidates: [candidate], topCandidate: candidate, overallConfidence: .medium, clusters: [], eventCoverage: [event.id: 1], sectCrossingDetected: false, warnings: [], analysisDate: Date(timeIntervalSince1970: 1_700_000_100), configUsed: .default, computeTimeSeconds: 1)
        let narrative = RectificationNarrative(markdown: "## Comparación narrativa", provider: .anthropic, model: "mock-model", inputTokens: 10, outputTokens: 5, estimatedCostUSD: 0.01, generatedAt: Date(timeIntervalSince1970: 1_700_000_200))
        return (session, result, narrative)
    }
}
