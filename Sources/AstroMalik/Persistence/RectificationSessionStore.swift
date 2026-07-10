import Foundation

struct SavedRectificationSession: Identifiable, Equatable {
    let id: UUID
    let name: String
    let baseChartID: UUID?
    let updatedAt: Date
    let hasResult: Bool
    let versionCount: Int
}

struct RectificationSessionArchive: Codable, Equatable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let session: RectificationSession
    let result: RectificationAnalysisResult?
    let narrative: RectificationNarrative?
}

final class RectificationSessionStore {
    private let db: SQLiteDB
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init() throws {
        let config = try MigrationRunner.Config.standard()
        try self.init(path: config.userDBURL.path)
    }

    init(path: String) throws {
        db = try SQLiteDB(path: path, readonly: false)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
        try Self.createTables(in: db)
    }

    static func createTables(in db: SQLiteDB) throws {
        try db.execute("""
        CREATE TABLE IF NOT EXISTS rectification_sessions (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, base_chart_id TEXT,
          session_json BLOB NOT NULL, result_json BLOB, narrative_json BLOB,
          created_at REAL NOT NULL, updated_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS rectification_analysis_versions (
          id TEXT PRIMARY KEY, session_id TEXT NOT NULL, version INTEGER NOT NULL,
          result_json BLOB NOT NULL, narrative_json BLOB, created_at REAL NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_rectification_versions_session_version
        ON rectification_analysis_versions(session_id, version);
        """)
    }

    func list() throws -> [SavedRectificationSession] {
        let rows = try db.query("""
        SELECT s.id, s.name, s.base_chart_id, s.updated_at,
               CASE WHEN s.result_json IS NULL THEN 0 ELSE 1 END AS has_result,
               (SELECT COUNT(*) FROM rectification_analysis_versions v WHERE v.session_id=s.id) AS version_count
        FROM rectification_sessions s ORDER BY s.updated_at DESC
        """)
        return rows.compactMap { row in
            guard let raw = row["id"]?.string, let id = UUID(uuidString: raw),
                  let name = row["name"]?.string, let timestamp = row["updated_at"]?.double else { return nil }
            return SavedRectificationSession(
                id: id, name: name,
                baseChartID: row["base_chart_id"]?.string.flatMap(UUID.init(uuidString:)),
                updatedAt: Date(timeIntervalSince1970: timestamp),
                hasResult: (row["has_result"]?.int ?? 0) == 1,
                versionCount: row["version_count"]?.int ?? 0
            )
        }
    }

    @discardableResult
    func save(session: RectificationSession, result: RectificationAnalysisResult?, narrative: RectificationNarrative?) throws -> Int {
        let sessionData = try encoder.encode(session)
        let resultData = try result.map(encoder.encode)
        let narrativeData = try narrative.map(encoder.encode)
        let canonicalResult = try resultData.map { try decoder.decode(RectificationAnalysisResult.self, from: $0) }
        let now = Date().timeIntervalSince1970
        try db.run("""
        INSERT INTO rectification_sessions(id,name,base_chart_id,session_json,result_json,narrative_json,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name, base_chart_id=excluded.base_chart_id,
          session_json=excluded.session_json, result_json=excluded.result_json,
          narrative_json=excluded.narrative_json, updated_at=excluded.updated_at
        """, args: [
            .text(session.id.uuidString), .text(session.name), session.baseChartID.map { .text($0.uuidString) } ?? .null,
            .blob(sessionData), resultData.map(SQLiteValue.blob) ?? .null,
            narrativeData.map(SQLiteValue.blob) ?? .null,
            .real(session.createdAt.timeIntervalSince1970), .real(now)
        ])
        guard let resultData else { return try versionCount(sessionID: session.id) }
        if try latestResult(sessionID: session.id) == canonicalResult {
            try db.run("""
            UPDATE rectification_analysis_versions SET narrative_json=?
            WHERE session_id=? AND version=(
              SELECT MAX(version) FROM rectification_analysis_versions WHERE session_id=?
            )
            """, args: [narrativeData.map(SQLiteValue.blob) ?? .null, .text(session.id.uuidString), .text(session.id.uuidString)])
            return try versionCount(sessionID: session.id)
        }
        let version = try versionCount(sessionID: session.id) + 1
        try db.run("""
        INSERT INTO rectification_analysis_versions(id,session_id,version,result_json,narrative_json,created_at)
        VALUES(?,?,?,?,?,?)
        """, args: [.text(UUID().uuidString), .text(session.id.uuidString), .integer(Int64(version)), .blob(resultData), narrativeData.map(SQLiteValue.blob) ?? .null, .real(now)])
        return version
    }

    func load(id: UUID) throws -> RectificationSessionArchive {
        guard let row = try db.queryOne("SELECT session_json,result_json,narrative_json FROM rectification_sessions WHERE id=?", args: [.text(id.uuidString)]),
              case .blob(let sessionData)? = row["session_json"] else {
            throw CocoaError(.fileNoSuchFile)
        }
        let result: RectificationAnalysisResult? = try decodeOptional(row["result_json"])
        let narrative: RectificationNarrative? = try decodeOptional(row["narrative_json"])
        return RectificationSessionArchive(schemaVersion: 1, session: try decoder.decode(RectificationSession.self, from: sessionData), result: result, narrative: narrative)
    }

    func delete(id: UUID) throws {
        try db.run("DELETE FROM rectification_analysis_versions WHERE session_id=?", args: [.text(id.uuidString)])
        try db.run("DELETE FROM rectification_sessions WHERE id=?", args: [.text(id.uuidString)])
    }

    func exportArchive(id: UUID) throws -> Data { try encoder.encode(load(id: id)) }

    func importArchive(_ data: Data) throws -> RectificationSessionArchive {
        let archive = try decoder.decode(RectificationSessionArchive.self, from: data)
        guard archive.schemaVersion == RectificationSessionArchive.currentSchemaVersion else {
            throw RectificationValidationError.unsupportedSessionSchema(archive.schemaVersion)
        }
        _ = try save(session: archive.session, result: archive.result, narrative: archive.narrative)
        return archive
    }

    private func versionCount(sessionID: UUID) throws -> Int {
        guard let row = try db.queryOne(
            "SELECT COUNT(*) AS count FROM rectification_analysis_versions WHERE session_id=?",
            args: [.text(sessionID.uuidString)]
        ) else { return 0 }
        return row["count"]?.int ?? 0
    }

    private func latestResult(sessionID: UUID) throws -> RectificationAnalysisResult? {
        let row = try db.queryOne(
            "SELECT result_json FROM rectification_analysis_versions WHERE session_id=? ORDER BY version DESC LIMIT 1",
            args: [.text(sessionID.uuidString)]
        )
        guard case .blob(let data)? = row?["result_json"] else { return nil }
        return try decoder.decode(RectificationAnalysisResult.self, from: data)
    }

    private func decodeOptional<T: Decodable>(_ value: SQLiteValue?) throws -> T? {
        guard case .blob(let data)? = value else { return nil }
        return try decoder.decode(T.self, from: data)
    }
}
