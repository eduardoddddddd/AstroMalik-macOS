import Foundation
import CryptoKit

/// Includes every persisted natal field, not merely ID/JD. Any edit invalidates
/// derived results while retaining the user's destination intention.
enum AstroNatalFingerprint {
    static func make(_ chart: NatalChart) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(chart)).map { String(format: "%02x", $0) }.joined()
    }
}
struct AstroSavedPlaceIntent: Codable, Equatable, Sendable {
    let place: AstroPlace
    let bodies: [AstroBody]
    let angles: [AstroAngle]
    let proximityPolicy: AstroProximityPolicy
    func validate() throws {
        guard !place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Set(bodies).count == bodies.count, Set(angles).count == angles.count else {
            throw AstrocartographyError.invalidValue("savedPlaceIntent")
        }
    }
}
struct AstroSavedPlaceProvenance: Codable, Equatable, Sendable {
    let contractVersion: Int
    let calculationRevision: String
    let distanceAlgorithm: String
    let relocationAlgorithm: String
    let savedAt: Date
}
struct AstroSavedPlace: Equatable, Identifiable, Sendable {
    let id: UUID
    let natalChartID: UUID
    let natalFingerprint: String
    let intent: AstroSavedPlaceIntent
    let provenance: AstroSavedPlaceProvenance
    /// Nil for stale/migrated result, never an unvalidated persisted calculation.
    let calculation: AstroLocationCalculation?
    let requiresRecalculation: Bool
}
struct AstroSavedPlaceLoad: Sendable {
    let places: [AstroSavedPlace]
    let warnings: [String]
}

/// Additive, independently versioned tables in user.db; never touches corpus or
/// natal records. Owned by UserStore/MainActor, no SQLite connection crosses tasks.
final class AstroSavedPlaceRepository {
    static let schemaVersion = 2
    private let db: SQLiteDB
    init(db: SQLiteDB) throws {
        self.db = db
        try Self.migrate(db)
    }
    static func migrate(_ db: SQLiteDB) throws {
        try db.execute("BEGIN IMMEDIATE")
        do {
            try db.execute("CREATE TABLE IF NOT EXISTS astrocartography_schema (id INTEGER PRIMARY KEY CHECK(id=1), version INTEGER NOT NULL)")
            let version = try db.queryOne("SELECT version FROM astrocartography_schema WHERE id=1")?["version"]?.int ?? 0
            guard version >= 0, version <= schemaVersion else { throw AstrocartographyError.invalidValue("futureSavedPlaceSchema") }
            // Version 1 stores intentions/provenance only. Version 2 adds natal
            // fingerprint + derived result; migrated intentions require recompute.
            try db.execute("""
                CREATE TABLE IF NOT EXISTS astrocartography_saved_places (
                    id TEXT PRIMARY KEY, chart_id TEXT NOT NULL,
                    intent_json TEXT NOT NULL, provenance_json TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """)
            let columns = Set(try db.query("PRAGMA table_info(astrocartography_saved_places)").compactMap { $0["name"]?.string })
            if !columns.contains("natal_fingerprint") { try db.execute("ALTER TABLE astrocartography_saved_places ADD COLUMN natal_fingerprint TEXT NOT NULL DEFAULT ''") }
            if !columns.contains("result_json") { try db.execute("ALTER TABLE astrocartography_saved_places ADD COLUMN result_json TEXT") }
            try db.execute("CREATE INDEX IF NOT EXISTS astrocartography_places_chart ON astrocartography_saved_places(chart_id)")
            try db.run("INSERT OR REPLACE INTO astrocartography_schema (id,version) VALUES (1,?)", args: [.integer(Int64(schemaVersion))])
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            throw error
        }
    }
    func save(id: UUID = UUID(), chartID: UUID, fingerprint: String, intent: AstroSavedPlaceIntent,
              calculation: AstroLocationCalculation, revision: String) throws -> UUID {
        try intent.validate()
        if let existingChart = try db.queryOne("SELECT chart_id FROM astrocartography_saved_places WHERE id=?", args: [.text(id.uuidString)])?["chart_id"]?.string,
           existingChart != chartID.uuidString { throw AstrocartographyError.invalidValue("crossChartSavedPlaceUpdate") }
        guard !fingerprint.isEmpty, !revision.isEmpty else { throw AstrocartographyError.invalidValue("savedPlaceProvenance") }
        try Self.validate(calculation, location: intent.place.coordinate, timeZone: intent.place.timeZone, chartID: chartID)
        let provenance = AstroSavedPlaceProvenance(contractVersion: AstrocartographyContract.version,
            calculationRevision: revision, distanceAlgorithm: AstroLocationAnalyzer.algorithmVersion,
            relocationAlgorithm: AstroRelocationEngine.algorithmVersion, savedAt: Date())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
        try db.run("""
            INSERT OR REPLACE INTO astrocartography_saved_places
            (id,chart_id,intent_json,provenance_json,created_at,natal_fingerprint,result_json) VALUES (?,?,?,?,?,?,?)
            """, args: [.text(id.uuidString), .text(chartID.uuidString), .text(try json(intent)),
                        .text(try json(provenance)), .real(provenance.savedAt.timeIntervalSince1970), .text(fingerprint), .text(try json(calculation))])
        return id
    }
    func load(chartID: UUID, fingerprint: String, revision: String) throws -> AstroSavedPlaceLoad {
        let rows = try db.query("SELECT * FROM astrocartography_saved_places WHERE chart_id=? ORDER BY created_at DESC,id", args: [.text(chartID.uuidString)])
        var places: [AstroSavedPlace] = [], warnings: [String] = []
        for row in rows {
            do {
                guard let rawID = row["id"]?.string, let id = UUID(uuidString: rawID),
                      let intentJSON = row["intent_json"]?.string, let provenanceJSON = row["provenance_json"]?.string else {
                    throw AstrocartographyError.invalidValue("savedPlaceRow")
                }
                let decoder = JSONDecoder()
                let intent = try decoder.decode(AstroSavedPlaceIntent.self, from: Data(intentJSON.utf8)); try intent.validate()
                let provenance = try decoder.decode(AstroSavedPlaceProvenance.self, from: Data(provenanceJSON.utf8))
                let savedFingerprint = row["natal_fingerprint"]?.string ?? ""
                let compatible = savedFingerprint == fingerprint && !fingerprint.isEmpty && provenance.calculationRevision == revision &&
                    provenance.contractVersion == AstrocartographyContract.version && provenance.distanceAlgorithm == AstroLocationAnalyzer.algorithmVersion &&
                    provenance.relocationAlgorithm == AstroRelocationEngine.algorithmVersion
                var calculation: AstroLocationCalculation?
                if compatible, let rawResult = row["result_json"]?.string {
                    do {
                        let decoded = try decoder.decode(AstroLocationCalculation.self, from: Data(rawResult.utf8))
                        try Self.validate(decoded, location: intent.place.coordinate, timeZone: intent.place.timeZone, chartID: chartID)
                        calculation = decoded
                    } catch { warnings.append("Resultado guardado dañado para \(intent.place.name); conserva intención y debe recalcularse.") }
                }
                places.append(AstroSavedPlace(id: id, natalChartID: chartID, natalFingerprint: savedFingerprint, intent: intent,
                    provenance: provenance, calculation: calculation, requiresRecalculation: calculation == nil))
            } catch { warnings.append("Un lugar guardado no se puede leer; sus datos se conservan sin modificar. ID: \(row["id"]?.string ?? "desconocido").") }
        }
        return AstroSavedPlaceLoad(places: places, warnings: warnings)
    }
    func delete(id: UUID, chartID: UUID) throws {
        try db.run("DELETE FROM astrocartography_saved_places WHERE id=? AND chart_id=?", args: [.text(id.uuidString),.text(chartID.uuidString)])
    }
    func deletePlaces(for chartID: UUID) throws {
        try db.run("DELETE FROM astrocartography_saved_places WHERE chart_id=?", args: [.text(chartID.uuidString)])
    }
    func invalidateResults(for chartID: UUID, matching fingerprint: String) throws {
        try db.run("UPDATE astrocartography_saved_places SET result_json=NULL WHERE chart_id=? AND natal_fingerprint<>?",
                   args: [.text(chartID.uuidString),.text(fingerprint)])
    }
    private static func validate(_ calculation: AstroLocationCalculation, location: GeoCoordinate, timeZone: AstroDestinationTimeZone, chartID: UUID) throws {
        let analysis = calculation.analysis
        guard analysis.location == location, analysis.sphereRadiusKm == AstroLocationAnalyzer.sphereRadiusKm,
              Set(analysis.proximities.map(\.lineID)).count == analysis.proximities.count,
              analysis.proximities.allSatisfy({ $0.distanceKm.isFinite && $0.distanceKm >= 0 &&
                  $0.distanceKm <= .pi * analysis.sphereRadiusKm + 0.001 && $0.estimatedErrorKm.isFinite && $0.estimatedErrorKm >= 0 &&
                  analysis.request.bodies.contains($0.lineID.body) }) else {
            throw AstrocartographyError.invalidValue("savedLocationAnalysis")
        }
        if let snapshot = calculation.curveSnapshot, snapshot.request != analysis.request {
            throw AstrocartographyError.snapshotMismatch
        }
        if let relocation = calculation.relocation {
            let r = relocation.chart
            guard relocation.source.natalChartID == chartID, r.natalChartID == chartID, r.instant == analysis.request.instant,
                  r.instant == relocation.source.instant, r.destination == location, relocation.destinationTimeZone == timeZone, r.houseSystem == relocation.source.houseSystem,
                  r.cuspsDegrees.count == 12, (r.cuspsDegrees + [r.ascendantDegrees,r.mcDegrees]).allSatisfy({ $0.isFinite && (0..<360).contains($0) }),
                  r.bodies.count == 10, Set(r.bodies.map(\.body)).count == 10, r.bodies.allSatisfy({ b in (1...12).contains(b.house) &&
                      relocation.source.bodies.contains(where: { $0.body == b.body && $0.longitudeDegrees == b.longitudeDegrees }) }) else {
                throw AstrocartographyError.invalidValue("savedRelocatedChart")
            }
        }
    }
}
