import Foundation
import CSwissEph

enum LunarReturnError: LocalizedError, Equatable {
    case missingNatalMoon
    case invalidReturnCount(Int)
    case invalidNatalBirthData
    case calculationFailed(String)
    case invalidReturnJD

    var errorDescription: String? {
        switch self {
        case .missingNatalMoon:
            return "La carta natal no contiene Luna."
        case .invalidReturnCount(let count):
            return "Cantidad de retornos invalida: \(count)."
        case .invalidNatalBirthData:
            return "La carta natal no tiene fecha u hora validas para calcular la edad del retorno."
        case .calculationFailed(let message):
            return "No se pudo calcular la revolucion lunar: \(message)"
        case .invalidReturnJD:
            return "Swiss Ephemeris devolvio una fecha de retorno lunar invalida."
        }
    }
}

enum LunarReturnEngine {
    static func calculate(request: LunarReturnRequest) throws -> LunarReturnReading {
        guard (1...120).contains(request.count) else {
            throw LunarReturnError.invalidReturnCount(request.count)
        }

        let natalChart = request.natalChart
        guard let natalMoon = natalChart.bodies.first(where: { $0.key == "LUNA" }) else {
            throw LunarReturnError.missingNatalMoon
        }

        let birthJD = try natalBirthJD(for: natalChart)
        var startJD = jd(from: request.startDate)
        var events: [LunarReturnEvent] = []

        for index in 1...request.count {
            let exactJD = try moonReturnJD(targetLongitude: natalMoon.longitude, startJD: startJD)
            var returnChart = try AstroEngine.computeNatalChart(
                jd: exactJD,
                lat: request.latitude,
                lon: request.longitude
            )
            let localDateTime = formatJD(exactJD, timezoneName: request.timezone)
            let utcDateTime = formatJD(exactJD, timezoneName: "UTC")
            returnChart = NatalChart(
                id: UUID(),
                name: "Revolucion Lunar #\(index) — \(displayName(natalChart))",
                birthDate: String(localDateTime.prefix(10)),
                birthTime: String(localDateTime.dropFirst(11).prefix(5)),
                timezone: request.timezone,
                latitude: request.latitude,
                longitude: request.longitude,
                placeName: request.placeName,
                houseSystem: "Placidus",
                ascendant: returnChart.ascendant,
                mc: returnChart.mc,
                cusps: returnChart.cusps,
                bodies: returnChart.bodies
            )

            let moon = try moonData(
                jd: exactJD,
                natalLongitude: natalMoon.longitude,
                cusps: returnChart.cusps
            )
            let dominantAspects = Array(returnAspects(chart: returnChart).prefix(10))
            let placements = returnChart.bodies.map { body in
                LunarReturnNatalHousePlacement(
                    planetKey: body.key,
                    planetLabel: body.label,
                    natalHouse: AstroEngine.planetHouse(deg: body.longitude, cusps: natalChart.cusps),
                    returnHouse: body.house,
                    formatted: body.formatted
                )
            }
            let ageDays = (exactJD - birthJD) * 86_400 / 86_400

            // MARK: - Interpretive analysis
            let ascSignKey = AstroEngine.degToSignKey(returnChart.ascendant.longitude)
            let ascSignIndex = Int(returnChart.ascendant.longitude.truncatingRemainder(dividingBy: 360) / 30)
            let ascSignLabel = SIGN_LABELS[max(0, min(11, ascSignIndex))]

            let angularHouses: Set<Int> = [1, 4, 7, 10]
            let angularPlanetCount = returnChart.bodies.filter { angularHouses.contains($0.house) }.count

            let intensityScore = RevolutionTemplates.lunarIntensityScore(
                moonHouse: moon.house,
                moonSignKey: moon.signKey,
                dominantAspects: dominantAspects,
                angularPlanetCount: angularPlanetCount
            )

            let moonFocusText = RevolutionTemplates.lunarMoonInHouse(moon.house)
            let ascToneText = RevolutionTemplates.lunarAscTone(signKey: ascSignKey)

            let miniNarrative = composeMiniNarrative(
                index: index,
                localDate: localDateTime,
                moonHouse: moon.house,
                moonFormatted: moon.formatted,
                ascSignLabel: ascSignLabel,
                intensityScore: intensityScore,
                tenseAspectCount: dominantAspects.filter {
                    ["CUADRADO", "OPOSICION"].contains($0.aspKey) &&
                    ($0.keyA == "LUNA" || $0.keyB == "LUNA")
                }.count,
                angularPlanetCount: angularPlanetCount
            )

            let event = LunarReturnEvent(
                index: index,
                exactJD: exactJD,
                exactLocalDateTime: localDateTime,
                exactUTCDateTime: utcDateTime,
                returnChart: returnChart,
                ageDays: ageDays,
                ageYears: ageDays / 365.25,
                moon: moon,
                natalHouseForReturnAsc: AstroEngine.planetHouse(
                    deg: returnChart.ascendant.longitude,
                    cusps: natalChart.cusps
                ),
                natalHouseForReturnMC: AstroEngine.planetHouse(
                    deg: returnChart.mc.longitude,
                    cusps: natalChart.cusps
                ),
                dominantAspects: dominantAspects,
                returnPlanetsInNatalHouses: placements,
                intensityScore: intensityScore,
                intensityLabel: RevolutionTemplates.intensityLabel(intensityScore),
                ascSignKey: ascSignKey,
                ascSignLabel: ascSignLabel,
                moonFocusText: moonFocusText,
                ascToneText: ascToneText,
                miniNarrative: miniNarrative
            )
            events.append(event)
            startJD = exactJD + 1.0
        }

        let stats = buildStatistics(events: events)

        return LunarReturnReading(
            natalChart: natalChart,
            natalMoon: LunarReturnNatalMoon(
                longitude: natalMoon.longitude,
                formatted: natalMoon.formatted,
                house: natalMoon.house
            ),
            startDate: request.startDate,
            count: request.count,
            placeName: request.placeName,
            latitude: request.latitude,
            longitude: request.longitude,
            timezone: request.timezone,
            events: events,
            statistics: stats
        )
    }

    static func moonReturnJD(targetLongitude: Double, startJD: Double) throws -> Double {
        var serr = [CChar](repeating: 0, count: 256)
        let jd = swe_mooncross_ut(targetLongitude, startJD, SEFLG_SPEED, &serr)
        guard jd > startJD else {
            let message = String(cString: serr).trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                throw LunarReturnError.invalidReturnJD
            }
            throw LunarReturnError.calculationFailed(message)
        }
        guard jd.isFinite else {
            throw LunarReturnError.invalidReturnJD
        }
        return jd
    }

    private static func moonData(
        jd: Double,
        natalLongitude: Double,
        cusps: [Double]
    ) throws -> LunarReturnMoonData {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let rc = swe_calc_ut(jd, SE_MOON, SEFLG_SPEED, &xx, &serr)
        guard rc >= 0 else {
            let message = String(cString: serr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw LunarReturnError.calculationFailed(message.isEmpty ? "No se pudo leer la Luna del retorno." : message)
        }
        let longitude = xx[0]
        let signKey = AstroEngine.degToSignKey(longitude)
        return LunarReturnMoonData(
            longitude: longitude,
            latitude: xx[1],
            distance: xx[2],
            speed: xx[3],
            formatted: AstroEngine.degToSign(longitude),
            house: AstroEngine.planetHouse(deg: longitude, cusps: cusps),
            precisionArcseconds: angularDiff(longitude, natalLongitude) * 3_600,
            signKey: signKey
        )
    }

    private static func natalBirthJD(for chart: NatalChart) throws -> Double {
        guard !chart.birthDate.isEmpty, !chart.birthTime.isEmpty, !chart.timezone.isEmpty else {
            throw LunarReturnError.invalidNatalBirthData
        }
        do {
            return try julianDayFromLocal(
                birthDate: chart.birthDate,
                birthTime: chart.birthTime,
                timezoneName: chart.timezone
            ).jd
        } catch {
            throw LunarReturnError.invalidNatalBirthData
        }
    }

    private static func returnAspects(chart: NatalChart) -> [NatalAspect] {
        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { body in
            (body.key, AstroEngine.RawPlanet(
                key: body.key,
                label: body.label,
                deg: body.longitude,
                speed: body.retrograde ? -1 : 1,
                retro: body.retrograde
            ))
        })
        return AstroEngine.computeNatalAspects(planets: rawPlanets)
    }

    private static func buildStatistics(events: [LunarReturnEvent]) -> LunarReturnStatistics {
        let intervals = zip(events, events.dropFirst()).map { ($1.exactJD - $0.exactJD) * 86_400 / 86_400 }
        let moonHouses = Dictionary(grouping: events, by: { $0.moon.house })
            .mapValues(\.count)
        let mostFrequentHouse = moonHouses.max {
            if $0.value == $1.value {
                return $0.key > $1.key
            }
            return $0.value < $1.value
        }?.key
        let precisions = events.map(\.moon.precisionArcseconds)
        let speeds = events.map(\.moon.speed)
        let distances = events.map(\.moon.distance)
        let intensities = events.map(\.intensityScore)

        return LunarReturnStatistics(
            averageIntervalDays: intervals.isEmpty ? nil : intervals.reduce(0, +) / Double(intervals.count),
            shortestIntervalDays: intervals.min(),
            longestIntervalDays: intervals.max(),
            mostFrequentMoonHouse: mostFrequentHouse,
            meanPrecisionArcseconds: precisions.isEmpty ? 0 : precisions.reduce(0, +) / Double(precisions.count),
            minPrecisionArcseconds: precisions.min() ?? 0,
            maxSpeed: speeds.max() ?? 0,
            minSpeed: speeds.min() ?? 0,
            maxDistance: distances.max() ?? 0,
            minDistance: distances.min() ?? 0,
            averageIntensity: intensities.isEmpty ? 0 : Double(intensities.reduce(0, +)) / Double(intensities.count)
        )
    }

    private static func composeMiniNarrative(
        index: Int,
        localDate: String,
        moonHouse: Int,
        moonFormatted: String,
        ascSignLabel: String,
        intensityScore: Int,
        tenseAspectCount: Int,
        angularPlanetCount: Int
    ) -> String {
        var parts: [String] = []

        // Opening with date context
        let dateShort = String(localDate.prefix(10))
        parts.append("Retorno lunar #\(index) (\(dateShort)).")

        // Moon house focus
        let houseFocus: String
        switch moonHouse {
        case 1: houseFocus = "El foco está en la identidad y la presencia personal."
        case 2: houseFocus = "El foco está en los recursos y la seguridad material."
        case 3: houseFocus = "El foco está en la comunicación y el entorno cercano."
        case 4: houseFocus = "El foco está en el hogar y la vida familiar."
        case 5: houseFocus = "El foco está en la creatividad y el placer."
        case 6: houseFocus = "El foco está en el trabajo y la salud."
        case 7: houseFocus = "El foco está en las relaciones y los compromisos."
        case 8: houseFocus = "El foco está en la transformación y los procesos profundos."
        case 9: houseFocus = "El foco está en la expansión y la búsqueda de sentido."
        case 10: houseFocus = "El foco está en la carrera y la imagen pública."
        case 11: houseFocus = "El foco está en las amistades y los proyectos colectivos."
        case 12: houseFocus = "El foco está en la interioridad y el cierre de ciclos."
        default: houseFocus = "Temas variados durante este ciclo."
        }
        parts.append(houseFocus)

        // Intensity context
        if intensityScore >= 4 {
            if tenseAspectCount > 0 {
                parts.append("Periodo de alta intensidad emocional con \(tenseAspectCount) aspecto\(tenseAspectCount > 1 ? "s" : "") tenso\(tenseAspectCount > 1 ? "s" : "") a la Luna.")
            } else {
                parts.append("Periodo de mucha actividad con \(angularPlanetCount) planeta\(angularPlanetCount > 1 ? "s" : "") en casas angulares.")
            }
        } else if intensityScore <= 2 {
            parts.append("Ciclo tranquilo, favorable para la estabilidad y la reflexión.")
        }

        return parts.joined(separator: " ")
    }

    private static func jd(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func formatJD(_ jd: Double, timezoneName: String) -> String {
        let date = Date(timeIntervalSince1970: (jd - 2_440_587.5) * 86_400)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timezoneName) ?? TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func angularDiff(_ a: Double, _ b: Double) -> Double {
        var diff = abs((a - b + 360).truncatingRemainder(dividingBy: 360))
        if diff > 180 { diff = 360 - diff }
        return diff
    }
}

private func displayName(_ chart: NatalChart) -> String {
    chart.name.isEmpty ? chart.birthDate : chart.name
}
