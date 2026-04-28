import Foundation
import CSwissEph

enum HoraryNativeEngine {
    private static let signs = [
        "Aries", "Tauro", "Geminis", "Cancer", "Leo", "Virgo",
        "Libra", "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis",
    ]

    private static let elements = [
        "Aries": "fuego", "Tauro": "tierra", "Geminis": "aire", "Cancer": "agua",
        "Leo": "fuego", "Virgo": "tierra", "Libra": "aire", "Escorpio": "agua",
        "Sagitario": "fuego", "Capricornio": "tierra", "Acuario": "aire", "Piscis": "agua",
    ]

    private static let modalities = [
        "Aries": "cardinal", "Tauro": "fijo", "Geminis": "mutable", "Cancer": "cardinal",
        "Leo": "fijo", "Virgo": "mutable", "Libra": "cardinal", "Escorpio": "fijo",
        "Sagitario": "mutable", "Capricornio": "cardinal", "Acuario": "fijo", "Piscis": "mutable",
    ]

    private static let rulerships = [
        "Aries": "Marte", "Tauro": "Venus", "Geminis": "Mercurio", "Cancer": "Luna",
        "Leo": "Sol", "Virgo": "Mercurio", "Libra": "Venus", "Escorpio": "Marte",
        "Sagitario": "Jupiter", "Capricornio": "Saturno", "Acuario": "Saturno", "Piscis": "Jupiter",
    ]

    private static let exaltations = [
        "Aries": "Sol", "Tauro": "Luna", "Cancer": "Jupiter", "Virgo": "Mercurio",
        "Libra": "Saturno", "Capricornio": "Marte", "Piscis": "Venus",
    ]

    private static let falls = [
        "Libra": "Sol", "Escorpio": "Luna", "Capricornio": "Jupiter", "Piscis": "Mercurio",
        "Aries": "Saturno", "Cancer": "Marte", "Virgo": "Venus",
    ]

    private static let triplicities = [
        "fuego": ["dia": "Sol", "noche": "Jupiter", "participante": "Saturno"],
        "tierra": ["dia": "Venus", "noche": "Luna", "participante": "Marte"],
        "aire": ["dia": "Saturno", "noche": "Mercurio", "participante": "Jupiter"],
        "agua": ["dia": "Venus", "noche": "Marte", "participante": "Luna"],
    ]

    private static let egyptianTerms: [String: [(Double, String)]] = [
        "Aries": [(6, "Jupiter"), (14, "Venus"), (21, "Mercurio"), (26, "Marte"), (30, "Saturno")],
        "Tauro": [(8, "Venus"), (14, "Mercurio"), (22, "Jupiter"), (27, "Saturno"), (30, "Marte")],
        "Geminis": [(6, "Mercurio"), (14, "Jupiter"), (21, "Venus"), (28, "Saturno"), (30, "Marte")],
        "Cancer": [(7, "Marte"), (13, "Venus"), (19, "Mercurio"), (26, "Jupiter"), (30, "Saturno")],
        "Leo": [(6, "Jupiter"), (11, "Venus"), (18, "Saturno"), (24, "Mercurio"), (30, "Marte")],
        "Virgo": [(7, "Mercurio"), (13, "Venus"), (17, "Jupiter"), (21, "Marte"), (30, "Saturno")],
        "Libra": [(6, "Saturno"), (14, "Mercurio"), (21, "Jupiter"), (28, "Venus"), (30, "Marte")],
        "Escorpio": [(7, "Marte"), (11, "Venus"), (19, "Mercurio"), (24, "Jupiter"), (30, "Saturno")],
        "Sagitario": [(12, "Jupiter"), (17, "Venus"), (21, "Mercurio"), (26, "Saturno"), (30, "Marte")],
        "Capricornio": [(7, "Mercurio"), (14, "Jupiter"), (22, "Venus"), (26, "Saturno"), (30, "Marte")],
        "Acuario": [(7, "Mercurio"), (13, "Venus"), (20, "Jupiter"), (25, "Marte"), (30, "Saturno")],
        "Piscis": [(12, "Venus"), (16, "Jupiter"), (19, "Mercurio"), (28, "Marte"), (30, "Saturno")],
    ]

    private static let decans = [
        "Aries": ["Marte", "Sol", "Venus"],
        "Tauro": ["Mercurio", "Luna", "Saturno"],
        "Geminis": ["Jupiter", "Marte", "Sol"],
        "Cancer": ["Venus", "Mercurio", "Luna"],
        "Leo": ["Saturno", "Jupiter", "Marte"],
        "Virgo": ["Sol", "Venus", "Mercurio"],
        "Libra": ["Luna", "Saturno", "Jupiter"],
        "Escorpio": ["Marte", "Sol", "Venus"],
        "Sagitario": ["Mercurio", "Luna", "Saturno"],
        "Capricornio": ["Jupiter", "Marte", "Sol"],
        "Acuario": ["Venus", "Mercurio", "Luna"],
        "Piscis": ["Saturno", "Jupiter", "Marte"],
    ]

    private static let traditionalPlanets: [(String, Int32)] = [
        ("Sol", SE_SUN),
        ("Luna", SE_MOON),
        ("Mercurio", SE_MERCURY),
        ("Venus", SE_VENUS),
        ("Marte", SE_MARS),
        ("Jupiter", SE_JUPITER),
        ("Saturno", SE_SATURN),
    ]

    private static let planetOrder = ["Sol", "Luna", "Mercurio", "Venus", "Marte", "Jupiter", "Saturno"]
    private static let chaldeanOrder = ["Saturno", "Jupiter", "Marte", "Sol", "Venus", "Mercurio", "Luna"]
    private static let dayRulers = [1: "Luna", 2: "Marte", 3: "Mercurio", 4: "Jupiter", 5: "Venus", 6: "Saturno", 7: "Sol"]
    private static let aspects = ["conjuncion": 0.0, "sextil": 60.0, "cuadratura": 90.0, "trigono": 120.0, "oposicion": 180.0]
    private static let moieties = ["Sol": 15.0, "Luna": 12.0, "Mercurio": 7.0, "Venus": 7.0, "Marte": 7.5, "Jupiter": 9.0, "Saturno": 9.0]
    private static let meanSpeeds = ["Sol": 0.9856, "Luna": 13.1764, "Mercurio": 1.23, "Venus": 1.18, "Marte": 0.524, "Jupiter": 0.0831, "Saturno": 0.0335, "Nodo Norte": -0.053]
    private static let questionTopics = [
        1: "el consultante y su situacion",
        2: "el dinero y los bienes",
        3: "los hermanos, mensajes y desplazamientos",
        4: "el hogar y los finales",
        5: "los hijos, placeres y creatividad",
        6: "la salud y el trabajo cotidiano",
        7: "el matrimonio o la contraparte",
        8: "las deudas, perdidas y temores",
        9: "los viajes largos, estudios y creencias",
        10: "la carrera, honra y reputacion",
        11: "las amistades y esperanzas",
        12: "los enemigos ocultos y las aflicciones",
    ]

    static func calculate(_ req: HoraryRequest) throws -> HoraryResponse {
        let localDate = try parseLocalDate(req.datetimeLocal, timezone: req.timezone)
        let jd = try julianDay(req.datetimeLocal, timezone: req.timezone)
        let houses = try AstroEngine.calcHouses(jd: jd, lat: req.latitude, lon: req.longitude, system: "R")
        let bodies = try calculateBodies(jd: jd, cusps: houses.cusps)
        let bodyMap = Dictionary(uniqueKeysWithValues: bodies.map { ($0.name, $0) })
        guard let sun = bodyMap["Sol"], let moon = bodyMap["Luna"] else {
            throw HoraryEngineError.invalidOutput("No se pudo calcular Sol y Luna para Horaria.")
        }
        let sect = sun.house >= 7 ? "dia" : "noche"
        let parts = calculateParts(asc: houses.asc, sun: sun, moon: moon, sect: sect, cusps: houses.cusps, includeFortune: req.includeFortune)
        let dignities = planetOrder.compactMap { name in
            bodyMap[name].map { dignity(for: $0, sect: sect, sun: sun) }
        }
        let dignityMap = Dictionary(uniqueKeysWithValues: dignities.map { ($0.name, $0) })
        let planetaryHourRuler = planetaryHourRuler(for: localDate, latitude: req.latitude, longitude: req.longitude, timezone: req.timezone)
        let considerations = evaluateConsiderations(asc: houses.asc, bodies: bodyMap, planetaryHourRuler: planetaryHourRuler)
        let chart = HoraryChart(
            header: HoraryHeader(
                question: req.question,
                datetimeLocal: req.datetimeLocal,
                timezone: req.timezone,
                placeName: req.placeName,
                latitude: req.latitude,
                longitude: req.longitude,
                questionHouse: req.questionHouse,
                questionTopic: questionTopics[req.questionHouse] ?? "el asunto consultado"
            ),
            angles: HoraryAngles(
                asc: HoraryAngle(longitude: normalize(houses.asc), sign: signName(houses.asc), degreeInSign: degreeInSign(houses.asc)),
                mc: HoraryAngle(longitude: normalize(houses.mc), sign: signName(houses.mc), degreeInSign: degreeInSign(houses.mc))
            ),
            planetaryHourRuler: planetaryHourRuler,
            sect: sect,
            bodies: bodies,
            parts: parts,
            dignities: dignities,
            aspects: detectAspects(bodies: bodyMap),
            considerations: considerations
        )
        let judgement = judge(req: req, chart: chart, cusps: houses.cusps, bodies: bodyMap, dignities: dignityMap)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let chartJSON = String(decoding: try encoder.encode(chart), as: UTF8.self)
        let judgementJSON = String(decoding: try encoder.encode(judgement), as: UTF8.self)
        let text = renderJudgementText(judgement: judgement, chart: chart)
        return HoraryResponse(
            chartJSON: chartJSON,
            judgementJSON: judgementJSON,
            judgementText: text,
            calculatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private static func calculateBodies(jd: Double, cusps: [Double]) throws -> [HoraryBody] {
        var result: [HoraryBody] = []
        for (name, id) in traditionalPlanets + [("Nodo Norte", SE_TRUE_NODE)] {
            var xx = [Double](repeating: 0, count: 6)
            var serr = [CChar](repeating: 0, count: 256)
            let rc = swe_calc_ut(jd, id, SEFLG_SWIEPH | SEFLG_SPEED, &xx, &serr)
            guard rc >= 0 else {
                throw AstroError.calcFailed(name, String(cString: serr))
            }
            result.append(makeBody(name: name, longitude: xx[0], latitude: xx[1], speed: xx[3], cusps: cusps))
        }
        return result
    }

    private static func makeBody(name: String, longitude: Double, latitude: Double, speed: Double, cusps: [Double]) -> HoraryBody {
        let normalized = normalize(longitude)
        return HoraryBody(
            name: name,
            longitude: normalized,
            latitude: latitude,
            speed: speed,
            sign: signName(normalized),
            degreeInSign: degreeInSign(normalized),
            house: AstroEngine.planetHouse(deg: normalized, cusps: cusps),
            retrograde: speed < 0,
            stationary: abs(speed) < 0.03
        )
    }

    private static func calculateParts(asc: Double, sun: HoraryBody, moon: HoraryBody, sect: String, cusps: [Double], includeFortune: Bool) -> [HoraryPart] {
        var parts: [HoraryPart] = []
        let fortune = sect == "dia" ? normalize(asc + moon.longitude - sun.longitude) : normalize(asc + sun.longitude - moon.longitude)
        if includeFortune {
            parts.append(makeBody(name: "Parte de Fortuna", longitude: fortune, latitude: 0, speed: 0, cusps: cusps))
        }
        let spirit = sect == "dia" ? normalize(asc + sun.longitude - moon.longitude) : normalize(asc + moon.longitude - sun.longitude)
        parts.append(makeBody(name: "Parte del Espiritu", longitude: spirit, latitude: 0, speed: 0, cusps: cusps))
        return parts
    }

    private static func detectAspects(bodies: [String: HoraryBody]) -> [HoraryAspect] {
        var found: [HoraryAspect] = []
        for i in 0..<planetOrder.count {
            for j in (i + 1)..<planetOrder.count {
                guard let a = bodies[planetOrder[i]], let b = bodies[planetOrder[j]], let aspect = aspectBetween(a, b, requireWithinSignForMoon: false) else { continue }
                found.append(aspect.aspect)
            }
        }
        return found
    }

    private static func evaluateConsiderations(asc: Double, bodies: [String: HoraryBody], planetaryHourRuler: String) -> [HoraryConsideration] {
        guard let moon = bodies["Luna"], let saturn = bodies["Saturno"] else { return [] }
        let ascSign = signName(asc)
        let regentAsc = rulerships[ascSign] ?? ""
        let ascDegree = degreeInSign(asc)
        let activeHourAgreement = hourAgreement(hourRuler: planetaryHourRuler, ascRuler: regentAsc, ascSign: ascSign)
        return [
            HoraryConsideration(key: "asc_temprano", active: ascDegree < 3, severity: "advertencia", description: "ASC en los primeros 3 grados: asunto prematuro o aun inmaduro."),
            HoraryConsideration(key: "asc_tardio", active: ascDegree >= 27, severity: "advertencia", description: "ASC en los ultimos 3 grados: asunto ya avanzado o juicio tardio."),
            HoraryConsideration(key: "via_combusta", active: moon.longitude >= 195 && moon.longitude <= 225, severity: "advertencia", description: "Luna en via combusta: el asunto se halla bajo gran turbacion."),
            HoraryConsideration(key: "luna_vacia", active: moonVoidOfCourse(moon: moon, bodies: bodies), severity: "advertencia", description: "Luna vacia de curso: no perfecciona aspecto mayor antes de salir del signo."),
            HoraryConsideration(key: "saturno_1_7", active: [1, 7].contains(saturn.house), severity: "advertencia", description: "Saturno en I o VII: dano para consultante o para el juicio del astrologo."),
            HoraryConsideration(key: "acuerdo_hora", active: activeHourAgreement, severity: "favorable", description: "Acuerdo entre regente de la hora y regente del ASC."),
        ]
    }

    private static func moonVoidOfCourse(moon: HoraryBody, bodies: [String: HoraryBody]) -> Bool {
        if moon.speed <= 0 { return true }
        for body in bodies.values where planetOrder.contains(body.name) && body.name != "Luna" {
            if let detail = aspectBetween(moon, body, requireWithinSignForMoon: true), detail.perfectsBeforeSignChange == true {
                return false
            }
        }
        return true
    }

    private static func judge(req: HoraryRequest, chart: HoraryChart, cusps: [Double], bodies: [String: HoraryBody], dignities: [String: HoraryDignity]) -> HoraryJudgement {
        let ascSign = chart.angles.asc.sign
        let querentName = rulerships[ascSign] ?? "Luna"
        let questionHouse = min(12, max(1, req.questionHouse))
        let quesitedSign = signName(cusps[questionHouse - 1])
        let quesitedName = rulerships[quesitedSign] ?? "Saturno"
        let moonName = "Luna"
        let querentCosignifiers = cosignifiers(in: 1, bodies: bodies, dignities: dignities, excluding: [querentName, "Luna", "Sol"])
        let quesitedCosignifiers = cosignifiers(in: questionHouse, bodies: bodies, dignities: dignities, excluding: [quesitedName, "Luna", "Sol"])
        let activeKeys = chart.activeConsiderations.map(\.key)
        let hourAgreement = activeKeys.contains("acuerdo_hora")
        let warnings = chart.activeConsiderations
            .filter { $0.severity == "advertencia" }
            .map(\.description)
        let radical = hourAgreement || warnings.count < 3

        let route = resolveRoute(
            querentName: querentName,
            quesitedName: quesitedName,
            moonName: moonName,
            querentCosignifiers: querentCosignifiers,
            quesitedCosignifiers: quesitedCosignifiers,
            bodies: bodies,
            dignities: dignities
        )
        let reception = receptionBetween(querentName, quesitedName, bodies: bodies, sect: chart.sect)
        let verdictData = verdict(route: route, activeKeys: activeKeys, radical: radical, reception: reception, dignities: dignities, querent: querentName, quesited: quesitedName)
        let routeTiming = timingRangeFromRoute(route, bodies: bodies)
        var notes: [String] = []
        if let aspectName = route.aspectName, route.kind != "sin_perfeccion" {
            notes.append("Perfección por \(renderAspect(aspectName)) entre \(route.significatorQuerent) y \(route.significatorQuesited).")
        }
        if reception.mutual {
            notes.append("Recepcion mutua entre \(querentName) y \(quesitedName): \(reception.aReceivesB.joined(separator: ", ")) / \(reception.bReceivesA.joined(separator: ", ")).")
        } else if reception.simple {
            notes.append("Recepcion simple presente entre \(querentName) y \(quesitedName).")
        }
        if !activeKeys.isEmpty {
            notes.append("Consideraciones activas: \(activeKeys.joined(separator: ", ")).")
        }
        return HoraryJudgement(
            question: req.question,
            radical: radical,
            perfectionKind: route.kind,
            timeEstimate: route.kind == "sin_perfeccion" ? nil : routeTiming,
            questionHouse: questionHouse,
            questionTopic: chart.header.questionTopic,
            significators: HorarySignificators(
                querent: querentName,
                quesited: quesitedName,
                moon: moonName,
                querentCosignifiers: querentCosignifiers,
                quesitedCosignifiers: quesitedCosignifiers
            ),
            perfectionRoute: route,
            activeConsiderationKeys: activeKeys,
            notes: notes,
            verdict: verdictData.verdict,
            confidence: verdictData.confidence,
            mainReason: verdictData.mainReason,
            supportingFactors: verdictData.supporting,
            blockingFactors: verdictData.blocking,
            technicalWarnings: warnings,
            timingRange: route.kind == "sin_perfeccion" ? nil : routeTiming
        )
    }

    private static func resolveRoute(
        querentName: String,
        quesitedName: String,
        moonName: String,
        querentCosignifiers: [String],
        quesitedCosignifiers: [String],
        bodies: [String: HoraryBody],
        dignities: [String: HoraryDignity]
    ) -> HoraryPerfectionRoute {
        let consultCandidates = unique([querentName, moonName] + querentCosignifiers)
        let quesitedCandidates = unique([quesitedName] + quesitedCosignifiers)
        for (indexA, aName) in consultCandidates.enumerated() {
            for (indexB, bName) in quesitedCandidates.enumerated() where aName != bName {
                guard let a = bodies[aName], let b = bodies[bName] else { continue }
                let usesCosignifier = indexA > 0 || indexB > 0
                if usesCosignifier && !isStrongCosignifier(aName, primary: querentName, dignities: dignities) && !isStrongCosignifier(bName, primary: quesitedName, dignities: dignities) {
                    continue
                }
                if let detail = aspectBetween(a, b, requireWithinSignForMoon: true), detail.aspect.applying {
                    return HoraryPerfectionRoute(
                        kind: "aplicativo_directo",
                        significatorQuerent: aName,
                        significatorQuesited: bName,
                        intermediary: nil,
                        aspectName: detail.aspect.aspectName,
                        usesCosignifier: usesCosignifier,
                        degreesToPerfect: detail.degreesToPerfect,
                        degreesToSignChange: detail.degreesToSignChange,
                        fasterBody: detail.fasterBody,
                        perfectsBeforeSignChange: detail.perfectsBeforeSignChange,
                        confidence: routeConfidence(for: detail, aspectName: detail.aspect.aspectName)
                    )
                }
            }
        }
        if let translation = translationRoute(consultCandidates: consultCandidates, quesitedCandidates: quesitedCandidates, bodies: bodies) {
            return translation
        }
        if let collection = collectionRoute(consultCandidates: consultCandidates, quesitedCandidates: quesitedCandidates, bodies: bodies) {
            return collection
        }
        return HoraryPerfectionRoute(
            kind: "sin_perfeccion",
            significatorQuerent: querentName,
            significatorQuesited: quesitedName,
            intermediary: nil,
            aspectName: nil,
            usesCosignifier: false,
            degreesToPerfect: nil,
            degreesToSignChange: bodies["Luna"].map { 30 - $0.degreeInSign },
            fasterBody: nil,
            perfectsBeforeSignChange: nil,
            confidence: nil
        )
    }

    private static func translationRoute(consultCandidates: [String], quesitedCandidates: [String], bodies: [String: HoraryBody]) -> HoraryPerfectionRoute? {
        for aName in consultCandidates {
            for bName in quesitedCandidates where aName != bName {
                guard let a = bodies[aName], let b = bodies[bName] else { continue }
                for translatorName in planetOrder where translatorName != aName && translatorName != bName {
                    guard let translator = bodies[translatorName], abs(translator.speed) > max(abs(a.speed), abs(b.speed)) else { continue }
                    let toA = aspectBetween(translator, a, requireWithinSignForMoon: true)
                    let toB = aspectBetween(translator, b, requireWithinSignForMoon: true)
                    if let toA, let toB, toA.aspect.separating, toB.aspect.applying {
                        return indirectRoute(kind: "translacion", aName: aName, bName: bName, intermediary: translatorName)
                    }
                    if let toA, let toB, toB.aspect.separating, toA.aspect.applying {
                        return indirectRoute(kind: "translacion", aName: aName, bName: bName, intermediary: translatorName)
                    }
                }
            }
        }
        return nil
    }

    private static func collectionRoute(consultCandidates: [String], quesitedCandidates: [String], bodies: [String: HoraryBody]) -> HoraryPerfectionRoute? {
        for aName in consultCandidates {
            for bName in quesitedCandidates where aName != bName {
                guard let a = bodies[aName], let b = bodies[bName] else { continue }
                for collectorName in planetOrder where collectorName != aName && collectorName != bName {
                    guard let collector = bodies[collectorName], abs(collector.speed) < min(abs(a.speed), abs(b.speed)) else { continue }
                    let fromA = aspectBetween(a, collector, requireWithinSignForMoon: true)
                    let fromB = aspectBetween(b, collector, requireWithinSignForMoon: true)
                    if let fromA, let fromB, fromA.aspect.applying, fromB.aspect.applying {
                        return indirectRoute(kind: "coleccion", aName: aName, bName: bName, intermediary: collectorName)
                    }
                }
            }
        }
        return nil
    }

    private static func indirectRoute(kind: String, aName: String, bName: String, intermediary: String) -> HoraryPerfectionRoute {
        HoraryPerfectionRoute(
            kind: kind,
            significatorQuerent: aName,
            significatorQuesited: bName,
            intermediary: intermediary,
            aspectName: nil,
            usesCosignifier: false,
            degreesToPerfect: nil,
            degreesToSignChange: nil,
            fasterBody: nil,
            perfectsBeforeSignChange: nil,
            confidence: "media"
        )
    }

    private struct NativeAspectDetail {
        let aspect: HoraryAspect
        let exactTimeDays: Double?
        let degreesToPerfect: Double?
        let degreesToSignChange: Double?
        let fasterBody: String
        let perfectsBeforeSignChange: Bool?
    }

    private static func aspectBetween(_ a: HoraryBody, _ b: HoraryBody, requireWithinSignForMoon: Bool) -> NativeAspectDetail? {
        guard let orbA = moieties[a.name], let orbB = moieties[b.name] else { return nil }
        let orb = (orbA + orbB) / 2
        let faster = abs(a.speed) >= abs(b.speed) ? a : b
        let slower = faster.name == a.name ? b : a
        let separation = normalize(slower.longitude - faster.longitude)
        let relative = slower.speed - faster.speed
        var best: (name: String, angle: Double, distance: Double, time: Double?)?
        for (name, angle) in aspects {
            let distance = angularDistance(separation, angle)
            guard distance <= orb else { continue }
            let time = exactTimeDays(separation: separation, relative: relative, angle: angle)
            if best == nil || distance < best!.distance {
                best = (name, angle, distance, time)
            }
        }
        guard let best else { return nil }
        let applying = (best.time ?? -1) > 0
        let moon = a.name == "Luna" ? a : b.name == "Luna" ? b : nil
        let degreesToSignChange = moon.map { 30 - $0.degreeInSign }
        let timeToSignChange = moon.flatMap { $0.speed > 0 ? (30 - $0.degreeInSign) / $0.speed : nil }
        let perfectsBeforeSignChange = timeToSignChange.flatMap { limit in best.time.map { $0 <= limit } }
        if requireWithinSignForMoon, moon != nil, perfectsBeforeSignChange != true {
            return nil
        }
        return NativeAspectDetail(
            aspect: HoraryAspect(
                bodyA: a.name,
                bodyB: b.name,
                aspectName: best.name,
                angle: best.angle,
                distance: best.distance,
                orb: orb,
                applying: applying,
                separating: !applying,
                timeEstimate: applying ? timingRange(degrees: best.distance, house: faster.house, sign: faster.sign) : nil
            ),
            exactTimeDays: best.time,
            degreesToPerfect: best.distance,
            degreesToSignChange: degreesToSignChange,
            fasterBody: faster.name,
            perfectsBeforeSignChange: perfectsBeforeSignChange
        )
    }

    private static func exactTimeDays(separation: Double, relative: Double, angle: Double) -> Double? {
        guard abs(relative) > 1e-9 else { return nil }
        var candidates: [Double] = []
        for offset in [-360.0, 0.0, 360.0] {
            let t = (angle + offset - separation) / relative
            if t > 0 { candidates.append(t) }
        }
        return candidates.min()
    }

    private static func dignity(for body: HoraryBody, sect: String, sun: HoraryBody) -> HoraryDignity {
        let essential = essentialDignity(planet: body.name, sign: body.sign, degree: body.degreeInSign, sect: sect)
        let accidental = accidentalDignity(body: body, sun: sun)
        return HoraryDignity(
            name: body.name,
            essentialScore: essential.score,
            accidentalScore: accidental.score,
            totalScore: essential.score + accidental.score,
            essentialTags: essential.tags,
            accidentalTags: accidental.tags
        )
    }

    private static func essentialDignity(planet: String, sign: String, degree: Double, sect: String) -> (score: Int, tags: [String]) {
        var score = 0
        var tags: [String] = []
        if rulerships[sign] == planet { score += 5; tags.append("domicilio") }
        if exaltations[sign] == planet { score += 4; tags.append("exaltacion") }
        if let element = elements[sign], triplicities[element]?[sect] == planet {
            score += 3
            tags.append("triplicidad_\(sect)")
        }
        if termRuler(sign: sign, degree: degree) == planet { score += 2; tags.append("termino") }
        if decanRuler(sign: sign, degree: degree) == planet { score += 1; tags.append("decanato") }
        if detrimentRuler(sign: sign) == planet { score -= 5; tags.append("detrimento") }
        if falls[sign] == planet { score -= 4; tags.append("caida") }
        if tags.isEmpty { score -= 5; tags.append("peregrino") }
        return (score, tags)
    }

    private static func accidentalDignity(body: HoraryBody, sun: HoraryBody) -> (score: Int, tags: [String]) {
        var score = 0
        var tags: [String] = []
        let houseType = houseType(body.house)
        var housePoints = houseType == "angular" ? 5 : houseType == "sucedente" ? 2 : -2
        if body.house == 12 && ["Jupiter", "Venus"].contains(body.name) {
            housePoints = 0
            tags.append("casa_12_mitigada")
        }
        if body.house == 6 && ["Marte", "Saturno"].contains(body.name) {
            housePoints = -4
            tags.append("casa_6_afliccion")
        }
        score += housePoints
        tags.append(houseType)
        if body.retrograde {
            score -= 5
            tags.append("retrogrado")
        } else if !["Sol", "Luna", "Parte de Fortuna", "Parte del Espiritu"].contains(body.name) {
            score += 4
            tags.append("directo")
        }
        let sunSeparation = angularDistance(body.longitude, sun.longitude)
        if body.name != "Sol", body.sign == sun.sign {
            if sunSeparation < 17.0 / 60.0 {
                score += 5
                tags.append("cazimi")
            } else if sunSeparation < 8.5 {
                score -= 5
                tags.append("combusto")
            } else if sunSeparation < 17 {
                score -= 4
                tags.append("bajo_los_rayos")
            }
        }
        if let mean = meanSpeeds[body.name] {
            if abs(body.speed) > mean {
                score += 2
                tags.append("rapido")
            } else if abs(body.speed) < mean {
                score -= 2
                tags.append("lento")
            }
        }
        return (score, tags)
    }

    private static func receptionBetween(_ aName: String, _ bName: String, bodies: [String: HoraryBody], sect: String) -> (aReceivesB: [String], bReceivesA: [String], mutual: Bool, simple: Bool) {
        guard let a = bodies[aName], let b = bodies[bName] else { return ([], [], false, false) }
        let aReceivesB = receptionDignities(receiver: a.name, target: b, sect: sect)
        let bReceivesA = receptionDignities(receiver: b.name, target: a, sect: sect)
        let mutual = !aReceivesB.isEmpty && !bReceivesA.isEmpty
        return (aReceivesB, bReceivesA, mutual, (!aReceivesB.isEmpty || !bReceivesA.isEmpty) && !mutual)
    }

    private static func receptionDignities(receiver: String, target: HoraryBody, sect: String) -> [String] {
        let tags = essentialDignity(planet: receiver, sign: target.sign, degree: target.degreeInSign, sect: sect).tags
        let allowed = Set(["domicilio", "exaltacion", "triplicidad_dia", "triplicidad_noche", "termino"])
        return tags.filter { allowed.contains($0) }
    }

    private static func verdict(route: HoraryPerfectionRoute, activeKeys: [String], radical: Bool, reception: (aReceivesB: [String], bReceivesA: [String], mutual: Bool, simple: Bool), dignities: [String: HoraryDignity], querent: String, quesited: String) -> (verdict: String, confidence: String, mainReason: String, supporting: [String], blocking: [String]) {
        var supporting: [String] = []
        var blocking: [String] = []
        if activeKeys.contains("acuerdo_hora") { supporting.append("La hora planetaria concuerda con el Ascendente y avala la radicalidad.") }
        if reception.mutual { supporting.append("Hay recepción mutua entre los significadores principales.") }
        if reception.simple { supporting.append("Hay recepción simple que mitiga parte de la dificultad.") }
        if let dignity = dignities[querent], dignity.totalScore >= 8 { supporting.append("\(querent) aparece fuerte por dignidad o accidente.") }
        if activeKeys.contains("asc_temprano") { blocking.append("El Ascendente temprano indica que el asunto todavía está inmaduro.") }
        if activeKeys.contains("asc_tardio") { blocking.append("El Ascendente tardío sugiere que el asunto ya está avanzado o llega tarde al juicio.") }
        if activeKeys.contains("luna_vacia") { blocking.append("La Luna está vacía de curso y no empuja el asunto antes de cambiar de signo.") }
        if activeKeys.contains("via_combusta") { blocking.append("La Luna en vía combusta aumenta la turbación del asunto.") }
        if let dignity = dignities[quesited], dignity.essentialScore <= -4 { blocking.append("\(quesited) está esencialmente debilitado.") }
        if !radical { blocking.append("La carta acumula advertencias y baja la fiabilidad del juicio.") }

        let hasPerfection = route.kind != "sin_perfeccion"
        let hardAspect = route.aspectName == "cuadratura" || route.aspectName == "oposicion"
        let verdict: String
        let mainReason: String
        if hasPerfection && !hardAspect {
            verdict = "si"
            mainReason = "Hay un mecanismo de perfección válido dentro de las condiciones de la carta."
        } else if hasPerfection && reception.mutual {
            verdict = "si"
            mainReason = "Hay perfección con obstáculo, mitigada por recepción suficiente."
        } else if hasPerfection {
            verdict = "requiere_mediacion"
            mainReason = hardAspect ? "Hay perfección, pero por aspecto difícil y con condiciones que exigen ajuste." : "Hay perfección, pero depende de condiciones secundarias."
        } else if activeKeys.contains("luna_vacia") || activeKeys.contains("asc_temprano") {
            verdict = "no_todavia"
            mainReason = "No aparece perfección válida y la carta muestra inmadurez o falta de movimiento."
        } else {
            verdict = "dudoso"
            mainReason = "No aparece una vía técnica suficiente para asegurar el desenlace."
        }

        let confidence: String
        if !radical || activeKeys.contains("asc_temprano") || activeKeys.contains("asc_tardio") {
            confidence = "baja"
        } else if activeKeys.contains("luna_vacia") || hardAspect {
            confidence = "media"
        } else {
            confidence = "alta"
        }
        return (verdict, confidence, mainReason, supporting, blocking)
    }

    private static func renderJudgementText(judgement: HoraryJudgement, chart: HoraryChart) -> String {
        let verdict = renderVerdict(judgement.verdict)
        let supporting = (judgement.supportingFactors ?? []).map { "- \($0)" }.joined(separator: "\n")
        let blocking = (judgement.blockingFactors ?? []).map { "- \($0)" }.joined(separator: "\n")
        let warnings = (judgement.technicalWarnings ?? []).map { "- \($0)" }.joined(separator: "\n")
        let route = judgement.perfectionRoute
        let timing = judgement.timingRange ?? "No hay tiempo claro de resolución."
        return """
        RESUMEN
        \(verdict) · Confianza \(judgement.confidence ?? "media").
        \(judgement.mainReason ?? "La carta requiere lectura prudente.")

        SIGNIFICADORES
        Consultante: \(judgement.significators.querent).
        Quesited: \(judgement.significators.quesited).
        Luna: \(judgement.significators.moon).

        PERFECCION
        Ruta: \(route.kind).
        Aspecto: \(route.aspectName.map(renderAspect) ?? "sin aspecto directo").
        Tiempo: \(timing).

        A FAVOR
        \(supporting.isEmpty ? "- No hay factores favorables dominantes." : supporting)

        EN CONTRA
        \(blocking.isEmpty ? "- No hay bloqueos dominantes." : blocking)

        NOTAS TECNICAS
        \(warnings.isEmpty ? "- Sin advertencias técnicas activas." : warnings)
        """
    }

    private static func parseLocalDate(_ datetimeLocal: String, timezone: String) throws -> Date {
        guard let tz = TimeZone(identifier: timezone) else {
            throw JulianDayError.invalidTimezone(timezone)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let pieces = datetimeLocal.replacingOccurrences(of: "T", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .split(separator: "-")
            .compactMap { Int($0) }
        guard pieces.count >= 5 else { throw JulianDayError.invalidDate(datetimeLocal) }
        var comps = DateComponents()
        comps.year = pieces[0]
        comps.month = pieces[1]
        comps.day = pieces[2]
        comps.hour = pieces[3]
        comps.minute = pieces[4]
        comps.second = pieces.count >= 6 ? pieces[5] : 0
        guard let date = cal.date(from: comps) else { throw JulianDayError.invalidDate(datetimeLocal) }
        return date
    }

    private static func julianDay(_ datetimeLocal: String, timezone: String) throws -> Double {
        let localDate = try parseLocalDate(datetimeLocal, timezone: timezone)
        guard let utc = TimeZone(identifier: "UTC") else { throw JulianDayError.utcUnavailable }
        let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: localDate)
        let hour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60 + Double(comps.second ?? 0) / 3600
        return swe_julday(Int32(comps.year ?? 2000), Int32(comps.month ?? 1), Int32(comps.day ?? 1), hour, SE_GREG_CAL)
    }

    private static func planetaryHourRuler(for date: Date, latitude: Double, longitude: Double, timezone: String) -> String {
        guard let tz = TimeZone(identifier: timezone) else { return "Sol" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let today = sunriseSunset(on: date, latitude: latitude, longitude: longitude, timezone: tz, calendar: cal)
        if date < today.sunrise {
            let yesterdayDate = cal.date(byAdding: .day, value: -1, to: date) ?? date
            let yesterday = sunriseSunset(on: yesterdayDate, latitude: latitude, longitude: longitude, timezone: tz, calendar: cal)
            let duration = today.sunrise.timeIntervalSince(yesterday.sunset) / 12
            let index = max(0, Int(floor(date.timeIntervalSince(yesterday.sunset) / duration)))
            return chaldean(after: firstNightRuler(for: yesterday.sunrise, calendar: cal), steps: index)
        }
        if date < today.sunset {
            let duration = today.sunset.timeIntervalSince(today.sunrise) / 12
            let index = max(0, Int(floor(date.timeIntervalSince(today.sunrise) / duration)))
            return chaldean(after: dayRuler(for: date, calendar: cal), steps: index)
        }
        let tomorrowDate = cal.date(byAdding: .day, value: 1, to: date) ?? date
        let tomorrow = sunriseSunset(on: tomorrowDate, latitude: latitude, longitude: longitude, timezone: tz, calendar: cal)
        let duration = tomorrow.sunrise.timeIntervalSince(today.sunset) / 12
        let index = max(0, Int(floor(date.timeIntervalSince(today.sunset) / duration)))
        return chaldean(after: firstNightRuler(for: today.sunrise, calendar: cal), steps: index)
    }

    private static func sunriseSunset(on date: Date, latitude: Double, longitude: Double, timezone: TimeZone, calendar: Calendar) -> (sunrise: Date, sunset: Date) {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let offsetHours = Double(timezone.secondsFromGMT(for: date)) / 3600
        let gamma = 2.0 * Double.pi / 365.0 * Double(dayOfYear - 1)
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let zenith = 90.833 * Double.pi / 180
        let latRad = latitude * Double.pi / 180
        let cosHA = min(1, max(-1, (cos(zenith) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)))
        let ha = acos(cosHA) * 180 / Double.pi
        let noonMin = 720 - 4 * longitude - eqTime + offsetHours * 60
        let start = calendar.startOfDay(for: date)
        return (
            start.addingTimeInterval((noonMin - ha * 4) * 60),
            start.addingTimeInterval((noonMin + ha * 4) * 60)
        )
    }

    private static func dayRuler(for date: Date, calendar: Calendar) -> String {
        dayRulers[calendar.component(.weekday, from: date)] ?? "Sol"
    }

    private static func firstNightRuler(for date: Date, calendar: Calendar) -> String {
        chaldean(after: dayRuler(for: date, calendar: calendar), steps: 12)
    }

    private static func chaldean(after planet: String, steps: Int) -> String {
        guard let index = chaldeanOrder.firstIndex(of: planet) else { return "Sol" }
        return chaldeanOrder[(index + steps) % chaldeanOrder.count]
    }

    private static func hourAgreement(hourRuler: String, ascRuler: String, ascSign: String) -> Bool {
        if hourRuler == ascRuler { return true }
        if let element = elements[ascSign], let rulers = triplicities[element] {
            let values = Set(rulers.values)
            if values.contains(hourRuler) && values.contains(ascRuler) { return true }
        }
        let nHour = planetaryNature(hourRuler)
        let nAsc = planetaryNature(ascRuler)
        return !nHour.intersection(nAsc).isEmpty
    }

    private static func planetaryNature(_ planet: String) -> Set<String> {
        switch planet {
        case "Sol": return ["caliente", "seco", "diurno"]
        case "Luna": return ["fria", "humeda", "nocturna"]
        case "Mercurio": return ["variable"]
        case "Venus": return ["templada", "humeda", "nocturna", "benefica"]
        case "Marte": return ["caliente", "seco", "malefica"]
        case "Jupiter": return ["caliente", "humedo", "benefica"]
        case "Saturno": return ["fria", "seca", "malefica"]
        default: return []
        }
    }

    private static func cosignifiers(in house: Int, bodies: [String: HoraryBody], dignities: [String: HoraryDignity], excluding: Set<String>) -> [String] {
        bodies.values
            .filter { $0.house == house && planetOrder.contains($0.name) && !excluding.contains($0.name) }
            .sorted {
                let left = dignities[$0.name]?.essentialScore ?? 0
                let right = dignities[$1.name]?.essentialScore ?? 0
                if left != right { return left > right }
                return (dignities[$0.name]?.totalScore ?? 0) > (dignities[$1.name]?.totalScore ?? 0)
            }
            .map(\.name)
    }

    private static func isStrongCosignifier(_ name: String, primary: String, dignities: [String: HoraryDignity]) -> Bool {
        name == primary || (dignities[name]?.essentialScore ?? -99) >= 3
    }

    private static func timingRange(for detail: NativeAspectDetail, faster: HoraryBody?) -> String {
        guard let degrees = detail.degreesToPerfect, let faster else { return "tiempo simbolico condicionado" }
        return timingRange(degrees: degrees, house: faster.house, sign: faster.sign)
    }

    private static func timingRangeFromRoute(_ route: HoraryPerfectionRoute, bodies: [String: HoraryBody]) -> String {
        if route.kind == "translacion" || route.kind == "coleccion" {
            return "tiempo condicionado por mediacion"
        }
        guard let degrees = route.degreesToPerfect,
              let fasterName = route.fasterBody,
              let faster = bodies[fasterName] else {
            return "tiempo simbolico condicionado"
        }
        return timingRange(degrees: degrees, house: faster.house, sign: faster.sign)
    }

    private static func routeConfidence(for detail: NativeAspectDetail, aspectName: String) -> String {
        if detail.perfectsBeforeSignChange == false { return "baja" }
        if aspectName == "cuadratura" || aspectName == "oposicion" { return "media" }
        return "alta"
    }

    private static func timingRange(degrees: Double, house: Int, sign: String) -> String {
        let type = houseType(house)
        let modality = modalities[sign] ?? "mutable"
        let unit: String
        switch (type, modality) {
        case ("angular", "cardinal"): unit = "dias"
        case ("angular", "fijo"): unit = "meses"
        case ("angular", "mutable"): unit = "semanas"
        case ("sucedente", "cardinal"): unit = "semanas"
        case ("sucedente", "fijo"): unit = "meses"
        case ("sucedente", "mutable"): unit = "meses"
        case ("cadente", "cardinal"): unit = "meses"
        case ("cadente", "fijo"): unit = "anos"
        default: unit = "meses"
        }
        let rounded = max(1, Int(degrees.rounded()))
        return "aprox. \(rounded) \(unit)"
    }

    private static func houseType(_ house: Int) -> String {
        if [1, 4, 7, 10].contains(house) { return "angular" }
        if [2, 5, 8, 11].contains(house) { return "sucedente" }
        return "cadente"
    }

    private static func termRuler(sign: String, degree: Double) -> String? {
        egyptianTerms[sign]?.first(where: { degree < $0.0 })?.1
    }

    private static func decanRuler(sign: String, degree: Double) -> String? {
        decans[sign]?[min(Int(degree / 10), 2)]
    }

    private static func detrimentRuler(sign: String) -> String? {
        guard let index = signs.firstIndex(of: sign) else { return nil }
        return rulerships[signs[(index + 6) % 12]]
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func normalize(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    private static func signName(_ longitude: Double) -> String {
        signs[min(11, max(0, Int(normalize(longitude) / 30)))]
    }

    private static func degreeInSign(_ longitude: Double) -> Double {
        normalize(longitude).truncatingRemainder(dividingBy: 30)
    }

    private static func angularDistance(_ a: Double, _ b: Double) -> Double {
        abs(normalize(a - b + 180) - 180)
    }

    private static func renderAspect(_ aspect: String) -> String {
        switch aspect {
        case "conjuncion": return "conjunción"
        case "trigono": return "trígono"
        case "oposicion": return "oposición"
        default: return aspect
        }
    }

    private static func renderVerdict(_ verdict: String?) -> String {
        switch verdict {
        case "si": return "Sí"
        case "no": return "No"
        case "no_todavia": return "No todavía"
        case "requiere_mediacion": return "Requiere mediación o ajuste"
        case "dudoso": return "Dudoso"
        default: return "Juicio prudente"
        }
    }
}
