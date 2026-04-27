import Foundation
import CSwissEph

// MARK: - Primary Direction Calculator

/// Motor de cálculo de Direcciones Primarias.
/// Proyección Regiomontana (default). No usa ninguna dependencia externa.
/// Port del algoritmo de Morinus (regiomontanpd.py / regiospec.py / primdirs.py).
///
/// Patrón nonisolated: todas las funciones son puras, sin estado compartido.
/// El caller es responsable de ejecutar en Task.detached para no bloquear MainActor.
final class PrimaryDirectionCalculator: Sendable {

    // MARK: - Configuration

    struct Config: Sendable {
        /// Método de proyección (Regiomontanus o Placidus)
        let method: PrimaryDirectionMethod

        /// Clave de conversión arco → tiempo
        let key: PrimaryDirectionKey

        /// Velocidad solar natal (°/día) — requerida si key == .brahe
        let natalSolarSpeed: Double?

        /// Rango máximo en años (default 120)
        let maxYears: Double

        /// Aspectos a considerar
        let aspects: [PDaspect]

        /// Prómissores: planetas e hylegíacos
        let promissors: [String]

        /// Significadores
        let significators: [PDSignificator]

        /// Incluir direcciones conversas
        let includeConverse: Bool

        /// Plano de aspecto
        let aspectPlane: PDAspectPlane

        init(
            method: PrimaryDirectionMethod = .regiomontanus,
            key: PrimaryDirectionKey = .naibod,
            natalSolarSpeed: Double? = nil,
            maxYears: Double = 120,
            aspects: [PDaspect] = PDaspect.allCases,
            promissors: [String] = [],
            significators: [PDSignificator] = [],
            includeConverse: Bool = true,
            aspectPlane: PDAspectPlane = .zodiacal
        ) {
            self.method = method
            self.key = key
            self.natalSolarSpeed = natalSolarSpeed
            self.maxYears = maxYears
            self.aspects = aspects
            self.promissors = promissors.isEmpty
                ? PLANET_LIST.map(\.key) + ["ASC", "MC"]
                : promissors
            self.significators = significators.isEmpty
                ? Self.defaultSignificators(for: aspectPlane)
                : significators
            self.includeConverse = includeConverse
            self.aspectPlane = aspectPlane
        }

        private static func defaultSignificators(for plane: PDAspectPlane) -> [PDSignificator] {
            if plane == .ecliptic {
                return [.asc, .dsc, .mc, .ic, .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]
            }
            return [.asc, .mc, .sun, .moon]
        }
    }

    // MARK: - Internal Types

    /// Datos ecuatoriales de un cuerpo celeste
    struct EquatorialBody: Sendable {
        let key: String
        let label: String
        let longitude: Double          // ° eclíptica
        let latitude: Double           // ° eclíptica
        let ra: Double                 // ° ecuador
        let declination: Double        // °
        let speed: Double              // °/día (para key Brahe)
    }

    // MARK: - Main Calculation

    /// Calcula todas las direcciones primarias para una carta natal.
    /// - Parameters:
    ///   - chart: Carta natal con planetas, casas, ASC, MC
    ///   - jd: Día juliano del nacimiento
    ///   - config: Configuración del cálculo
    /// - Returns: Array de direcciones primarias calculadas, ordenadas por arco
    func calculate(
        chart: NatalChart,
        jd: Double,
        birthDate: Date,
        config: Config
    ) -> [PrimaryDirection] {

        // 1. Obtener oblicuidad de la eclíptica
        let obliquity = getObliquity(jd: jd)

        // 2. Obtener RAMC (Right Ascension of Medium Coeli)
        let ramc = getRamc(jd: jd, lon: chart.longitude)

        // 3. Calcular coordenadas ecuatoriales de todos los cuerpos
        let bodies = computeEquatorialBodies(chart: chart, jd: jd, obliquity: obliquity)

        // 4. Grados por año para la clave seleccionada
        let degreesPerYear = resolveDegreesPerYear(config: config, bodies: bodies)
        guard degreesPerYear > 0 else { return [] }

        // 5. Arco máximo
        let maxArc = config.maxYears * degreesPerYear

        // 6. Generar todas las direcciones
        var directions: [PrimaryDirection] = []

        for sig in config.significators {
            guard let sigBody = resolveSignificatorBody(
                sig, bodies: bodies, chart: chart, obliquity: obliquity, ramc: ramc
            ) else { continue }

            let sigSpec = RegiomontanusSpeculum(
                placelat: chart.latitude, ramc: ramc,
                lon: sigBody.longitude, lat: sigBody.latitude,
                ra: sigBody.ra, decl: sigBody.declination
            )

            for promKey in config.promissors {
                // Skip auto-direction (planet to itself at conjunction)
                if promKey == sig.rawValue { continue }

                guard let promBody = resolvePromissorBody(
                    promKey, bodies: bodies, chart: chart, obliquity: obliquity, ramc: ramc
                ) else { continue }

                for aspect in config.aspects {
                    // Skip opposition for ASC↔DSC, MC↔IC (redundant)
                    if aspect == .opposition && (sig.rawValue == "ASC" || sig.rawValue == "MC") {
                        continue
                    }

                    // Calculate direct direction
                    let directArcs = calculateDirectionArc(
                        promissor: promBody,
                        significator: sigBody,
                        sigSpeculum: sigSpec,
                        aspect: aspect,
                        placelat: chart.latitude,
                        ramc: ramc,
                        obliquity: obliquity,
                        plane: config.aspectPlane
                    )

                    for arc in directArcs {
                        if abs(arc) > maxArc || abs(arc) < 0.001 { continue }

                        let age = abs(arc) / degreesPerYear
                        let estimatedDate = Calendar.current.date(
                            byAdding: .day,
                            value: Int(age * 365.25),
                            to: birthDate
                        ) ?? birthDate

                        let pd = PrimaryDirection(
                            promissor: promKey,
                            promissorLabel: promBody.label,
                            significator: sig.rawValue,
                            significatorLabel: sig.label,
                            aspect: aspect,
                            aspectAngle: aspect.angle,
                            directionType: arc > 0 ? .direct : .converse,
                            aspectPlane: config.aspectPlane,
                            arc: arc,
                            estimatedAge: age,
                            estimatedDate: estimatedDate,
                            method: config.method,
                            key: config.key,
                            technicalData: PDTechnicalData(
                                promissorRA: promBody.ra,
                                promissorDeclination: promBody.declination,
                                significatorRA: sigBody.ra,
                                significatorDeclination: sigBody.declination,
                                significatorPole: sigSpec.pole,
                                obliquity: obliquity,
                                ramc: ramc,
                                geoLatitude: chart.latitude
                            )
                        )
                        directions.append(pd)
                    }
                }
            }
        }

        return directions.sorted { abs($0.arc) < abs($1.arc) }
    }

    // MARK: - Directional Arc Calculation (Core Algorithm)

    /// Calcula el arco direccional entre prómissor y significador.
    /// Devuelve hasta 2 arcos (siniestro y diestro) para aspectos no simétricos.
    /// Port exacto de regiomontanpd.py → toPlanet() (mundane branch for conjunctions).
    private func calculateDirectionArc(
        promissor: EquatorialBody,
        significator: EquatorialBody,
        sigSpeculum: RegiomontanusSpeculum,
        aspect: PDaspect,
        placelat: Double,
        ramc: Double,
        obliquity: Double,
        plane: PDAspectPlane
    ) -> [Double] {

        var results: [Double] = []
        let raic = RegiomontanusSpeculum.normalize(ramc + 180)

        // For conjunction and opposition, only one direction
        // For others, calculate both sinister and dexter
        let aspectAngles: [Double]
        if aspect == .conjunction || aspect == .opposition {
            aspectAngles = [aspect.angle]
        } else {
            aspectAngles = [aspect.angle, -aspect.angle]
        }

        for aspAngle in aspectAngles {
            if plane == .ecliptic {
                let targetLongitude = RegiomontanusSpeculum.normalize(significator.longitude + aspAngle)
                var arc = targetLongitude - promissor.longitude
                if arc < 0 { arc += 360 }
                if arc > 180 { arc -= 360 }
                results.append(arc)
            } else if plane == .mundane {
                // --- MUNDANE DIRECTIONS ---
                // Significator's W is its equatorial position
                let wsig = sigSpeculum.w

                if aspect == .conjunction {
                    // Promissor must come to the same pole as significator
                    let val = tan(promissor.declination * .pi / 180) *
                              tan(sigSpeculum.pole * .pi / 180)
                    guard abs(val) <= 1.0 else { continue }
                    let qprom = asin(val) * 180 / .pi

                    let wprom: Double
                    if sigSpeculum.eastern {
                        wprom = RegiomontanusSpeculum.normalize(promissor.ra - qprom)
                    } else {
                        wprom = RegiomontanusSpeculum.normalize(promissor.ra + qprom)
                    }

                    results.append(wprom - wsig)
                } else {
                    // Mundane aspect: rotate sig's W by aspect, then project promissor
                    let wsigAspected = RegiomontanusSpeculum.normalize(wsig + aspAngle)

                    // Calculate the MD of the aspected point
                    var med2 = abs(ramc - wsigAspected)
                    if med2 > 180 { med2 = 360 - med2 }
                    var icd2 = abs(raic - wsigAspected)
                    if icd2 > 180 { icd2 = 360 - icd2 }
                    let mdsig = min(med2, icd2)

                    let val = tan(promissor.declination * .pi / 180) *
                              tan(placelat * .pi / 180) *
                              sin(mdsig * .pi / 180)
                    guard abs(val) <= 1.0 else { continue }
                    let qprom = asin(val) * 180 / .pi

                    // Determine eastern/western for the aspected point
                    var eastern2 = true
                    if ramc > raic {
                        if wsigAspected > raic && wsigAspected < ramc { eastern2 = false }
                    } else {
                        if (wsigAspected > raic && wsigAspected < 360) ||
                           (wsigAspected < ramc && wsigAspected > 0) { eastern2 = false }
                    }

                    let wprom: Double
                    if eastern2 {
                        wprom = RegiomontanusSpeculum.normalize(promissor.ra - qprom)
                    } else {
                        wprom = RegiomontanusSpeculum.normalize(promissor.ra + qprom)
                    }

                    results.append(wprom - wsigAspected)
                }

            } else {
                // --- ZODIACAL DIRECTIONS ---
                // Apply aspect to significator's ecliptic longitude
                let lonsig = RegiomontanusSpeculum.normalize(significator.longitude + aspAngle)

                // Get W of the significator at aspected position (no latitude for zodiacal)
                guard let (wsig, spole, seastern) = getZodiacalW(
                    lon: lonsig, lat: 0.0,
                    placelat: placelat, ramc: ramc, obliquity: obliquity,
                    referencePole: nil, referenceEastern: nil
                ) else { continue }

                // Get W of the promissor under the same pole
                guard let (wprom, _, _) = getZodiacalW(
                    lon: promissor.longitude, lat: promissor.latitude,
                    placelat: placelat, ramc: ramc, obliquity: obliquity,
                    referencePole: spole, referenceEastern: seastern
                ) else { continue }

                results.append(wprom - wsig)
            }
        }

        return results
    }

    // MARK: - Zodiacal W Calculation

    /// Calcula W zodiacal para una posición eclíptica dada.
    /// Port de regiocampbasepd.py → getZodW()
    /// - Returns: (W, pole, eastern) o nil si el cálculo es imposible
    private func getZodiacalW(
        lon: Double,
        lat: Double,
        placelat: Double,
        ramc: Double,
        obliquity: Double,
        referencePole: Double?,
        referenceEastern: Bool?
    ) -> (w: Double, pole: Double, eastern: Bool)? {

        // Convert ecliptic → equatorial
        let (raConverted, declConverted) = eclipticToEquatorial(
            lon: lon, lat: lat, obliquity: obliquity
        )

        let raic = RegiomontanusSpeculum.normalize(ramc + 180)

        // Determine eastern
        var eastern = true
        if ramc > raic {
            if raConverted > raic && raConverted < ramc { eastern = false }
        } else {
            if (raConverted > raic && raConverted < 360) ||
               (raConverted < ramc && raConverted > 0) { eastern = false }
        }

        // If we have a reference, use the reference eastern
        if let refEastern = referenceEastern {
            eastern = refEastern
        }

        // Meridian distance
        var med = abs(ramc - raConverted)
        if med > 180 { med = 360 - med }
        var icd = abs(raic - raConverted)
        if icd > 180 { icd = 360 - icd }

        let md = min(med, icd)
        let umd = (med <= icd)

        // Zenith distance
        let zd = RegiomontanusSpeculum.calcZD(md: md, placelat: placelat, decl: declConverted, umd: umd)
        let tmpZD = abs(zd) > 90 ? 180 - abs(zd) : abs(zd)

        // Pole
        let pole: Double
        if let refPole = referencePole {
            pole = refPole
        } else {
            let poleVal = sin(placelat * .pi / 180) * sin(tmpZD * .pi / 180)
            guard abs(poleVal) <= 1.0 else { return nil }
            pole = asin(poleVal) * 180 / .pi
        }

        // Q
        let qVal = tan(declConverted * .pi / 180) * tan(pole * .pi / 180)
        guard abs(qVal) <= 1.0 else { return nil }
        let q = asin(qVal) * 180 / .pi

        // W
        let w: Double
        if eastern {
            w = RegiomontanusSpeculum.normalize(raConverted - q)
        } else {
            w = RegiomontanusSpeculum.normalize(raConverted + q)
        }

        return (w, pole, eastern)
    }

    // MARK: - Coordinate Conversion

    /// Convierte coordenadas eclípticas a ecuatoriales usando swe_cotrans.
    func eclipticToEquatorial(lon: Double, lat: Double, obliquity: Double) -> (ra: Double, decl: Double) {
        var xin = [Double](repeating: 0, count: 3)
        var xout = [Double](repeating: 0, count: 3)
        xin[0] = lon
        xin[1] = lat
        xin[2] = 1.0
        swe_cotrans(&xin, &xout, -obliquity)
        return (xout[0], xout[1])
    }

    // MARK: - Swiss Ephemeris Helpers

    /// Obtiene oblicuidad de la eclíptica para un JD dado.
    func getObliquity(jd: Double) -> Double {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        // SE_ECL_NUT returns nutation and obliquity
        swe_calc_ut(jd, SE_ECL_NUT, 0, &xx, &serr)
        return xx[0]  // true obliquity
    }

    /// Obtiene RAMC (Right Ascension of MC) para un JD y longitud geográfica.
    func getRamc(jd: Double, lon: Double) -> Double {
        // RAMC = Sidereal Time * 15 at the given geographic longitude
        let siderealTime = swe_sidtime(jd) // hours at Greenwich
        let ramc = RegiomontanusSpeculum.normalize(siderealTime * 15.0 + lon)
        return ramc
    }

    // MARK: - Body Resolution

    /// Calcula coordenadas ecuatoriales para todos los cuerpos de la carta.
    func computeEquatorialBodies(
        chart: NatalChart,
        jd: Double,
        obliquity: Double
    ) -> [String: EquatorialBody] {

        var result: [String: EquatorialBody] = [:]

        for planet in PLANET_LIST {
            var xx = [Double](repeating: 0, count: 6)
            var serr = [CChar](repeating: 0, count: 256)
            let flags: Int32 = SEFLG_SPEED
            let rc = swe_calc_ut(jd, planet.id, flags, &xx, &serr)
            guard rc >= 0 else { continue }

            let lon = xx[0]
            let lat = xx[1]
            let speed = xx[3]

            // Convert to equatorial
            let (ra, decl) = eclipticToEquatorial(lon: lon, lat: lat, obliquity: obliquity)

            result[planet.key] = EquatorialBody(
                key: planet.key,
                label: planet.label,
                longitude: lon,
                latitude: lat,
                ra: ra,
                declination: decl,
                speed: speed
            )
        }

        // ASC and MC as special bodies (0° latitude)
        let (ascRA, ascDecl) = eclipticToEquatorial(
            lon: chart.ascendant.longitude, lat: 0, obliquity: obliquity
        )
        result["ASC"] = EquatorialBody(
            key: "ASC", label: "ASC",
            longitude: chart.ascendant.longitude, latitude: 0,
            ra: ascRA, declination: ascDecl, speed: 0
        )

        let (mcRA, mcDecl) = eclipticToEquatorial(
            lon: chart.mc.longitude, lat: 0, obliquity: obliquity
        )
        result["MC"] = EquatorialBody(
            key: "MC", label: "MC",
            longitude: chart.mc.longitude, latitude: 0,
            ra: mcRA, declination: mcDecl, speed: 0
        )

        // DSC and IC for completeness
        let dscLon = RegiomontanusSpeculum.normalize(chart.ascendant.longitude + 180)
        let (dscRA, dscDecl) = eclipticToEquatorial(lon: dscLon, lat: 0, obliquity: obliquity)
        result["DSC"] = EquatorialBody(
            key: "DSC", label: "DSC",
            longitude: dscLon, latitude: 0,
            ra: dscRA, declination: dscDecl, speed: 0
        )

        let icLon = RegiomontanusSpeculum.normalize(chart.mc.longitude + 180)
        let (icRA, icDecl) = eclipticToEquatorial(lon: icLon, lat: 0, obliquity: obliquity)
        result["IC"] = EquatorialBody(
            key: "IC", label: "IC",
            longitude: icLon, latitude: 0,
            ra: icRA, declination: icDecl, speed: 0
        )

        return result
    }

    /// Calcula espéculos Regiomontanos para todos los cuerpos.
    func computeSpeculums(
        bodies: [String: EquatorialBody],
        placelat: Double,
        ramc: Double
    ) -> [String: RegiomontanusSpeculum] {

        var result: [String: RegiomontanusSpeculum] = [:]
        for (key, body) in bodies {
            result[key] = RegiomontanusSpeculum(
                placelat: placelat, ramc: ramc,
                lon: body.longitude, lat: body.latitude,
                ra: body.ra, decl: body.declination
            )
        }
        return result
    }

    /// Resuelve un significador a su EquatorialBody.
    private func resolveSignificatorBody(
        _ sig: PDSignificator,
        bodies: [String: EquatorialBody],
        chart: NatalChart,
        obliquity: Double,
        ramc: Double
    ) -> EquatorialBody? {
        switch sig {
        case .asc:
            return bodies["ASC"]
        case .dsc:
            return bodies["DSC"]
        case .mc:
            return bodies["MC"]
        case .ic:
            return bodies["IC"]
        case .sun:
            return bodies["SOL"]
        case .moon:
            return bodies["LUNA"]
        case .mercury:
            return bodies["MERCURIO"]
        case .venus:
            return bodies["VENUS"]
        case .mars:
            return bodies["MARTE"]
        case .jupiter:
            return bodies["JUPITER"]
        case .saturn:
            return bodies["SATURNO"]
        case .uranus:
            return bodies["URANO"]
        case .neptune:
            return bodies["NEPTUNO"]
        case .pluto:
            return bodies["PLUTON"]
        case .partOfFortune:
            // Pars Fortunae = ASC + Luna - Sol (diurna) / ASC + Sol - Luna (nocturna)
            guard let sol = bodies["SOL"], let luna = bodies["LUNA"] else { return nil }
            let ascLon = chart.ascendant.longitude
            let solLon = sol.longitude
            let lunaLon = luna.longitude

            // Determine sect: diurnal if Sun above horizon
            let solSpec = RegiomontanusSpeculum(
                placelat: chart.latitude, ramc: ramc,
                lon: solLon, lat: sol.latitude, ra: sol.ra, decl: sol.declination
            )
            let isDiurnal = solSpec.aboveHorizon

            let fortuneLon: Double
            if isDiurnal {
                fortuneLon = RegiomontanusSpeculum.normalize(ascLon + lunaLon - solLon)
            } else {
                fortuneLon = RegiomontanusSpeculum.normalize(ascLon + solLon - lunaLon)
            }

            let (fRA, fDecl) = eclipticToEquatorial(lon: fortuneLon, lat: 0, obliquity: obliquity)
            return EquatorialBody(
                key: "PARTFORTUNA", label: "⊗ Parte de Fortuna",
                longitude: fortuneLon, latitude: 0,
                ra: fRA, declination: fDecl, speed: 0
            )
        }
    }

    /// Resuelve un prómissor key a su EquatorialBody.
    private func resolvePromissorBody(
        _ key: String,
        bodies: [String: EquatorialBody],
        chart: NatalChart,
        obliquity: Double,
        ramc: Double
    ) -> EquatorialBody? {
        return bodies[key]
    }

    /// Resuelve grados por año según la clave.
    private func resolveDegreesPerYear(
        config: Config,
        bodies: [String: EquatorialBody]
    ) -> Double {
        switch config.key {
        case .naibod:
            return config.key.degreesPerYear!
        case .ptolemy:
            return config.key.degreesPerYear!
        case .brahe:
            if let speed = config.natalSolarSpeed {
                return speed  // °/day solar speed as °/year for directions
            } else if let sol = bodies["SOL"] {
                return sol.speed  // fallback to computed solar speed
            }
            return 0.98564722  // ultimate fallback: Naibod
        }
    }
}
