import Foundation

// MARK: - Monthly Summary Engine

enum MonthlySummaryEngine {

    /// Genera el resumen predictivo mensual cruzando el cielo general con una carta natal.
    static func generateSummary(
        ephemeris: EphemerisMonth,
        natalChart: NatalChart,
        transits: [TransitEvent],
        ingresses: [TransitHouseIngress]
    ) -> MonthlySummary {
        let lunationHits = buildLunationHits(ephemeris.events, natalChart: natalChart)
        let eclipseHits = buildEclipseHits(ephemeris.events, natalChart: natalChart)
        let stationHits = buildStationHits(ephemeris.events, natalChart: natalChart)
        let activeTransits = topActiveTransits(
            transits,
            year: ephemeris.year,
            month: ephemeris.month
        )
        let highPriorityCount = activeTransits.filter { $0.priorityBand == .high }.count
        let criticalTransitCount = activeTransits.filter { $0.priorityBand == .critical }.count
        let climate = MonthlySummaryTemplates.climateSummary(
            lunationCount: lunationHits.count,
            hasEclipse: !eclipseHits.isEmpty,
            eclipseCount: eclipseHits.count,
            stationHitCount: stationHits.count,
            highPriorityTransitCount: highPriorityCount,
            criticalTransitCount: criticalTransitCount
        )

        return MonthlySummary(
            id: String(format: "%04d-%02d-%@", ephemeris.year, ephemeris.month, natalChart.id.uuidString),
            year: ephemeris.year,
            month: ephemeris.month,
            chartName: natalChart.name,
            lunationHits: lunationHits,
            eclipseHits: eclipseHits,
            stationHits: stationHits,
            activeTransits: activeTransits,
            houseIngresses: ingresses.sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.transitKey < rhs.transitKey
            },
            climateSummary: climate
        )
    }

    // MARK: - Public date helpers for views/tests

    static func monthBounds(year: Int, month: Int) -> (start: Date, end: Date)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let start = calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return nil
        }
        return (start, end)
    }

    // MARK: - Internals

    private static func buildLunationHits(
        _ events: [CelestialEvent],
        natalChart: NatalChart
    ) -> [LunationNatalHit] {
        events.compactMap { event in
            guard event.kind == .newMoon || event.kind == .fullMoon,
                  let longitude = event.longitude else { return nil }
            let house = normalizedHouse(AstroEngine.planetHouse(deg: longitude, cusps: natalChart.cusps))
            let conjunctions = conjunctions(to: longitude, in: natalChart, maxOrb: 5.0)
            let closest = conjunctions.first
            var narrative = MonthlySummaryTemplates.lunationInHouse(house, isNew: event.kind == .newMoon)
            if let closest {
                narrative += " " + MonthlySummaryTemplates.lunationConjunct(closest.planetLabel, orb: closest.orb)
            }
            return LunationNatalHit(
                event: event,
                natalHouse: house,
                conjunctPlanet: closest,
                narrative: narrative
            )
        }
    }

    private static func buildEclipseHits(
        _ events: [CelestialEvent],
        natalChart: NatalChart
    ) -> [EclipseNatalHit] {
        events.compactMap { event in
            guard event.kind == .solarEclipse || event.kind == .lunarEclipse,
                  let longitude = event.longitude else { return nil }
            let house = normalizedHouse(AstroEngine.planetHouse(deg: longitude, cusps: natalChart.cusps))
            let conjunctions = conjunctions(to: longitude, in: natalChart, maxOrb: 5.0)
            let angular = [1, 4, 7, 10].contains(house)
            var parts = [MonthlySummaryTemplates.eclipseInHouse(
                house,
                type: event.eclipseType ?? event.title,
                isSolar: event.kind == .solarEclipse
            )]
            if angular { parts.append(MonthlySummaryTemplates.eclipseAngular()) }
            for conjunction in conjunctions {
                parts.append(MonthlySummaryTemplates.eclipseOnPlanet(conjunction.planetLabel, orb: conjunction.orb))
            }
            return EclipseNatalHit(
                event: event,
                natalHouse: house,
                conjunctPlanets: conjunctions,
                isAngular: angular,
                narrative: parts.joined(separator: " ")
            )
        }
    }

    private static func buildStationHits(
        _ events: [CelestialEvent],
        natalChart: NatalChart
    ) -> [StationNatalHit] {
        events.flatMap { event -> [StationNatalHit] in
            guard event.kind == .stationRetrograde || event.kind == .stationDirect,
                  let longitude = event.longitude else { return [] }
            let stationPlanet = event.planetLabelA ?? planetLabel(for: event.planetKeyA) ?? event.title
            let stationType = event.kind == .stationRetrograde ? "retrógrada" : "directa"
            return natalChart.bodies.compactMap { body in
                let orb = angularDistance(longitude, body.longitude)
                guard orb <= 3.0 else { return nil }
                let house = normalizedHouse(body.house)
                return StationNatalHit(
                    event: event,
                    natalPlanetKey: body.key,
                    natalPlanetLabel: body.label,
                    natalHouse: house,
                    orb: rounded(orb, places: 2),
                    narrative: MonthlySummaryTemplates.stationOnPlanet(
                        stationPlanet: stationPlanet,
                        stationType: stationType,
                        natalPlanet: body.label,
                        natalHouse: house,
                        orb: orb
                    )
                )
            }
        }
        .sorted {
            if $0.event.dateUTC != $1.event.dateUTC { return $0.event.dateUTC < $1.event.dateUTC }
            return $0.orb < $1.orb
        }
    }

    private static func topActiveTransits(
        _ transits: [TransitEvent],
        year: Int,
        month: Int
    ) -> [TransitEvent] {
        let monthStart = String(format: "%04d-%02d-01", year, month)
        let monthEnd = String(format: "%04d-%02d-%02d", year, month, daysInMonth(year: year, month: month))
        let active = transits.filter { $0.toDate >= monthStart && $0.fromDate <= monthEnd }
        return Array(active.sorted {
            if $0.priorityScore != $1.priorityScore { return $0.priorityScore > $1.priorityScore }
            if $0.priorityBand.rank != $1.priorityBand.rank { return $0.priorityBand.rank > $1.priorityBand.rank }
            if $0.exactDate != $1.exactDate { return $0.exactDate < $1.exactDate }
            return $0.minOrb < $1.minOrb
        }.prefix(8))
    }

    private static func conjunctions(
        to longitude: Double,
        in natalChart: NatalChart,
        maxOrb: Double
    ) -> [PlanetConjunction] {
        natalChart.bodies.compactMap { body in
            let orb = angularDistance(longitude, body.longitude)
            guard orb <= maxOrb else { return nil }
            return PlanetConjunction(
                planetKey: body.key,
                planetLabel: body.label,
                orb: rounded(orb, places: 2)
            )
        }
        .sorted { $0.orb < $1.orb }
    }

    private static func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        var diff = abs((lhs - rhs + 360).truncatingRemainder(dividingBy: 360))
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    private static func normalizedHouse(_ house: Int) -> Int {
        (1...12).contains(house) ? house : 1
    }

    private static func rounded(_ value: Double, places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (value * multiplier).rounded() / multiplier
    }

    private static func planetLabel(for key: String?) -> String? {
        guard let key else { return nil }
        return MonthlySummaryTemplates.planetLabels[key] ?? key.capitalized
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let date = calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }
}

// MARK: - Templates

enum MonthlySummaryTemplates {
    static let planetLabels: [String: String] = [
        "SOL": "Sol", "LUNA": "Luna", "MERCURIO": "Mercurio",
        "VENUS": "Venus", "MARTE": "Marte", "JUPITER": "Júpiter",
        "SATURNO": "Saturno", "URANO": "Urano", "NEPTUNO": "Neptuno", "PLUTON": "Plutón",
        "ASC": "Ascendente", "MC": "Medio Cielo",
        "EJE_NODAL": "Eje Nodal", "NODO_NORTE": "Nodo Norte", "NODO_SUR": "Nodo Sur",
    ]

    static func lunationInHouse(_ house: Int, isNew: Bool) -> String {
        let phase = isNew ? "Luna Nueva" : "Luna Llena"
        switch house {
        case 1: return "\(phase) en tu casa 1: ciclo de reinvención personal, imagen y energía vital."
        case 2: return "\(phase) en tu casa 2: foco en recursos, dinero, valores y autoestima."
        case 3: return "\(phase) en tu casa 3: activación de comunicación, aprendizaje y entorno cercano."
        case 4: return "\(phase) en tu casa 4: movimiento en hogar, familia, raíces y vida privada."
        case 5: return "\(phase) en tu casa 5: creatividad, romance, hijos y expresión personal."
        case 6: return "\(phase) en tu casa 6: ajustes en salud, rutina, trabajo diario y servicio."
        case 7: return "\(phase) en tu casa 7: activación de relaciones, pareja, socios y acuerdos."
        case 8: return "\(phase) en tu casa 8: transformación, recursos compartidos, crisis y regeneración."
        case 9: return "\(phase) en tu casa 9: expansión, viajes, estudios superiores y búsqueda de sentido."
        case 10: return "\(phase) en tu casa 10: foco en carrera, vocación, reputación y dirección vital."
        case 11: return "\(phase) en tu casa 11: movimiento en grupos, amistades, proyectos y aspiraciones."
        case 12: return "\(phase) en tu casa 12: retiro, introspección, cierre de ciclos y lo inconsciente."
        default: return "\(phase) activa la casa \(house) de tu carta natal."
        }
    }

    static func lunationConjunct(_ planetLabel: String, orb: Double) -> String {
        "Además, esta lunación activa directamente tu \(planetLabel) natal (orbe \(String(format: "%.1f", orb))°), amplificando su significado personal."
    }

    static func eclipseInHouse(_ house: Int, type: String, isSolar: Bool) -> String {
        let eclipseKind = isSolar ? "Eclipse solar" : "Eclipse lunar"
        let typeSuffix = type.isEmpty ? "" : " (\(type))"
        switch house {
        case 1: return "\(eclipseKind)\(typeSuffix) en tu casa 1: punto de inflexión en identidad, cuerpo, imagen y modo de iniciar la vida."
        case 2: return "\(eclipseKind)\(typeSuffix) en tu casa 2: giro relevante en recursos, dinero, seguridad, valores y autoestima."
        case 3: return "\(eclipseKind)\(typeSuffix) en tu casa 3: cambio de ritmo en comunicación, decisiones, estudios y entorno cercano."
        case 4: return "\(eclipseKind)\(typeSuffix) en tu casa 4: umbral importante en hogar, familia, raíces y vida privada."
        case 5: return "\(eclipseKind)\(typeSuffix) en tu casa 5: giro creativo, romántico o vinculado a hijos y expresión personal."
        case 6: return "\(eclipseKind)\(typeSuffix) en tu casa 6: reajuste fuerte en salud, rutina, hábitos, trabajo diario y servicio."
        case 7: return "\(eclipseKind)\(typeSuffix) en tu casa 7: punto de inflexión en pareja, asociaciones, acuerdos y confrontaciones abiertas."
        case 8: return "\(eclipseKind)\(typeSuffix) en tu casa 8: transformación en intimidad, crisis, deudas, herencias o recursos compartidos."
        case 9: return "\(eclipseKind)\(typeSuffix) en tu casa 9: giro en creencias, viajes, formación superior, publicaciones o horizonte vital."
        case 10: return "\(eclipseKind)\(typeSuffix) en tu casa 10: redefinición de carrera, vocación, reputación y dirección pública."
        case 11: return "\(eclipseKind)\(typeSuffix) en tu casa 11: reordenación de amistades, redes, proyectos, aliados y aspiraciones."
        case 12: return "\(eclipseKind)\(typeSuffix) en tu casa 12: cierre profundo de ciclo, retiro, inconsciente y asuntos que maduran fuera de escena."
        default: return "\(eclipseKind)\(typeSuffix) activa la casa \(house) de tu carta natal con tono de punto de inflexión."
        }
    }

    static func eclipseOnPlanet(_ planetLabel: String, orb: Double) -> String {
        "Este eclipse activa tu \(planetLabel) natal (orbe \(String(format: "%.1f", orb))°). Es un evento de primer orden del año: marca un antes y un después en el ámbito de este planeta."
    }

    static func eclipseAngular() -> String {
        "El eclipse cae en un eje angular de tu carta, lo que intensifica su impacto en identidad, vínculos, hogar o dirección vital."
    }

    static func stationOnPlanet(
        stationPlanet: String,
        stationType: String,
        natalPlanet: String,
        natalHouse: Int,
        orb: Double
    ) -> String {
        "\(stationPlanet) se estaciona \(stationType) sobre tu \(natalPlanet) natal en casa \(natalHouse) (orbe \(String(format: "%.1f", orb))°). Durante varias semanas, la energía de \(stationPlanet) se concentra intensamente en este punto de tu carta."
    }

    static func climateSummary(
        lunationCount: Int,
        hasEclipse: Bool,
        eclipseCount: Int,
        stationHitCount: Int,
        highPriorityTransitCount: Int,
        criticalTransitCount: Int
    ) -> String {
        var parts: [String] = []
        if hasEclipse {
            parts.append(eclipseCount == 1
                ? "Un eclipse este mes marca un punto de inflexión"
                : "\(eclipseCount) eclipses hacen de este un mes extraordinario")
        }
        if stationHitCount > 0 {
            parts.append("\(stationHitCount) estación(es) planetaria(s) tocan tu carta directamente")
        }
        if criticalTransitCount > 0 {
            parts.append("\(criticalTransitCount) tránsito(s) de prioridad crítica")
        } else if highPriorityTransitCount > 0 {
            parts.append("\(highPriorityTransitCount) tránsito(s) de prioridad alta")
        }
        if parts.isEmpty {
            return lunationCount > 0
                ? "Mes de actividad moderada. Las lunaciones marcan el ritmo principal."
                : "Mes de actividad moderada, sin activaciones personales extraordinarias detectadas por el resumen mensual."
        }
        return parts.joined(separator: ". ") + "."
    }
}
