import Foundation
import SwiftUI

@MainActor
final class HoraryStore: ObservableObject {
    @Published var savedQueries: [SavedHoraryQuery] = []

    private var db: SQLiteDB?

    init() {
        Task { await self.setup() }
    }

    private func setup() async {
        do {
            let url = try Self.userDBURL()
            let queue = try SQLiteDB(path: url.path, readonly: false)
            try SavedHoraryQueryRecord.createTable(db: queue)
            db = queue
            await load()
        } catch {
            print("[HoraryStore] Error setup: \(error)")
        }
    }

    private static func userDBURL() throws -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("AstroMalik", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("user.db")
    }

    func load() async {
        guard let queue = db else { return }
        do {
            let records = try SavedHoraryQueryRecord.fetchAll(from: queue)
            savedQueries = records.compactMap { try? $0.toSavedHoraryQuery() }
        } catch {
            print("[HoraryStore] Error load: \(error)")
        }
    }

    func save(_ query: SavedHoraryQuery) throws {
        guard let queue = db else { return }
        let record = SavedHoraryQueryRecord(from: query)
        try record.save(to: queue)
        Task { await load() }
    }

    func delete(_ query: SavedHoraryQuery) throws {
        guard let queue = db else { return }
        try queue.run(
            "DELETE FROM saved_horary_queries WHERE id = ?",
            args: [.text(query.id.uuidString)]
        )
        Task { await load() }
    }
}

private struct SavedHoraryQueryRecord {
    let id: String
    let question: String
    let questionHouse: Int
    let datetimeLocal: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let placeName: String
    let includeFortune: Bool
    let chartJSON: String
    let judgementJSON: String
    let judgementText: String
    let calculatedAt: String
    let createdAt: Double

    init(from query: SavedHoraryQuery) {
        id = query.id.uuidString
        question = query.request.question
        questionHouse = query.request.questionHouse
        datetimeLocal = query.request.datetimeLocal
        timezone = query.request.timezone
        latitude = query.request.latitude
        longitude = query.request.longitude
        placeName = query.request.placeName
        includeFortune = query.request.includeFortune
        chartJSON = query.response.chartJSON
        judgementJSON = query.response.judgementJSON
        judgementText = query.response.judgementText
        calculatedAt = query.response.calculatedAt
        createdAt = query.createdAt.timeIntervalSince1970
    }

    func toSavedHoraryQuery() throws -> SavedHoraryQuery {
        try SavedHoraryQuery(
            id: UUID(uuidString: id) ?? UUID(),
            request: HoraryRequest(
                question: question,
                datetimeLocal: datetimeLocal,
                timezone: timezone,
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                questionHouse: questionHouse,
                includeFortune: includeFortune
            ),
            response: HoraryResponse(
                chartJSON: chartJSON,
                judgementJSON: judgementJSON,
                judgementText: judgementText,
                calculatedAt: calculatedAt
            ),
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    static func createTable(db: SQLiteDB) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS saved_horary_queries (
                id               TEXT PRIMARY KEY,
                question         TEXT NOT NULL,
                question_house   INTEGER NOT NULL,
                datetime_local   TEXT NOT NULL,
                timezone         TEXT NOT NULL,
                latitude         REAL NOT NULL,
                longitude        REAL NOT NULL,
                place_name       TEXT NOT NULL DEFAULT '',
                include_fortune  INTEGER NOT NULL,
                chart_json       TEXT NOT NULL,
                judgement_json   TEXT NOT NULL,
                judgement_text   TEXT NOT NULL,
                calculated_at    TEXT NOT NULL,
                created_at       REAL NOT NULL
            )
        """)
    }

    func save(to db: SQLiteDB) throws {
        let sql = """
            INSERT OR REPLACE INTO saved_horary_queries
            (id, question, question_house, datetime_local, timezone, latitude, longitude,
             place_name, include_fortune, chart_json, judgement_json, judgement_text,
             calculated_at, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        try db.run(sql, args: [
            .text(id),
            .text(question),
            .integer(Int64(questionHouse)),
            .text(datetimeLocal),
            .text(timezone),
            .real(latitude),
            .real(longitude),
            .text(placeName),
            .integer(includeFortune ? 1 : 0),
            .text(chartJSON),
            .text(judgementJSON),
            .text(judgementText),
            .text(calculatedAt),
            .real(createdAt),
        ])
    }

    static func fetchAll(from db: SQLiteDB) throws -> [SavedHoraryQueryRecord] {
        let rows = try db.query("SELECT * FROM saved_horary_queries ORDER BY created_at DESC")
        return rows.compactMap { row in
            guard let id = row["id"]?.string,
                  let question = row["question"]?.string,
                  let questionHouse = row["question_house"]?.int,
                  let datetimeLocal = row["datetime_local"]?.string,
                  let timezone = row["timezone"]?.string,
                  let latitude = row["latitude"]?.double,
                  let longitude = row["longitude"]?.double,
                  let chartJSON = row["chart_json"]?.string,
                  let judgementJSON = row["judgement_json"]?.string,
                  let judgementText = row["judgement_text"]?.string,
                  let calculatedAt = row["calculated_at"]?.string,
                  let createdAt = row["created_at"]?.double
            else { return nil }

            return SavedHoraryQueryRecord(
                id: id,
                question: question,
                questionHouse: questionHouse,
                datetimeLocal: datetimeLocal,
                timezone: timezone,
                latitude: latitude,
                longitude: longitude,
                placeName: row["place_name"]?.string ?? "",
                includeFortune: (row["include_fortune"]?.int ?? 0) != 0,
                chartJSON: chartJSON,
                judgementJSON: judgementJSON,
                judgementText: judgementText,
                calculatedAt: calculatedAt,
                createdAt: createdAt
            )
        }
    }
}

private extension SavedHoraryQueryRecord {
    init(
        id: String,
        question: String,
        questionHouse: Int,
        datetimeLocal: String,
        timezone: String,
        latitude: Double,
        longitude: Double,
        placeName: String,
        includeFortune: Bool,
        chartJSON: String,
        judgementJSON: String,
        judgementText: String,
        calculatedAt: String,
        createdAt: Double
    ) {
        self.id = id
        self.question = question
        self.questionHouse = questionHouse
        self.datetimeLocal = datetimeLocal
        self.timezone = timezone
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.includeFortune = includeFortune
        self.chartJSON = chartJSON
        self.judgementJSON = judgementJSON
        self.judgementText = judgementText
        self.calculatedAt = calculatedAt
        self.createdAt = createdAt
    }
}
