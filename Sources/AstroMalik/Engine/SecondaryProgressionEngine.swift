import Foundation
import CSwissEph

enum SecondaryProgressionError: LocalizedError {
    case invalidBirthData
    case dateBeforeBirth
    case calculationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBirthData:
            return "La carta natal no contiene fecha/hora/zona válidas para progresiones secundarias."
        case .dateBeforeBirth:
            return "La fecha de progresión es anterior al nacimiento."
        case .calculationFailed(let message):
            return "No se pudieron calcular progresiones secundarias: \(message)"
        }
    }
}

final class SecondaryProgressionEngine {
    private static let tropicalYearDays = 365.2422
    private static let naibodArcPerYear = 0.9856472222222222 // 0°59'08.33"
    private static let eventScanStepDays = 1.0
    private static let highlightedWindowYears = 5.0

    private let calendarUTC: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendarUTC = calendar
    }

    func progressions(
        chart: Chart,
        at date: Date,
        ascendantMode: ASCMode = .naibod
    ) -> ProgressionSnapshot {
        do {
            return try makeProgressions(chart: chart, at: date, ascendantMode: ascendantMode)
        } catch {
            preconditionFailure(error.localizedDescription)
        }
    }

    func progressedAspects(chart: Chart, from: Date, to: Date) -> [ProgressedAspect] {
        do {
            return try makeProgressedAspects(chart: chart, from: from, to: to, ascendantMode: .naibod)
        } catch {
            return []
        }
    }

    // MARK: - Snapshot

    private func makeProgressions(
        chart: Chart,
        at date: Date,
        ascendantMode: ASCMode
    ) throws -> ProgressionSnapshot {
        let natalJD = try natalJulianDay(chart)
        let age = try ageYears(chart: chart, at: date)
        guard age >= 0 else { throw SecondaryProgressionError.dateBeforeBirth }
        let progressedJD = natalJD + age
        let angles = try progressedAngles(chart: chart, natalJD: natalJD, progressedJD: progressedJD, ageYears: age, mode: ascendantMode)
        let bodies = try progressedBodies(jd: progressedJD, cusps: angles.cusps)
        let phase = try lunarPhase(atProgressedJD: progressedJD, chart: chart, natalJD: natalJD)

        let nextSignIngresses = try nextLunarSignIngresses(
            chart: chart,
            natalJD: natalJD,
            startProgressedJD: progressedJD,
            count: 3
        )
        let nextHouseIngresses = try nextLunarHouseIngresses(
            chart: chart,
            natalJD: natalJD,
            startProgressedJD: progressedJD,
            mode: ascendantMode,
            count: 3
        )
        let nextPhases = try nextLunarPhaseTransitions(
            chart: chart,
            natalJD: natalJD,
            startProgressedJD: progressedJD,
            count: 2
        )
        let highlighted = try highlightedChanges(
            chart: chart,
            natalJD: natalJD,
            centerProgressedJD: progressedJD,
            mode: ascendantMode
        )

        return ProgressionSnapshot(
            chartID: chart.id,
            chartName: chart.name,
            calculatedAt: Date(),
            targetDate: date,
            natalJulianDay: natalJD,
            progressedJulianDay: progressedJD,
            ageYears: age,
            ascendantMode: ascendantMode,
            bodies: bodies,
            ascendant: ProgressedAngle(
                key: "ASC",
                label: "Ascendente",
                longitude: angles.asc,
                formatted: AstroEngine.degToSign(angles.asc),
                house: 1
            ),
            mc: ProgressedAngle(
                key: "MC",
                label: "Medio Cielo",
                longitude: angles.mc,
                formatted: AstroEngine.degToSign(angles.mc),
                house: 10
            ),
            cusps: angles.cusps,
            lunarPhase: phase,
            nextLunarSignIngresses: nextSignIngresses,
            nextLunarHouseIngresses: nextHouseIngresses,
            nextLunarPhaseTransitions: nextPhases,
            highlightedChanges: highlighted
        )
    }

    private func natalJulianDay(_ chart: Chart) throws -> Double {
        try julianDayFromLocal(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ).jd
    }

    private func birthDate(for chart: Chart) throws -> Date {
        do {
            return try localDateFromBirthData(
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                timezoneName: chart.timezone
            )
        } catch {
            throw SecondaryProgressionError.invalidBirthData
        }
    }

    private func ageYears(chart: Chart, at date: Date) throws -> Double {
        let birth = try birthDate(for: chart)
        return date.timeIntervalSince(birth) / 86_400.0 / Self.tropicalYearDays
    }

    private func date(forProgressedJD progressedJD: Double, natalJD: Double, chart: Chart) throws -> Date {
        let birth = try birthDate(for: chart)
        let ageYears = progressedJD - natalJD
        return birth.addingTimeInterval(ageYears * Self.tropicalYearDays * 86_400.0)
    }

    private func progressedJD(forDate date: Date, chart: Chart, natalJD: Double) throws -> Double {
        natalJD + (try ageYears(chart: chart, at: date))
    }

    // MARK: - Positions

    private func progressedBodies(jd: Double, cusps: [Double]) throws -> [ProgressedBody] {
        var result: [ProgressedBody] = []
        for planet in PLANET_LIST {
            let raw = try planetPosition(jd: jd, planetID: planet.id, key: planet.key, label: planet.label)
            result.append(progressedBody(from: raw, cusps: cusps))
        }
        let north = try trueNodePosition(jd: jd)
        result.append(progressedBody(from: north, cusps: cusps))
        return result
    }

    private func progressedBody(from raw: RawProgressedPoint, cusps: [Double]) -> ProgressedBody {
        ProgressedBody(
            key: raw.key,
            label: raw.label,
            longitude: raw.longitude,
            formatted: AstroEngine.degToSign(raw.longitude),
            declination: raw.declination,
            house: AstroEngine.planetHouse(deg: raw.longitude, cusps: cusps),
            retrograde: raw.speed < 0,
            speed: raw.speed
        )
    }

    private func planetPosition(jd: Double, planetID: Int32, key: String, label: String) throws -> RawProgressedPoint {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, planetID, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else {
            throw SecondaryProgressionError.calculationFailed(String(cString: serr))
        }
        var eq = [Double](repeating: 0, count: 6)
        var eqSerr = [CChar](repeating: 0, count: 256)
        let eqRC = swe_calc_ut(jd, planetID, SEFLG_SPEED | SEFLG_EQUATORIAL, &eq, &eqSerr)
        guard eqRC >= 0 else {
            throw SecondaryProgressionError.calculationFailed(String(cString: eqSerr))
        }
        return RawProgressedPoint(
            key: key,
            label: label,
            longitude: normalized(xx[0]),
            declination: eq[1],
            speed: xx[3]
        )
    }

    private func trueNodePosition(jd: Double) throws -> RawProgressedPoint {
        try planetPosition(jd: jd, planetID: SE_TRUE_NODE, key: "NODO_NORTE", label: "☊ Nodo Norte")
    }

    private func eclipticLongitude(jd: Double, planetID: Int32) throws -> Double {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, planetID, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else { throw SecondaryProgressionError.calculationFailed(String(cString: serr)) }
        return normalized(xx[0])
    }

    private func eclipticSpeed(jd: Double, planetID: Int32) throws -> Double {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, planetID, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else { throw SecondaryProgressionError.calculationFailed(String(cString: serr)) }
        return xx[3]
    }

    private func progressedAngles(
        chart: Chart,
        natalJD: Double,
        progressedJD: Double,
        ageYears: Double,
        mode: ASCMode
    ) throws -> (cusps: [Double], asc: Double, mc: Double) {
        switch mode {
        case .naibod:
            let natalRAMC = normalized(swe_sidtime(natalJD) * 15.0 + chart.longitude)
            let progressedRAMC = normalized(natalRAMC + ageYears * Self.naibodArcPerYear)
            let eps = try trueObliquity(jd: progressedJD)
            return try housesForARMC(armc: progressedRAMC, latitude: chart.latitude, obliquity: eps, system: houseSystemCode(chart.houseSystem))
        case .bija:
            guard let natalSun = chart.bodies.first(where: { $0.key == "SOL" }) else {
                throw SecondaryProgressionError.invalidBirthData
            }
            let progressedSun = try eclipticLongitude(jd: progressedJD, planetID: SE_SUN)
            let delta = signedForwardArc(from: natalSun.longitude, to: progressedSun)
            let cusps = chart.cusps.map { normalized($0 + delta) }
            return (cusps, normalized(chart.ascendant.longitude + delta), normalized(chart.mc.longitude + delta))
        }
    }

    private func housesForARMC(armc: Double, latitude: Double, obliquity: Double, system: Character) throws -> (cusps: [Double], asc: Double, mc: Double) {
        var cusps = [Double](repeating: 0, count: 13)
        var ascmc = [Double](repeating: 0, count: 10)
        var cuspSpeeds = [Double](repeating: 0, count: 13)
        var ascmcSpeeds = [Double](repeating: 0, count: 10)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_houses_armc_ex2(
            armc,
            latitude,
            obliquity,
            Int32(system.asciiValue ?? 80),
            &cusps,
            &ascmc,
            &cuspSpeeds,
            &ascmcSpeeds,
            &serr
        )
        guard rc >= 0 else {
            let message = String(cString: serr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw SecondaryProgressionError.calculationFailed(message.isEmpty ? "Swiss Ephemeris no devolvió casas progresadas." : message)
        }
        return (Array(cusps[1...12]).map(normalized), normalized(ascmc[0]), normalized(ascmc[1]))
    }

    private func trueObliquity(jd: Double) throws -> Double {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, SE_ECL_NUT, 0, &xx, &serr)
        guard rc >= 0 else { throw SecondaryProgressionError.calculationFailed(String(cString: serr)) }
        return xx[0]
    }

    // MARK: - Lunar phase and ingresses

    private func lunarPhase(atProgressedJD jd: Double, chart: Chart, natalJD: Double) throws -> ProgressedLunarPhase {
        let angle = try lunarPhaseAngle(jd: jd)
        let phase = phaseName(for: angle)
        let nextBoundary = nextPhaseBoundary(after: angle)
        return ProgressedLunarPhase(
            id: "phase-current-\(rounded(angle, places: 3))",
            name: phase,
            angle: rounded(angle, places: 3),
            startsAt: try? date(forProgressedJD: jd, natalJD: natalJD, chart: chart),
            dateLabel: nil,
            nextBoundary: nextBoundary
        )
    }

    private func lunarPhaseAngle(jd: Double) throws -> Double {
        let moon = try eclipticLongitude(jd: jd, planetID: SE_MOON)
        let sun = try eclipticLongitude(jd: jd, planetID: SE_SUN)
        return EphemerisUtilities.phaseAngle(moonLongitude: moon, sunLongitude: sun)
    }

    private func phaseName(for angle: Double) -> ProgressedLunarPhaseName {
        let index = Int(floor(normalized(angle) / 45.0)) % 8
        return ProgressedLunarPhaseName.allCases[index]
    }

    private func nextPhaseBoundary(after angle: Double) -> Double {
        let nextIndex = floor(normalized(angle) / 45.0) + 1
        return normalized(nextIndex * 45.0)
    }

    private func nextLunarPhaseTransitions(chart: Chart, natalJD: Double, startProgressedJD: Double, count: Int) throws -> [ProgressedLunarPhase] {
        var transitions: [ProgressedLunarPhase] = []
        var target = nextPhaseBoundary(after: try lunarPhaseAngle(jd: startProgressedJD))
        var low = startProgressedJD
        while transitions.count < count {
            var high = low + 0.25
            var attempts = 0
            while attempts < 80 {
                let lowValue = EphemerisUtilities.signedAngularDistance(try lunarPhaseAngle(jd: low), target: target)
                let highValue = EphemerisUtilities.signedAngularDistance(try lunarPhaseAngle(jd: high), target: target)
                if lowValue * highValue <= 0 { break }
                high += 0.25
                attempts += 1
            }
            let exactJD = try bisectAngularCrossing(startJD: low, endJD: high, target: target) { jd in
                try lunarPhaseAngle(jd: jd)
            }
            let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
            let phase = phaseName(for: target)
            transitions.append(ProgressedLunarPhase(
                id: "phase-\(Int(target))-\(isoDay(date, timezone: chart.timezone))",
                name: phase,
                angle: rounded(target, places: 3),
                startsAt: date,
                dateLabel: displayDate(date, timezone: chart.timezone),
                nextBoundary: normalized(target + 45.0)
            ))
            low = exactJD + 0.01
            target = normalized(target + 45.0)
        }
        return transitions
    }

    private func nextLunarSignIngresses(chart: Chart, natalJD: Double, startProgressedJD: Double, count: Int) throws -> [ProgressedIngress] {
        var ingresses: [ProgressedIngress] = []
        var low = startProgressedJD
        while ingresses.count < count {
            let startLongitude = try eclipticLongitude(jd: low, planetID: SE_MOON)
            let fromSign = EphemerisUtilities.signIndex(for: startLongitude)
            let target = normalized(Double(fromSign + 1) * 30.0)
            var high = low + 0.25
            while EphemerisUtilities.signIndex(for: try eclipticLongitude(jd: high, planetID: SE_MOON)) == fromSign {
                high += 0.25
                if high - low > 4.0 { break }
            }
            let exactJD = try bisectAngularCrossing(startJD: low, endJD: high, target: target) { jd in
                try eclipticLongitude(jd: jd, planetID: SE_MOON)
            }
            let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
            let toSign = EphemerisUtilities.signIndex(for: target + 0.001)
            ingresses.append(ProgressedIngress(
                id: "moon-sign-\(toSign)-\(isoDay(date, timezone: chart.timezone))",
                kind: .lunarSign,
                date: date,
                dateLabel: displayDate(date, timezone: chart.timezone),
                bodyKey: "LUNA",
                bodyLabel: "Luna progresada",
                fromValue: SIGN_LABELS[fromSign],
                toValue: SIGN_LABELS[toSign],
                longitude: target,
                description: "La Luna progresada ingresa en \(SIGN_LABELS[toSign]).",
                priority: 4
            ))
            low = exactJD + 0.02
        }
        return ingresses
    }

    private func nextLunarHouseIngresses(chart: Chart, natalJD: Double, startProgressedJD: Double, mode: ASCMode, count: Int) throws -> [ProgressedIngress] {
        var ingresses: [ProgressedIngress] = []
        var low = startProgressedJD
        while ingresses.count < count {
            var fromHouse = try progressedMoonHouse(chart: chart, natalJD: natalJD, progressedJD: low, mode: mode)
            var high = low + 0.05
            var toHouse = try progressedMoonHouse(chart: chart, natalJD: natalJD, progressedJD: high, mode: mode)
            var attempts = 0
            while fromHouse == toHouse && attempts < 260 {
                high += 0.05
                toHouse = try progressedMoonHouse(chart: chart, natalJD: natalJD, progressedJD: high, mode: mode)
                attempts += 1
            }
            guard fromHouse != toHouse else { break }
            var a = low
            var b = high
            for _ in 0..<48 {
                let mid = (a + b) / 2.0
                let midHouse = try progressedMoonHouse(chart: chart, natalJD: natalJD, progressedJD: mid, mode: mode)
                if midHouse == fromHouse { a = mid } else { b = mid }
            }
            let exactJD = (a + b) / 2.0
            let exactAngles = try progressedAngles(chart: chart, natalJD: natalJD, progressedJD: exactJD, ageYears: exactJD - natalJD, mode: mode)
            let moonLongitude = try eclipticLongitude(jd: exactJD, planetID: SE_MOON)
            let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
            fromHouse = AstroEngine.planetHouse(deg: try eclipticLongitude(jd: max(low, exactJD - 0.001), planetID: SE_MOON), cusps: exactAngles.cusps)
            ingresses.append(ProgressedIngress(
                id: "moon-house-\(toHouse)-\(isoDay(date, timezone: chart.timezone))",
                kind: .lunarHouse,
                date: date,
                dateLabel: displayDate(date, timezone: chart.timezone),
                bodyKey: "LUNA",
                bodyLabel: "Luna progresada",
                fromValue: "Casa \(fromHouse)",
                toValue: "Casa \(toHouse)",
                longitude: moonLongitude,
                description: "La Luna progresada ingresa en Casa \(toHouse).",
                priority: 4
            ))
            low = exactJD + 0.02
        }
        return ingresses
    }

    private func progressedMoonHouse(chart: Chart, natalJD: Double, progressedJD: Double, mode: ASCMode) throws -> Int {
        let angles = try progressedAngles(chart: chart, natalJD: natalJD, progressedJD: progressedJD, ageYears: progressedJD - natalJD, mode: mode)
        let moon = try eclipticLongitude(jd: progressedJD, planetID: SE_MOON)
        return AstroEngine.planetHouse(deg: moon, cusps: angles.cusps)
    }

    // MARK: - Highlighted changes

    private func highlightedChanges(chart: Chart, natalJD: Double, centerProgressedJD: Double, mode: ASCMode) throws -> [ProgressedIngress] {
        let startJD = centerProgressedJD - Self.highlightedWindowYears
        let endJD = centerProgressedJD + Self.highlightedWindowYears
        var changes: [ProgressedIngress] = []
        changes += try planetSignChanges(chart: chart, natalJD: natalJD, startJD: startJD, endJD: endJD)
        changes += try stations(chart: chart, natalJD: natalJD, startJD: startJD, endJD: endJD)
        changes += try lunarPhaseChanges(chart: chart, natalJD: natalJD, startJD: startJD, endJD: endJD)
        return changes.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.priority > $1.priority
        }
    }

    private func planetSignChanges(chart: Chart, natalJD: Double, startJD: Double, endJD: Double) throws -> [ProgressedIngress] {
        let entries: [(key: String, label: String, id: Int32)] = [
            ("SOL", "Sol progresado", SE_SUN),
            ("MERCURIO", "Mercurio progresado", SE_MERCURY),
            ("VENUS", "Venus progresada", SE_VENUS),
        ]
        var result: [ProgressedIngress] = []
        for entry in entries {
            var low = startJD
            var lowSign = EphemerisUtilities.signIndex(for: try eclipticLongitude(jd: low, planetID: entry.id))
            while low < endJD {
                let high = min(low + 0.1, endJD)
                let highLongitude = try eclipticLongitude(jd: high, planetID: entry.id)
                let highSign = EphemerisUtilities.signIndex(for: highLongitude)
                if highSign != lowSign {
                    let target: Double
                    if highSign == (lowSign + 1) % 12 {
                        target = normalized(Double(lowSign + 1) * 30.0)
                    } else if highSign == (lowSign + 11) % 12 {
                        target = normalized(Double(lowSign) * 30.0)
                    } else {
                        target = normalized(Double(highSign) * 30.0)
                    }
                    let exactJD = try bisectAngularCrossing(startJD: low, endJD: high, target: target) { jd in
                        try eclipticLongitude(jd: jd, planetID: entry.id)
                    }
                    let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
                    let toSign = EphemerisUtilities.signIndex(for: try eclipticLongitude(jd: exactJD + 0.001, planetID: entry.id))
                    result.append(ProgressedIngress(
                        id: "sign-\(entry.key)-\(toSign)-\(isoDay(date, timezone: chart.timezone))",
                        kind: .planetSign,
                        date: date,
                        dateLabel: displayDate(date, timezone: chart.timezone),
                        bodyKey: entry.key,
                        bodyLabel: entry.label,
                        fromValue: SIGN_LABELS[lowSign],
                        toValue: SIGN_LABELS[toSign],
                        longitude: target,
                        description: "\(entry.label) cambia de \(SIGN_LABELS[lowSign]) a \(SIGN_LABELS[toSign]).",
                        priority: entry.key == "SOL" ? 5 : 4
                    ))
                    low = exactJD + 0.01
                    lowSign = EphemerisUtilities.signIndex(for: try eclipticLongitude(jd: low, planetID: entry.id))
                } else {
                    low = high
                    lowSign = highSign
                }
            }
        }
        return result
    }

    private func stations(chart: Chart, natalJD: Double, startJD: Double, endJD: Double) throws -> [ProgressedIngress] {
        let entries: [(key: String, label: String, id: Int32)] = [
            ("MERCURIO", "Mercurio progresado", SE_MERCURY),
            ("VENUS", "Venus progresada", SE_VENUS),
            ("MARTE", "Marte progresado", SE_MARS),
            ("JUPITER", "Júpiter progresado", SE_JUPITER),
            ("SATURNO", "Saturno progresado", SE_SATURN),
            ("URANO", "Urano progresado", SE_URANUS),
            ("NEPTUNO", "Neptuno progresado", SE_NEPTUNE),
            ("PLUTON", "Plutón progresado", SE_PLUTO),
            ("NODO_NORTE", "Nodo Norte progresado", SE_TRUE_NODE),
        ]
        var result: [ProgressedIngress] = []
        for entry in entries {
            var low = startJD
            var lowSpeed = try eclipticSpeed(jd: low, planetID: entry.id)
            while low < endJD {
                let high = min(low + 0.05, endJD)
                let highSpeed = try eclipticSpeed(jd: high, planetID: entry.id)
                if lowSpeed == 0 || lowSpeed * highSpeed < 0 {
                    let exactJD = try bisectScalarCrossing(startJD: low, endJD: high) { jd in
                        try eclipticSpeed(jd: jd, planetID: entry.id)
                    }
                    let before = try eclipticSpeed(jd: max(startJD, exactJD - 0.01), planetID: entry.id)
                    let after = try eclipticSpeed(jd: min(endJD, exactJD + 0.01), planetID: entry.id)
                    let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
                    let longitude = try eclipticLongitude(jd: exactJD, planetID: entry.id)
                    let toValue = after < 0 ? "Retrógrado" : "Directo"
                    result.append(ProgressedIngress(
                        id: "station-\(entry.key)-\(toValue)-\(isoDay(date, timezone: chart.timezone))",
                        kind: .station,
                        date: date,
                        dateLabel: displayDate(date, timezone: chart.timezone),
                        bodyKey: entry.key,
                        bodyLabel: entry.label,
                        fromValue: before < 0 ? "Retrógrado" : "Directo",
                        toValue: toValue,
                        longitude: longitude,
                        description: "\(entry.label) estaciona y pasa a movimiento \(toValue.lowercased()).",
                        priority: 5
                    ))
                    low = exactJD + 0.02
                    lowSpeed = try eclipticSpeed(jd: low, planetID: entry.id)
                } else {
                    low = high
                    lowSpeed = highSpeed
                }
            }
        }
        return result
    }

    private func lunarPhaseChanges(chart: Chart, natalJD: Double, startJD: Double, endJD: Double) throws -> [ProgressedIngress] {
        var result: [ProgressedIngress] = []
        var low = startJD
        var target = nextPhaseBoundary(after: try lunarPhaseAngle(jd: low))
        while low < endJD {
            var high = min(low + 0.25, endJD)
            var found = false
            while high <= endJD {
                let lowValue = EphemerisUtilities.signedAngularDistance(try lunarPhaseAngle(jd: low), target: target)
                let highValue = EphemerisUtilities.signedAngularDistance(try lunarPhaseAngle(jd: high), target: target)
                if lowValue * highValue <= 0 {
                    found = true
                    break
                }
                low = high
                high = min(high + 0.25, endJD)
                if high == low { break }
            }
            guard found else { break }
            let exactJD = try bisectAngularCrossing(startJD: low, endJD: high, target: target) { jd in
                try lunarPhaseAngle(jd: jd)
            }
            let date = try date(forProgressedJD: exactJD, natalJD: natalJD, chart: chart)
            let phase = phaseName(for: target)
            result.append(ProgressedIngress(
                id: "phase-highlight-\(Int(target))-\(isoDay(date, timezone: chart.timezone))",
                kind: .lunarPhase,
                date: date,
                dateLabel: displayDate(date, timezone: chart.timezone),
                bodyKey: "LUNA",
                bodyLabel: "Luna progresada",
                fromValue: phaseName(for: normalized(target - 0.001)).rawValue,
                toValue: phase.rawValue,
                longitude: target,
                description: "La fase lunar progresada entra en fase \(phase.rawValue.lowercased()).",
                priority: 3
            ))
            low = exactJD + 0.01
            target = normalized(target + 45.0)
        }
        return result
    }

    // MARK: - Aspects

    private func makeProgressedAspects(chart: Chart, from fromDate: Date, to toDate: Date, ascendantMode: ASCMode) throws -> [ProgressedAspect] {
        guard toDate >= fromDate else { return [] }
        let natalJD = try natalJulianDay(chart)
        let natalPoints = natalAspectPoints(chart: chart)
        let totalDays = max(0, calendarUTC.dateComponents([.day], from: calendarUTC.startOfDay(for: fromDate), to: calendarUTC.startOfDay(for: toDate)).day ?? 0)
        var eventsByID: [String: ProgressedAspect] = [:]
        var previous: [AspectTrackKey: AspectTrackSample] = [:]

        for dayIndex in 0...totalDays {
            guard let date = calendarUTC.date(byAdding: .day, value: dayIndex, to: calendarUTC.startOfDay(for: fromDate)) else { continue }
            let samples = try aspectTrackSamples(chart: chart, natalJD: natalJD, date: date, natalPoints: natalPoints, mode: ascendantMode)
            for sample in samples {
                if let prev = previous[sample.key], prev.value * sample.value <= 0 {
                    if let exact = try? bisectAspectDate(chart: chart, natalJD: natalJD, low: prev.date, high: sample.date, key: sample.key, natalPoints: natalPoints, mode: ascendantMode) {
                        let progressedPoints = try progressedAspectPoints(chart: chart, natalJD: natalJD, date: exact, mode: ascendantMode)
                        let exactSample = try aspectTrackSample(for: sample.key, progressedPoints: progressedPoints, natalPoints: natalPoints)
                        let event = makeAspectEvent(sample: exactSample, exactDate: exact, chart: chart)
                        eventsByID[event.id] = event
                    }
                }
                previous[sample.key] = AspectTrackSample(key: sample.key, date: sample.date, value: sample.value)
            }
        }

        return eventsByID.values.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.orb < $1.orb
        }
    }

    private func aspectTrackSamples(
        chart: Chart,
        natalJD: Double,
        date: Date,
        natalPoints: [AspectPoint],
        mode: ASCMode
    ) throws -> [AspectValueSample] {
        let progressed = try progressedAspectPoints(chart: chart, natalJD: natalJD, date: date, mode: mode)
        var samples: [AspectValueSample] = []
        for source in progressed {
            for target in natalPoints where source.key != target.key {
                for aspect in progressionAspectDefs {
                    for direction in directions(for: aspect.angle) {
                        let key = AspectTrackKey(
                            kind: .progressedToNatal,
                            sourceKey: source.key,
                            targetKey: target.key,
                            aspectKey: aspect.key,
                            direction: direction
                        )
                        let value = signedAspectDistance(source: source.longitude, target: target.longitude, angle: aspect.angle, direction: direction)
                        samples.append(AspectValueSample(key: key, date: date, value: value, source: source, target: target, aspect: aspect))
                    }
                }
            }
        }

        let progressedPlanets = progressed.filter { $0.isPlanet }
        for i in 0..<progressedPlanets.count {
            for j in (i + 1)..<progressedPlanets.count {
                let source = progressedPlanets[i]
                let target = progressedPlanets[j]
                for aspect in progressionAspectDefs {
                    for direction in directions(for: aspect.angle) {
                        let key = AspectTrackKey(
                            kind: .progressedToProgressed,
                            sourceKey: source.key,
                            targetKey: target.key,
                            aspectKey: aspect.key,
                            direction: direction
                        )
                        let value = signedAspectDistance(source: source.longitude, target: target.longitude, angle: aspect.angle, direction: direction)
                        samples.append(AspectValueSample(key: key, date: date, value: value, source: source, target: target, aspect: aspect))
                    }
                }
            }
        }
        return samples
    }

    private func aspectTrackSample(for key: AspectTrackKey, progressedPoints: [AspectPoint], natalPoints: [AspectPoint]) throws -> AspectValueSample {
        let source: AspectPoint
        let target: AspectPoint
        switch key.kind {
        case .progressedToNatal:
            guard let s = progressedPoints.first(where: { $0.key == key.sourceKey }),
                  let t = natalPoints.first(where: { $0.key == key.targetKey }) else {
                throw SecondaryProgressionError.calculationFailed("Punto de aspecto no encontrado")
            }
            source = s; target = t
        case .progressedToProgressed:
            guard let s = progressedPoints.first(where: { $0.key == key.sourceKey }),
                  let t = progressedPoints.first(where: { $0.key == key.targetKey }) else {
                throw SecondaryProgressionError.calculationFailed("Punto progresado no encontrado")
            }
            source = s; target = t
        }
        guard let aspect = progressionAspectDefs.first(where: { $0.key == key.aspectKey }) else {
            throw SecondaryProgressionError.calculationFailed("Aspecto no reconocido")
        }
        let value = signedAspectDistance(source: source.longitude, target: target.longitude, angle: aspect.angle, direction: key.direction)
        return AspectValueSample(key: key, date: Date(), value: value, source: source, target: target, aspect: aspect)
    }

    private func bisectAspectDate(
        chart: Chart,
        natalJD: Double,
        low: Date,
        high: Date,
        key: AspectTrackKey,
        natalPoints: [AspectPoint],
        mode: ASCMode
    ) throws -> Date {
        var a = low
        var b = high
        var fa = try aspectValue(on: a, chart: chart, natalJD: natalJD, key: key, natalPoints: natalPoints, mode: mode)
        for _ in 0..<48 {
            let mid = Date(timeIntervalSince1970: (a.timeIntervalSince1970 + b.timeIntervalSince1970) / 2.0)
            let fm = try aspectValue(on: mid, chart: chart, natalJD: natalJD, key: key, natalPoints: natalPoints, mode: mode)
            if abs(fm) < 1e-7 { return mid }
            if fa * fm <= 0 {
                b = mid
            } else {
                a = mid
                fa = fm
            }
        }
        return Date(timeIntervalSince1970: (a.timeIntervalSince1970 + b.timeIntervalSince1970) / 2.0)
    }

    private func aspectValue(on date: Date, chart: Chart, natalJD: Double, key: AspectTrackKey, natalPoints: [AspectPoint], mode: ASCMode) throws -> Double {
        let progressed = try progressedAspectPoints(chart: chart, natalJD: natalJD, date: date, mode: mode)
        return try aspectTrackSample(for: key, progressedPoints: progressed, natalPoints: natalPoints).value
    }

    private func makeAspectEvent(sample: AspectValueSample, exactDate: Date, chart: Chart) -> ProgressedAspect {
        let orb = abs(sample.value)
        let maxOrb = progressionOrb(for: sample.source, target: sample.target, kind: sample.key.kind)
        let inOrb = orb <= maxOrb + 0.0005
        let day = isoDay(exactDate, timezone: chart.timezone)
        let id = "\(sample.key.kind.rawValue)-\(sample.source.key)-\(sample.aspect.key)-\(sample.target.key)-\(sample.key.direction)-\(day)"
        return ProgressedAspect(
            id: id,
            kind: sample.key.kind,
            date: exactDate,
            exactDate: displayDate(exactDate, timezone: chart.timezone),
            progressedKey: sample.source.key,
            progressedLabel: sample.source.label,
            targetKey: sample.target.key,
            targetLabel: sample.target.label,
            aspectKey: sample.aspect.key,
            aspectLabel: sample.aspect.label,
            orb: rounded(inOrb ? orb : 0, places: 3),
            applying: true,
            priority: priority(source: sample.source, target: sample.target, aspectKey: sample.aspect.key, kind: sample.key.kind),
            progressedRetrograde: sample.source.retrograde
        )
    }

    private func progressedAspectPoints(chart: Chart, natalJD: Double, date: Date, mode: ASCMode) throws -> [AspectPoint] {
        let jd = try progressedJD(forDate: date, chart: chart, natalJD: natalJD)
        let angles = try progressedAngles(chart: chart, natalJD: natalJD, progressedJD: jd, ageYears: jd - natalJD, mode: mode)
        let bodies = try progressedBodies(jd: jd, cusps: angles.cusps)
        var points = bodies.map { AspectPoint(key: $0.key, label: ProgressionLabels.planetName(for: $0.key), longitude: $0.longitude, retrograde: $0.retrograde, isPlanet: true) }
        points.append(AspectPoint(key: "ASC", label: "Ascendente progresado", longitude: angles.asc, retrograde: false, isPlanet: false))
        points.append(AspectPoint(key: "MC", label: "Medio Cielo progresado", longitude: angles.mc, retrograde: false, isPlanet: false))
        return points
    }

    private func natalAspectPoints(chart: Chart) -> [AspectPoint] {
        var points = chart.bodies
            .filter { $0.key != "NODO_SUR" }
            .map { AspectPoint(key: $0.key, label: ProgressionLabels.planetName(for: $0.key), longitude: $0.longitude, retrograde: $0.retrograde, isPlanet: true) }
        points.append(AspectPoint(key: "ASC", label: "Ascendente natal", longitude: chart.ascendant.longitude, retrograde: false, isPlanet: false))
        points.append(AspectPoint(key: "MC", label: "Medio Cielo natal", longitude: chart.mc.longitude, retrograde: false, isPlanet: false))
        points += natalLots(chart: chart)
        return points
    }

    private func natalLots(chart: Chart) -> [AspectPoint] {
        guard let sun = chart.bodies.first(where: { $0.key == "SOL" }),
              let moon = chart.bodies.first(where: { $0.key == "LUNA" }) else { return [] }
        let isDay = (7...12).contains(sun.house)
        let fortune = normalized(chart.ascendant.longitude + (isDay ? moon.longitude - sun.longitude : sun.longitude - moon.longitude))
        let spirit = normalized(chart.ascendant.longitude + (isDay ? sun.longitude - moon.longitude : moon.longitude - sun.longitude))
        return [
            AspectPoint(key: "PARTE_FORTUNA", label: "Parte de Fortuna natal", longitude: fortune, retrograde: false, isPlanet: false),
            AspectPoint(key: "PARTE_ESPIRITU", label: "Parte del Espíritu natal", longitude: spirit, retrograde: false, isPlanet: false),
        ]
    }

    private func signedAspectDistance(source: Double, target: Double, angle: Double, direction: Int) -> Double {
        EphemerisUtilities.signedAngularDistance(source, target: normalized(target + Double(direction) * angle))
    }

    private func directions(for angle: Double) -> [Int] {
        if angle == 0 || angle == 180 { return [1] }
        return [1, -1]
    }

    private func progressionOrb(for source: AspectPoint, target: AspectPoint, kind: ProgressedAspectKind) -> Double {
        if source.key == "LUNA" || (kind == .progressedToProgressed && target.key == "LUNA") { return 0.5 }
        return 1.0
    }

    private func priority(source: AspectPoint, target: AspectPoint, aspectKey: String, kind: ProgressedAspectKind) -> Int {
        var value = 1
        if ["SOL", "LUNA", "ASC", "MC"].contains(source.key) { value += 2 }
        if ["SOL", "LUNA", "ASC", "MC"].contains(target.key) { value += 2 }
        if ["CONJUNCION", "OPOSICION", "CUADRADO"].contains(aspectKey) { value += 1 }
        if kind == .progressedToNatal { value += 1 }
        return min(5, value)
    }

    // MARK: - Formatting and math

    private func houseSystemCode(_ value: String) -> Character {
        let lower = value.lowercased()
        if lower.hasPrefix("regio") { return "R" }
        if lower.hasPrefix("whole") || lower.contains("signo entero") { return "W" }
        if lower.hasPrefix("koch") { return "K" }
        return "P"
    }

    private func displayDate(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: timezone) ?? TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isoDay(_ date: Date, timezone: String) -> String {
        displayDate(date, timezone: timezone)
    }

    private func normalized(_ degree: Double) -> Double {
        EphemerisUtilities.normalizedDegree(degree)
    }

    private func rounded(_ value: Double, places: Int) -> Double {
        EphemerisUtilities.rounded(value, places: places)
    }

    private func signedForwardArc(from start: Double, to end: Double) -> Double {
        normalized(end - start)
    }
}

private struct RawProgressedPoint {
    var key: String
    var label: String
    var longitude: Double
    var declination: Double
    var speed: Double
}

private struct ProgressionAspectDef {
    var angle: Double
    var label: String
    var key: String
}

private let progressionAspectDefs: [ProgressionAspectDef] = [
    ProgressionAspectDef(angle: 0, label: "☌ Conjunción", key: "CONJUNCION"),
    ProgressionAspectDef(angle: 60, label: "⚹ Sextil", key: "SEXTIL"),
    ProgressionAspectDef(angle: 90, label: "□ Cuadratura", key: "CUADRADO"),
    ProgressionAspectDef(angle: 120, label: "△ Trígono", key: "TRIGONO"),
    ProgressionAspectDef(angle: 180, label: "☍ Oposición", key: "OPOSICION"),
]

private struct AspectPoint: Hashable {
    var key: String
    var label: String
    var longitude: Double
    var retrograde: Bool
    var isPlanet: Bool
}

private struct AspectTrackKey: Hashable {
    var kind: ProgressedAspectKind
    var sourceKey: String
    var targetKey: String
    var aspectKey: String
    var direction: Int
}

private struct AspectTrackSample {
    var key: AspectTrackKey
    var date: Date
    var value: Double
}

private struct AspectValueSample {
    var key: AspectTrackKey
    var date: Date
    var value: Double
    var source: AspectPoint
    var target: AspectPoint
    var aspect: ProgressionAspectDef
}
