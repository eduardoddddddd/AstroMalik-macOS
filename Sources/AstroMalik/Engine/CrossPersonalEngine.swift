import Foundation

/// Sintetizador cross-personal. Consume los resultados de los engines
/// existentes (vía `CrossPersonalInputs`) y produce un estado astrológico
/// agregado con capas y cola de prioridad por convergencia. Sin LLM,
/// determinista, puro (no toca disco ni Swiss Ephemeris).
enum CrossPersonalEngine {
    static let engineVersion = "1.0.0"

    static func state(
        inputs: CrossPersonalInputs,
        options: CrossPersonalOptions = .default
    ) -> CrossPersonalState {
        let signature = buildSignature(inputs: inputs)
        let annual = buildAnnualLayer(inputs: inputs)
        let medium = buildMediumTermLayer(inputs: inputs)
        let short = buildShortTermLayer(inputs: inputs)
        let lunar = buildLunarLayer(inputs: inputs)
        let layers = [annual, medium, short, lunar]
        let topics = buildTopics(
            layers: layers,
            inputs: inputs,
            signature: signature,
            options: options
        )
        let metadata = CrossMetadata(
            generatedAt: Date(),
            referenceDate: inputs.referenceDate,
            chartID: inputs.chart.id,
            chartName: inputs.chart.name,
            engineVersion: engineVersion
        )
        return CrossPersonalState(
            metadata: metadata,
            natalSignature: signature,
            layers: layers,
            topics: topics
        )
    }
}

// MARK: - Natal Signature

private extension CrossPersonalEngine {
    static func buildSignature(inputs: CrossPersonalInputs) -> CrossNatalSignature {
        let chart = inputs.chart
        let ext = inputs.natalExtended

        let sun = chart.bodies.first { $0.key == "SOL" }
        let moon = chart.bodies.first { $0.key == "LUNA" }

        let sect = ext.almutenFiguris.totalScores.isEmpty
            ? SectEngine.sect(of: chart)
            : SectEngine.sect(of: chart)

        let ascSignIndex = signIndex(longitude: chart.ascendant.longitude)
        let ascRuler = EssentialDignityEngine.domicileRuler(of: ascSignIndex)

        let prominentLots = pickProminentLots(from: ext.lots, sect: sect, ascRulerKey: ascRuler)
        let patterns = ext.aspectPatterns.prefix(5).map { pattern in
            PatternSummary(
                kind: pattern.kind.rawValue,
                title: pattern.title,
                planetLabels: pattern.planetLabels,
                averageOrb: pattern.averageOrb
            )
        }

        let elements = elementBalance(from: ext.distribution)
        let modalities = modalityBalance(from: ext.distribution)
        let stars = ext.fixedStars.contacts.prefix(8).map {
            FixedStarSummary(
                starName: $0.starName,
                targetLabel: $0.targetLabel,
                orb: $0.orb,
                nature: $0.nature
            )
        }

        return CrossNatalSignature(
            sun: signedPlacement(from: sun),
            moon: signedPlacement(from: moon),
            ascendant: angularSummary(longitude: chart.ascendant.longitude, formatted: chart.ascendant.formatted),
            mc: angularSummary(longitude: chart.mc.longitude, formatted: chart.mc.formatted),
            sect: sect,
            ascendantRulerKey: ascRuler,
            ascendantRulerLabel: planetLabel(for: ascRuler),
            almutenFigurisKey: ext.almutenFiguris.winnerKey,
            almutenFigurisLabel: ext.almutenFiguris.winnerLabel,
            rulerOfGenitureKey: ext.rulerOfGeniture.rulerKey,
            rulerOfGenitureLabel: ext.rulerOfGeniture.rulerLabel,
            prominentLots: prominentLots,
            aspectPatterns: Array(patterns),
            elementBalance: elements,
            modalityBalance: modalities,
            fixedStarContacts: Array(stars)
        )
    }

    static func signedPlacement(from body: PlanetBody?) -> SignedPlacement {
        guard let body else {
            return SignedPlacement(key: "", label: "", signLabel: "", house: 0, degree: "", retrograde: false)
        }
        let sign = signIndex(longitude: body.longitude)
        return SignedPlacement(
            key: body.key,
            label: body.label,
            signLabel: SIGN_LABELS[sign],
            house: body.house,
            degree: body.formatted,
            retrograde: body.retrograde
        )
    }

    static func angularSummary(longitude: Double, formatted: String) -> AngularSummary {
        let sign = signIndex(longitude: longitude)
        return AngularSummary(signLabel: SIGN_LABELS[sign], degree: formatted)
    }

    static func pickProminentLots(from lots: [NatalLot], sect: SectInfo, ascRulerKey: String) -> [LotSummary] {
        let priorityOrder: [NatalLotKind] = [.fortune, .spirit, .eros, .victory, .necessity, .audacity, .nemesis]
        let map = Dictionary(uniqueKeysWithValues: lots.map { ($0.kind, $0) })
        return priorityOrder.prefix(3).compactMap { kind -> LotSummary? in
            guard let lot = map[kind] else { return nil }
            return LotSummary(
                kind: kind,
                signLabel: lot.signLabel,
                house: lot.house,
                rulerLabel: lot.rulerLabel
            )
        }
    }

    static func elementBalance(from distribution: NatalDistribution) -> ElementBalance {
        func count(_ name: String) -> Int {
            distribution.elements.first { $0.name.localizedCaseInsensitiveContains(name) }?.count ?? 0
        }
        return ElementBalance(
            fire: count("fuego"),
            earth: count("tierra"),
            air: count("aire"),
            water: count("agua")
        )
    }

    static func modalityBalance(from distribution: NatalDistribution) -> ModalityBalance {
        func count(_ name: String) -> Int {
            distribution.modalities.first { $0.name.localizedCaseInsensitiveContains(name) }?.count ?? 0
        }
        return ModalityBalance(
            cardinal: count("cardinal"),
            fixed: count("fijo"),
            mutable: count("mutable")
        )
    }
}

// MARK: - Annual Layer

private extension CrossPersonalEngine {
    static func buildAnnualLayer(inputs: CrossPersonalInputs) -> CrossLayer {
        var signals: [CrossSignal] = []

        // Profección anual
        let prof = inputs.profections.annual
        let profID = "annual.profection.\(prof.house).\(prof.lordKey)"
        let lotySubject = CrossSubject.planet(prof.lordKey, label: prof.lordLabel)
        signals.append(CrossSignal(
            id: profID,
            layer: .annual,
            source: "profection",
            subject: CrossSubject.house(prof.house),
            secondarySubjects: [lotySubject, CrossSubject(kind: .sign, key: prof.signKey, label: prof.signLabel)],
            weight: 1.0,
            summary: "Año en casa \(prof.house) (\(prof.signLabel)); Lord of the Year: \(prof.lordLabel)",
            detail: "Profección anual whole-sign desde el Ascendente. Lord of the Year = regente domicilio del signo profeccionado.",
            startsAt: prof.startDate,
            endsAt: prof.endDate,
            exactAt: nil
        ))

        // Lord of the Year como signal independiente para que entre en topics aunque la casa no converja
        signals.append(CrossSignal(
            id: "annual.profection.loty.\(prof.lordKey)",
            layer: .annual,
            source: "profection_loty",
            subject: lotySubject,
            secondarySubjects: [CrossSubject.house(prof.house)],
            weight: 0.9,
            summary: "Lord of the Year: \(prof.lordLabel)",
            detail: "Regente del año. Sus tránsitos y direcciones pesan el doble durante este año profeccional.",
            startsAt: prof.startDate,
            endsAt: prof.endDate,
            exactAt: nil
        ))

        // Revolución solar
        if let solar = inputs.solarReturn {
            let ascRulerKey = EssentialDignityEngine.domicileRuler(of: Int(solar.solarChart.ascendant.longitude / 30))
            signals.append(CrossSignal(
                id: "annual.solarReturn.ascRuler.\(ascRulerKey)",
                layer: .annual,
                source: "solar_return",
                subject: CrossSubject.planet(ascRulerKey, label: planetLabel(for: ascRulerKey)),
                secondarySubjects: [CrossSubject.axis("ASC")],
                weight: 0.7,
                summary: "Regente del Ascendente de la Revolución Solar: \(planetLabel(for: ascRulerKey))",
                detail: "El planeta que rige el ASC de la revolución solar marca el tono operativo del año.",
                startsAt: prof.startDate,
                endsAt: prof.endDate,
                exactAt: nil
            ))
            for repetition in solar.natalRepetitions.prefix(3) {
                signals.append(CrossSignal(
                    id: "annual.solarReturn.repetition.\(repetition.planetKey)",
                    layer: .annual,
                    source: "solar_return_repetition",
                    subject: CrossSubject.planet(repetition.planetKey, label: repetition.planetLabel),
                    secondarySubjects: [CrossSubject.house(repetition.house)],
                    weight: 0.5,
                    summary: "\(repetition.planetLabel) repite casa \(repetition.house) en la revolución solar",
                    detail: "Repetición de casa natal-solar: tema natal reforzado este año.",
                    startsAt: prof.startDate,
                    endsAt: prof.endDate,
                    exactAt: nil
                ))
            }
            for angular in solar.angularPlanets.prefix(4) {
                signals.append(CrossSignal(
                    id: "annual.solarReturn.angular.\(angular.planetKey)",
                    layer: .annual,
                    source: "solar_return_angular",
                    subject: CrossSubject.planet(angular.planetKey, label: angular.planetLabel),
                    secondarySubjects: [CrossSubject.house(angular.solarHouse)],
                    weight: 0.6,
                    summary: "\(angular.planetLabel) angular en RS (casa \(angular.solarHouse))",
                    detail: "Planetas angulares en la revolución solar dominan el año.",
                    startsAt: prof.startDate,
                    endsAt: prof.endDate,
                    exactAt: nil
                ))
            }
        }

        // ZR Spirit y Fortune — L1 y L2 actuales
        signals.append(contentsOf: zrSignals(timeline: inputs.zrSpirit, lotKind: .spirit, referenceDate: inputs.referenceDate))
        signals.append(contentsOf: zrSignals(timeline: inputs.zrFortune, lotKind: .fortune, referenceDate: inputs.referenceDate))

        // Firdaria mayor
        let major = inputs.firdariaMajor
        signals.append(CrossSignal(
            id: "annual.firdaria.major.\(major.ruler.key)",
            layer: .annual,
            source: "firdaria_major",
            subject: CrossSubject.planet(major.ruler.key, label: major.ruler.label),
            secondarySubjects: [],
            weight: 0.85,
            summary: "Firdaria mayor: \(major.ruler.shortLabel) (\(Int(major.nominalYears)) años)",
            detail: "Período firdariano mayor en curso. Da el color de fondo de varios años.",
            startsAt: major.startDate,
            endsAt: major.endDate,
            exactAt: nil
        ))

        // Firdaria menor
        if let minor = inputs.firdariaMinor {
            signals.append(CrossSignal(
                id: "annual.firdaria.minor.\(minor.ruler.key)",
                layer: .annual,
                source: "firdaria_minor",
                subject: CrossSubject.planet(minor.ruler.key, label: minor.ruler.label),
                secondarySubjects: [CrossSubject.planet(major.ruler.key, label: major.ruler.label)],
                weight: 0.6,
                summary: "Firdaria menor: \(minor.ruler.shortLabel) dentro de \(major.ruler.shortLabel)",
                detail: "Sub-período firdariano en curso. Modula el período mayor.",
                startsAt: minor.startDate,
                endsAt: minor.endDate,
                exactAt: nil
            ))
        }

        return CrossLayer(kind: .annual, label: CrossLayerKind.annual.label, signals: signals)
    }

    static func zrSignals(timeline: ZRTimeline, lotKind: NatalLotKind, referenceDate: Date) -> [CrossSignal] {
        var out: [CrossSignal] = []
        guard let l1 = timeline.currentL1(at: referenceDate) else { return out }

        let l1Subject = CrossSubject.sign(l1.signIndex)
        let lotSubject = CrossSubject.lot(lotKind)
        out.append(CrossSignal(
            id: "annual.zr.\(lotKind.rawValue).l1.\(l1.signKey)",
            layer: .annual,
            source: "zr_l1_\(lotKind.rawValue)",
            subject: l1Subject,
            secondarySubjects: [lotSubject],
            weight: 0.9,
            summary: "ZR \(lotKind.title) L1 en \(l1.signLabel)",
            detail: "Capítulo mayor de \(lotKind.title) en \(l1.signLabel). Tema de fondo de este período de la vida.",
            startsAt: l1.startDate,
            endsAt: l1.endDate,
            exactAt: nil
        ))

        if let l2 = timeline.currentL2(at: referenceDate) {
            let l2Subject = CrossSubject.sign(l2.signIndex)
            let weight = l2.isPeak ? 0.95 : 0.75
            out.append(CrossSignal(
                id: "annual.zr.\(lotKind.rawValue).l2.\(l2.signKey).\(Int(l2.startDate.timeIntervalSince1970))",
                layer: .annual,
                source: "zr_l2_\(lotKind.rawValue)",
                subject: l2Subject,
                secondarySubjects: [lotSubject, l1Subject],
                weight: weight,
                summary: "ZR \(lotKind.title) L2 en \(l2.signLabel)\(l2.isPeak ? " — PEAK" : "")",
                detail: l2.isPeak
                    ? "Sub-período L2 en pico angular respecto al L1. Período de máxima visibilidad."
                    : "Sub-período L2 en curso dentro de \(l1.signLabel).",
                startsAt: l2.startDate,
                endsAt: l2.endDate,
                exactAt: nil
            ))
        }

        // LB próximo (siguiente Loosing of the Bond)
        let upcoming = timeline.upcomingHighlightedEvents(after: referenceDate, limit: 3)
        for event in upcoming where event.kind == .loosingOfBond {
            out.append(CrossSignal(
                id: "annual.zr.\(lotKind.rawValue).lb.\(event.id)",
                layer: .annual,
                source: "zr_lb_\(lotKind.rawValue)",
                subject: lotSubject,
                secondarySubjects: [],
                weight: 0.7,
                summary: "Próximo LB de \(lotKind.title) — \(event.signLabel ?? "")",
                detail: "Loosing of the Bond próximo. Cambio cualitativo del capítulo.",
                startsAt: nil,
                endsAt: nil,
                exactAt: event.date
            ))
        }

        return out
    }
}

// MARK: - Medium-term Layer

private extension CrossPersonalEngine {
    static func buildMediumTermLayer(inputs: CrossPersonalInputs) -> CrossLayer {
        var signals: [CrossSignal] = []
        let referenceYear = inputs.referenceDate
        let lower = referenceYear.addingTimeInterval(-365 * 86_400)
        let upper = referenceYear.addingTimeInterval(365 * 86_400)

        // Direcciones primarias activas ±12 meses
        for direction in inputs.primaryDirections where direction.estimatedDate >= lower && direction.estimatedDate <= upper {
            let primary = mapKeyToSubject(direction.significator, label: direction.significatorLabel)
            let secondary = mapKeyToSubject(direction.promissor, label: direction.promissorLabel)
            signals.append(CrossSignal(
                id: "medium.primary.\(direction.id.uuidString)",
                layer: .mediumTerm,
                source: "primary_direction",
                subject: primary,
                secondarySubjects: [secondary],
                weight: weightForPD(direction.weight),
                summary: "PD: \(direction.promissorLabel) \(direction.aspect.symbol ?? direction.aspect.label) \(direction.significatorLabel)",
                detail: "Dirección primaria \(direction.directionType.rawValue) en plano \(direction.aspectPlane.rawValue), clave \(direction.key.rawValue).",
                startsAt: nil,
                endsAt: nil,
                exactAt: direction.estimatedDate
            ))
        }

        // Arco solar ±12 meses
        for arc in inputs.solarArc where arc.exactDate >= lower && arc.exactDate <= upper {
            let primary = mapKeyToSubject(arc.natalPoint, label: arc.natalPointLabel)
            let secondary = mapKeyToSubject(arc.directedPoint, label: arc.directedPointLabel)
            signals.append(CrossSignal(
                id: "medium.solarArc.\(arc.id.uuidString)",
                layer: .mediumTerm,
                source: "solar_arc",
                subject: primary,
                secondarySubjects: [secondary],
                weight: weightForPD(arc.weight),
                summary: "Arco solar: \(arc.directedPointLabel) \(arc.aspect.label) \(arc.natalPointLabel)",
                detail: "Dirección por arco solar (modo \(arc.mode.label)).",
                startsAt: nil,
                endsAt: nil,
                exactAt: arc.exactDate
            ))
        }

        // Progresiones secundarias — aspectos del año
        for aspect in inputs.progressedAspects where aspect.date >= lower && aspect.date <= upper {
            let primary = mapKeyToSubject(aspect.targetKey, label: aspect.targetLabel)
            let secondary = mapKeyToSubject(aspect.progressedKey, label: aspect.progressedLabel)
            signals.append(CrossSignal(
                id: "medium.progressed.\(aspect.id)",
                layer: .mediumTerm,
                source: "progressed_aspect",
                subject: primary,
                secondarySubjects: [secondary],
                weight: 0.5 + Double(aspect.priority) * 0.1,
                summary: "Progresión: \(aspect.progressedLabel) \(aspect.aspectLabel) \(aspect.targetLabel)",
                detail: aspect.kind.label,
                startsAt: nil,
                endsAt: nil,
                exactAt: aspect.date
            ))
        }

        // Luna progresada por casa actual
        if let moon = inputs.progressionSnapshot.progressedMoon {
            signals.append(CrossSignal(
                id: "medium.progressed.moon.house.\(moon.house)",
                layer: .mediumTerm,
                source: "progressed_moon_house",
                subject: CrossSubject.house(moon.house),
                secondarySubjects: [CrossSubject.planet("LUNA", label: "☽ Luna")],
                weight: 0.55,
                summary: "Luna progresada en casa \(moon.house) (\(moon.signLabel))",
                detail: "La Luna progresada permanece ~2-3 años en cada casa: tema doméstico/emocional del período.",
                startsAt: nil,
                endsAt: nil,
                exactAt: nil
            ))
        }

        // Fase lunar progresada actual
        let phase = inputs.progressionSnapshot.lunarPhase
        signals.append(CrossSignal(
            id: "medium.progressed.phase.\(phase.name.rawValue)",
            layer: .mediumTerm,
            source: "progressed_lunar_phase",
            subject: CrossSubject.planet("LUNA", label: "☽ Luna"),
            secondarySubjects: [CrossSubject.planet("SOL", label: "☉ Sol")],
            weight: 0.45,
            summary: "Fase lunar progresada: \(phase.label)",
            detail: "Fase progresada del ciclo Sol-Luna (~30 años por ciclo completo).",
            startsAt: nil,
            endsAt: nil,
            exactAt: nil
        ))

        // Ingresos lunares progresados próximos
        for ingress in inputs.progressionSnapshot.nextLunarSignIngresses.prefix(2) {
            signals.append(CrossSignal(
                id: "medium.progressed.moon.signIngress.\(ingress.id)",
                layer: .mediumTerm,
                source: "progressed_moon_sign_ingress",
                subject: CrossSubject.planet("LUNA", label: "☽ Luna"),
                secondarySubjects: [],
                weight: 0.4,
                summary: "Luna progresada → \(ingress.toValue)",
                detail: ingress.description,
                startsAt: nil,
                endsAt: nil,
                exactAt: ingress.date
            ))
        }

        return CrossLayer(kind: .mediumTerm, label: CrossLayerKind.mediumTerm.label, signals: signals)
    }
}

// MARK: - Short-term Layer

private extension CrossPersonalEngine {
    static func buildShortTermLayer(inputs: CrossPersonalInputs) -> CrossLayer {
        var signals: [CrossSignal] = []
        let slowKeys: Set<String> = ["SATURNO", "URANO", "NEPTUNO", "PLUTON", "NODO_NORTE", "NODO_SUR"]
        let sensitiveKeys: Set<String> = sensitiveTargets(inputs: inputs)

        for event in inputs.transits {
            guard slowKeys.contains(event.transitKey) else { continue }
            guard sensitiveKeys.contains(event.natalKey) || event.priorityBand == .critical || event.priorityBand == .high else { continue }
            let primary = mapKeyToSubject(event.natalKey, label: event.natalLabel)
            let secondary = mapKeyToSubject(event.transitKey, label: event.transitLabel)
            let weight = max(0.3, min(1.0, event.priorityScore.isFinite ? event.priorityScore : 0.5))
            signals.append(CrossSignal(
                id: "short.transit.\(event.id.uuidString)",
                layer: .shortTerm,
                source: "transit",
                subject: primary,
                secondarySubjects: [secondary],
                weight: weight,
                summary: "Tránsito: \(event.transitLabel) \(event.aspectLabel) \(event.natalLabel) (\(event.priorityBand.label))",
                detail: event.metricReasons.joined(separator: " · "),
                startsAt: nil,
                endsAt: nil,
                exactAt: ISO8601DateFormatter().date(from: event.exactDate + "T12:00:00Z")
            ))
        }

        return CrossLayer(kind: .shortTerm, label: CrossLayerKind.shortTerm.label, signals: signals)
    }

    static func sensitiveTargets(inputs: CrossPersonalInputs) -> Set<String> {
        var set: Set<String> = ["SOL", "LUNA", "ASC", "MC"]
        set.insert(inputs.natalExtended.almutenFiguris.winnerKey)
        set.insert(inputs.natalExtended.rulerOfGeniture.rulerKey)
        set.insert(inputs.profections.annual.lordKey)
        let ascSign = signIndex(longitude: inputs.chart.ascendant.longitude)
        set.insert(EssentialDignityEngine.domicileRuler(of: ascSign))
        return set
    }
}

// MARK: - Lunar Layer

private extension CrossPersonalEngine {
    static func buildLunarLayer(inputs: CrossPersonalInputs) -> CrossLayer {
        var signals: [CrossSignal] = []
        for hit in inputs.upcomingLunations {
            let primary = mapKeyToSubject(hit.targetKey, label: hit.targetLabel)
            signals.append(CrossSignal(
                id: "lunar.lunation.\(hit.kind.rawValue).\(hit.targetKey).\(Int(hit.date.timeIntervalSince1970))",
                layer: .lunar,
                source: "lunation",
                subject: primary,
                secondarySubjects: [],
                weight: 0.5,
                summary: "\(labelForLunation(hit.kind)) sobre \(hit.targetLabel)",
                detail: "Lunación próxima a \(hit.signLabel) — orbe \(String(format: "%.2f", hit.orb))°.",
                startsAt: nil,
                endsAt: nil,
                exactAt: hit.date
            ))
        }
        for hit in inputs.upcomingEclipses {
            let primary = mapKeyToSubject(hit.targetKey, label: hit.targetLabel)
            signals.append(CrossSignal(
                id: "lunar.eclipse.\(hit.kind.rawValue).\(hit.targetKey).\(Int(hit.date.timeIntervalSince1970))",
                layer: .lunar,
                source: "eclipse",
                subject: primary,
                secondarySubjects: [],
                weight: 1.0,
                summary: "\(labelForLunation(hit.kind)) sobre \(hit.targetLabel)",
                detail: "Eclipse próximo en \(hit.signLabel) — orbe \(String(format: "%.2f", hit.orb))°. Impacto duradero.",
                startsAt: nil,
                endsAt: nil,
                exactAt: hit.date
            ))
        }
        return CrossLayer(kind: .lunar, label: CrossLayerKind.lunar.label, signals: signals)
    }

    static func labelForLunation(_ kind: LunarPointHit.Kind) -> String {
        switch kind {
        case .newMoon: return "Luna Nueva"
        case .fullMoon: return "Luna Llena"
        case .firstQuarter: return "Cuarto Creciente"
        case .lastQuarter: return "Cuarto Menguante"
        case .solarEclipse: return "Eclipse Solar"
        case .lunarEclipse: return "Eclipse Lunar"
        }
    }
}

// MARK: - Topics

private extension CrossPersonalEngine {
    static func buildTopics(
        layers: [CrossLayer],
        inputs: CrossPersonalInputs,
        signature: CrossNatalSignature,
        options: CrossPersonalOptions
    ) -> [PriorityTopic] {
        // Agrupar signals por subject primario
        var bySubject: [CrossSubject: [CrossSignal]] = [:]
        for layer in layers {
            for signal in layer.signals {
                bySubject[signal.subject, default: []].append(signal)
            }
        }

        let lotyKey = inputs.profections.annual.lordKey
        let sectLuminaryKey = signature.sect.luminary.key
        let rulerGenitureKey = signature.rulerOfGenitureKey

        let zrPeakSigns: Set<String> = {
            var set: Set<String> = []
            if let l2 = inputs.zrSpirit.currentL2(at: inputs.referenceDate), l2.isPeak {
                set.insert(l2.signKey)
            }
            if let l2 = inputs.zrFortune.currentL2(at: inputs.referenceDate), l2.isPeak {
                set.insert(l2.signKey)
            }
            return set
        }()

        var topics: [PriorityTopic] = []
        for (subject, signals) in bySubject {
            // Score base
            let base = signals.reduce(0.0) { acc, sig in
                acc + sig.weight * sig.layer.weight
            }
            // Eclipse multiplier
            let eclipseAdjustment = signals.reduce(0.0) { acc, sig in
                guard sig.layer == .lunar, sig.source == "eclipse" else { return acc }
                return acc + sig.weight * sig.layer.weight * (options.eclipseLunarMultiplier - 1.0)
            }
            // Convergencia
            let distinctLayers = Set(signals.map(\.layer))
            let convergence = options.convergenceMultipliers.multiplier(for: distinctLayers.count)
            var score = (base + eclipseAdjustment) * convergence

            // Bonus
            switch subject.kind {
            case .planet:
                if subject.key == lotyKey { score += options.subjectScoringBonus.lordOfTheYear }
                if subject.key == sectLuminaryKey { score += options.subjectScoringBonus.sectLuminary }
                if subject.key == rulerGenitureKey { score += options.subjectScoringBonus.rulerOfGeniture }
            case .sign:
                if zrPeakSigns.contains(subject.key) { score += options.subjectScoringBonus.zrPeakSignMatch }
            default:
                break
            }

            let signalIDs = signals.map(\.id)
            let summary = composeTopicSummary(subject: subject, signals: signals)
            let topicID = "topic.\(subject.kind.rawValue).\(subject.key)"
            topics.append(PriorityTopic(
                id: topicID,
                title: composeTopicTitle(subject: subject),
                subject: subject,
                convergenceScore: round(score * 1000) / 1000,
                layerCount: distinctLayers.count,
                layers: Array(distinctLayers).sorted { $0.rawValue < $1.rawValue },
                signalIDs: signalIDs,
                summary: summary
            ))
        }

        return topics
            .sorted { lhs, rhs in
                if lhs.convergenceScore != rhs.convergenceScore { return lhs.convergenceScore > rhs.convergenceScore }
                if lhs.layerCount != rhs.layerCount { return lhs.layerCount > rhs.layerCount }
                return lhs.subject.key < rhs.subject.key
            }
            .prefix(options.topTopicsLimit)
            .map { $0 }
    }

    static func composeTopicTitle(subject: CrossSubject) -> String {
        switch subject.kind {
        case .planet: return "\(subject.label) como tema"
        case .house: return "\(subject.label) activada"
        case .sign: return "\(subject.label) — signo activo"
        case .lot: return "\(subject.label) — capítulo activo"
        case .axis: return "\(subject.label) — eje activado"
        }
    }

    static func composeTopicSummary(subject: CrossSubject, signals: [CrossSignal]) -> String {
        let sources = signals.map(\.source)
        let uniqueSources = Array(NSOrderedSet(array: sources)) as? [String] ?? []
        let count = signals.count
        return "\(count) señales · \(uniqueSources.joined(separator: ", "))"
    }
}

// MARK: - Helpers

private extension CrossPersonalEngine {
    static func signIndex(longitude: Double) -> Int {
        let normalized = (longitude.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return max(0, min(11, Int(normalized / 30)))
    }

    static func planetLabel(for key: String) -> String {
        if let known = AstroPlanetKey(rawValue: key) { return known.label }
        return key
    }

    static func mapKeyToSubject(_ key: String, label: String) -> CrossSubject {
        switch key {
        case "ASC", "MC", "DSC", "IC":
            return CrossSubject.axis(key)
        case "PARTFORTUNA", "PARTE_FORTUNA", "LOTE_FORTUNE":
            return CrossSubject.lot(.fortune)
        case "PARTE_ESPIRITU", "LOTE_SPIRIT":
            return CrossSubject.lot(.spirit)
        default:
            if key.hasPrefix("LOTE_") {
                let rawKind = String(key.dropFirst("LOTE_".count)).lowercased()
                if let kind = NatalLotKind(rawValue: rawKind) {
                    return CrossSubject.lot(kind)
                }
            }
            return CrossSubject.planet(key, label: label)
        }
    }

    static func weightForPD(_ weight: PDWeight) -> Double {
        switch weight {
        case .critical: return 1.0
        case .major: return 0.8
        case .moderate: return 0.6
        case .minor: return 0.4
        }
    }
}
