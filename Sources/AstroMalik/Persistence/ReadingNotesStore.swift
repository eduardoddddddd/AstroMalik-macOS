import Foundation
import SwiftUI

@MainActor
final class ReadingNotesStore: ObservableObject {
    struct ReadingNote: Codable, Equatable, Identifiable {
        var id: String { chartId }
        var chartId: String
        var synthesis: String
        var updatedAt: Date
    }

    @Published private(set) var notes: [String: ReadingNote] = [:]

    private var db: SQLiteDB?

    init(databaseURL: URL? = nil) {
        do {
            let url = try databaseURL ?? Self.userDBURL()
            let queue = try SQLiteDB(path: url.path, readonly: false)
            try Self.createTable(db: queue)
            db = queue
            try load()
        } catch {
            print("[ReadingNotesStore] Error setup: \(error)")
        }
    }

    func note(for chartId: String) -> ReadingNote? {
        notes[chartId]
    }

    func save(_ note: ReadingNote) throws {
        guard let db else { return }
        try db.run(
            """
            INSERT INTO reading_notes (chart_id, synthesis, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(chart_id) DO UPDATE SET
                synthesis = excluded.synthesis,
                updated_at = excluded.updated_at
            """,
            args: [.text(note.chartId), .text(note.synthesis), .real(note.updatedAt.timeIntervalSince1970)]
        )
        notes[note.chartId] = note
    }

    func reload() throws {
        try load()
    }

    private func load() throws {
        guard let db else { return }
        let rows = try db.query("SELECT chart_id, synthesis, updated_at FROM reading_notes")
        var loaded: [String: ReadingNote] = [:]
        for row in rows {
            guard let chartId = row["chart_id"]?.string else { continue }
            let synthesis = row["synthesis"]?.string ?? ""
            let updatedAt = Date(timeIntervalSince1970: row["updated_at"]?.double ?? 0)
            loaded[chartId] = ReadingNote(chartId: chartId, synthesis: synthesis, updatedAt: updatedAt)
        }
        notes = loaded
    }

    private static func createTable(db: SQLiteDB) throws {
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS reading_notes (
                chart_id TEXT PRIMARY KEY NOT NULL,
                synthesis TEXT NOT NULL DEFAULT '',
                updated_at REAL NOT NULL
            )
            """
        )
    }

    private static func userDBURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw ReadingNotesStoreError.applicationSupportUnavailable
        }
        let dir = appSupport.appendingPathComponent("AstroMalik", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("user.db")
    }
}

private enum ReadingNotesStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        "No se pudo localizar Application Support para guardar notas de lectura."
    }
}
