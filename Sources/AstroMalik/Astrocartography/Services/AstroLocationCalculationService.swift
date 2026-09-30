import Foundation

struct AstroLocationCalculationRequest: Equatable, Sendable {
    let curves: AstrocartographyResult
    let source: AstroRelocationSource?
    let sourceError: String?
    let destination: GeoCoordinate
    let timeZone: AstroDestinationTimeZone
}
struct AstroLocationCalculation: Codable, Equatable, Sendable {
    let analysis: LocationAnalysis
    let relocation: AstroRelocationCalculation?
    let relocationError: String?
    /// Retains actual returned flags, fallback diagnostics and library provenance
    /// for later readings/exports. Optional only for legacy or synthetic results.
    let curveSnapshot: EquatorialSnapshot?
    init(analysis: LocationAnalysis, relocation: AstroRelocationCalculation?, relocationError: String?,
         curveSnapshot: EquatorialSnapshot? = nil) {
        self.analysis = analysis; self.relocation = relocation; self.relocationError = relocationError
        self.curveSnapshot = curveSnapshot
    }
}
protocol AstroLocationCalculating: Sendable {
    func calculate(_ request: AstroLocationCalculationRequest) throws -> AstroLocationCalculation
}
struct AstroLocationCalculator: AstroLocationCalculating {
    let relocator: any AstroRelocationCalculating
    func calculate(_ request: AstroLocationCalculationRequest) throws -> AstroLocationCalculation {
        let analysis = try AstroLocationAnalyzer.analyze(location: request.destination, result: request.curves)
        try Task.checkCancellation()
        guard let source = request.source else {
            return AstroLocationCalculation(analysis: analysis, relocation: nil,
                relocationError: request.sourceError ?? "Faltan posiciones geocéntricas natales válidas.", curveSnapshot: request.curves.snapshot)
        }
        guard source.instant == analysis.request.instant else { throw AstrocartographyError.snapshotMismatch }
        do {
            let relocation = try relocator.relocate(source: source, destination: request.destination, timeZone: request.timeZone)
            try Task.checkCancellation()
            return AstroLocationCalculation(analysis: analysis, relocation: relocation, relocationError: nil, curveSnapshot: request.curves.snapshot)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            // A polar house failure does not discard valid geographic distances.
            return AstroLocationCalculation(analysis: analysis, relocation: nil, relocationError: error.localizedDescription, curveSnapshot: request.curves.snapshot)
        }
    }
}

/// Detached numeric work, per-consumer latest-wins, cancellable and bounded LRU.
/// Actual curves/snapshot, retained natal longitudes, system, JD, destination and
/// display-zone metadata identify cache entries; no UUID-only or rounded keys.
/// Immutable calculator/revision: recreate after ephemeris configuration changes.
actor AstroLocationCalculationService {
    private let calculator: any AstroLocationCalculating
    let revision: String
    private let maximumEntries: Int
    private var cache: [(AstroLocationCalculationRequest, AstroLocationCalculation)] = []
    private var generation = UUID()
    private var active: Task<AstroLocationCalculation, Error>?
    private(set) var hits = 0
    private(set) var misses = 0
    init(calculator: any AstroLocationCalculating, revision: String, maximumEntries: Int = 8) throws {
        guard !revision.isEmpty, maximumEntries >= 0 else { throw AstrocartographyError.invalidValue("locationServiceConfiguration") }
        self.calculator = calculator; self.revision = revision; self.maximumEntries = maximumEntries
    }
    func calculate(_ request: AstroLocationCalculationRequest) async throws -> AstroLocationCalculation {
        try Task.checkCancellation()
        active?.cancel(); active = nil
        let token = UUID(); generation = token
        if let index = cache.firstIndex(where: { $0.0 == request }) {
            let entry = cache.remove(at: index); cache.append(entry); hits += 1
            return entry.1
        }
        misses += 1
        let calculator = calculator
        let task = Task.detached(priority: Task.currentPriority) {
            try Task.checkCancellation()
            let result = try calculator.calculate(request)
            try Task.checkCancellation()
            return result
        }
        active = task
        do {
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: {
                task.cancel(); Task { await self.cancel(token) }
            }
            try Task.checkCancellation()
            guard generation == token else { throw CancellationError() }
            guard result.analysis.request == request.curves.snapshot.request, result.analysis.location == request.destination else {
                throw AstrocartographyError.snapshotMismatch
            }
            if let snapshot = result.curveSnapshot, snapshot != request.curves.snapshot { throw AstrocartographyError.snapshotMismatch }
            if let relocated = result.relocation {
                guard relocated.source == request.source, relocated.chart.instant == request.source?.instant,
                      relocated.chart.destination == request.destination, relocated.destinationTimeZone == request.timeZone else {
                    throw AstrocartographyError.snapshotMismatch
                }
            }
            active = nil
            if maximumEntries > 0 {
                cache.append((request,result))
                if cache.count > maximumEntries { cache.removeFirst() }
            }
            return result
        } catch {
            if generation == token { active = nil }
            throw error
        }
    }
    func invalidateCache() { cancel(generation); cache.removeAll() }
    private func cancel(_ token: UUID) {
        guard generation == token else { return }
        generation = UUID(); active?.cancel(); active = nil
    }
}
