import XCTest
@testable import AstroMalik

@MainActor
final class ReadingNotesStoreTests: XCTestCase {
    func testSaveAndReloadSynthesisByChartId() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingNotesStoreTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("user.db")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ReadingNotesStore(databaseURL: url)
        let note = ReadingNotesStore.ReadingNote(
            chartId: "chart-1",
            synthesis: "Síntesis persistida",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try store.save(note)
        XCTAssertEqual(store.note(for: "chart-1")?.synthesis, "Síntesis persistida")

        let reloaded = ReadingNotesStore(databaseURL: url)
        XCTAssertEqual(reloaded.note(for: "chart-1"), note)
    }

    func testUpdatingExistingNoteDoesNotDuplicate() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingNotesStoreTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("user.db")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ReadingNotesStore(databaseURL: url)
        try store.save(.init(chartId: "chart-1", synthesis: "Uno", updatedAt: Date(timeIntervalSince1970: 1)))
        try store.save(.init(chartId: "chart-1", synthesis: "Dos", updatedAt: Date(timeIntervalSince1970: 2)))

        let reloaded = ReadingNotesStore(databaseURL: url)
        XCTAssertEqual(reloaded.note(for: "chart-1")?.synthesis, "Dos")
    }
}
