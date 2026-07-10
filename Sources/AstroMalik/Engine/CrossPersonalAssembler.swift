import Foundation

/// Orquestador robusto para el estado cross-personal.
///
/// Mantiene `CrossPersonalEngine` puro: aquí se invocan engines, efemérides y
/// servicios, siempre con fallbacks defensivos para que una técnica que falle no
/// rompa el estado agregado.
enum CrossPersonalAssembler {
    static func assemble(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore
    ) async throws -> CrossPersonalInputs {
        let natalExtended = (try? NatalExtendedAnalysis.compute(chart: chart, configuration: .default))
            ?? fallbackNatalExtended(chart: chart)

        let profections = (try? await ProfectionEngine(corpusStore: corpusStore).profections(for: chart, at: referenceDate))
            ?? fallbackProfections(chart: chart, referenceDate: referenceDate)

        let solarReturn = safeSolarReturn(chart: chart, referenceDate: referenceDate, corpusStore: corpusStore)
        let primaryDirections = safePrimaryDirections(chart: chart, referenceDate: referenceDate)
        let solarArc = safeSolarArc(chart: chart, referenceDate: referenceDate)

        let progressionEngine = SecondaryProgressionEngine()
        let progressionSnapshot = safeProgressionSnapshot(engine: progressionEngine, chart: chart, referenceDate: referenceDate)
        let progressedAspects = safeProgressedAspects(engine: progressionEngine, chart: chart, referenceDate: referenceDate)

        let firdariaEngine = FirdariaEngine()
        let firdariaCurrent = firdariaEngine.currentFirdaria(chart: chart, at: referenceDate)
        let firdariaUpcoming = firdariaEngine.upcomingMinorChanges(chart: chart, at: referenceDate, limit: 5)

        let zrEngine = ZodiacalReleasingEngine()
        let zrSpirit = zrEngine.zr(chart: chart, lot: .spirit, depth: 2)
        let zrFortune = zrEngine.zr(chart: chart, lot: .fortune, depth: 2)

        let transits = await safeTransits(chart: chart, referenceDate: referenceDate, corpusStore: corpusStore)
        let upcomingLunations = await safeLunarHits(
            chart: chart,
            referenceDate: referenceDate,
            natalExtended: natalExtended,
            profections: profections,
            mode: .lunations
        )
        let upcomingEclipses = await safeLunarHits(
            chart: chart,
            referenceDate: referenceDate,
            natalExtended: natalExtended,
            profections: profections,
            mode: .eclipses
        )

        return CrossPersonalInputs(
            chart: chart,
            referenceDate: referenceDate,
            natalExtended: natalExtended,
            profections: profections,
            solarReturn: solarReturn,
            primaryDirections: primaryDirections,
            solarArc: solarArc,
            progressionSnapshot: progressionSnapshot,
            progressedAspects: progressedAspects,
            firdariaMajor: firdariaCurrent.major,
            firdariaMinor: firdariaCurrent.minor,
            firdariaUpcoming: firdariaUpcoming,
            zrSpirit: zrSpirit,
            zrFortune: zrFortune,
            transits: transits,
            upcomingLunations: upcomingLunations,
            upcomingEclipses: upcomingEclipses
        )
    }

    static func state(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore,
        options: CrossPersonalOptions = .default
    ) async throws -> CrossPersonalState {
        let inputs = try await assemble(chart: chart, referenceDate: referenceDate, corpusStore: corpusStore)
        return CrossPersonalEngine.state(inputs: inputs, options: options)
    }
}

// MARK: - Engine calls

private extension CrossPersonalAssembler {
    static func safeSolarReturn(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore
    ) -> SolarReturnReading? {
        guard let year = birthdayYearInForce(chart: chart, referenceDate: referenceDate) else { return nil }
        let request = SolarReturnRequest(
            natalChart: chart,
            year: year,
            placeName: chart.placeName,
            latitude: chart.latitude,
            longitude: chart.longitude,
            timezone: chart.timezone
        )
        return try? SolarReturnEngine.calculate(request: request, corpusStore: corpusStore)
    }

    static func safePrimaryDirections(chart: NatalChart, referenceDate: Date) -> [PrimaryDirection] {
        guard let birth = birthDate(for: chart),
              let jd = try? julianDayFromLocal(
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                timezoneName: chart.timezone
              ).jd
        else { return [] }

        let age = max(1, ageYears(chart: chart, at: referenceDate) ?? 1)
        let config = PrimaryDirectionCalculator.Config(
            method: .regiomontanus,
            key: .naibod,
            natalSolarSpeed: nil,
            maxYears: min(120, max(age + 2, 2)),
            aspects: PDaspect.allCases,
            promissors: [],
            significators: [],
            includeConverse: true,
            aspectPlane: .zodiacal
        )
        let result = PrimaryDirectionsService().compute(chart: chart, jd: jd, birthDate: birth, config: config)
        let lower = addMonths(-12, to: referenceDate) ?? referenceDate.addingTimeInterval(-365 * 86_400)
        let upper = addMonths(12, to: referenceDate) ?? referenceDate.addingTimeInterval(365 * 86_400)
        return result.enrichedDirections
            .map(\.direction)
            .filter { lower...upper ~= $0.estimatedDate }
    }

    static func safeSolarArc(chart: NatalChart, referenceDate: Date) -> [SolarArcDirection] {
        let age = ageYears(chart: chart, at: referenceDate) ?? 0
        return SolarArcEngine().solarArc(
            chart: chart,
            from: max(0, age - 1),
            to: max(0, age + 1),
            mode: .real,
            orb: 1.0
        )
    }

    static func safeProgressionSnapshot(
        engine: SecondaryProgressionEngine,
        chart: NatalChart,
        referenceDate: Date
    ) -> ProgressionSnapshot {
        guard hasValidBirthData(chart) else { return fallbackProgressionSnapshot(chart: chart, referenceDate: referenceDate) }
        return engine.progressions(chart: chart, at: referenceDate, ascendantMode: .naibod)
    }

    static func safeProgressedAspects(
        engine: SecondaryProgressionEngine,
        chart: NatalChart,
        referenceDate: Date
    ) -> [ProgressedAspect] {
        let lower = addMonths(-6, to: referenceDate) ?? referenceDate.addingTimeInterval(-183 * 86_400)
        let upper = addMonths(6, to: referenceDate) ?? referenceDate.addingTimeInterval(183 * 86_400)
        return engine.progressedAspects(chart: chart, from: lower, to: upper)
    }

    static func safeTransits(
        chart: NatalChart,
        referenceDate: Date,
        corpusStore: CorpusStore
    ) async -> [TransitEvent] {
        let lower = addMonths(-6, to: referenceDate) ?? referenceDate.addingTimeInterval(-183 * 86_400)
        let upper = addMonths(6, to: referenceDate) ?? referenceDate.addingTimeInterval(183 * 86_400)
        return (try? await computeTransitPeriod(
            natalChart: chart,
            fromDate: lower,
            toDate: upper,
            timezone: chart.timezone,
            excludeMoon: true,
            corpusStore: corpusStore
        )) ?? []
    }
}

// MARK: - Lunations / eclipses

private extension CrossPersonalAssembler {
    enum LunarHitMode { case lunations, eclipses }

    static func safeLunarHits(
        chart: NatalChart,
        referenceDate: Date,
        natalExtended: NatalExtendedAnalysisResult,
        profections: ProfectionResult,
        mode: LunarHitMode
    ) async -> [LunarPointHit] {
        let endMonths = mode == .lunations ? 3 : 12
        guard let endDate = addMonths(endMonths, to: referenceDate) else { return [] }
        let startJD = julianDay(from: referenceDate)
        let endJD = julianDay(from: endDate)
        let targets = sensitivePoints(chart: chart, natalExtended: natalExtended, profections: profections)
        guard !targets.isEmpty else { return [] }

        let events: [CelestialEvent]
        switch mode {
        case .lunations:
            let phaseEvents = (try? await LunationCalculator.findLunations(from: startJD, to: endJD, timezone: chart.timezone)) ?? []
            let quarters = (try? await LunationCalculator.findQuarters(from: startJD, to: endJD, timezone: chart.timezone)) ?? []
            events = Array((phaseEvents + quarters).sorted { $0.dateUTC < $1.dateUTC }.prefix(4))
        case .eclipses:
            events = (try? await EclipseCalculator.findEclipses(from: startJD, to: endJD, timezone: chart.timezone)) ?? []
        }

        let orb = mode == .lunations ? 3.0 : 5.0
        var hits: [LunarPointHit] = []
        for event in events {
            guard let longitude = event.longitude,
                  let kind = LunarPointHit.Kind(eventKind: event.kind),
                  let date = isoDate(event.dateUTC)
            else { continue }

            for target in targets {
                let distance = abs(EphemerisUtilities.signedAngularDistance(longitude, target: target.longitude))
                guard distance <= orb else { continue }
                hits.append(LunarPointHit(
                    kind: kind,
                    date: date,
                    longitude: longitude,
                    signLabel: event.signLabel ?? EphemerisUtilities.signLabel(for: longitude),
                    targetKey: target.key,
                    targetLabel: target.label,
                    orb: EphemerisUtilities.rounded(distance, places: 3)
                ))
            }
        }
        return hits.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.orb != $1.orb { return $0.orb < $1.orb }
            return $0.targetKey < $1.targetKey
        }
    }

    struct SensitivePoint: Hashable {
        let key: String
        let label: String
        let longitude: Double
    }

    static func sensitivePoints(
        chart: NatalChart,
        natalExtended: NatalExtendedAnalysisResult,
        profections: ProfectionResult
    ) -> [SensitivePoint] {
        var points: [SensitivePoint] = []

        func add(_ key: String, _ label: String, _ longitude: Double?) {
            guard let longitude else { return }
            let normalized = EphemerisUtilities.normalizedDegree(longitude)
            if points.contains(where: { $0.key == key }) { return }
            points.append(SensitivePoint(key: key, label: label, longitude: normalized))
        }

        add("SOL", "☉ Sol", chart.bodies.first { $0.key == "SOL" }?.longitude)
        add("LUNA", "☽ Luna", chart.bodies.first { $0.key == "LUNA" }?.longitude)
        add("ASC", "Ascendente", chart.ascendant.longitude)
        add("MC", "Medio Cielo", chart.mc.longitude)

        let ascRuler = EssentialDignityEngine.domicileRuler(of: EphemerisUtilities.signIndex(for: chart.ascendant.longitude))
        add(ascRuler, "Regente ASC: \(planetLabel(for: ascRuler))", chart.bodies.first { $0.key == ascRuler }?.longitude)

        let lotyKey = profections.annual.lordKey
        add(lotyKey, "Lord of the Year: \(profections.annual.lordLabel)", chart.bodies.first { $0.key == lotyKey }?.longitude)

        let almutenKey = natalExtended.almutenFiguris.winnerKey
        add(almutenKey, "Almuten Figuris: \(natalExtended.almutenFiguris.winnerLabel)", chart.bodies.first { $0.key == almutenKey }?.longitude)

        let genitureKey = natalExtended.rulerOfGeniture.rulerKey
        add(genitureKey, "Regente de la Genitura: \(natalExtended.rulerOfGeniture.rulerLabel)", chart.bodies.first { $0.key == genitureKey }?.longitude)

        return points
    }
}

private extension LunarPointHit.Kind {
    init?(eventKind: CelestialEventKind) {
        switch eventKind {
        case .newMoon: self = .newMoon
        case .fullMoon: self = .fullMoon
        case .firstQuarter: self = .firstQuarter
        case .lastQuarter: self = .lastQuarter
        case .solarEclipse: self = .solarEclipse
        case .lunarEclipse: self = .lunarEclipse
        default: return nil
        }
    }
}

// MARK: - Fallbacks

private extension CrossPersonalAssembler {
    static func fallbackNatalExtended(chart: NatalChart) -> NatalExtendedAnalysisResult {
        let sect = SectEngine.sect(of: chart)
        let ascSign = EphemerisUtilities.signIndex(for: chart.ascendant.longitude)
        let ascRuler = EssentialDignityEngine.domicileRuler(of: ascSign)
        let luminary = chart.bodies.first { $0.key == sect.luminary.key }
        let syzygy = PrenatalSyzygy(
            kind: .newMoon,
            julianDay: (try? julianDayFromLocal(birthDate: chart.birthDate, birthTime: chart.birthTime, timezoneName: chart.timezone).jd) ?? 0,
            longitude: chart.bodies.first { $0.key == "LUNA" }?.longitude ?? chart.ascendant.longitude,
            formatted: chart.bodies.first { $0.key == "LUNA" }?.formatted ?? chart.ascendant.formatted
        )
        let lots = NatalLotKind.allCases.compactMap { kind -> NatalLot? in
            let lot = try? HellenisticLots.lot(kind == .fortune ? .fortune : .spirit, chart: chart)
            guard kind == .fortune || kind == .spirit, let lot else { return nil }
            return NatalLot(
                key: "LOTE_\(kind.rawValue.uppercased())",
                kind: kind,
                name: "Lote de \(kind.title)",
                formulaComment: "Fallback desde HellenisticLots",
                longitude: lot.longitude,
                formatted: lot.formatted,
                signIndex: lot.signIndex,
                signKey: lot.signKey,
                signLabel: lot.signLabel,
                house: AstroEngine.planetHouse(deg: lot.longitude, cusps: chart.cusps),
                rulerKey: EssentialDignityEngine.domicileRuler(of: lot.signIndex),
                rulerLabel: planetLabel(for: EssentialDignityEngine.domicileRuler(of: lot.signIndex)),
                dispositorKey: EssentialDignityEngine.domicileRuler(of: lot.signIndex),
                dispositorLabel: planetLabel(for: EssentialDignityEngine.domicileRuler(of: lot.signIndex))
            )
        }

        return NatalExtendedAnalysisResult(
            generatedAt: Date(),
            configuration: .default,
            lots: lots,
            almutenFiguris: AlmutenFigurisResult(
                winnerKey: ascRuler,
                winnerLabel: planetLabel(for: ascRuler),
                totalScores: [],
                pointScores: [],
                bonuses: [],
                prenatalSyzygy: syzygy,
                notes: ["Fallback defensivo: se usa el regente del Ascendente como almuten aproximado."]
            ),
            rulerOfGeniture: RulerOfGeniture(
                sectLabel: sect.label,
                luminaryKey: sect.luminary.key,
                luminaryLabel: sect.luminary.label,
                luminaryLongitude: luminary?.longitude ?? 0,
                luminaryFormatted: luminary?.formatted ?? "—",
                rulerKey: ascRuler,
                rulerLabel: planetLabel(for: ascRuler),
                dignityAwards: [],
                dignitySummary: "Fallback defensivo"
            ),
            aspectPatterns: [],
            distribution: NatalDistribution(elements: [], modalities: [], hemispheres: [], quadrants: [], singletons: []),
            receptions: [],
            antiscia: AntisciaResult(points: [], contacts: []),
            declinations: DeclinationResult(bodies: [], pairs: [], outOfBounds: []),
            fixedStars: FixedStarResult(epochJulianDay: 0, precessionAppliedDegrees: 0, stars: [], contacts: [])
        )
    }

    static func fallbackProfections(chart: NatalChart, referenceDate: Date) -> ProfectionResult {
        let age = max(0, Int(floor(ageYears(chart: chart, at: referenceDate) ?? 0)))
        let ascSign = EphemerisUtilities.signIndex(for: chart.ascendant.longitude)
        let signIndex = (ascSign + age) % 12
        let lord = EssentialDignityEngine.domicileRuler(of: signIndex)
        let start = birthdayDate(chart: chart, age: age) ?? referenceDate
        let end = birthdayDate(chart: chart, age: age + 1) ?? referenceDate.addingTimeInterval(365 * 86_400)
        let annual = ProfectionPeriod(
            id: "annual-fallback-\(age)",
            kind: .annual,
            sequence: age,
            age: age,
            house: (age % 12) + 1,
            signKey: SIGN_KEYS[signIndex],
            signLabel: SIGN_LABELS[signIndex],
            cuspLongitude: Double(signIndex) * 30,
            cuspFormatted: AstroEngine.degToSign(Double(signIndex) * 30),
            lordKey: lord,
            lordLabel: planetLabel(for: lord),
            startDate: start,
            endDate: end,
            natalPlanetsInHouse: [],
            natalAspectsByLord: []
        )
        return ProfectionResult(annual: annual, monthly: [], daily: [], activations: [])
    }

    static func fallbackProgressionSnapshot(chart: NatalChart, referenceDate: Date) -> ProgressionSnapshot {
        let bodies = chart.bodies.map {
            ProgressedBody(
                key: $0.key,
                label: $0.label,
                longitude: $0.longitude,
                formatted: $0.formatted,
                declination: 0,
                house: $0.house,
                retrograde: $0.retrograde,
                speed: 0
            )
        }
        return ProgressionSnapshot(
            chartID: chart.id,
            chartName: chart.name,
            calculatedAt: Date(),
            targetDate: referenceDate,
            natalJulianDay: 0,
            progressedJulianDay: 0,
            ageYears: ageYears(chart: chart, at: referenceDate) ?? 0,
            ascendantMode: .naibod,
            bodies: bodies,
            ascendant: ProgressedAngle(key: "ASC", label: "Ascendente", longitude: chart.ascendant.longitude, formatted: chart.ascendant.formatted, house: 1),
            mc: ProgressedAngle(key: "MC", label: "Medio Cielo", longitude: chart.mc.longitude, formatted: chart.mc.formatted, house: 10),
            cusps: chart.cusps,
            lunarPhase: ProgressedLunarPhase(id: "fallback-phase", name: .new, angle: 0, startsAt: nil, dateLabel: nil, nextBoundary: 45),
            nextLunarSignIngresses: [],
            nextLunarHouseIngresses: [],
            nextLunarPhaseTransitions: [],
            highlightedChanges: []
        )
    }
}

// MARK: - Dates and labels

private extension CrossPersonalAssembler {
    static func birthdayYearInForce(chart: NatalChart, referenceDate: Date) -> Int? {
        let calendar = calendar(for: chart)
        let birth = birthComponents(chart: chart)
        guard let birthYear = birth.year,
              let referenceYear = calendar.dateComponents([.year], from: referenceDate).year
        else { return nil }
        var birthday = birth
        birthday.year = referenceYear
        guard let birthdayThisYear = calendar.date(from: birthday) else { return referenceYear }
        let year = referenceDate < birthdayThisYear ? referenceYear - 1 : referenceYear
        guard year >= birthYear else { return birthYear }
        return year
    }

    static func birthdayDate(chart: NatalChart, age: Int) -> Date? {
        let calendar = calendar(for: chart)
        var comps = birthComponents(chart: chart)
        guard let birthYear = comps.year else { return nil }
        comps.year = birthYear + age
        return calendar.date(from: comps)
    }

    static func birthDate(for chart: NatalChart) -> Date? {
        calendar(for: chart).date(from: birthComponents(chart: chart))
    }

    static func birthComponents(chart: NatalChart) -> DateComponents {
        let calendar = calendar(for: chart)
        guard let birthDate = try? localDateFromBirthData(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ) else { return DateComponents(timeZone: calendar.timeZone) }
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: birthDate
        )
    }

    static func hasValidBirthData(_ chart: NatalChart) -> Bool {
        birthDate(for: chart) != nil && (try? julianDayFromLocal(birthDate: chart.birthDate, birthTime: chart.birthTime, timezoneName: chart.timezone)) != nil
    }

    static func ageYears(chart: NatalChart, at date: Date) -> Double? {
        guard let birth = birthDate(for: chart) else { return nil }
        return date.timeIntervalSince(birth) / 86_400 / 365.2422
    }

    static func calendar(for chart: NatalChart) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func addMonths(_ months: Int, to date: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(byAdding: .month, value: months, to: date)
    }

    static func julianDay(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    static func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    static func planetLabel(for key: String) -> String {
        AstroPlanetKey(rawValue: key)?.label ?? ProgressionLabels.planetGlyphLabel(for: key)
    }
}

// `CrossPersonalEngine` wants a compact symbol when summarizing primary directions.
extension PDaspect {
    var symbol: String? {
        switch self {
        case .conjunction: return "☌"
        case .sextile: return "⚹"
        case .square: return "□"
        case .trine: return "△"
        case .opposition: return "☍"
        }
    }
}
