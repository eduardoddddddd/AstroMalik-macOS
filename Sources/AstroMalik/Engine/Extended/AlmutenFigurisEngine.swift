import Foundation
import CSwissEph

final class AlmutenFigurisEngine {
    private let lotsEngine = LotsEngine()
    private let chaldeanHourOrder = ["SATURNO", "JUPITER", "MARTE", "SOL", "VENUS", "MERCURIO", "LUNA"]

    func almutenFiguris(chart: Chart) throws -> AlmutenFigurisResult {
        let jd = try ExtendedAstro.birthJulianDay(for: chart)
        let sect = SectEngine.sect(of: chart)
        let isDiurnal = sect.isDiurnal
        let fortune = try lotsEngine.lot(.fortune, chart: chart)
        let syzygy = try prenatalSyzygy(before: jd)

        let sun = try ExtendedAstro.body("SOL", in: chart)
        let moon = try ExtendedAstro.body("LUNA", in: chart)
        let points: [(key: String, name: String, longitude: Double)] = [
            ("SOL", "Sol", sun.longitude),
            ("LUNA", "Luna", moon.longitude),
            ("ASC", "Ascendente", chart.ascendant.longitude),
            ("LOTE_FORTUNA", "Lote de Fortuna", fortune.longitude),
            ("SICIGIA_PRENATAL", "Sicigia prenatal", syzygy.longitude),
        ]

        var totals = Dictionary(uniqueKeysWithValues: ExtendedAstro.traditionalPlanetKeys.map { ($0, 0) })
        var pointScores: [AlmutenPointScore] = []
        for point in points {
            let awards = ExtendedAstro.dignityAwards(at: point.longitude, isDiurnal: isDiurnal)
            for award in awards {
                totals[award.planetKey, default: 0] += award.points
            }
            pointScores.append(AlmutenPointScore(
                key: point.key,
                name: point.name,
                longitude: ExtendedAstro.rounded(point.longitude, places: 6),
                formatted: AstroEngine.degToSign(point.longitude),
                dignityAwards: awards
            ))
        }

        let bonuses = bonusAwards(chart: chart, jd: jd)
        for bonus in bonuses {
            totals[bonus.planetKey, default: 0] += bonus.points
        }

        let scores = ExtendedAstro.traditionalPlanetKeys.map { key in
            let bonusPoints = bonuses.filter { $0.planetKey == key }.reduce(0) { $0 + $1.points }
            let total = totals[key, default: 0]
            return AlmutenPlanetScore(
                planetKey: key,
                planetLabel: ExtendedAstro.planetLabel(for: key),
                essentialPoints: total - bonusPoints,
                bonusPoints: bonusPoints,
                total: total
            )
        }.sorted { lhs, rhs in
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            let leftIndex = ExtendedAstro.traditionalPlanetKeys.firstIndex(of: lhs.planetKey) ?? 99
            let rightIndex = ExtendedAstro.traditionalPlanetKeys.firstIndex(of: rhs.planetKey) ?? 99
            return leftIndex < rightIndex
        }

        let winner = scores.first ?? AlmutenPlanetScore(
            planetKey: "SOL",
            planetLabel: ExtendedAstro.planetLabel(for: "SOL"),
            essentialPoints: 0,
            bonusPoints: 0,
            total: 0
        )

        return AlmutenFigurisResult(
            winnerKey: winner.planetKey,
            winnerLabel: winner.planetLabel,
            totalScores: scores,
            pointScores: pointScores,
            bonuses: bonuses,
            prenatalSyzygy: syzygy,
            notes: [
                "Ibn Ezra: cinco puntos ponderados por dignidad esencial: Sol, Luna, ASC, Fortuna y sicigia prenatal.",
                "Triplicidad: regente diurno/nocturno según secta + participante, siguiendo la elección ya usada por EssentialDignityEngine.",
                "Bonos Lilly +12: regente del día, regente de hora planetaria y fase/orientalidad preferida (superiores orientales; Mercurio/Venus occidentales; Luna creciente)."
            ]
        )
    }

    func prenatalSyzygy(before jd: Double) throws -> PrenatalSyzygy {
        let newMoon = try previousPhase(targetAngle: 0, before: jd)
        let fullMoon = try previousPhase(targetAngle: 180, before: jd)
        let chosen = newMoon.jd > fullMoon.jd ? newMoon : fullMoon
        let kind: PrenatalSyzygy.Kind = chosen.target == 0 ? .newMoon : .fullMoon
        return PrenatalSyzygy(
            kind: kind,
            julianDay: ExtendedAstro.rounded(chosen.jd, places: 6),
            longitude: ExtendedAstro.rounded(chosen.longitude, places: 6),
            formatted: AstroEngine.degToSign(chosen.longitude)
        )
    }

    private func bonusAwards(chart: Chart, jd: Double) -> [AlmutenBonus] {
        var bonuses: [AlmutenBonus] = []
        if let dayRuler = planetaryDayRuler(chart: chart) {
            bonuses.append(AlmutenBonus(
                planetKey: dayRuler,
                planetLabel: ExtendedAstro.planetLabel(for: dayRuler),
                kind: "regente_dia",
                points: 12,
                detail: "Regente del día de la semana local"
            ))
        }
        if let hourRuler = planetaryHourRuler(chart: chart, jd: jd) {
            bonuses.append(AlmutenBonus(
                planetKey: hourRuler,
                planetLabel: ExtendedAstro.planetLabel(for: hourRuler),
                kind: "regente_hora",
                points: 12,
                detail: "Regente de la hora planetaria (día/noche divididos en 12 horas desiguales)"
            ))
        }
        bonuses += orientalityBonuses(chart: chart)
        return bonuses
    }

    private func planetaryDayRuler(chart: Chart) -> String? {
        guard let date = localBirthDate(chart: chart) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .gmt
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return "SOL"
        case 2: return "LUNA"
        case 3: return "MARTE"
        case 4: return "MERCURIO"
        case 5: return "JUPITER"
        case 6: return "VENUS"
        case 7: return "SATURNO"
        default: return nil
        }
    }

    private func planetaryHourRuler(chart: Chart, jd: Double) -> String? {
        guard let previousRise = previousSunEvent(before: jd, type: Int32(SE_CALC_RISE | SE_BIT_DISC_CENTER | SE_BIT_NO_REFRACTION), chart: chart),
              let previousSet = previousSunEvent(before: jd, type: Int32(SE_CALC_SET | SE_BIT_DISC_CENTER | SE_BIT_NO_REFRACTION), chart: chart),
              let nextRise = nextSunEvent(after: jd, type: Int32(SE_CALC_RISE | SE_BIT_DISC_CENTER | SE_BIT_NO_REFRACTION), chart: chart),
              let nextSet = nextSunEvent(after: jd, type: Int32(SE_CALC_SET | SE_BIT_DISC_CENTER | SE_BIT_NO_REFRACTION), chart: chart) else {
            return nil
        }

        let isDaytime = previousRise > previousSet
        let start = isDaytime ? previousRise : previousSet
        let end = isDaytime ? nextSet : nextRise
        guard end > start else { return nil }
        let hourLength = (end - start) / 12.0
        let hourIndex = min(11, max(0, Int(floor((jd - start) / hourLength))))
        let baseOffset = isDaytime ? 0 : 12
        let dayReferenceJD = isDaytime ? previousRise : previousSet
        let dayRuler = planetaryDayRuler(atJD: dayReferenceJD, timezone: chart.timezone)
        guard let dayRuler, let base = chaldeanHourOrder.firstIndex(of: dayRuler) else { return nil }
        return chaldeanHourOrder[(base + baseOffset + hourIndex) % chaldeanHourOrder.count]
    }

    private func planetaryDayRuler(atJD jd: Double, timezone: String) -> String? {
        let date = EphemerisUtilities.julianDayToDate(jd)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .gmt
        switch calendar.component(.weekday, from: date) {
        case 1: return "SOL"
        case 2: return "LUNA"
        case 3: return "MARTE"
        case 4: return "MERCURIO"
        case 5: return "JUPITER"
        case 6: return "VENUS"
        case 7: return "SATURNO"
        default: return nil
        }
    }

    private func localBirthDate(chart: Chart) -> Date? {
        let parts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let time = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3, time.count >= 2 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .gmt
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: parts[0], month: parts[1], day: parts[2],
            hour: time[0], minute: time[1]
        ))
    }

    private func orientalityBonuses(chart: Chart) -> [AlmutenBonus] {
        guard let sun = try? ExtendedAstro.body("SOL", in: chart) else { return [] }
        var bonuses: [AlmutenBonus] = []
        for key in ["LUNA", "MERCURIO", "VENUS", "MARTE", "JUPITER", "SATURNO"] {
            guard let body = try? ExtendedAstro.body(key, in: chart) else { continue }
            let distanceFromSun = ExtendedAstro.normalized(sun.longitude - body.longitude)
            let oriental = distanceFromSun > 0 && distanceFromSun < 180
            let waxingMoon = key == "LUNA" && ExtendedAstro.normalized(body.longitude - sun.longitude) < 180
            let preferred: Bool
            switch key {
            case "MARTE", "JUPITER", "SATURNO": preferred = oriental
            case "MERCURIO", "VENUS": preferred = !oriental
            case "LUNA": preferred = waxingMoon
            default: preferred = false
            }
            if preferred {
                bonuses.append(AlmutenBonus(
                    planetKey: key,
                    planetLabel: ExtendedAstro.planetLabel(for: key),
                    kind: "orientalidad",
                    points: 12,
                    detail: key == "LUNA" ? "Luna creciente como equivalente de fortaleza de fase" : (oriental ? "Oriental al Sol" : "Occidental al Sol")
                ))
            }
        }
        return bonuses
    }

    private func previousSunEvent(before jd: Double, type: Int32, chart: Chart) -> Double? {
        var cursor = jd - 2.5
        var last: Double?
        while cursor < jd {
            guard let event = nextSunEvent(after: cursor, type: type, chart: chart) else { return last }
            if event >= jd { return last }
            last = event
            cursor = event + 0.001
        }
        return last
    }

    private func nextSunEvent(after jd: Double, type: Int32, chart: Chart) -> Double? {
        var geopos = [chart.longitude, chart.latitude, 0.0]
        var tret = 0.0
        var serr = [CChar](repeating: 0, count: 256)
        var star = [CChar](repeating: 0, count: 1)
        let rc = swe_rise_trans(jd, SE_SUN, &star, 0, type, &geopos, 0, 0, &tret, &serr)
        return rc >= 0 ? tret : nil
    }

    private func previousPhase(targetAngle: Double, before jd: Double) throws -> (jd: Double, longitude: Double, target: Double) {
        var end = jd - 0.0001
        var endValue = try phaseDistance(jd: end, target: targetAngle)
        let step = 0.5
        for _ in 0..<80 {
            let start = end - step
            let startValue = try phaseDistance(jd: start, target: targetAngle)
            if startValue == 0 || startValue.sign != endValue.sign {
                var lo = start
                var hi = end
                var fLo = startValue
                for _ in 0..<48 {
                    let mid = (lo + hi) / 2.0
                    let fMid = try phaseDistance(jd: mid, target: targetAngle)
                    if fLo == 0 || fLo.sign == fMid.sign {
                        lo = mid
                        fLo = fMid
                    } else {
                        hi = mid
                    }
                }
                let exact = (lo + hi) / 2.0
                let longitude = try syzygyLongitude(jd: exact, target: targetAngle)
                return (exact, longitude, targetAngle)
            }
            end = start
            endValue = startValue
        }
        throw NatalExtendedError.swissCalculation("Sicigia", "No se encontró luna nueva/llena prenatal en la ventana de búsqueda.")
    }

    private func phaseDistance(jd: Double, target: Double) throws -> Double {
        let sun = try ExtendedAstro.swissLongitude(jd: jd, planetID: SE_SUN, label: "Sol")
        let moon = try ExtendedAstro.swissLongitude(jd: jd, planetID: SE_MOON, label: "Luna")
        let phase = ExtendedAstro.normalized(moon - sun)
        var distance = ExtendedAstro.normalized(phase - target + 180) - 180
        if distance == -180 { distance = 180 }
        return distance
    }

    private func syzygyLongitude(jd: Double, target: Double) throws -> Double {
        let sun = try ExtendedAstro.swissLongitude(jd: jd, planetID: SE_SUN, label: "Sol")
        let moon = try ExtendedAstro.swissLongitude(jd: jd, planetID: SE_MOON, label: "Luna")
        // Para luna nueva ambos coinciden; para luna llena usamos el grado lunar
        // como punto operativo de la oposición prenatal.
        return target == 0 ? sun : moon
    }
}
