import Foundation
import SwiftUI

@MainActor
final class RectificationViewModel: ObservableObject {
    @Published var session: RectificationSession?
    @Published var config = RectificationConfig.default
    @Published private(set) var result: RectificationAnalysisResult?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress = 0.0
    @Published var errorMessage: String?
    @Published var saveMessage: String?
    @Published var llmProvider: LLMProvider = .anthropic
    @Published private(set) var narrative: RectificationNarrative?
    @Published private(set) var isGeneratingNarrative = false
    @Published private(set) var savedSessions: [SavedRectificationSession] = []

    private var analysisTask: Task<Void, Never>?
    private let engine: RectificationEngine
    private let sessionStore: RectificationSessionStore?

    init(engine: RectificationEngine = RectificationEngine(), sessionStore: RectificationSessionStore? = try? RectificationSessionStore()) {
        self.engine = engine
        self.sessionStore = sessionStore
        refreshSavedSessions()
    }

    func load(chart: NatalChart) {
        guard session?.baseChartID != chart.id else { return }
        session = RectificationSession(
            baseChartID: chart.id,
            name: chart.name.isEmpty ? "Rectificación" : chart.name,
            birthDate: chart.birthDate,
            reportedBirthTime: chart.birthTime,
            timezone: chart.timezone,
            latitude: chart.latitude,
            longitude: chart.longitude,
            placeName: chart.placeName,
            searchRange: RectificationSearchRange(centerTime: chart.birthTime)
        )
        result = nil
        narrative = nil
        errorMessage = nil
    }

    func addEvent() {
        guard var session else { return }
        let birth = (try? localDateFromBirthData(
            birthDate: session.birthDate,
            birthTime: session.reportedBirthTime,
            timezoneName: session.timezone
        )) ?? Date()
        let suggested = min(Date(), birth.addingTimeInterval(365.2422 * 86_400 * Double(session.events.count + 18)))
        session.events.append(RectificationEvent(
            type: .other,
            title: "Nuevo evento",
            dateStart: suggested,
            precision: .exactDay
        ))
        session.updatedAt = Date()
        self.session = session
    }

    func removeEvents(at offsets: IndexSet) {
        session?.events.remove(atOffsets: offsets)
        session?.updatedAt = Date()
    }

    func analyze() {
        guard let session else { return }
        analysisTask?.cancel()
        isAnalyzing = true
        progress = 0
        errorMessage = nil
        saveMessage = nil
        narrative = nil
        analysisTask = Task {
            do {
                let result = try await engine.analyze(session: session, config: config) { [weak self] value in
                    await MainActor.run { self?.progress = value }
                }
                try Task.checkCancellation()
                self.result = result
                self.persistCurrent()
            } catch is CancellationError {
                self.errorMessage = "Análisis cancelado."
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isAnalyzing = false
        }
    }

    func cancel() {
        analysisTask?.cancel()
    }

    func generateNarrative() {
        guard let result, let session else { return }
        isGeneratingNarrative = true
        errorMessage = nil
        Task {
            do {
                narrative = try await RectificationNarrativeBuilder().build(
                    result: result, session: session, provider: llmProvider
                )
                persistCurrent()
            } catch {
                errorMessage = "Narrativa IA: \(error.localizedDescription)"
            }
            isGeneratingNarrative = false
        }
    }

    func saveSession() {
        persistCurrent()
        saveMessage = "Sesión guardada."
    }

    func loadSession(id: UUID) {
        do {
            guard let archive = try sessionStore?.load(id: id) else { return }
            session = archive.session
            result = archive.result
            narrative = archive.narrative
            errorMessage = nil
            saveMessage = "Sesión reabierta."
        } catch { errorMessage = "No se pudo abrir la sesión: \(error.localizedDescription)" }
    }

    func deleteSession(id: UUID) {
        do { try sessionStore?.delete(id: id); refreshSavedSessions() }
        catch { errorMessage = "No se pudo eliminar la sesión: \(error.localizedDescription)" }
    }

    func exportArchiveData() throws -> Data {
        guard let session else { throw CocoaError(.fileNoSuchFile) }
        persistCurrent()
        guard let data = try sessionStore?.exportArchive(id: session.id) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    func importArchiveData(_ data: Data) throws {
        guard let archive = try sessionStore?.importArchive(data) else { throw CocoaError(.fileReadUnknown) }
        session = archive.session; result = archive.result; narrative = archive.narrative
        refreshSavedSessions()
    }

    private func persistCurrent() {
        guard let session else { return }
        do {
            _ = try sessionStore?.save(session: session, result: result, narrative: narrative)
            refreshSavedSessions()
        } catch { errorMessage = "No se pudo guardar la sesión: \(error.localizedDescription)" }
    }

    private func refreshSavedSessions() {
        savedSessions = (try? sessionStore?.list()) ?? []
    }

    func saveTopCandidate(in store: UserStore) {
        guard var chart = result?.topCandidate?.chart else { return }
        chart = NatalChart(
            id: UUID(),
            name: "\(session?.name ?? chart.name) — rectificada \(chart.birthTime)",
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezone: chart.timezone,
            latitude: chart.latitude,
            longitude: chart.longitude,
            placeName: chart.placeName,
            houseSystem: chart.houseSystem,
            ascendant: chart.ascendant,
            mc: chart.mc,
            cusps: chart.cusps,
            bodies: chart.bodies
        )
        do {
            try store.save(chart)
            let score = result?.topCandidate?.totalScore ?? 0
            try store.setMetadata(
                id: chart.id,
                notes: "Carta creada por Rectificación asistida. Sesión: \(session?.id.uuidString ?? "—"). Score: \(String(format: "%.1f", score)). La hora es una hipótesis astrológica y no sustituye un registro oficial.",
                tags: ["rectificada", "rectificacion"]
            )
            saveMessage = "Carta rectificada guardada como una carta nueva."
        } catch {
            errorMessage = "No se pudo guardar la candidata: \(error.localizedDescription)"
        }
    }
}
