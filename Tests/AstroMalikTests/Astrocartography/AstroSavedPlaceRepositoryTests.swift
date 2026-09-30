import XCTest
@testable import AstroMalik

final class AstroSavedPlaceRepositoryTests: XCTestCase {
    private var directory: URL!
    private var db: SQLiteDB!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        db = try SQLiteDB(path: directory.appendingPathComponent("isolated-user.db").path)
    }
    override func tearDownWithError() throws {
        db = nil; try FileManager.default.removeItem(at: directory)
    }
    func testSaveLoadRestartUpdateDeleteAndOtherChartsUntouched() throws {
        let repo = try AstroSavedPlaceRepository(db: db)
        let chart = UUID(), other = UUID(), saved = try fixture(chart: chart)
        let id = try repo.save(chartID: chart, fingerprint: "fingerprint", intent: saved.intent, calculation: saved.calculation, revision: "revision")
        let otherID = try repo.save(chartID: other, fingerprint: "other", intent: saved.intent, calculation: saved.calculation, revision: "revision")
        XCTAssertThrowsError(try repo.save(id: otherID, chartID: chart, fingerprint: "fingerprint", intent: saved.intent,
                                          calculation: saved.calculation, revision: "revision"))
        let reopenedDB = try SQLiteDB(path: db.path)
        let reopened = try AstroSavedPlaceRepository(db: reopenedDB)
        let loaded = try reopened.load(chartID: chart, fingerprint: "fingerprint", revision: "revision")
        XCTAssertTrue(loaded.warnings.isEmpty); XCTAssertEqual(loaded.places.count, 1)
        XCTAssertEqual(loaded.places[0].id, id); XCTAssertEqual(loaded.places[0].calculation, saved.calculation)
        XCTAssertFalse(loaded.places[0].requiresRecalculation)
        let changed = AstroSavedPlaceIntent(place: AstroPlace(name: "Updated", coordinate: saved.intent.place.coordinate,
            origin: .manual, timeZone: try AstroDestinationTimeZone()), bodies: [.sun], angles: [], proximityPolicy: try AstroProximityPolicy(nearKm: 40, regionalKm: 200))
        _ = try repo.save(id: id, chartID: chart, fingerprint: "fingerprint", intent: changed, calculation: saved.calculation, revision: "revision")
        let updated = try repo.load(chartID: chart, fingerprint: "fingerprint", revision: "revision")
        XCTAssertEqual(updated.places.count, 1); XCTAssertEqual(updated.places[0].intent, changed)
        try repo.delete(id: otherID, chartID: chart) // cross-chart deletion is protected
        XCTAssertEqual(try repo.load(chartID: other, fingerprint: "other", revision: "revision").places.count, 1)
        try repo.delete(id: id, chartID: chart)
        XCTAssertTrue(try repo.load(chartID: chart, fingerprint: "fingerprint", revision: "revision").places.isEmpty)
        try repo.deletePlaces(for: other)
        XCTAssertTrue(try repo.load(chartID: other, fingerprint: "other", revision: "revision").places.isEmpty)
    }
    func testNatalEditOrResourceRevisionInvalidatesResultButRetainsIntention() throws {
        let repo = try AstroSavedPlaceRepository(db: db), chart = UUID(), f = try fixture(chart: UUID())
        _ = try repo.save(chartID: chart, fingerprint: "before", intent: f.intent, calculation: f.calculation, revision: "revision")
        let edited = try repo.load(chartID: chart, fingerprint: "after", revision: "revision")
        XCTAssertEqual(edited.places[0].intent, f.intent); XCTAssertNil(edited.places[0].calculation); XCTAssertTrue(edited.places[0].requiresRecalculation)
        let revision = try repo.load(chartID: chart, fingerprint: "before", revision: "different")
        XCTAssertNil(revision.places[0].calculation)
        try repo.invalidateResults(for: chart, matching: "after")
        let reverted = try repo.load(chartID: chart, fingerprint: "before", revision: "revision")
        XCTAssertNil(reverted.places[0].calculation) // explicit natal save cannot resurrect old cached results
    }
    func testVersionOneMigrationIsIdempotentAndPreservesNatalData() throws {
        try db.execute("CREATE TABLE saved_charts (id TEXT PRIMARY KEY, chart_json TEXT); INSERT INTO saved_charts VALUES ('test-natal','DO NOT MODIFY');")
        try db.execute("CREATE TABLE astrocartography_schema (id INTEGER PRIMARY KEY, version INTEGER); INSERT INTO astrocartography_schema VALUES (1,1)")
        try db.execute("CREATE TABLE astrocartography_saved_places (id TEXT PRIMARY KEY,chart_id TEXT,intent_json TEXT,provenance_json TEXT,created_at REAL)")
        let chart = UUID(), f = try fixture(chart: chart), id = UUID()
        let provenance = AstroSavedPlaceProvenance(contractVersion: 1, calculationRevision: "revision", distanceAlgorithm: AstroLocationAnalyzer.algorithmVersion,
            relocationAlgorithm: AstroRelocationEngine.algorithmVersion, savedAt: Date(timeIntervalSince1970: 100))
        let encoder = JSONEncoder()
        try db.run("INSERT INTO astrocartography_saved_places VALUES (?,?,?,?,?)", args: [.text(id.uuidString),.text(chart.uuidString),
            .text(String(decoding: try encoder.encode(f.intent), as: UTF8.self)), .text(String(decoding: try encoder.encode(provenance), as: UTF8.self)), .real(100)])
        let repo = try AstroSavedPlaceRepository(db: db)
        try AstroSavedPlaceRepository.migrate(db)
        let loaded = try repo.load(chartID: chart, fingerprint: "new", revision: "revision")
        XCTAssertEqual(loaded.places[0].id, id); XCTAssertEqual(loaded.places[0].intent, f.intent)
        XCTAssertTrue(loaded.places[0].requiresRecalculation)
        XCTAssertEqual(try db.queryOne("SELECT chart_json FROM saved_charts")?["chart_json"]?.string, "DO NOT MODIFY")
        XCTAssertEqual(try db.queryOne("SELECT version FROM astrocartography_schema")?["version"]?.int, 2)
    }
    func testFutureSchemaRejectedWithoutModification() throws {
        try db.execute("CREATE TABLE astrocartography_schema (id INTEGER PRIMARY KEY,version INTEGER); INSERT INTO astrocartography_schema VALUES (1,99)")
        XCTAssertThrowsError(try AstroSavedPlaceRepository(db: db))
        XCTAssertEqual(try db.queryOne("SELECT version FROM astrocartography_schema")?["version"]?.int, 99)
        XCTAssertNil(try db.queryOne("SELECT name FROM sqlite_master WHERE name='astrocartography_saved_places'"))
    }
    func testCorruptRowsArePreservedAndInvalidResultFallsBackToIntention() throws {
        let repo = try AstroSavedPlaceRepository(db: db), chart = UUID(), f = try fixture(chart: UUID())
        let id = try repo.save(chartID: chart, fingerprint: "fingerprint", intent: f.intent, calculation: f.calculation, revision: "revision")
        try db.run("UPDATE astrocartography_saved_places SET result_json='broken' WHERE id=?", args: [.text(id.uuidString)])
        var loaded = try repo.load(chartID: chart, fingerprint: "fingerprint", revision: "revision")
        XCTAssertEqual(loaded.places.count, 1); XCTAssertNil(loaded.places[0].calculation); XCTAssertEqual(loaded.warnings.count, 1)
        try db.run("UPDATE astrocartography_saved_places SET intent_json='broken' WHERE id=?", args: [.text(id.uuidString)])
        loaded = try repo.load(chartID: chart, fingerprint: "fingerprint", revision: "revision")
        XCTAssertTrue(loaded.places.isEmpty); XCTAssertEqual(loaded.warnings.count, 1)
        XCTAssertEqual(try db.query("SELECT * FROM astrocartography_saved_places").count, 1)
    }
    func testMalformedFiniteButInvalidDataRejectedAndDecodedCoordinatesValidated() throws {
        let repo = try AstroSavedPlaceRepository(db: db), f = try fixture(chart: UUID())
        let a = f.calculation.analysis
        let bad = AstroLocationCalculation(analysis: LocationAnalysis(request: a.request, location: a.location,
            proximities: [AstroLineProximity(lineID: AstroLineID(body: .sun, angle: .mc), distanceKm: -1,
                nearestPoint: a.location, estimatedErrorKm: 0)], sphereRadiusKm: 6371.0088), relocation: nil, relocationError: nil)
        XCTAssertThrowsError(try repo.save(chartID: UUID(), fingerprint: "x", intent: f.intent, calculation: bad, revision: "r"))
        let badPolicy = "{\"nearKm\":500,\"regionalKm\":200}"
        XCTAssertThrowsError(try JSONDecoder().decode(AstroProximityPolicy.self, from: Data(badPolicy.utf8)))
        let badPlace = "{\"name\":\"bad\",\"coordinate\":{\"latitude\":100,\"longitude\":0},\"origin\":\"manual\",\"timeZone\":{\"identifier\":\"UTC\",\"isVerified\":false}}"
        XCTAssertThrowsError(try JSONDecoder().decode(AstroPlace.self, from: Data(badPlace.utf8)))
    }
    func testTransactionRollbackPreservesPlacesWhenNatalDeleteFails() throws {
        let repo = try AstroSavedPlaceRepository(db: db), chart = UUID(), f = try fixture(chart: UUID())
        _ = try repo.save(chartID: chart, fingerprint: "x", intent: f.intent, calculation: f.calculation, revision: "r")
        try db.execute("BEGIN IMMEDIATE")
        do {
            try repo.deletePlaces(for: chart)
            try db.execute("DELETE FROM missing_natal_table")
            try db.execute("COMMIT")
            XCTFail("must fail")
        } catch { try db.execute("ROLLBACK") }
        XCTAssertEqual(try repo.load(chartID: chart, fingerprint: "x", revision: "r").places.count, 1)
    }
    @MainActor
    func testUserStoreIsolatedLifecyclePreventsOrphansAndInvalidatesOnEditAndRename() async throws {
        let store = try UserStore(database: db)
        var natal = NatalChart.placeholder
        natal.birthDate = "2000-01-01"; natal.birthTime = "12:00"; natal.timezone = "UTC"
        let f = try fixture(chart: natal.id), fingerprint = try AstroNatalFingerprint.make(natal)
        XCTAssertThrowsError(try store.saveAstroPlace(chartID: natal.id, fingerprint: fingerprint, intent: f.intent, calculation: f.calculation, revision: "r"))
        try store.save(natal); await store.load()
        _ = try store.saveAstroPlace(chartID: natal.id, fingerprint: fingerprint, intent: f.intent, calculation: f.calculation, revision: "r")
        XCTAssertNotNil(try store.loadAstroPlaces(chartID: natal.id, fingerprint: fingerprint, revision: "r").places[0].calculation)
        natal.latitude = 1
        XCTAssertThrowsError(try store.saveAstroPlace(chartID: natal.id, fingerprint: AstroNatalFingerprint.make(natal), intent: f.intent, calculation: f.calculation, revision: "r"))
        try store.save(natal); await store.load()
        XCTAssertNil(try store.loadAstroPlaces(chartID: natal.id, fingerprint: fingerprint, revision: "r").places[0].calculation)
        try store.rename(id: natal.id, name: "Renamed isolated")
        await store.load()
        XCTAssertEqual(store.savedCharts[0].name, "Renamed isolated")
        try store.delete(natal); await store.load()
        XCTAssertTrue(store.savedCharts.isEmpty)
        XCTAssertTrue(try store.loadAstroPlaces(chartID: natal.id, fingerprint: fingerprint, revision: "r").places.isEmpty)
    }
    @MainActor
    func testFutureAstroSchemaDoesNotDisableNatalStorage() async throws {
        try db.execute("CREATE TABLE astrocartography_schema (id INTEGER PRIMARY KEY,version INTEGER); INSERT INTO astrocartography_schema VALUES (1,99)")
        let store = try UserStore(database: db)
        let natal = NatalChart.placeholder
        try store.save(natal); await store.load()
        XCTAssertEqual(store.savedCharts.count, 1)
        XCTAssertThrowsError(try store.loadAstroPlaces(chartID: natal.id, fingerprint: "x", revision: "r"))
        try store.delete(natal); await store.load()
        XCTAssertTrue(store.savedCharts.isEmpty)
    }

    private func fixture(chart: UUID) throws -> (intent: AstroSavedPlaceIntent, calculation: AstroLocationCalculation) {
        let place = try AstroPlace(name: "Synthetic destination", coordinate: GeoCoordinate(latitude: 0, longitude: -180), origin: .manual, timeZone: AstroDestinationTimeZone())
        let request = try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: 2451545), bodies: [.sun])
        let analysis = LocationAnalysis(request: request, location: place.coordinate,
            proximities: [AstroLineProximity(lineID: AstroLineID(body: .sun, angle: .mc), distanceKm: 12.3,
                nearestPoint: place.coordinate, estimatedErrorKm: 1.000001)], sphereRadiusKm: 6371.0088)
        let intent = AstroSavedPlaceIntent(place: place, bodies: [.sun], angles: [.mc], proximityPolicy: try AstroProximityPolicy())
        return (intent, AstroLocationCalculation(analysis: analysis, relocation: nil, relocationError: "synthetic polar"))
    }
}
