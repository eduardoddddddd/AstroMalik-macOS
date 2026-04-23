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
    var fromDate: String
    var toDate: String
    var exactDate: String
    var minOrb: Double
    var retrogradeOnExact: Bool
    var lastDate: Date
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

    let cal = Calendar(identifier: .gregorian)
    let totalDays = cal.dateComponents([.day], from: fromDate, to: toDate).day! + 1
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

    let isoFmt = ISO8601DateFormatter()
    isoFmt.formatOptions = [.withFullDate]
    isoFmt.timeZone = TimeZone(identifier: "UTC")

    for dayIdx in 0..<totalDays {
        let currentDate = cal.date(byAdding: .day, value: dayIdx, to: fromDate)!
        let noonISO = isoFmt.string(from: currentDate)

        guard let jdResult = try? julianDayFromLocal(
            birthDate: noonISO,
            birthTime: "12:00",
            timezoneName: "UTC"
        ) else { continue }

        let transitPlanets = try AstroEngine.calcPlanets(jd: jdResult.jd)
        let aspects = AstroEngine.findAspects(from: natalPlanets, to: transitPlanets)

        for asp in aspects {
            if excludeMoon && asp.trKey == "LUNA" { continue }
            if asp.trKey == asp.nKey { continue }

            let baseKey = "\(asp.trKey):\(asp.aspKey):\(asp.nKey)"
            let currentISO = noonISO

            if let prevKey = lastEventKeyByBase[baseKey],
               let existing = events[prevKey],
               cal.dateComponents([.day], from: existing.lastDate, to: currentDate).day! <= EVENT_GAP_DAYS {
                var ev = existing
                ev.toDate = currentISO
                ev.lastDate = currentDate
                if asp.orb < ev.minOrb {
                    ev.minOrb = asp.orb
                    ev.exactDate = currentISO
                    ev.retrogradeOnExact = transitPlanets[asp.trKey]?.retro ?? false
                }
                events[prevKey] = ev
            } else {
                let suffix = events.keys.filter { $0.hasPrefix(baseKey) }.count + 1
                let newKey = suffix == 1 ? baseKey : "\(baseKey):\(suffix)"
                events[newKey] = EventAccum(
                    transitKey: asp.trKey,
                    transitLabel: PLANET_NAMES[asp.trKey] ?? asp.trKey.capitalized,
                    natalKey: asp.nKey,
                    natalLabel: PLANET_NAMES[asp.nKey] ?? asp.nKey.capitalized,
                    aspectKey: asp.aspKey,
                    aspectLabel: ASPECT_NAMES[asp.aspKey] ?? asp.aspKey.capitalized,
                    color: ASPECT_COLORS[asp.aspKey] ?? "#6b6560",
                    fromDate: currentISO,
                    toDate: currentISO,
                    exactDate: currentISO,
                    minOrb: asp.orb,
                    retrogradeOnExact: transitPlanets[asp.trKey]?.retro ?? false,
                    lastDate: currentDate
                )
                lastEventKeyByBase[baseKey] = newKey
            }
        }
    }

    var results: [TransitEvent] = []
    for accum in events.values {
        let fromD = isoFmt.date(from: accum.fromDate) ?? fromDate
        let toD   = isoFmt.date(from: accum.toDate)   ?? fromDate
        let activeDays = cal.dateComponents([.day], from: fromD, to: toD).day! + 1
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
            fromDate: accum.fromDate,
            toDate: accum.toDate,
            exactDate: accum.exactDate,
            activeDays: activeDays,
            minOrb: accum.minOrb,
            retrogradeOnExact: accum.retrogradeOnExact,
            score: score,
            stars: stars,
            text: text,
            source: source
        ))
    }

    return results.sorted {
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.minOrb != $1.minOrb { return $0.minOrb < $1.minOrb }
        return $0.exactDate < $1.exactDate
    }
}

// MARK: - Aux

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
    var errorDescription: String? {
        switch self {
        case .invalidRange: return "La fecha final debe ser posterior a la inicial"
        case .rangeTooBig:  return "El rango máximo es 10 años"
        }
    }
}
