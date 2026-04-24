import Foundation
import CSwissEph

// MARK: - AstroEngine
// Porta astro_core.py: cálculo natal con Swiss Ephemeris C library.
// Sistema de casas Placidus. Motor idéntico al de AstroBot original.

// MARK: - Constants

let PLANET_LIST: [(id: Int32, label: String, key: String)] = [
    (SE_SUN,     "☉ Sol",        "SOL"),
    (SE_MOON,    "☽ Luna",       "LUNA"),
    (SE_MERCURY, "☿ Mercurio",   "MERCURIO"),
    (SE_VENUS,   "♀ Venus",      "VENUS"),
    (SE_MARS,    "♂ Marte",      "MARTE"),
    (SE_JUPITER, "♃ Júpiter",    "JUPITER"),
    (SE_SATURN,  "♄ Saturno",    "SATURNO"),
    (SE_URANUS,  "⛢ Urano",      "URANO"),
    (SE_NEPTUNE, "♆ Neptuno",    "NEPTUNO"),
    (SE_PLUTO,   "♇ Plutón",     "PLUTON"),
]

let OUTER_PLANETS: Set<String> = ["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON", "MARTE"]

let SIGN_LABELS = [
    "♈ Aries", "♉ Tauro", "♊ Géminis", "♋ Cáncer",
    "♌ Leo",   "♍ Virgo", "♎ Libra",   "♏ Escorpio",
    "♐ Sagitario", "♑ Capricornio", "♒ Acuario", "♓ Piscis",
]

let SIGN_KEYS = [
    "ARIES", "TAURO", "GEMINIS", "CANCER", "LEO", "VIRGO",
    "LIBRA", "ESCORPIO", "SAGITARIO", "CAPRICORNIO", "ACUARIO", "PISCIS",
]

struct AspectDef {
    let angle: Double
    let label: String
    let key: String
    let orb: Double
}

let ASPECT_DEFS: [AspectDef] = [
    AspectDef(angle: 0,   label: "☌ Conjunción", key: "CONJUNCION", orb: 8),
    AspectDef(angle: 60,  label: "⚹ Sextil",     key: "SEXTIL",     orb: 5),
    AspectDef(angle: 90,  label: "□ Cuadratura",  key: "CUADRADO",   orb: 7),
    AspectDef(angle: 120, label: "△ Trígono",     key: "TRIGONO",    orb: 7),
    AspectDef(angle: 180, label: "☍ Oposición",   key: "OPOSICION",  orb: 8),
]

// MARK: - Engine

final class AstroEngine {

    // Configurar ruta de efemérides (llamar al inicio de la app)
    static func configure(ephePath: String? = nil) {
        if let path = ephePath {
            swe_set_ephe_path(UnsafeMutablePointer<CChar>(mutating: (path as NSString).utf8String))
        } else {
            swe_set_ephe_path(nil)
        }
    }

    /// Formatea grados a "♈ Aries 12°34'"
    static func degToSign(_ deg: Double) -> String {
        let d = deg.truncatingRemainder(dividingBy: 360)
        let signIdx = Int(d / 30)
        let inSign  = d.truncatingRemainder(dividingBy: 30)
        let intDeg  = Int(inSign)
        let intMin  = Int((inSign - Double(intDeg)) * 60)
        let sign    = SIGN_LABELS[max(0, min(11, signIdx))]
        return "\(sign) \(String(format: "%02d", intDeg))°\(String(format: "%02d", intMin))'"
    }

    /// Devuelve la clave de signo para corpus ("ARIES", "TAURO"…)
    static func degToSignKey(_ deg: Double) -> String {
        let idx = Int(deg.truncatingRemainder(dividingBy: 360) / 30)
        return SIGN_KEYS[max(0, min(11, idx))]
    }

    // MARK: Planets

    struct RawPlanet {
        var key: String
        var label: String
        var deg: Double
        var speed: Double
        var retro: Bool
    }

    static func calcPlanets(jd: Double) throws -> [String: RawPlanet] {
        var result: [String: RawPlanet] = [:]
        for planet in PLANET_LIST {
            var xx = [Double](repeating: 0, count: 6)
            var serr = [CChar](repeating: 0, count: 256)
            let rc = swe_calc_ut(jd, planet.id, SEFLG_SPEED, &xx, &serr)
            if rc < 0 {
                let err = String(cString: serr)
                throw AstroError.calcFailed(planet.key, err)
            }
            let retro = xx[3] < 0
            result[planet.key] = RawPlanet(
                key: planet.key,
                label: planet.label,
                deg: xx[0],
                speed: xx[3],
                retro: retro
            )
        }
        return result
    }

    // MARK: Houses

    static func calcHouses(
        jd: Double, lat: Double, lon: Double, system: Character = "P"
    ) throws -> (cusps: [Double], asc: Double, mc: Double) {
        var cusps  = [Double](repeating: 0, count: 13)   // [0] unused, [1..12]
        var ascmc  = [Double](repeating: 0, count: 10)
        var cuspSpeeds = [Double](repeating: 0, count: 13)
        var ascmcSpeeds = [Double](repeating: 0, count: 10)
        var serr = [CChar](repeating: 0, count: 256)
        let hsys   = Int32(system.asciiValue ?? 80)       // 'P' = 80
        let rc = swe_houses_ex2(jd, 0, lat, lon, hsys, &cusps, &ascmc, &cuspSpeeds, &ascmcSpeeds, &serr)
        guard rc >= 0 else {
            let message = String(cString: serr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw AstroError.housesUnavailable(message.isEmpty ? "Swiss Ephemeris no devolvió casas." : message)
        }
        return (
            Array(cusps[1...12]),   // grados de las 12 cúspides
            ascmc[0],               // ASC
            ascmc[1]                // MC
        )
    }

    /// Equivale al bucle de casas en astrobot.py (cmd_carta)
    static func planetHouse(deg: Double, cusps: [Double]) -> Int {
        var d = deg.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        for i in 0..<12 {
            let cs = cusps[i]
            let ce = cusps[(i + 1) % 12]
            if ce < cs {
                if d >= cs || d < ce { return i + 1 }
            } else {
                if cs <= d && d < ce { return i + 1 }
            }
        }
        return 1
    }

    // MARK: Aspects

    static func findAspects(
        from aMap: [String: RawPlanet],
        to bMap: [String: RawPlanet],
        outerOnly: Bool = false
    ) -> [TransitAspectRaw] {
        var found: [TransitAspectRaw] = []
        for (trKey, trData) in bMap {
            if outerOnly && !OUTER_PLANETS.contains(trKey) { continue }
            for (nKey, nData) in aMap {
                let diff = angularDiff(trData.deg, nData.deg)
                for asp in ASPECT_DEFS {
                    let orb = abs(diff - asp.angle)
                    if orb <= asp.orb {
                        found.append(TransitAspectRaw(
                            trKey: trKey, trLabel: trData.label + (trData.retro ? " ℞" : ""),
                            nKey: nKey, nLabel: nData.label,
                            aspKey: asp.key, aspLabel: asp.label,
                            orb: orb, exactDeg: diff
                        ))
                    }
                }
            }
        }
        return found.sorted { $0.orb < $1.orb }
    }

    static func computeNatalAspects(planets: [String: RawPlanet]) -> [NatalAspect] {
        let keys = PLANET_LIST.map { $0.key }
        var found: [NatalAspect] = []
        for i in 0..<keys.count {
            for j in (i+1)..<keys.count {
                let ka = keys[i]; let kb = keys[j]
                guard let pa = planets[ka], let pb = planets[kb] else { continue }
                let diff = angularDiff(pa.deg, pb.deg)
                for asp in ASPECT_DEFS {
                    let orb = abs(diff - asp.angle)
                    if orb <= asp.orb {
                        found.append(NatalAspect(
                            keyA: ka, labelA: pa.label,
                            keyB: kb, labelB: pb.label,
                            aspLabel: asp.label,
                            aspKey: asp.key,
                            orb: (orb * 100).rounded() / 100,
                            corpusClave: "\(ka)_\(kb)_\(asp.key)"
                        ))
                    }
                }
            }
        }
        return found.sorted { $0.orb < $1.orb }
    }

    // MARK: Natal Chart

    static func computeNatalChart(
        jd: Double, lat: Double, lon: Double
    ) throws -> NatalChart {
        let rawPlanets = try calcPlanets(jd: jd)
        let (cusps, asc, mc) = try calcHouses(jd: jd, lat: lat, lon: lon, system: "P")

        var bodies: [PlanetBody] = []
        for planet in PLANET_LIST {
            guard let rp = rawPlanets[planet.key] else { continue }
            let house = planetHouse(deg: rp.deg, cusps: cusps)
            bodies.append(PlanetBody(
                key: planet.key,
                label: planet.label,
                longitude: rp.deg,
                formatted: degToSign(rp.deg),
                house: house,
                retrograde: rp.retro
            ))
        }

        return NatalChart(
            name: "",
            birthDate: "", birthTime: "", timezone: "",
            latitude: lat, longitude: lon, placeName: "",
            ascendant: AngularPoint(longitude: asc.truncatingRemainder(dividingBy: 360),
                                    formatted: degToSign(asc)),
            mc: AngularPoint(longitude: mc.truncatingRemainder(dividingBy: 360),
                             formatted: degToSign(mc)),
            cusps: cusps.map { $0.truncatingRemainder(dividingBy: 360) },
            bodies: bodies
        )
    }

    // MARK: Helpers

    private static func angularDiff(_ a: Double, _ b: Double) -> Double {
        var diff = abs((a - b + 360).truncatingRemainder(dividingBy: 360))
        if diff > 180 { diff = 360 - diff }
        return diff
    }
}

// MARK: - Supporting Types

struct TransitAspectRaw {
    var trKey: String
    var trLabel: String
    var nKey: String
    var nLabel: String
    var aspKey: String
    var aspLabel: String
    var orb: Double
    var exactDeg: Double
}

// MARK: - Error

enum AstroError: LocalizedError {
    case calcFailed(String, String)
    case housesUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .calcFailed(let planet, let msg): return "Error calculando \(planet): \(msg)"
        case .housesUnavailable(let msg): return "No se pudieron calcular las casas: \(msg)"
        }
    }
}
