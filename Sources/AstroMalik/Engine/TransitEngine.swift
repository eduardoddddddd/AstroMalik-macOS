import Foundation
import CSwissEph

// MARK: - Transit Engine
// Porta transits.py: calcula tránsitos por periodo con scoring de intensidad.

private let EVENT_GAP_DAYS = 5

private let PLANET_WEIGHTS: [String: Double] = [
    "PLUTON": 10, "NEPTUNO": 9, "URANO": 8,
    "SATURNO": 7, "JUPITER": 6,
    "MARTE": 4, "VENUS": 2, "MERCURIO": 2, "SOL": 2, "LUNA": 1,
]

private let ASPECT_WEIGHTS: [String: Double] = [
    "CONJUNCION": 5, "OPOSICION": 4.5, "CUADRADO": 4, "TRIGONO": 3, "SEXTIL": 2,
]

private let ASPECT_ORBS: [String: Double] = {
    var d: [String: Double] = [:]
    for asp in ASPECT_DEFS { d[asp.key] = asp.orb }
    return d
}()

private let ASPECT_COLORS: [String: String] = [
    "CONJUNCION": "#d97706", "SEXTIL": "#2563eb",
    "CUADRADO": "#dc2626",   "TRIGONO": "#15803d",
    "OPOSICION": "#a21caf",
]

// MARK: - Score

private func buildScore(transitKey: String, aspectKey: String, minOrb: Double) -> Double {
    let pw = PLANET_WEIGHTS[transitKey] ?? 1.0
    let aw = ASPECT_WEIGHTS[aspectKey]  ?? 1.0
    let maxOrb = ASPECT_ORBS[aspectKey] ?? 6.0
    let orbFactor = maxOrb > 0 ? max(0, 1 - minOrb / maxOrb) : 0.5
    return (pw * aw * (0.5 + 0.5 * orbFactor) * 10).rounded() / 10
}

private func intensityFor(aspectKey: String, orb: Double) -> Double {
    let maxOrb = ASPECT_ORBS[aspectKey] ?? 6.0
    guard maxOrb > 0 else { return 0 }
    return min(1, max(0, 1 - orb / maxOrb))
}

private func starsForScore(_ score: Double) -> Int {
    switch score {
    case 25...: return 5
    case 15...: return 4
    case 8...:  return 3
    case 3...:  return 2
    default:    return 1
    }
}

private func starsForMultiplier(_ value: Double) -> Int {
    switch value {
    case 1.65...: return 5
    case 1.40...: return 4
    case 1.15...: return 3
    case 0.95...: return 2
    default: return 1
    }
}

private func priorityStars(for band: TransitPriorityBand) -> Int {
    switch band {
    case .critical: return 5
    case .high: return 4
    case .medium: return 3
    case .low: return 2
    }
}

private func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
    min(max(value, range.lowerBound), range.upperBound)
}

// MARK: - Accumulator

private struct EventAccum {
    var transitKey: String
    var transitLabel: String
    var natalKey: String
    var natalLabel: String
    var aspectKey: String
    var aspectLabel: String
    var color: String
    var natalHouse: Int?
    var transitHouse: Int?
    var fromDate: Date
    var toDate: Date
    var exactDate: Date
    var minOrb: Double
    var retrogradeOnExact: Bool
    var lastDate: Date
    var samples: [TransitIntensitySample]
}

// MARK: - Main Calculation

/// Calcula todos los tránsitos entre `fromDate` y `toDate` para una carta natal dada.
func computeTransitPeriod(
    natalChart: NatalChart,
    fromDate: Date,
    toDate: Date,
    timezone: String,
    excludeMoon: Bool = true,
    corpusStore: CorpusStore
) async throws -> [TransitEvent] {

    guard toDate >= fromDate else {
        throw TransitError.invalidRange
    }

    guard let utc = TimeZone(identifier: "UTC") else { throw TransitError.utcUnavailable }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utc
    guard let dayDelta = cal.dateComponents([.day], from: fromDate, to: toDate).day else {
        throw TransitError.dateCalculationFailed
    }
    let totalDays = dayDelta + 1
    guard totalDays <= 3660 else { throw TransitError.rangeTooBig }

    var natalPlanets = Dictionary(uniqueKeysWithValues: natalChart.bodies.map { body in
        (body.key, AstroEngine.RawPlanet(
            key: body.key,
            label: body.label,
            deg: body.longitude,
            speed: body.retrograde ? -1 : 1,
            retro: body.retrograde
        ))
    })
    natalPlanets["ASC"] = AstroEngine.RawPlanet(
        key: "ASC",
        label: "Ascendente",
        deg: natalChart.ascendant.longitude,
        speed: 0,
        retro: false
    )
    natalPlanets["MC"] = AstroEngine.RawPlanet(
        key: "MC",
        label: "Medio Cielo",
        deg: natalChart.mc.longitude,
        speed: 0,
        retro: false
    )

    var natalHouses = Dictionary(uniqueKeysWithValues: natalChart.bodies.map { ($0.key, $0.house) })
    natalHouses["ASC"] = 1
    natalHouses["MC"] = 10

    var events: [String: EventAccum] = [:]
    var lastEventKeyByBase: [String: String] = [:]
    var eventSequenceByBase: [String: Int] = [:]
    let isoFmt = ISO8601DateFormatter()
    isoFmt.formatOptions = [.withFullDate]
    isoFmt.timeZone = utc

    for dayIdx in 0..<totalDays {
        try Task.checkCancellation()

        guard let currentDate = cal.date(byAdding: .day, value: dayIdx, to: fromDate) else {
            throw TransitError.dateCalculationFailed
        }
        let comps = cal.dateComponents([.year, .month, .day], from: currentDate)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            throw TransitError.dateCalculationFailed
        }
        let jd = swe_julday(Int32(year), Int32(month), Int32(day), 12.0, SE_GREG_CAL)

        let transitPlanets = try AstroEngine.calcPlanets(jd: jd)
        let aspects = AstroEngine.findAspects(from: natalPlanets, to: transitPlanets)

        for asp in aspects {
            if excludeMoon && asp.trKey == "LUNA" { continue }
            if asp.trKey == asp.nKey { continue }
            let transitHouse = transitPlanets[asp.trKey].map {
                AstroEngine.planetHouse(deg: $0.deg, cusps: natalChart.cusps)
            }

            let baseKey = "\(asp.trKey):\(asp.aspKey):\(asp.nKey)"
            let sample = TransitIntensitySample(
                date: isoFmt.string(from: currentDate),
                orb: (asp.orb * 100).rounded() / 100,
                intensity: (intensityFor(aspectKey: asp.aspKey, orb: asp.orb) * 1000).rounded() / 1000
            )

            if let prevKey = lastEventKeyByBase[baseKey],
               let existing = events[prevKey],
               daysBetween(existing.lastDate, currentDate, calendar: cal) <= EVENT_GAP_DAYS {
                var ev = existing
                ev.toDate = currentDate
                ev.lastDate = currentDate
                ev.samples.append(sample)
                if asp.orb < ev.minOrb {
                    ev.minOrb = asp.orb
                    ev.exactDate = currentDate
                    ev.retrogradeOnExact = transitPlanets[asp.trKey]?.retro ?? false
                }
                events[prevKey] = ev
            } else {
                let suffix = (eventSequenceByBase[baseKey] ?? 0) + 1
                eventSequenceByBase[baseKey] = suffix
                let newKey = suffix == 1 ? baseKey : "\(baseKey):\(suffix)"
                events[newKey] = EventAccum(
                    transitKey: asp.trKey,
                    transitLabel: PLANET_NAMES[asp.trKey] ?? asp.trKey.capitalized,
                    natalKey: asp.nKey,
                    natalLabel: PLANET_NAMES[asp.nKey] ?? asp.nKey.capitalized,
                    aspectKey: asp.aspKey,
                    aspectLabel: ASPECT_NAMES[asp.aspKey] ?? asp.aspKey.capitalized,
                    color: ASPECT_COLORS[asp.aspKey] ?? "#6b6560",
                    natalHouse: natalHouses[asp.nKey],
                    transitHouse: transitHouse,
                    fromDate: currentDate,
                    toDate: currentDate,
                    exactDate: currentDate,
                    minOrb: asp.orb,
                    retrogradeOnExact: transitPlanets[asp.trKey]?.retro ?? false,
                    lastDate: currentDate,
                    samples: [sample]
                )
                lastEventKeyByBase[baseKey] = newKey
            }
        }
    }

    var results: [TransitEvent] = []
    for accum in events.values {
        try Task.checkCancellation()

        let activeDays = daysBetween(accum.fromDate, accum.toDate, calendar: cal) + 1
        let score = buildScore(transitKey: accum.transitKey, aspectKey: accum.aspectKey, minOrb: accum.minOrb)
        let stars = starsForScore(score)
        let personal = buildPersonalRelevance(
            natalChart: natalChart,
            natalKey: accum.natalKey,
            natalHouse: accum.natalHouse,
            transitHouse: accum.transitHouse
        )
        let (text, source) = corpusStore.lookupTransit(
            trKey: accum.transitKey, nKey: accum.natalKey, aspKey: accum.aspectKey
        )
        results.append(TransitEvent(
            transitKey: accum.transitKey,
            transitLabel: accum.transitLabel,
            natalKey: accum.natalKey,
            natalLabel: accum.natalLabel,
            aspectKey: accum.aspectKey,
            aspectLabel: accum.aspectLabel,
            color: accum.color,
            fromDate: isoFmt.string(from: accum.fromDate),
            toDate: isoFmt.string(from: accum.toDate),
            exactDate: isoFmt.string(from: accum.exactDate),
            activeDays: activeDays,
            minOrb: accum.minOrb,
            retrogradeOnExact: accum.retrogradeOnExact,
            score: score,
            stars: stars,
            technicalScore: score,
            technicalStars: stars,
            personalRelevance: personal.multiplier,
            personalRelevanceStars: personal.stars,
            temporalImpact: 1.0,
            temporalImpactStars: starsForMultiplier(1.0),
            priorityScore: score * personal.multiplier,
            priorityStars: priorityStars(for: .low),
            priorityBand: .low,
            metricReasons: personal.reasons,
            text: text,
            source: source,
            samples: accum.samples.sorted { $0.date < $1.date }
        ))
    }

    let passCounts = Dictionary(grouping: results) { "\($0.transitKey):\($0.aspectKey):\($0.natalKey)" }
        .mapValues(\.count)

    results = results.map { event in
        let passCount = passCounts["\(event.transitKey):\(event.aspectKey):\(event.natalKey)"] ?? 1
        let clusterCount = clusterCount(for: event, in: results)
        let temporal = buildTemporalImpact(event: event, passCount: passCount, clusterCount: clusterCount)
        let priorityScore = event.score * event.personalRelevance * temporal.multiplier
        var updated = event
        updated.temporalImpact = temporal.multiplier
        updated.temporalImpactStars = temporal.stars
        updated.priorityScore = priorityScore
        updated.metricReasons = uniqueReasons(event.metricReasons + temporal.reasons)
        return updated
    }

    results = assignPriorityBands(to: results)

    return results.sorted {
        if $0.priorityBand.rank != $1.priorityBand.rank { return $0.priorityBand.rank > $1.priorityBand.rank }
        if $0.priorityScore != $1.priorityScore { return $0.priorityScore > $1.priorityScore }
        if $0.exactDate != $1.exactDate { return $0.exactDate < $1.exactDate }
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.minOrb != $1.minOrb { return $0.minOrb < $1.minOrb }
        return $0.transitKey < $1.transitKey
    }
}

// MARK: - Aux

private func assignPriorityBands(to events: [TransitEvent]) -> [TransitEvent] {
    guard !events.isEmpty else { return [] }
    let sortedIDs = events
        .sorted {
            if $0.priorityScore != $1.priorityScore { return $0.priorityScore > $1.priorityScore }
            if $0.exactDate != $1.exactDate { return $0.exactDate < $1.exactDate }
            return $0.minOrb < $1.minOrb
        }
        .map(\.id)
    let ranks = Dictionary(uniqueKeysWithValues: sortedIDs.enumerated().map { ($0.element, $0.offset) })
    let total = Double(max(1, events.count))

    return events.map { event in
        let rank = ranks[event.id] ?? events.count
        let percentile = Double(rank) / total
        let band: TransitPriorityBand
        if percentile < 0.10 && event.priorityScore >= 35 {
            band = .critical
        } else if percentile < 0.25 && event.priorityScore >= 22 {
            band = .high
        } else if percentile < 0.50 && event.priorityScore >= 12 {
            band = .medium
        } else {
            band = .low
        }

        var updated = event
        updated.priorityBand = band
        updated.priorityStars = priorityStars(for: band)
        return updated
    }
}

private func buildPersonalRelevance(
    natalChart: NatalChart,
    natalKey: String,
    natalHouse: Int?,
    transitHouse: Int?
) -> (multiplier: Double, stars: Int, reasons: [String]) {
    var multiplier = 1.0
    var reasons: [String] = []

    if natalKey == "ASC" || natalKey == "MC" {
        multiplier += 0.45
        reasons.append(natalKey == "ASC" ? "Toca Ascendente" : "Toca Medio Cielo")
    }

    if natalKey == "SOL" || natalKey == "LUNA" {
        multiplier += 0.40
        reasons.append("Toca Sol/Luna")
    }

    if natalKey == ascendantRulerKey(for: natalChart.ascendant.longitude) {
        multiplier += 0.35
        reasons.append("Regente del Ascendente")
    }

    switch natalKey {
    case "VENUS", "MARTE":
        multiplier += 0.25
        reasons.append("Planeta personal fuerte")
    case "MERCURIO":
        multiplier += 0.20
        reasons.append("Planeta personal")
    case "JUPITER", "SATURNO":
        multiplier += 0.15
        reasons.append("Planeta social")
    default:
        break
    }

    if let natalHouse {
        switch natalHouse {
        case 1, 4, 7, 10:
            multiplier += 0.30
            reasons.append("Planeta natal angular")
        case 2, 5, 8, 11:
            multiplier += 0.15
            reasons.append("Planeta natal sucedente")
        case 3, 6, 9, 12:
            multiplier += 0.05
            reasons.append("Planeta natal cadente")
        default:
            break
        }
    }

    if let transitHouse {
        switch transitHouse {
        case 1, 4, 7, 10:
            multiplier += 0.20
            reasons.append("Tránsito por casa angular")
        case 2, 5, 8, 11:
            multiplier += 0.10
            reasons.append("Tránsito por casa sucedente")
        default:
            break
        }
    }

    let clampedMultiplier = clamped(multiplier, 0.75...1.85)
    return (
        multiplier: clampedMultiplier,
        stars: starsForMultiplier(clampedMultiplier),
        reasons: uniqueReasons(reasons)
    )
}

private func buildTemporalImpact(
    event: TransitEvent,
    passCount: Int,
    clusterCount: Int
) -> (multiplier: Double, stars: Int, reasons: [String]) {
    var multiplier = 1.0
    var reasons: [String] = []

    switch event.activeDays {
    case ...7:
        multiplier *= 0.85
        reasons.append("Tránsito breve")
    case ...30:
        multiplier *= 0.95
    case ...120:
        multiplier *= 1.10
        reasons.append("Duración sostenida")
    case ...365:
        multiplier *= 1.22
        reasons.append("Duración larga")
    default:
        multiplier *= 1.30
        reasons.append("Duración muy larga")
    }

    if event.minOrb <= 0.25 {
        multiplier *= 1.18
        reasons.append("Orbe exacto menor de 0.25°")
    } else if event.minOrb <= 0.50 {
        multiplier *= 1.12
        reasons.append("Orbe exacto menor de 0.5°")
    } else if event.minOrb <= 1.00 {
        multiplier *= 1.06
        reasons.append("Orbe exacto menor de 1°")
    }

    switch passCount {
    case 2:
        multiplier *= 1.12
        reasons.append("Dos pasadas por retrogradación")
    case 3:
        multiplier *= 1.25
        reasons.append("Tres pasadas por retrogradación")
    case 4...:
        multiplier *= 1.35
        reasons.append("Más de tres pasadas por retrogradación")
    default:
        break
    }

    if clusterCount >= 3 {
        multiplier *= 1.22
        reasons.append("Cluster de tránsitos al mismo punto")
    } else if clusterCount == 2 {
        multiplier *= 1.10
        reasons.append("Dos tránsitos próximos al mismo punto")
    }

    let clampedMultiplier = clamped(multiplier, 0.75...1.80)
    return (
        multiplier: clampedMultiplier,
        stars: starsForMultiplier(clampedMultiplier),
        reasons: uniqueReasons(reasons)
    )
}

private func ascendantRulerKey(for longitude: Double) -> String {
    switch AstroEngine.degToSignKey(longitude) {
    case "ARIES", "ESCORPIO": return "MARTE"
    case "TAURO", "LIBRA": return "VENUS"
    case "GEMINIS", "VIRGO": return "MERCURIO"
    case "CANCER": return "LUNA"
    case "LEO": return "SOL"
    case "SAGITARIO", "PISCIS": return "JUPITER"
    case "CAPRICORNIO", "ACUARIO": return "SATURNO"
    default: return ""
    }
}

private func clusterCount(for event: TransitEvent, in events: [TransitEvent]) -> Int {
    events.filter { candidate in
        candidate.natalKey == event.natalKey
            && candidate.stars >= 3
            && abs(daysBetweenISO(event.exactDate, candidate.exactDate)) <= 21
    }.count
}

private func daysBetweenISO(_ lhs: String, _ rhs: String) -> Int {
    guard let lhsDate = dateFromISO(lhs), let rhsDate = dateFromISO(rhs) else { return Int.max }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return abs(cal.dateComponents([.day], from: lhsDate, to: rhsDate).day ?? Int.max)
}

private func dateFromISO(_ isoDate: String) -> Date? {
    let parts = isoDate.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return cal.date(from: DateComponents(timeZone: cal.timeZone, year: parts[0], month: parts[1], day: parts[2]))
}

private func uniqueReasons(_ reasons: [String]) -> [String] {
    var seen = Set<String>()
    return reasons.filter { seen.insert($0).inserted }
}

private func daysBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
    calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

private let PLANET_NAMES: [String: String] = [
    "SOL": "Sol", "LUNA": "Luna", "MERCURIO": "Mercurio",
    "VENUS": "Venus", "MARTE": "Marte", "JUPITER": "Jupiter",
    "SATURNO": "Saturno", "URANO": "Urano", "NEPTUNO": "Neptuno", "PLUTON": "Pluton",
    "ASC": "Ascendente", "MC": "Medio Cielo",
]

private let ASPECT_NAMES: [String: String] = [
    "CONJUNCION": "Conjuncion", "SEXTIL": "Sextil",
    "CUADRADO": "Cuadratura", "TRIGONO": "Trigono", "OPOSICION": "Oposicion",
]

enum TransitError: LocalizedError {
    case invalidRange
    case rangeTooBig
    case dateCalculationFailed
    case utcUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidRange: return "La fecha final debe ser posterior a la inicial"
        case .rangeTooBig:  return "El rango máximo es 10 años"
        case .dateCalculationFailed: return "No se pudo construir el calendario diario de tránsitos"
        case .utcUnavailable: return "No se pudo resolver UTC para calcular tránsitos"
        }
    }
}
