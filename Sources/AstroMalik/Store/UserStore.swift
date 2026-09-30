import Foundation
import SwiftUI

// MARK: - User Store (SQLite3 directo, sin GRDB)

@MainActor
final class UserStore: ObservableObject {
    @Published var savedCharts: [NatalChart] = []
    @Published var chartMetadata: [UUID: ChartMetadata] = [:]

    private var db: SQLiteDB?
    private var astroPlaces: AstroSavedPlaceRepository?
    private var astroStorageError: String?

    init() {
        Task { await self.setup() }
    }

    /// Explicit injection for isolated tests/tools. Never resolves a user path.
    init(database: SQLiteDB) throws {
        try SavedChartRecord.createTable(db: database)
        try SavedChartRecord.migrateMetadataColumns(db: database)
        db = database
        do { astroPlaces = try AstroSavedPlaceRepository(db: database) }
        catch { astroStorageError = error.localizedDescription }
        Task { await load() }
    }

    // MARK: - Setup

    private func setup() async {
        do {
            let url = try Self.userDBURL()
            let queue = try SQLiteDB(path: url.path, readonly: false)
            try SavedChartRecord.createTable(db: queue)
            try SavedChartRecord.migrateMetadataColumns(db: queue)
            db = queue
            // An unsupported/corrupt astro schema must not disable natal storage.
            do { astroPlaces = try AstroSavedPlaceRepository(db: queue) }
            catch { astroStorageError = error.localizedDescription }
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
        try queue.execute("BEGIN IMMEDIATE")
        do {
            try record.save(to: queue)
            try astroPlaces?.invalidateResults(for: chart.id, matching: AstroNatalFingerprint.make(chart))
            try queue.execute("COMMIT")
        } catch { try? queue.execute("ROLLBACK"); throw error }
        Task { await load() }
    }

    func delete(_ chart: NatalChart) throws {
        guard let queue = db else { return }
        try queue.execute("BEGIN IMMEDIATE")
        do {
            try astroPlaces?.deletePlaces(for: chart.id)
            try queue.run("DELETE FROM saved_charts WHERE id = ?", args: [.text(chart.id.uuidString)])
            try queue.execute("COMMIT")
        } catch { try? queue.execute("ROLLBACK"); throw error }
        Task { await load() }
    }

    func loadAstroPlaces(chartID: UUID, fingerprint: String, revision: String) throws -> AstroSavedPlaceLoad {
        guard let astroPlaces else { throw UserStoreError.astroStorageUnavailable(astroStorageError ?? "Almacenamiento aún no disponible.") }
        return try astroPlaces.load(chartID: chartID, fingerprint: fingerprint, revision: revision)
    }
    func saveAstroPlace(id: UUID = UUID(), chartID: UUID, fingerprint: String, intent: AstroSavedPlaceIntent,
                       calculation: AstroLocationCalculation, revision: String) throws -> UUID {
        guard let astroPlaces else { throw UserStoreError.astroStorageUnavailable(astroStorageError ?? "Almacenamiento aún no disponible.") }
        guard let queue = db,
              let json = try queue.queryOne("SELECT chart_json FROM saved_charts WHERE id=?", args: [.text(chartID.uuidString)])?["chart_json"]?.string,
              let natal = try? JSONDecoder().decode(NatalChart.self, from: Data(json.utf8)) else {
            throw UserStoreError.chartMustBeSaved
        }
        guard try AstroNatalFingerprint.make(natal) == fingerprint else { throw UserStoreError.natalChangesMustBeSaved }
        return try astroPlaces.save(id: id, chartID: chartID, fingerprint: fingerprint, intent: intent, calculation: calculation, revision: revision)
    }
    func deleteAstroPlace(id: UUID, chartID: UUID) throws {
        guard let astroPlaces else { throw UserStoreError.astroStorageUnavailable(astroStorageError ?? "Almacenamiento aún no disponible.") }
        try astroPlaces.delete(id: id, chartID: chartID)
    }

    func rename(id: UUID, name: String) throws {
        guard let queue = db else { return }
        guard let record = try SavedChartRecord.fetchAll(from: queue).first(where: { $0.id == id.uuidString }),
              var chart = record.toNatalChart() else { return }
        chart.name = name
        // Keep chart_json and indexed name in sync; fingerprint must describe
        // the same edited natal that UserStore.load actually returns.
        try save(chart)
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
    case chartMustBeSaved
    case natalChangesMustBeSaved
    case astroStorageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable: return "No se pudo localizar Application Support para guardar cartas."
        case .chartMustBeSaved: return "Guarda primero la carta natal para asociar este lugar sin referencias huérfanas."
        case .natalChangesMustBeSaved: return "Guarda primero los cambios de la carta natal; el lugar corresponde a una edición aún no persistida."
        case .astroStorageUnavailable(let message): return "Guardados de astrocartografía no disponibles: \(message)"
        }
    }
}
