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

    private var analysisTask: Task<Void, Never>?
    private let engine: RectificationEngine

    init(engine: RectificationEngine = RectificationEngine()) {
        self.engine = engine
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
            } catch {
                errorMessage = "Narrativa IA: \(error.localizedDescription)"
            }
            isGeneratingNarrative = false
        }
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
