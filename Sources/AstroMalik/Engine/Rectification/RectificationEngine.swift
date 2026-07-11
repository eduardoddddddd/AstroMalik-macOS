import Foundation

final class RectificationEngine: Sendable {
    typealias ProgressHandler = (Double) async -> Void

    private let generator = RectificationCandidateGenerator()

    func analyze(
        session: RectificationSession,
        config: RectificationConfig = .default,
        progress: ProgressHandler? = nil
    ) async throws -> RectificationAnalysisResult {
        try session.validate(config: config)
        let started = Date()
        let ephemerisCache = config.enabledTechniques.contains(.transitsToAngles)
            ? try RectificationEphemerisCache.prepare(for: session)
            : RectificationEphemerisCache(transitsByEvent: [:])
        let systems = config.evaluateMultipleHouseSystems
            ? RectificationHouseSystem.allCases
            : [config.houseSystem]

        var results: [RectificationAnalysisResult] = []
        var systemFailures: [String] = []
        results.reserveCapacity(systems.count)
        for (index, system) in systems.enumerated() {
            try Task.checkCancellation()
            var systemConfig = config
            systemConfig.houseSystem = system
            systemConfig.evaluateMultipleHouseSystems = false
            let lower = Double(index) / Double(systems.count)
            let upper = Double(index + 1) / Double(systems.count)
            let mappedProgress: ProgressHandler = { value in
                await progress?(lower + value * (upper - lower))
            }
            do {
                results.append(try await analyzeSingle(
                    session: session,
                    config: systemConfig,
                    ephemerisCache: ephemerisCache,
                    progress: mappedProgress
                ))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard config.evaluateMultipleHouseSystems else { throw error }
                systemFailures.append("\(system.label): \(error.localizedDescription)")
                await progress?(upper)
            }
        }

        guard var best = results.max(by: {
            ($0.topCandidate?.totalScore ?? 0) < ($1.topCandidate?.totalScore ?? 0)
        }) else {
            throw RectificationCandidateGeneratorError.noCandidates
        }
        let winningHouseSystem = best.configUsed.houseSystem
        if config.evaluateMultipleHouseSystems {
            best.houseSystemEvaluations = results.map {
                RectificationHouseSystemEvaluation(
                    houseSystem: $0.configUsed.houseSystem,
                    topBirthTime: $0.topCandidate?.birthTime ?? "—",
                    topScore: $0.topCandidate?.totalScore ?? 0,
                    confidence: $0.overallConfidence
                )
            }.sorted { $0.topScore > $1.topScore }
            best.warnings.append(houseSystemConsensusWarning(for: best.houseSystemEvaluations ?? []))
            if !systemFailures.isEmpty {
                best.warnings.append("Sistemas no evaluables: \(systemFailures.joined(separator: "; ")).")
            }
        }
        var effectiveConfig = config
        effectiveConfig.houseSystem = winningHouseSystem
        best.configUsed = effectiveConfig
        best.computeTimeSeconds = Date().timeIntervalSince(started)
        await progress?(1)
        return best
    }

    private func analyzeSingle(
        session: RectificationSession,
        config: RectificationConfig,
        ephemerisCache: RectificationEphemerisCache,
        progress: ProgressHandler?
    ) async throws -> RectificationAnalysisResult {
        let started = Date()
        await progress?(0.01)

        let coarse = try await generator.coarseCandidates(session: session, config: config)
        let transitScorer = TransitAngleRectificationScorer(cache: ephemerisCache)
        let coarseScorers: [any RectificationTechniqueScorer] = [
            SolarArcRectificationScorer(),
            transitScorer,
        ].filter { config.enabledTechniques.contains($0.technique) }
        let scoredCoarse = try await score(
            coarse,
            session: session,
            config: config,
            scorers: coarseScorers,
            progressRange: 0.05...0.42,
            progress: progress
        )

        let centers = distinctCenters(from: scoredCoarse, limit: min(3, scoredCoarse.count), session: session)
        let fine = try await generator.fineCandidates(around: centers, session: session, config: config)
        await progress?(0.46)

        let allScorers: [any RectificationTechniqueScorer] = [
            SolarArcRectificationScorer(),
            transitScorer,
            ProgressionRectificationScorer(),
            PrimaryDirectionRectificationScorer(),
            AscendantQuestionnaireScorer(),
            ProfectionRectificationScorer(),
            FirdariaRectificationScorer(),
            ZodiacalReleasingRectificationScorer(),
            LotsRectificationScorer(),
            SolarReturnRectificationScorer(),
        ].filter { config.enabledTechniques.contains($0.technique) }
        var candidates = try await score(
            fine,
            session: session,
            config: config,
            scorers: allScorers,
            progressRange: 0.46...0.94,
            progress: progress
        )
        candidates.sort { $0.totalScore > $1.totalScore }
        let clusters = buildClusters(candidates: candidates, windowMinutes: config.clusterWindowMinutes)
        let confidence = confidenceBand(candidates: candidates, eventCount: session.events.count)
        for index in candidates.indices {
            candidates[index].confidenceBand = index == 0 ? confidence : band(for: candidates[index].totalScore)
        }
        let top = candidates.first
        let coverage = Dictionary(uniqueKeysWithValues: session.events.map { event in
            (event.id, Set(top?.evidence.filter { $0.eventID == event.id }.map(\.technique) ?? []).count)
        })
        let sects = Set(candidates.map { SectEngine.sect(of: $0.chart).isDiurnal })
        var warnings: [String] = []
        if candidates.isEmpty { warnings.append("No se obtuvieron candidatas finales.") }
        if let first = candidates.first, let second = candidates.dropFirst().first,
           first.totalScore - second.totalScore < 3 {
            warnings.append("Las primeras candidatas están muy próximas: el resultado no distingue un minuto único.")
        }
        if coverage.values.contains(0) {
            warnings.append("Hay eventos sin cobertura por ninguna técnica habilitada.")
        }
        if sects.count > 1 {
            warnings.append("El rango cruza un cambio de secta diurna/nocturna.")
        }
        return RectificationAnalysisResult(
            schemaVersion: RectificationAnalysisResult.currentSchemaVersion,
            sessionID: session.id,
            candidates: candidates,
            topCandidate: top,
            overallConfidence: confidence,
            clusters: clusters,
            eventCoverage: coverage,
            sectCrossingDetected: sects.count > 1,
            warnings: warnings,
            analysisDate: Date(),
            configUsed: config,
            computeTimeSeconds: Date().timeIntervalSince(started)
        )
    }

    private func score(
        _ candidates: [RectificationCandidate],
        session: RectificationSession,
        config: RectificationConfig,
        scorers: [any RectificationTechniqueScorer],
        progressRange: ClosedRange<Double>,
        progress: ProgressHandler?
    ) async throws -> [RectificationCandidate] {
        var output: [RectificationCandidate] = []
        output.reserveCapacity(candidates.count)
        for (index, original) in candidates.enumerated() {
            try Task.checkCancellation()
            var candidate = original
            var evidence: [RectificationEvidence] = []
            var warnings: [String] = []
            for scorer in scorers {
                do {
                    evidence.append(contentsOf: try scorer.evidence(candidate: candidate, session: session, config: config))
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    warnings.append("\(scorer.technique.rawValue): \(error.localizedDescription)")
                }
            }
            let consolidated = consolidate(evidence: evidence, events: session.events, techniques: scorers.map(\.technique))
            candidate.evidence = consolidated.evidence
            candidate.eventScores = consolidated.eventScores
            candidate.techniqueScores = consolidated.techniqueScores
            let diagnostics = RectificationOverfittingAnalyzer.diagnostics(
                rawScore: consolidated.totalScore,
                eventScores: consolidated.eventScores,
                techniqueScores: consolidated.techniqueScores,
                enabledTechniqueCount: scorers.count,
                config: config
            )
            candidate.totalScore = diagnostics.adjustedScore
            candidate.overfittingDiagnostics = diagnostics
            candidate.confidenceBand = band(for: diagnostics.adjustedScore)
            if diagnostics.penalty >= 2 {
                warnings.append("Penalización anti-overfitting: -\(String(format: "%.1f", diagnostics.penalty)) puntos.")
            }
            candidate.warnings = warnings
            output.append(candidate)
            let fraction = Double(index + 1) / Double(max(1, candidates.count))
            await progress?(progressRange.lowerBound + fraction * (progressRange.upperBound - progressRange.lowerBound))
        }
        return output.sorted { $0.totalScore > $1.totalScore }
    }

    private func consolidate(
        evidence: [RectificationEvidence],
        events: [RectificationEvent],
        techniques: [RectificationTechnique]
    ) -> (evidence: [RectificationEvidence], eventScores: [UUID: Double], techniqueScores: [RectificationTechnique: Double], totalScore: Double) {
        let grouped = Dictionary(grouping: evidence) { "\($0.eventID.uuidString)|\($0.technique.rawValue)" }
        let strongest = grouped.values.compactMap { $0.max { $0.score < $1.score } }
        var eventScores: [UUID: Double] = [:]
        for event in events {
            let scores = strongest.filter { $0.eventID == event.id }.map(\.score).sorted(by: >)
            guard let first = scores.first else { eventScores[event.id] = 0; continue }
            let confirmation = scores.dropFirst().enumerated().reduce(0.0) { partial, item in
                partial + item.element * RectificationScoringPolicy.confirmationWeight(at: item.offset)
            }
            eventScores[event.id] = min(100, first + confirmation)
        }
        var techniqueScores: [RectificationTechnique: Double] = [:]
        for technique in techniques {
            let values = strongest.filter { $0.technique == technique }.map(\.score)
            techniqueScores[technique] = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
        let total = events.isEmpty ? 0 : eventScores.values.reduce(0, +) / Double(events.count)
        return (strongest.sorted { $0.score > $1.score }, eventScores, techniqueScores, (total * 100).rounded() / 100)
    }

    private func distinctCenters(from candidates: [RectificationCandidate], limit: Int, session: RectificationSession) -> [RectificationCandidate] {
        var selected: [RectificationCandidate] = []
        let minimumGap = max(60, session.searchRange.coarseStepSeconds * 2)
        for candidate in candidates {
            guard selected.allSatisfy({ abs(timeSeconds($0.birthTime) - timeSeconds(candidate.birthTime)) >= minimumGap }) else { continue }
            selected.append(candidate)
            if selected.count == limit { break }
        }
        return selected.isEmpty ? Array(candidates.prefix(limit)) : selected
    }


    private func buildClusters(candidates: [RectificationCandidate], windowMinutes: Int) -> [CandidateCluster] {
        let relevant = candidates.filter { $0.totalScore >= (candidates.first?.totalScore ?? 0) * 0.65 }
            .sorted { timeSeconds($0.birthTime) < timeSeconds($1.birthTime) }
        var groups: [[RectificationCandidate]] = []
        for candidate in relevant {
            if let last = groups.last?.last,
               timeSeconds(candidate.birthTime) - timeSeconds(last.birthTime) <= windowMinutes * 60 {
                groups[groups.count - 1].append(candidate)
            } else {
                groups.append([candidate])
            }
        }
        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            let best = group.max { $0.totalScore < $1.totalScore } ?? first
            return CandidateCluster(
                id: UUID(), centerTime: best.birthTime,
                timeRange: "\(first.birthTime)–\(last.birthTime)",
                candidateIDs: group.map(\.id),
                averageScore: group.map(\.totalScore).reduce(0, +) / Double(group.count),
                ascendantSign: AstroEngine.degToSignKey(best.ascendantLongitude)
            )
        }.sorted { $0.averageScore > $1.averageScore }
    }

    private func confidenceBand(candidates: [RectificationCandidate], eventCount: Int) -> RectificationConfidenceBand {
        guard let top = candidates.first,
              eventCount >= RectificationScoringPolicy.minimumConfidenceEventCount else { return .inconclusive }
        let gap = top.totalScore - (candidates.dropFirst().first?.totalScore ?? 0)
        if top.totalScore >= RectificationScoringPolicy.highCandidateScore,
           gap >= RectificationScoringPolicy.highMinimumGap,
           eventCount >= RectificationScoringPolicy.highMinimumEventCount { return .high }
        if top.totalScore >= RectificationScoringPolicy.mediumCandidateScore,
           gap >= RectificationScoringPolicy.mediumMinimumGap { return .medium }
        if top.totalScore > 0 { return .low }
        return .inconclusive
    }

    private func band(for score: Double) -> RectificationConfidenceBand {
        if score >= RectificationScoringPolicy.highCandidateScore { return .high }
        if score >= RectificationScoringPolicy.mediumCandidateScore { return .medium }
        if score > 0 { return .low }
        return .inconclusive
    }

    private func timeSeconds(_ time: String) -> Int {
        (try? parseLocalTime(time).totalSeconds) ?? 0
    }

    private func houseSystemConsensusWarning(
        for evaluations: [RectificationHouseSystemEvaluation]
    ) -> String {
        guard let winner = evaluations.first else {
            return "No se pudo comparar la estabilidad entre sistemas de casas."
        }
        let validTimes = evaluations.compactMap { try? parseLocalTime($0.topBirthTime).totalSeconds }.sorted()
        let spread: Int
        if validTimes.count < 2 {
            spread = 0
        } else {
            let internalGaps = zip(validTimes, validTimes.dropFirst()).map { $1 - $0 }
            let wrapGap = 86_400 - (validTimes.last ?? 0) + (validTimes.first ?? 0)
            spread = 86_400 - max(internalGaps.max() ?? 0, wrapGap)
        }
        if spread <= 5 * 60 {
            return "Los sistemas de casas convergen en una ventana de \(max(0, spread / 60)) min; gana \(winner.houseSystem.label)."
        }
        return "Los sistemas de casas no convergen: dispersión de \(spread / 60) min; gana \(winner.houseSystem.label). Revise la comparación antes de fijar la hora."
    }
}
