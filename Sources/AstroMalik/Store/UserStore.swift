import Foundation
import SwiftUI

// MARK: - User Store (SQLite3 directo, sin GRDB)

@MainActor
final class UserStore: ObservableObject {
    @Published var savedCharts: [NatalChart] = []

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
            db = queue
            await load()
        } catch {
            print("[UserStore] Error setup: \(error)")
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

    // MARK: - CRUD

    func load() async {
        guard let queue = db else { return }
        do {
            let records = try SavedChartRecord.fetchAll(from: queue)
            savedCharts = records.compactMap { $0.toNatalChart() }
        } catch {
            print("[UserStore] Error load: \(error)")
        }
    }

    func save(_ chart: NatalChart) throws {
        guard let queue = db else { return }
        let record = SavedChartRecord(from: chart)
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
}
