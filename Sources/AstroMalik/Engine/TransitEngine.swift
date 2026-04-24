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

// MARK: - Accumulator

private struct EventAccum {
    var transitKey: String
    var transitLabel: String
    var natalKey: String
    var natalLabel: String
    var aspectKey: String
    var aspectLabel: String
    var color: String
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

    let natalPlanets = Dictionary(uniqueKeysWithValues: natalChart.bodies.map { body in
        (body.key, AstroEngine.RawPlanet(
            key: body.key,
            label: body.label,
            deg: body.longitude,
            speed: body.retrograde ? -1 : 1,
            retro: body.retrograde
        ))
    })

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
            text: text,
            source: source,
            samples: accum.samples.sorted { $0.date < $1.date }
        ))
    }

    return results.sorted {
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.minOrb != $1.minOrb { return $0.minOrb < $1.minOrb }
        return $0.exactDate < $1.exactDate
    }
}

// MARK: - Aux

private func daysBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
    calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

private let PLANET_NAMES: [String: String] = [
    "SOL": "Sol", "LUNA": "Luna", "MERCURIO": "Mercurio",
    "VENUS": "Venus", "MARTE": "Marte", "JUPITER": "Jupiter",
    "SATURNO": "Saturno", "URANO": "Urano", "NEPTUNO": "Neptuno", "PLUTON": "Pluton",
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
