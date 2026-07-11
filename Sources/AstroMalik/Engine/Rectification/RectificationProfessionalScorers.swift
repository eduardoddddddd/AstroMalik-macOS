import Foundation

struct AscendantQuestionnaireScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .ascendantSignQuestionnaire

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        guard let questionnaire = session.ascendantQuestionnaire,
              questionnaire.completion >= 0.6,
              let preliminary = questionnaire.preliminarySignIndex else { return [] }
        let candidateSign = Int(candidate.ascendantLongitude / 30) % 12
        let distance = min((candidateSign - preliminary + 12) % 12, (preliminary - candidateSign + 12) % 12)
        let closeness: Double = distance == 0 ? 1 : ([4, 8].contains(distance) ? 0.65 : 0.15)
        return session.events.map { event in
            RectificationEvidence(
                id: UUID(), eventID: event.id, technique: technique,
                factor: "Cuestionario: \(SIGN_LABELS[preliminary]) frente a ASC \(SIGN_LABELS[candidateSign])",
                exactDate: nil, eventDate: event.dateStart, deltaDays: nil, orbDegrees: nil,
                symbolicFit: distance == 0 ? .moderate : .weak,
                score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: distance == 0 ? .moderate : .weak, closeness: closeness),
                explanation: "Se usa como señal preliminar de baja ponderación, nunca como prueba biográfica.",
                debugData: ["preliminarySign": SIGN_KEYS[preliminary], "candidateSign": SIGN_KEYS[candidateSign], "completion": String(questionnaire.completion)]
            )
        }
    }
}

struct ProfectionRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .profections

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let birth = try localDateFromBirthData(birthDate: candidate.chart.birthDate, birthTime: candidate.birthTime, timezoneName: candidate.chart.timezone)
        let ascSign = Int(candidate.ascendantLongitude / 30) % 12
        return session.events.compactMap { event in
            let age = max(0, Int(event.dateStart.timeIntervalSince(birth) / 86_400 / 365.2422))
            let house = age % 12 + 1
            let sign = (ascSign + age) % 12
            let ruler = EssentialDignityEngine.domicileRuler(of: sign)
            let rule = RectificationSymbolismRules.rule(for: event.type)
            let houseMatch = rule.houses.contains(house)
            let rulerMatch = rule.bodyKeys.contains(ruler)
            guard houseMatch || rulerMatch else { return nil }
            let fit: RectificationSymbolicFit = houseMatch && rulerMatch ? .strong : .moderate
            return RectificationEvidence(
                id: UUID(), eventID: event.id, technique: technique,
                factor: "Profección anual de casa \(house), regente \(ExtendedAstro.planetLabel(for: ruler))",
                exactDate: event.dateStart, eventDate: event.dateStart, deltaDays: 0, orbDegrees: nil,
                symbolicFit: fit,
                score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: 1, techniqueQuality: 0.72),
                explanation: "La casa o su señor anual coincide con los significadores del evento.",
                debugData: ["house": String(house), "sign": SIGN_KEYS[sign], "ruler": ruler]
            )
        }
    }
}

struct FirdariaRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .firdaria

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let engine = FirdariaEngine()
        return session.events.compactMap { event in
            let period = engine.currentFirdaria(chart: candidate.chart, at: event.dateStart)
            let major = period.major.ruler.key
            let minor = period.minor?.ruler.key
            let rule = RectificationSymbolismRules.rule(for: event.type)
            guard rule.bodyKeys.contains(major) || minor.map(rule.bodyKeys.contains) == true else { return nil }
            let fit: RectificationSymbolicFit = rule.bodyKeys.contains(major) && minor.map(rule.bodyKeys.contains) == true ? .strong : .moderate
            return RectificationEvidence(
                id: UUID(), eventID: event.id, technique: technique,
                factor: "Firdaria \(period.major.ruler.label) / \(period.minor?.ruler.label ?? "—")",
                exactDate: event.dateStart, eventDate: event.dateStart, deltaDays: 0, orbDegrees: nil,
                symbolicFit: fit,
                score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: 1, techniqueQuality: 0.62),
                explanation: "Los señores mayor o menor coinciden con significadores del evento.",
                debugData: ["major": major, "minor": minor ?? ""]
            )
        }
    }
}

struct ZodiacalReleasingRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .zodiacalReleasing

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let fortune = ZodiacalReleasingEngine().zr(chart: candidate.chart, lot: .fortune, depth: 2)
        let spirit = ZodiacalReleasingEngine().zr(chart: candidate.chart, lot: .spirit, depth: 2)
        return session.events.compactMap { event in
            let periods = [fortune.currentL1(at: event.dateStart), spirit.currentL1(at: event.dateStart)].compactMap { $0 }
            guard let strongest = periods.max(by: { zrQuality($0) < zrQuality($1) }), zrQuality(strongest) >= 0.55 else { return nil }
            let fit: RectificationSymbolicFit = strongest.isPeak || strongest.hasLoosingOfBond ? .strong : .moderate
            return RectificationEvidence(
                id: UUID(), eventID: event.id, technique: technique,
                factor: "ZR L1 \(strongest.signLabel)\(strongest.isPeak ? " · peak" : "")\(strongest.hasLoosingOfBond ? " · ruptura de vínculo" : "")",
                exactDate: event.dateStart, eventDate: event.dateStart, deltaDays: 0, orbDegrees: nil,
                symbolicFit: fit,
                score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: zrQuality(strongest), techniqueQuality: 0.62),
                explanation: "El periodo mayor aporta confirmación temporal, no decide por sí solo la hora.",
                debugData: ["sign": strongest.signKey, "angularity": strongest.angularity?.rawValue ?? "", "peak": String(strongest.isPeak)]
            )
        }
    }

    private func zrQuality(_ period: ZRPeriod) -> Double {
        if period.hasLoosingOfBond { return 1 }
        if period.isPeak { return 0.9 }
        if period.angularity == .angular { return 0.7 }
        return period.angularity == .succedent ? 0.55 : 0.35
    }
}

struct LotsRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .lots

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        let lots = try LotsEngine().lots(chart: candidate.chart)
        return session.events.compactMap { event in
            let rule = RectificationSymbolismRules.rule(for: event.type)
            let relevant = lots.filter { rule.houses.contains($0.house) || rule.bodyKeys.contains($0.rulerKey) }
            guard let lot = relevant.first else { return nil }
            let fit: RectificationSymbolicFit = rule.houses.contains(lot.house) && rule.bodyKeys.contains(lot.rulerKey) ? .strong : .moderate
            return RectificationEvidence(
                id: UUID(), eventID: event.id, technique: technique,
                factor: "\(lot.name) en casa \(lot.house), regente \(lot.rulerLabel)",
                exactDate: nil, eventDate: event.dateStart, deltaDays: nil, orbDegrees: nil,
                symbolicFit: fit,
                score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: 0.75, techniqueQuality: 0.55),
                explanation: "El lote sensible a la hora cae en una casa o regencia coherente con el evento.",
                debugData: ["lot": lot.kind.rawValue, "house": String(lot.house), "ruler": lot.rulerKey]
            )
        }
    }
}

struct SolarReturnRectificationScorer: RectificationTechniqueScorer {
    let technique: RectificationTechnique = .solarReturn

    func evidence(candidate: RectificationCandidate, session: RectificationSession, config: RectificationConfig) throws -> [RectificationEvidence] {
        var output: [RectificationEvidence] = []
        let eventsByYear = Dictionary(grouping: session.events) {
            Calendar(identifier: .gregorian).component(.year, from: $0.dateStart)
        }
        for (year, events) in eventsByYear {
            try Task.checkCancellation()
            let jd = try SolarReturnEngine.solarReturnJD(natalChart: candidate.chart, year: year)
            let houses = try AstroEngine.calcHouses(
                jd: jd,
                lat: candidate.chart.latitude,
                lon: candidate.chart.longitude,
                system: config.houseSystem.swissEphemerisCode
            )
            let pairs = [("ASC", houses.asc, candidate.ascendantLongitude), ("MC", houses.mc, candidate.mcLongitude)]
            guard let match = pairs.map({ ($0.0, RectificationScoringSupport.closestAspect(source: $0.1, target: $0.2)) }).min(by: { $0.1.1 < $1.1.1 }), match.1.1 <= 4 * config.orbMultiplier else { continue }
            for event in events {
                let rule = RectificationSymbolismRules.rule(for: event.type)
                let fit: RectificationSymbolicFit = (match.0 == "ASC" && rule.houses.contains(1)) || (match.0 == "MC" && rule.houses.contains(10)) ? .strong : .moderate
                output.append(RectificationEvidence(
                    id: UUID(), eventID: event.id, technique: technique,
                    factor: "Ángulo de revolución solar \(match.1.0.label) \(match.0)",
                    exactDate: nil, eventDate: event.dateStart, deltaDays: nil, orbDegrees: match.1.1,
                    symbolicFit: fit,
                    score: RectificationScoringSupport.evidenceScore(event: event, technique: technique, config: config, fit: fit, closeness: 1 - match.1.1 / max(0.01, 4 * config.orbMultiplier), techniqueQuality: 0.65),
                    explanation: "La revolución del año repite un ángulo natal de la candidata.",
                    debugData: ["year": String(year), "angle": match.0, "aspect": match.1.0.rawValue]
                ))
            }
        }
        return output
    }
}
