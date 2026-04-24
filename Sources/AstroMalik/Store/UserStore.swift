import Foundation
import SwiftUI

// MARK: - User Store (SQLite3 directo, sin GRDB)

@MainActor
final class UserStore: ObservableObject {
    @Published var savedCharts: [NatalChart] = []
    @Published var chartMetadata: [UUID: ChartMetadata] = [:]

    private var db: SQLiteDB?

    init() {
        Task { await self.setup() }
    }

    // MARK: - Setup

    private func setup() async {
        do {
            let url = try Self.userDBURL()
            let queue = try SQLiteDB(path: url.path, readonly: false)
            try SavedChartRecord.createTable(db: queue)
            try SavedChartRecord.migrateMetadataColumns(db: queue)
            db = queue
            await load()
        } catch {
            print("[UserStore] Error setup: \(error)")
        }
    }

    private static func userDBURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw UserStoreError.applicationSupportUnavailable
        }
        let dir = appSupport.appendingPathComponent("AstroMalik", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("user.db")
    }

    // MARK: - CRUD

    func load() async {
        guard let queue = db else { return }
        do {
            let records = try SavedChartRecord.fetchAll(from: queue)
            savedCharts = records.compactMap { $0.toNatalChart() }
            chartMetadata = Dictionary(uniqueKeysWithValues: records.compactMap { record in
                guard let id = UUID(uuidString: record.id) else { return nil }
                return (id, ChartMetadata(notes: record.notes, tags: record.tags))
            })
        } catch {
            print("[UserStore] Error load: \(error)")
        }
    }

    func save(_ chart: NatalChart) throws {
        guard let queue = db else { return }
        var record = SavedChartRecord(from: chart)
        if let existing = chartMetadata[chart.id] {
            record.notes = existing.notes
            record.tags = existing.tags
        }
        try record.save(to: queue)
        Task { await load() }
    }

    func delete(_ chart: NatalChart) throws {
        guard let queue = db else { return }
        try queue.run("DELETE FROM saved_charts WHERE id = ?", args: [.text(chart.id.uuidString)])
        Task { await load() }
    }

    func rename(id: UUID, name: String) throws {
        guard let queue = db else { return }
        try queue.run("UPDATE saved_charts SET name = ? WHERE id = ?",
                      args: [.text(name), .text(id.uuidString)])
        Task { await load() }
    }

    func setMetadata(id: UUID, notes: String, tags: [String]) throws {
        guard let queue = db else { return }
        let cleanTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        try queue.run(
            "UPDATE saved_charts SET notes = ?, tags = ? WHERE id = ?",
            args: [.text(notes), .text(cleanTags.joined(separator: ",")), .text(id.uuidString)]
        )
        Task { await load() }
    }
}

struct ChartMetadata: Equatable {
    var notes: String
    var tags: [String]
}

private enum UserStoreError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        "No se pudo localizar Application Support para guardar cartas."
    }
}
