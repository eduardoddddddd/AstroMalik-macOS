import Foundation

protocol RectificationTechniqueScorer {
    var technique: RectificationTechnique { get }
    func evidence(
        candidate: RectificationCandidate,
        session: RectificationSession,
        config: RectificationConfig
    ) throws -> [RectificationEvidence]
}

enum RectificationScoringSupport {
    static let secondsPerDay = 86_400.0
    static let tropicalYearDays = 365.2422

    static func closestAspect(source: Double, target: Double) -> (PDaspect, Double) {
        var difference = abs((source - target).truncatingRemainder(dividingBy: 360))
        if difference > 180 { difference = 360 - difference }
        return PDaspect.allCases
            .map { ($0, abs(difference - $0.angle)) }
            .min { $0.1 < $1.1 }!
    }

    static func evidenceScore(
        event: RectificationEvent,
        technique: RectificationTechnique,
        config: RectificationConfig,
        fit: RectificationSymbolicFit,
        closeness: Double,
        techniqueQuality: Double = 1
    ) -> Double {
        let importance = Double(event.importance) / 5.0
        let weight = config.techniqueWeights[technique] ?? 1
        let score = 100
            * importance
            * event.precision.scoreMultiplier
            * event.confidence.scoreMultiplier
            * min(1, max(0, closeness))
            * RectificationSymbolismRules.multiplier(for: fit)
            * min(1, max(0, techniqueQuality))
            * min(1.5, weight) / 1.5
            * schoolMultiplier(for: technique, school: config.resolvedSchool)
        return (min(100, score) * 100).rounded() / 100
    }

    static func schoolMultiplier(for technique: RectificationTechnique, school: RectificationSchool) -> Double {
        switch school {
        case .balanced: return 1
        case .traditional:
            return [.primaryDirections, .profections, .firdaria, .zodiacalReleasing, .lots, .solarReturn].contains(technique) ? 1.12 : 0.90
        case .modern:
            return [.solarArc, .secondaryProgressions, .transitsToAngles, .ascendantSignQuestionnaire].contains(technique) ? 1.10 : 0.92
        }
    }

    static func eventWindowDays(_ event: RectificationEvent) -> Double {
        switch event.precision {
        case .exactDay: return 45
        case .approximateWeek: return 60
        case .approximateMonth: return 90
        case .approximateQuarter: return 150
        case .approximateYear: return 365
        case .dateRange:
            guard let end = event.dateEnd else { return 90 }
            return max(45, end.timeIntervalSince(event.dateStart) / secondsPerDay / 2 + 30)
        }
    }

    static func eventDistanceDays(_ date: Date, event: RectificationEvent) -> Double {
        if let end = event.dateEnd, date >= event.dateStart, date <= end { return 0 }
        if date < event.dateStart { return event.dateStart.timeIntervalSince(date) / secondsPerDay }
        return date.timeIntervalSince(event.dateEnd ?? event.dateStart) / secondsPerDay
    }

    static func temporalCloseness(deltaDays: Double, windowDays: Double) -> Double {
        exp(-2.0 * max(0, deltaDays) / max(1, windowDays))
    }
}

struct SolarArcRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .solarArc

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let birthDate = try localDateFromBirthData(
            birthDate: candidate.chart.birthDate,
            birthTime: candidate.birthTime,
            timezoneName: candidate.chart.timezone
        )
        let engine = SolarArcEngine()
        var result: [RectificationEvidence] = []
        let natalPoints = candidate.chart.bodies.map { ($0.key, $0.label, $0.longitude) }
            + [("ASC", "Ascendente", candidate.ascendantLongitude), ("MC", "Medio Cielo", candidate.mcLongitude)]
        let angles = [("ASC", "Ascendente", candidate.ascendantLongitude), ("MC", "Medio Cielo", candidate.mcLongitude)]

        for event in session.events {
            let age = event.dateStart.timeIntervalSince(birthDate) / RectificationScoringSupport.secondsPerDay / RectificationScoringSupport.tropicalYearDays
            guard age >= 0, let arc = engine.solarArcAmount(chart: candidate.chart, age: age) else { continue }
            let maxOrb = 1.0 * config.orbMultiplier
            for point in natalPoints {
                let directed = normalized(point.2 + arc)
                for angle in angles {
                    let (aspect, orb) = RectificationScoringSupport.closestAspect(source: directed, target: angle.2)
                    guard orb <= maxOrb else { continue }
                    let fit = RectificationSymbolismRules.symbolicFit(event: event, sourceKey: point.0, targetKey: angle.0)
                    let closeness = 1 - orb / maxOrb
                    result.append(RectificationEvidence(
                        id: UUID(), eventID: event.id, technique: technique,
                        factor: "\(point.1) por arco solar \(aspect.label) \(angle.1)",
                        exactDate: event.dateStart, eventDate: event.dateStart, deltaDays: 0,
                        orbDegrees: orb, symbolicFit: fit,
                        score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: closeness),
                        explanation: "El arco solar activa un ángulo natal con orbe \(String(format: "%.2f", orb))°.",
                        debugData: ["source": point.0, "target": angle.0, "aspect": aspect.rawValue, "arc": String(arc)]
                    ))
                }
            }
        }
        return result
    }

    private func normalized(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }
}

struct TransitAngleRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .transitsToAngles
    private let transitKeys = Set(["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON", "MARTE"])
    private let transitsByEvent: [UUID: [String: RectificationTransitBody]]

    init(cache: RectificationEphemerisCache? = nil) {
        transitsByEvent = cache?.transitsByEvent ?? [:]
    }

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        var result: [RectificationEvidence] = []
        let angles = [("ASC", "Ascendente", candidate.ascendantLongitude), ("MC", "Medio Cielo", candidate.mcLongitude)]
        let activeTransitKeys = config.useModernPlanets ? transitKeys : transitKeys.subtracting(["URANO", "NEPTUNO", "PLUTON"])
        for event in session.events {
            try Task.checkCancellation()
            let planets: [String: RectificationTransitBody]
            if let cached = transitsByEvent[event.id] {
                planets = cached
            } else {
                let jd = event.dateStart.timeIntervalSince1970 / RectificationScoringSupport.secondsPerDay + 2_440_587.5
                planets = try AstroEngine.calcPlanets(jd: jd).mapValues {
                    RectificationTransitBody(label: $0.label, longitude: $0.deg)
                }
            }
            for key in activeTransitKeys {
                guard let planet = planets[key] else { continue }
                for angle in angles {
                    let (aspect, orb) = RectificationScoringSupport.closestAspect(source: planet.longitude, target: angle.2)
                    let maxOrb = (key == "MARTE" ? 1.0 : 1.5) * config.orbMultiplier
                    guard orb <= maxOrb else { continue }
                    let fit = RectificationSymbolismRules.symbolicFit(event: event, sourceKey: key, targetKey: angle.0)
                    result.append(RectificationEvidence(
                        id: UUID(), eventID: event.id, technique: technique,
                        factor: "\(planet.label) en tránsito \(aspect.label) \(angle.1)",
                        exactDate: event.dateStart, eventDate: event.dateStart, deltaDays: 0,
                        orbDegrees: orb, symbolicFit: fit,
                        score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: 1 - orb / maxOrb),
                        explanation: "Un planeta transitante activa un ángulo de la candidata en la fecha del evento.",
                        debugData: ["transit": key, "target": angle.0, "aspect": aspect.rawValue]
                    ))
                }
            }
        }
        return result
    }
}

struct ProgressionRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .secondaryProgressions

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let engine = SecondaryProgressionEngine()
        var result: [RectificationEvidence] = []
        for event in session.events {
            try Task.checkCancellation()
            let window = RectificationScoringSupport.eventWindowDays(event)
            let from = event.dateStart.addingTimeInterval(-window * RectificationScoringSupport.secondsPerDay)
            let to = (event.dateEnd ?? event.dateStart).addingTimeInterval(window * RectificationScoringSupport.secondsPerDay)
            let aspects = engine.progressedAspects(chart: candidate.chart, from: from, to: to)
            for aspect in aspects where aspect.progressedKey == "LUNA" || aspect.progressedKey == "ASC" || aspect.progressedKey == "MC" || aspect.targetKey == "ASC" || aspect.targetKey == "MC" {
                let delta = RectificationScoringSupport.eventDistanceDays(aspect.date, event: event)
                let fit = RectificationSymbolismRules.symbolicFit(event: event, sourceKey: aspect.progressedKey, targetKey: aspect.targetKey)
                result.append(RectificationEvidence(
                    id: UUID(), eventID: event.id, technique: technique,
                    factor: aspect.title, exactDate: aspect.date, eventDate: event.dateStart,
                    deltaDays: delta, orbDegrees: aspect.orb, symbolicFit: fit,
                    score: RectificationScoringSupport.evidenceScore(
                        event: event, technique: technique, config: config, fit: fit,
                        closeness: RectificationScoringSupport.temporalCloseness(deltaDays: delta, windowDays: window),
                        techniqueQuality: aspect.progressedKey == "LUNA" ? 1 : 0.85
                    ),
                    explanation: "La progresión perfecciona cerca del evento con diferencia de \(Int(delta.rounded())) días.",
                    debugData: ["source": aspect.progressedKey, "target": aspect.targetKey, "aspect": aspect.aspectKey]
                ))
            }
        }
        return result
    }
}

struct PrimaryDirectionRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .primaryDirections

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let birthDate = try localDateFromBirthData(
            birthDate: candidate.chart.birthDate,
            birthTime: candidate.birthTime,
            timezoneName: candidate.chart.timezone
        )
        let jd = try julianDayFromLocal(
            birthDate: candidate.chart.birthDate,
            birthTime: candidate.birthTime,
            timezoneName: candidate.chart.timezone
        ).jd
        let maximumAge = session.events.map { max(0, $0.dateStart.timeIntervalSince(birthDate) / RectificationScoringSupport.secondsPerDay / RectificationScoringSupport.tropicalYearDays) }.max() ?? 1
        let directions = PrimaryDirectionCalculator().calculate(
            chart: candidate.chart,
            jd: jd,
            birthDate: birthDate,
            config: .init(maxYears: maximumAge + 2)
        )
        var result: [RectificationEvidence] = []
        for event in session.events {
            let window = RectificationScoringSupport.eventWindowDays(event)
            for direction in directions where direction.significator == "ASC" || direction.significator == "MC" {
                let delta = RectificationScoringSupport.eventDistanceDays(direction.estimatedDate, event: event)
                guard delta <= window * 2 else { continue }
                let fit = RectificationSymbolismRules.symbolicFit(event: event, sourceKey: direction.promissor, targetKey: direction.significator)
                result.append(RectificationEvidence(
                    id: UUID(), eventID: event.id, technique: technique,
                    factor: "\(direction.promissorLabel) \(direction.aspect.label) \(direction.significatorLabel)",
                    exactDate: direction.estimatedDate, eventDate: event.dateStart,
                    deltaDays: delta, orbDegrees: abs(direction.arc), symbolicFit: fit,
                    score: RectificationScoringSupport.evidenceScore(
                        event: event, technique: technique, config: config, fit: fit,
                        closeness: RectificationScoringSupport.temporalCloseness(deltaDays: delta, windowDays: window),
                        techniqueQuality: Double(direction.weight.rawValue) / 4
                    ),
                    explanation: "La dirección primaria fecha una activación angular a \(Int(delta.rounded())) días del evento.",
                    debugData: ["promissor": direction.promissor, "significator": direction.significator, "aspect": direction.aspect.rawValue, "type": direction.directionType.rawValue]
                ))
            }
        }
        return result
    }
}
