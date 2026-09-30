import Foundation

/// One instance per consuming workflow. The calculator and its provenance key
/// are immutable: replace this service (or invalidate after file updates) when
/// provider/options/ephemeris files change. Do not use a natal object's UUID as
/// the cache key: only the actual immutable calculation inputs identify a result.
actor AstrocartographyCalculationService {
    enum State: Equatable, Sendable {
        case idle
        case calculating(AstrocartographyRequest)
        case ready(AstrocartographyResult)
        case cancelled
        case failed(AstrocartographyRequest, String)
    }

    struct CacheStatistics: Equatable, Sendable {
        let hits: Int
        let misses: Int
        let evictions: Int
        let entries: Int
        let vertices: Int
    }

    private struct CacheKey: Hashable {
        let julianDay: Double
        let timeScale: String
        let bodies: [String]
        let toleranceKm: Double
        let convention: String
        let contractVersion: Int
        let algorithmVersion: String
        let ephemerisRevision: String
    }
    private struct Entry {
        let key: CacheKey
        let result: AstrocartographyResult
        let vertices: Int
    }

    private let calculator: any AstrocartographyCalculating
    private let ephemerisRevision: String
    private let algorithmVersion: String
    private let maximumEntries: Int
    private let maximumVertices: Int
    private var cache: [Entry] = [] // LRU first; deliberately small and bounded.
    private var active: Task<AstrocartographyResult, Error>?
    private var generation = UUID()
    private var hits = 0
    private var misses = 0
    private var evictions = 0
    private(set) var state: State = .idle

    /// ephemerisRevision must identify provider, path/data revision and options
    /// (e.g. library version + resource digest + returned-flags policy). It is
    /// explicit because a filesystem path alone cannot detect changed files.
    init(calculator: any AstrocartographyCalculating, ephemerisRevision: String,
         algorithmVersion: String = AstrocartographyEngine.algorithmVersion,
         maximumEntries: Int = 8, maximumVertices: Int = 200_000) throws {
        guard !ephemerisRevision.isEmpty, !algorithmVersion.isEmpty,
              maximumEntries >= 0, maximumVertices >= 0 else {
            throw AstrocartographyError.invalidValue("calculationCacheConfiguration")
        }
        self.calculator = calculator
        self.ephemerisRevision = ephemerisRevision
        self.algorithmVersion = algorithmVersion
        self.maximumEntries = maximumEntries
        self.maximumVertices = maximumVertices
    }

    func calculate(request: AstrocartographyRequest) async throws -> AstrocartographyResult {
        try Task.checkCancellation()
        active?.cancel()
        let token = UUID()
        generation = token
        active = nil
        let key = CacheKey(julianDay: request.instant.julianDay, timeScale: request.instant.timeScale.rawValue,
            bodies: request.bodies.map(\.rawValue), toleranceKm: request.geometryToleranceKm,
            convention: request.convention, contractVersion: request.contractVersion,
            algorithmVersion: algorithmVersion, ephemerisRevision: ephemerisRevision)
        if let index = cache.firstIndex(where: { $0.key == key }) {
            let entry = cache.remove(at: index)
            cache.append(entry)
            hits += 1
            state = .ready(entry.result)
            return entry.result
        }
        misses += 1
        state = .calculating(request)
        let calculator = self.calculator
        // Heavy synchronous geometry never runs on the caller/main actor or
        // inside this actor. The Swiss snapshot releases the common lock first.
        let task = Task.detached(priority: Task.currentPriority) {
            try Task.checkCancellation()
            let result = try calculator.calculate(request: request)
            try Task.checkCancellation()
            return result
        }
        active = task
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
                Task { await self.cancel(generation: token) }
            }
            try Task.checkCancellation()
            // Required even if a future calculator ignores cancellation entirely.
            guard generation == token else { throw CancellationError() }
            guard result.snapshot.request == request else { throw AstrocartographyError.snapshotMismatch }
            active = nil
            insert(result, for: key)
            state = .ready(result)
            return result
        } catch {
            if generation == token {
                active = nil
                state = error is CancellationError ? .cancelled : .failed(request, error.localizedDescription)
            }
            throw error
        }
    }

    func cancel() {
        cancel(generation: generation)
    }

    /// Call on ephemeris-file changes or explicit reload. Cancels work as well:
    /// in-flight results from the old revision must not repopulate the cache.
    func invalidateCache() {
        cancel()
        cache.removeAll()
        state = .idle
    }

    func cacheStatistics() -> CacheStatistics {
        CacheStatistics(hits: hits, misses: misses, evictions: evictions,
                        entries: cache.count, vertices: cache.reduce(0) { $0 + $1.vertices })
    }

    private func cancel(generation token: UUID) {
        guard generation == token else { return }
        generation = UUID()
        active?.cancel()
        active = nil
        state = .cancelled
    }

    private func insert(_ result: AstrocartographyResult, for key: CacheKey) {
        let vertices = result.lines.reduce(0) { count, line in
            count + line.segments.reduce(0) { $0 + $1.coordinates.count }
        }
        guard maximumEntries > 0, vertices <= maximumVertices else { return }
        cache.append(Entry(key: key, result: result, vertices: vertices))
        while cache.count > maximumEntries || cache.reduce(0, { $0 + $1.vertices }) > maximumVertices {
            cache.removeFirst()
            evictions += 1
        }
    }
}
