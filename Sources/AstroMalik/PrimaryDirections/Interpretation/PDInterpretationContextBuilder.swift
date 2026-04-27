import Foundation

// MARK: - PDInterpretationContextBuilder
// Construye PDInterpretationContext automáticamente desde NatalChart + PrimaryDirection.
// Evalúa los 6 factores moduladores morinistas sin requerir entrada manual.

enum PDInterpretationContextBuilder {

    // MARK: - Primary API

    /// Construye el contexto completo para el intérprete LLM.
    /// - Parameters:
    ///   - chart: Carta natal del nativo.
    ///   - direction: Dirección primaria a interpretar.
    ///   - currentDate: Fecha actual (para calcular edad del nativo).
    ///   - profectionYear: Año de profección (nil = calculado automáticamente).
    static func build(
        chart: NatalChart,
        direction: PrimaryDirection,
        currentDate: Date = Date(),
        profectionYear: Int? = nil
    ) -> PDInterpretationContext {
        // 1. Determinar sect de la carta
        let sunBody = chart.bodies.first(where: { $0.key == "SOL" })
        let isDiurnal = sunBody.map { EssentialDignityEngine.isDiurnal(sunHouse: $0.house) } ?? true

        // 2. Planeta promissor: buscar en los bodies de la carta
        let promissorBody = chart.bodies.first(where: { $0.key == direction.promissor })
        let promissorLon = promissorBody?.longitude

        // 3. Dignidad esencial del promissor
        let essentialDignity: String?
        if let lon = promissorLon {
            essentialDignity = EssentialDignityEngine.description(
                planet: direction.promissor,
                longitude: lon
            )
        } else {
            essentialDignity = nil
        }

        // 4. Sect del promissor
        let promissorInSect = EssentialDignityEngine.isInSect(
            planet: direction.promissor,
            isDiurnal: isDiurnal
        )

        // 5. Casa natal del promissor
        let promissorHouse = promissorBody?.house

        // 6. Aspecto natal entre promissor y significador
        let natalAspect = findNatalAspect(
            chart: chart,
            promissor: direction.promissor,
            significator: direction.significator
        )

        // 7. Condición del significador
        let significatorCondition = buildSignificatorCondition(
            chart: chart,
            significator: direction.significator,
            isDiurnal: isDiurnal
        )

        // 8. Edad actual del nativo
        let birthDate = parseDate(chart.birthDate, timezone: chart.timezone)
        let nativeCurrentAge = birthDate.map { ageFrom(birth: $0, to: currentDate) }

        // 9. Año de nacimiento
        let birthYear = birthDate.map { Calendar.current.component(.year, from: $0) }

        // 10. Profección del año (activa contexto adicional para la dirección)
        let profection = buildProfectionInfo(
            chart: chart,
            direction: direction,
            profectionYear: profectionYear
        )

        // 11. Recepciones mutuas entre promissor y significador
        let mutualReception = checkMutualReception(
            chart: chart,
            promissor: direction.promissor,
            significator: direction.significator
        )

        // 12. Dignidades accidentales del promissor
        let accidentalFactors = buildAccidentalFactors(
            chart: chart,
            promissor: direction.promissor,
            isDiurnal: isDiurnal
        )

        // Combinar condición del significador con recepción mutua
        var fullSignificatorCondition = significatorCondition
        if let mr = mutualReception {
            let suffix = " | Recepción mutua por domicilio con \(mr)"
            fullSignificatorCondition = (fullSignificatorCondition ?? "") + suffix
        }
        if let acc = accidentalFactors, !acc.isEmpty {
            let prefix = (essentialDignity ?? "") + " | accidental: \(acc)"
            _ = prefix // usado abajo vía dignityWithAccidental
        }

        // Dignidad completa (esencial + accidental)
        var finalDignity = essentialDignity
        if let acc = accidentalFactors, !acc.isEmpty {
            finalDignity = [(essentialDignity ?? "peregrino"), "accidental: \(acc)"]
                .filter { !$0.isEmpty }.joined(separator: " | ")
        }

        // Profección appended to significator condition
        if let prof = profection {
            let suffix = " | Profección año \(prof.year): signo \(prof.signName), señor \(prof.lord)"
            fullSignificatorCondition = (fullSignificatorCondition ?? "") + suffix
        }

        return PDInterpretationContext(
            promissorDignity: finalDignity,
            promissorNatalHouse: promissorHouse,
            natalAspectBetweenPromissorAndSignificator: natalAspect,
            isNocturnal: !isDiurnal,
            promissorInSect: promissorInSect,
            significatorCondition: fullSignificatorCondition,
            nativeCurrentAge: nativeCurrentAge,
            birthYear: birthYear
        )
    }

    // MARK: - Profection

    struct ProfectionInfo: Sendable {
        let year: Int           // Año de profección (edad)
        let signIndex: Int      // Signo activado
        let signName: String    // Nombre del signo
        let lord: String        // Señor del año (regente del signo)
    }

    /// Calcula la profección anual al año de activación de la dirección.
    /// Cada año de vida avanza un signo desde el Ascendente.
    static func profection(
        ascendantLongitude: Double,
        ageAtDirection: Double
    ) -> ProfectionInfo {
        let year = Int(ageAtDirection)
        let ascSignIndex = EssentialDignityEngine.signIndex(ascendantLongitude)
        let profSignIndex = (ascSignIndex + year) % 12
        let lord = EssentialDignityEngine.domicileRuler(of: profSignIndex)
        return ProfectionInfo(
            year: year,
            signIndex: profSignIndex,
            signName: EssentialDignityEngine.signName(profSignIndex),
            lord: lord
        )
    }

    // MARK: - Private Helpers

    private static func buildProfectionInfo(
        chart: NatalChart,
        direction: PrimaryDirection,
        profectionYear: Int?
    ) -> ProfectionInfo? {
        guard !chart.cusps.isEmpty else { return nil }
        let ascLon = chart.ascendant.longitude
        let age = direction.estimatedAge
        return profection(ascendantLongitude: ascLon, ageAtDirection: age)
    }

    private static func findNatalAspect(
        chart: NatalChart,
        promissor: String,
        significator: String
    ) -> String? {
        // Significadores angulares (ASC/MC) no tienen posición en bodies — aspecto no aplica
        guard significator != "ASC" && significator != "MC" else { return nil }

        guard let promissorBody = chart.bodies.first(where: { $0.key == promissor }),
              let sigBody = chart.bodies.first(where: { $0.key == significator })
        else { return nil }

        let diff = abs(promissorBody.longitude - sigBody.longitude)
            .truncatingRemainder(dividingBy: 360)
        let normalizedDiff = min(diff, 360 - diff)

        for asp in ASPECT_DEFS {
            if abs(normalizedDiff - asp.angle) <= asp.orb {
                let orbActual = abs(normalizedDiff - asp.angle)
                return "\(asp.label) (\(String(format: "%.1f", orbActual))° orbe)"
            }
        }
        return nil
    }

    private static func buildSignificatorCondition(
        chart: NatalChart,
        significator: String,
        isDiurnal: Bool
    ) -> String? {
        var parts: [String] = []

        switch significator {
        case "ASC":
            // Planetas en Casa 1
            let inFirst = chart.bodies.filter { $0.house == 1 }.map { $0.label }
            if inFirst.isEmpty {
                parts.append("Ascendente sin planetas en Casa 1")
            } else {
                parts.append("Planetas en Casa 1: \(inFirst.joined(separator: ", "))")
            }
            // Signo del Ascendente
            let ascSign = EssentialDignityEngine.signName(
                EssentialDignityEngine.signIndex(chart.ascendant.longitude)
            )
            parts.append("ASC en \(ascSign)")
            // Regente del Ascendente
            let ascRuler = EssentialDignityEngine.domicileRuler(
                of: EssentialDignityEngine.signIndex(chart.ascendant.longitude)
            )
            parts.append("Regente ASC: \(ascRuler)")

        case "MC":
            let inTenth = chart.bodies.filter { $0.house == 10 }.map { $0.label }
            if inTenth.isEmpty {
                parts.append("MC sin planetas en Casa 10")
            } else {
                parts.append("Planetas en Casa 10: \(inTenth.joined(separator: ", "))")
            }
            let mcSign = EssentialDignityEngine.signName(
                EssentialDignityEngine.signIndex(chart.mc.longitude)
            )
            parts.append("MC en \(mcSign)")
            let mcRuler = EssentialDignityEngine.domicileRuler(
                of: EssentialDignityEngine.signIndex(chart.mc.longitude)
            )
            parts.append("Regente MC: \(mcRuler)")

        default:
            // Planeta como significador (SOL, LUNA, PARTFORTUNA)
            if let body = chart.bodies.first(where: { $0.key == significator }) {
                let dignity = EssentialDignityEngine.description(
                    planet: significator,
                    longitude: body.longitude
                )
                parts.append("\(body.label) en \(body.formatted) Casa \(body.house) (\(dignity))")
                // Sect
                let inSect = EssentialDignityEngine.isInSect(planet: significator, isDiurnal: isDiurnal)
                parts.append(inSect ? "en sect" : "fuera de sect")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    private static func buildAccidentalFactors(
        chart: NatalChart,
        promissor: String,
        isDiurnal: Bool
    ) -> String? {
        guard let body = chart.bodies.first(where: { $0.key == promissor }) else { return nil }

        var parts: [String] = []

        // Angularidad
        let angularity: String
        switch body.house {
        case 1, 4, 7, 10: angularity = "angular (Casa \(body.house))"
        case 2, 5, 8, 11: angularity = "suceedente (Casa \(body.house))"
        default:           angularity = "cadente (Casa \(body.house))"
        }
        parts.append(angularity)

        // Retrogradación
        if body.retrograde { parts.append("retrógrado") }

        // Combustión (dentro de 8° del Sol)
        if promissor != "SOL",
           let sun = chart.bodies.first(where: { $0.key == "SOL" }) {
            let diff = abs(body.longitude - sun.longitude)
                .truncatingRemainder(dividingBy: 360)
            let dist = min(diff, 360 - diff)
            if dist <= 8.5 {
                let label = dist <= 0.5 ? "en cazimi (≤0.5°)" : dist <= 8 ? "combusto (\(String(format:"%.1f",dist))° Sol)" : "bajo los rayos"
                parts.append(label)
            }
        }

        return parts.joined(separator: ", ")
    }

    private static func checkMutualReception(
        chart: NatalChart,
        promissor: String,
        significator: String
    ) -> String? {
        guard significator != "ASC" && significator != "MC" else { return nil }
        guard let promBody = chart.bodies.first(where: { $0.key == promissor }),
              let sigBody = chart.bodies.first(where: { $0.key == significator })
        else { return nil }

        let hasMR = EssentialDignityEngine.mutualReceptionByDomicile(
            planetA: promissor, lonA: promBody.longitude,
            planetB: significator, lonB: sigBody.longitude
        )
        return hasMR ? significator : nil
    }

    // MARK: - Date Helpers

    private static func parseDate(_ dateStr: String, timezone: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: timezone) ?? .current
        return fmt.date(from: dateStr)
    }

    private static func ageFrom(birth: Date, to current: Date) -> Double {
        let diff = current.timeIntervalSince(birth)
        return diff / (365.25 * 24 * 3600)
    }
}
