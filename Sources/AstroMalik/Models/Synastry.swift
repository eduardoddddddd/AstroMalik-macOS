import Foundation

/// Clasificación de los puntos que intervienen en una sinastría. Vive en un solo
/// sitio para que el motor, la síntesis y la interfaz no acaben con criterios
/// divergentes sobre qué es personal, lento o angular.
enum SynastryPointClass {
    static let angles: Set<String> = ["ASC", "MC"]
    static let luminaries: Set<String> = ["SOL", "LUNA"]
    static let personal: Set<String> = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE"]
    static let outer: Set<String> = ["URANO", "NEPTUNO", "PLUTON"]
    static let slow: Set<String> = ["JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON"]
    static let benefics: Set<String> = ["VENUS", "JUPITER"]
    static let malefics: Set<String> = ["MARTE", "SATURNO"]

    /// Velocidad media, de la más rápida a la más lenta. En sinastría el punto
    /// más lento domina el contacto con independencia de en qué carta esté.
    private static let speedOrder: [String] = [
        "LUNA", "MERCURIO", "VENUS", "SOL", "MARTE",
        "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON",
    ]

    static func isAngle(_ key: String) -> Bool { angles.contains(key) }

    /// Orden editorial de un par de puntos: 0 ángulos y luminarias, 1 personal
    /// y social, 2 personal–lento, 3 puramente generacional.
    static func interpretivePriority(_ keyA: String, _ keyB: String) -> Int {
        if isAngle(keyA) || isAngle(keyB)
            || luminaries.contains(keyA) || luminaries.contains(keyB) {
            return 0
        }
        let a = outer.contains(keyA)
        let b = outer.contains(keyB)
        if !a && !b { return 1 }
        if a != b { return 2 }
        return 3
    }

    /// Orden de velocidad; los ángulos se tratan como puntos rapidísimos porque
    /// dependen de la hora exacta de nacimiento.
    static func speedRank(_ key: String) -> Int {
        if isAngle(key) { return -1 }
        return speedOrder.firstIndex(of: key) ?? speedOrder.count
    }

    /// Orbe máximo admitido para un contacto entre dos puntos. Recorta el orbe
    /// genérico de `ASPECT_DEFS`, que es demasiado ancho para pares lentos: una
    /// conjunción Urano–Neptuno a 8° es ruido generacional, no un contacto.
    static func orbLimit(baseOrb: Double, _ keyA: String, _ keyB: String) -> Double {
        let cap: Double
        if isAngle(keyA) || isAngle(keyB) {
            cap = 5
        } else if luminaries.contains(keyA) || luminaries.contains(keyB) {
            cap = 8
        } else if personal.contains(keyA) && personal.contains(keyB) {
            cap = 6
        } else if slow.contains(keyA) && slow.contains(keyB) {
            cap = 4
        } else {
            cap = 6
        }
        return min(baseOrb, cap)
    }
}

enum SynastryDirection: String, Codable, CaseIterable {
    case aToB
    case bToA

    func sourceName(chartAName: String, chartBName: String) -> String {
        self == .aToB ? chartAName : chartBName
    }

    func targetName(chartAName: String, chartBName: String) -> String {
        self == .aToB ? chartBName : chartAName
    }
}

struct SynastryAspect: Identifiable, Codable, Equatable {
    var id: String { "\(direction.rawValue)_\(corpusClave)" }
    var direction: SynastryDirection
    var sourcePlanetKey: String
    var sourcePlanetLabel: String
    var targetPlanetKey: String
    var targetPlanetLabel: String
    var aspectKey: String
    var aspectLabel: String
    var orb: Double
    var corpusClave: String
    var interpretation: Interpretation?

    /// Hay algo que mostrar. Los contactos a los ángulos no están en el corpus
    /// pero siempre generan texto propio vía `SynastryAngleNarrative`, así que
    /// cuentan igual para la cobertura, la síntesis y la nota.
    var hasText: Bool { interpretation != nil || involvesAngle }

    var involvesAngle: Bool {
        SynastryPointClass.isAngle(sourcePlanetKey)
            || SynastryPointClass.isAngle(targetPlanetKey)
    }

    /// Orden editorial: ángulos y luminarias, contactos interpersonales/sociales,
    /// personal-lento y, al final, contactos puramente generacionales.
    var interpretivePriority: Int {
        SynastryPointClass.interpretivePriority(sourcePlanetKey, targetPlanetKey)
    }

    var isPrimarilyGenerational: Bool {
        interpretivePriority == 3
    }
}

/// Un contacto geométrico entre ambas cartas. Conserva las dos interpretaciones
/// direccionales del corpus sin duplicar la geometría en la interfaz.
struct SynastryContact: Identifiable, Codable, Equatable {
    var id: String
    var aToB: SynastryAspect?
    var bToA: SynastryAspect?

    var chartAPlanetKey: String {
        aToB?.sourcePlanetKey ?? bToA?.targetPlanetKey ?? ""
    }

    var chartAPlanetLabel: String {
        aToB?.sourcePlanetLabel ?? bToA?.targetPlanetLabel ?? ""
    }

    var chartBPlanetKey: String {
        aToB?.targetPlanetKey ?? bToA?.sourcePlanetKey ?? ""
    }

    var chartBPlanetLabel: String {
        aToB?.targetPlanetLabel ?? bToA?.sourcePlanetLabel ?? ""
    }

    var aspectKey: String {
        aToB?.aspectKey ?? bToA?.aspectKey ?? ""
    }

    var aspectLabel: String {
        aToB?.aspectLabel ?? bToA?.aspectLabel ?? ""
    }

    var orb: Double {
        [aToB?.orb, bToA?.orb].compactMap { $0 }.min() ?? 0
    }

    var interpretivePriority: Int {
        [aToB?.interpretivePriority, bToA?.interpretivePriority]
            .compactMap { $0 }
            .min() ?? 3
    }

    var isPrimarilyGenerational: Bool {
        interpretivePriority == 3
    }

    var hasText: Bool {
        aToB?.hasText == true || bToA?.hasText == true
    }

    var representativeAspect: SynastryAspect? {
        aToB ?? bToA
    }

    func aspect(for direction: SynastryDirection) -> SynastryAspect? {
        direction == .aToB ? aToB : bToA
    }

    /// Direcciones que aportan una lectura realmente distinta.
    ///
    /// Desde que el corpus respeta la jerarquía planetaria —manda el punto más
    /// lento, esté en la carta que esté—, las dos direcciones de un par de
    /// planetas distintos describen la misma dinámica y se solapan al 99%.
    /// Mostrar ambas sería repetir el texto con los nombres cambiados. Solo los
    /// contactos de un planeta consigo mismo producen un espejo real, en el que
    /// cada persona ocupa por turno el papel activo.
    var distinctDirections: [SynastryDirection] {
        let available = SynastryDirection.allCases.filter { aspect(for: $0) != nil }
        guard chartAPlanetKey == chartBPlanetKey else {
            return Array(available.prefix(1))
        }
        return available
    }

    static func grouped(_ aspects: [SynastryAspect]) -> [SynastryContact] {
        var contacts: [String: SynastryContact] = [:]
        for aspect in aspects {
            let id = contactID(for: aspect)
            var contact = contacts[id] ?? SynastryContact(id: id, aToB: nil, bToA: nil)
            switch aspect.direction {
            case .aToB:
                contact.aToB = preferred(existing: contact.aToB, candidate: aspect)
            case .bToA:
                contact.bToA = preferred(existing: contact.bToA, candidate: aspect)
            }
            contacts[id] = contact
        }
        return contacts.values.sorted(by: editorialOrder)
    }

    static func editorialOrder(_ lhs: SynastryContact, _ rhs: SynastryContact) -> Bool {
        if lhs.hasText != rhs.hasText { return lhs.hasText && !rhs.hasText }
        if lhs.interpretivePriority != rhs.interpretivePriority {
            return lhs.interpretivePriority < rhs.interpretivePriority
        }
        if lhs.orb != rhs.orb { return lhs.orb < rhs.orb }
        return lhs.id < rhs.id
    }

    private static func contactID(for aspect: SynastryAspect) -> String {
        switch aspect.direction {
        case .aToB:
            return "\(aspect.sourcePlanetKey)|\(aspect.targetPlanetKey)|\(aspect.aspectKey)"
        case .bToA:
            return "\(aspect.targetPlanetKey)|\(aspect.sourcePlanetKey)|\(aspect.aspectKey)"
        }
    }

    private static func preferred(
        existing: SynastryAspect?,
        candidate: SynastryAspect
    ) -> SynastryAspect {
        guard let existing else { return candidate }
        if candidate.hasText != existing.hasText {
            return candidate.hasText ? candidate : existing
        }
        return candidate.orb < existing.orb ? candidate : existing
    }
}

struct SynastryDoubleWhammy: Identifiable, Codable, Equatable {
    var id: String
    var firstPlanetKey: String
    var firstPlanetLabel: String
    var secondPlanetKey: String
    var secondPlanetLabel: String
    var contacts: [SynastryContact]

    var label: String {
        "\(plainPlanetName(firstPlanetLabel))–\(plainPlanetName(secondPlanetLabel))"
    }

    private func plainPlanetName(_ label: String) -> String {
        label.split(separator: " ").dropFirst().joined(separator: " ").isEmpty
            ? label
            : label.split(separator: " ").dropFirst().joined(separator: " ")
    }
}

struct SynastrySynthesis: Equatable {
    private static let harmoniousAspectKeys: Set<String> = ["SEXTIL", "TRIGONO"]
    private static let frictionAspectKeys: Set<String> = ["CUADRADO", "OPOSICION"]

    /// Pares con carga relacional reconocida. Una reciprocidad solo se destaca
    /// entre estos: exigirlo evita que Neptuno–Plutón, común a toda una
    /// generación, aparezca como si fuera un rasgo de la pareja.
    private static let relationalPairs: Set<String> = [
        "LUNA|SOL", "MARTE|VENUS", "LUNA|VENUS", "SOL|VENUS",
        "LUNA|SATURNO", "SATURNO|VENUS", "MARTE|SOL", "LUNA|MARTE",
        "ASC|VENUS", "ASC|SOL", "ASC|LUNA", "ASC|MARTE",
    ]

    var contactCount: Int
    var harmonyScore: Double
    var frictionScore: Double
    var conjunctionScore: Double
    var centralContact: SynastryContact?
    var doubleWhammies: [SynastryDoubleWhammy]

    /// Proporción de facilidad sobre el total ponderado. Por construcción del
    /// scoring, una comparación sin sesgo real tiende a 0.5, así que el valor
    /// puede leerse directamente contra ese punto medio.
    var harmonyShare: Double? {
        let total = harmonyScore + frictionScore
        guard total > 0 else { return nil }
        return harmonyScore / total
    }

    /// Punto neutro del balance: la proporción de armonía que produciría una
    /// comparación sin sesgo real. No es 0.5 exacto porque la valencia de la
    /// conjunción se inclina levemente hacia la fricción (hay más puntos
    /// maléficos y exteriores que benéficos), y eso es contenido doctrinal, no
    /// un artefacto. Se calcula sobre la parrilla completa de puntos, así que se
    /// recalibra solo si alguien cambia las tablas de importancia o de valencia.
    static let neutralHarmonyShare: Double = {
        var harmonic = 0.0
        var total = 0.0
        for keyA in AstroEngine.SYNASTRY_POINT_KEYS {
            for keyB in AstroEngine.SYNASTRY_POINT_KEYS {
                if SynastryPointClass.isAngle(keyA), SynastryPointClass.isAngle(keyB) {
                    continue
                }
                // Por cada par hay dos aspectos armónicos, dos de fricción y una
                // conjunción que se reparte según su valencia.
                let weight = importanceWeight(keyA: keyA, keyB: keyB)
                let share = conjunctionHarmonyShare(keyA: keyA, keyB: keyB)
                harmonic += weight * (2 + share)
                total += weight * 5
            }
        }
        return total > 0 ? harmonic / total : 0.5
    }()

    /// Margen alrededor del punto neutro a partir del cual se declara un
    /// predominio. Es simétrico por construcción, así que «facilidad» y
    /// «fricción» son igual de fáciles de obtener.
    private static let balanceMargin = 0.08

    var balanceText: String {
        guard let share = harmonyShare else {
            return "No hay suficientes contactos ponderados para describir un balance entre facilidad y fricción."
        }
        if share >= Self.neutralHarmonyShare + Self.balanceMargin {
            return "Predomina la facilidad de intercambio, con fricciones puntuales que pueden aportar contraste y ajuste."
        }
        if share <= Self.neutralHarmonyShare - Self.balanceMargin {
            return "Predomina la fricción movilizadora: conviene leerla como diferencia de ritmos y necesidades, no como un desenlace fijo."
        }
        return "El balance es mixto: hay apoyos claros y tensiones de peso semejante que piden negociación consciente."
    }

    static func build(from contacts: [SynastryContact]) -> SynastrySynthesis {
        var harmony = 0.0
        var friction = 0.0
        var conjunction = 0.0
        for contact in contacts {
            let weight = contributionWeight(for: contact)
            if harmoniousAspectKeys.contains(contact.aspectKey) {
                harmony += weight
            } else if frictionAspectKeys.contains(contact.aspectKey) {
                friction += weight
            } else if contact.aspectKey == "CONJUNCION" {
                // La conjunción no es neutra: su signo depende de los planetas.
                let share = conjunctionHarmonyShare(for: contact)
                harmony += weight * share
                friction += weight * (1 - share)
                conjunction += weight
            }
        }
        return SynastrySynthesis(
            contactCount: contacts.count,
            harmonyScore: harmony,
            frictionScore: friction,
            conjunctionScore: conjunction,
            centralContact: centralContact(in: contacts),
            doubleWhammies: findDoubleWhammies(in: contacts)
        )
    }

    /// Peso de un contacto = importancia de los puntos × exactitud del orbe,
    /// normalizado por la anchura de la ventana angular del aspecto.
    ///
    /// La normalización es lo que hace comparables armonía y fricción. Sin ella
    /// el resultado mide la tabla de orbes y no la pareja: con los orbes por
    /// defecto, la ventana armónica (sextil + trígono) es más ancha que la de
    /// fricción (cuadratura + oposición), de modo que una comparación cualquiera
    /// tendía a parecer más fácil de lo que es. Al dividir por la anchura, cada
    /// tipo de aspecto aporta lo mismo en promedio y el punto neutro cae en 0.5.
    static func contributionWeight(for contact: SynastryContact) -> Double {
        let limit = SynastryPointClass.orbLimit(
            baseOrb: baseOrb(for: contact.aspectKey),
            contact.chartAPlanetKey,
            contact.chartBPlanetKey
        )
        guard limit > 0 else { return 0 }
        let exactness = max(0, 1 - contact.orb / limit)
        return importanceWeight(for: contact) * exactness / priorWidth(contact.aspectKey, limit: limit)
    }

    private static func baseOrb(for aspectKey: String) -> Double {
        switch aspectKey {
        case "CONJUNCION", "OPOSICION": return 8
        case "CUADRADO", "TRIGONO": return 7
        default: return 5
        }
    }

    /// Grados de la franja 0–180° en los que el aspecto se dispara. Conjunción y
    /// oposición solo tienen un lado disponible; el resto, dos.
    private static func priorWidth(_ aspectKey: String, limit: Double) -> Double {
        switch aspectKey {
        case "CONJUNCION", "OPOSICION": return limit
        default: return 2 * limit
        }
    }

    private static func importanceWeight(for contact: SynastryContact) -> Double {
        importanceWeight(keyA: contact.chartAPlanetKey, keyB: contact.chartBPlanetKey)
    }

    static func importanceWeight(keyA: String, keyB: String) -> Double {
        let keys = [keyA, keyB]
        if keys.contains(where: SynastryPointClass.isAngle) { return 3.5 }
        if keys.contains(where: SynastryPointClass.luminaries.contains) { return 3.0 }
        if keys.contains(where: SynastryPointClass.personal.contains) { return 2.25 }
        switch SynastryPointClass.interpretivePriority(keyA, keyB) {
        case 1: return 1.5
        case 2: return 1.0
        default: return 0.5
        }
    }

    private static func conjunctionHarmonyShare(for contact: SynastryContact) -> Double {
        conjunctionHarmonyShare(keyA: contact.chartAPlanetKey, keyB: contact.chartBPlanetKey)
    }

    /// Cuánto de armónica es una conjunción, entre 0 y 1. Se apoya en la
    /// distinción tradicional entre benéficos y maléficos, extendida a los
    /// planetas exteriores por su efecto desestabilizador.
    static func conjunctionHarmonyShare(keyA: String, keyB: String) -> Double {
        let keys = [keyA, keyB]
        let hasBenefic = keys.contains(where: SynastryPointClass.benefics.contains)
        let hasHardEdge = keys.contains {
            SynastryPointClass.malefics.contains($0) || SynastryPointClass.outer.contains($0)
        }
        switch (hasBenefic, hasHardEdge) {
        case (true, false): return 0.8
        case (false, true): return 0.25
        default: return 0.5
        }
    }

    /// Relieve editorial de un contacto, para decidir cuál abre la lectura.
    ///
    /// Es una escala distinta de `importanceWeight` a propósito: el balance
    /// necesita pesos normalizados por probabilidad para que los tipos de
    /// aspecto sean comparables entre sí, mientras que el tema central es una
    /// jerarquía de relieve, donde un Sol–Luna manda sobre un Mercurio–Neptuno
    /// aunque este último sea más exacto.
    static func prominence(for contact: SynastryContact) -> Double {
        let keys = [contact.chartAPlanetKey, contact.chartBPlanetKey]
        let headline = keys.filter {
            SynastryPointClass.luminaries.contains($0) || SynastryPointClass.isAngle($0)
        }.count
        let personal = keys.filter(SynastryPointClass.personal.contains).count

        let base: Double
        switch (headline, personal) {
        case (2, _): base = 5.0
        case (1, 2): base = 4.0
        case (1, _): base = 3.0
        case (0, 2): base = 2.5
        case (0, 1): base = 1.5
        default: base = 0.5
        }

        let limit = SynastryPointClass.orbLimit(
            baseOrb: baseOrb(for: contact.aspectKey),
            contact.chartAPlanetKey,
            contact.chartBPlanetKey
        )
        guard limit > 0 else { return 0 }
        return base * max(0, 1 - contact.orb / limit)
    }

    /// El contacto que abre la lectura. Antes se elegía por orbe mínimo puro, lo
    /// que hacía que un Mercurio–Neptuno exactísimo desplazara a un Sol–Luna.
    private static func centralContact(in contacts: [SynastryContact]) -> SynastryContact? {
        contacts
            .filter {
                SynastryPointClass.personal.contains($0.chartAPlanetKey)
                    || SynastryPointClass.personal.contains($0.chartBPlanetKey)
                    || SynastryPointClass.isAngle($0.chartAPlanetKey)
                    || SynastryPointClass.isAngle($0.chartBPlanetKey)
            }
            .max {
                let lhs = prominence(for: $0)
                let rhs = prominence(for: $1)
                if lhs != rhs { return lhs < rhs }
                return $0.orb > $1.orb
            }
    }

    private static func findDoubleWhammies(
        in contacts: [SynastryContact]
    ) -> [SynastryDoubleWhammy] {
        var groups: [String: [SynastryContact]] = [:]
        for contact in contacts where contact.chartAPlanetKey != contact.chartBPlanetKey {
            let keys = [contact.chartAPlanetKey, contact.chartBPlanetKey].sorted()
            let id = "\(keys[0])|\(keys[1])"
            guard relationalPairs.contains(id) else { continue }
            groups[id, default: []].append(contact)
        }

        return groups.compactMap { id, matches in
            let keys = id.split(separator: "|").map(String.init)
            guard keys.count == 2 else { return nil }
            let forward = matches.contains {
                $0.chartAPlanetKey == keys[0] && $0.chartBPlanetKey == keys[1]
            }
            let reverse = matches.contains {
                $0.chartAPlanetKey == keys[1] && $0.chartBPlanetKey == keys[0]
            }
            guard forward, reverse else { return nil }
            let first = matches.first {
                $0.chartAPlanetKey == keys[0] || $0.chartBPlanetKey == keys[0]
            }
            let second = matches.first {
                $0.chartAPlanetKey == keys[1] || $0.chartBPlanetKey == keys[1]
            }
            return SynastryDoubleWhammy(
                id: id,
                firstPlanetKey: keys[0],
                firstPlanetLabel: label(for: keys[0], in: first),
                secondPlanetKey: keys[1],
                secondPlanetLabel: label(for: keys[1], in: second),
                contacts: matches.sorted(by: SynastryContact.editorialOrder)
            )
        }
        .sorted { $0.id < $1.id }
    }

    private static func label(for key: String, in contact: SynastryContact?) -> String {
        guard let contact else { return key.capitalized }
        if contact.chartAPlanetKey == key { return contact.chartAPlanetLabel }
        if contact.chartBPlanetKey == key { return contact.chartBPlanetLabel }
        return key.capitalized
    }
}

enum SynastryNaming {
    private static let standaloneSourceMarker = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}_])A(?![\p{L}\p{N}_])"#
    )
    private static let standaloneTargetMarker = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}_])B(?![\p{L}\p{N}_])"#
    )

    static func displayName(for chart: NatalChart) -> String {
        let trimmed = chart.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? chart.birthDate : trimmed
    }

    static func presentedText(
        _ text: String,
        direction: SynastryDirection,
        chartAName: String,
        chartBName: String
    ) -> String {
        let source = direction.sourceName(chartAName: chartAName, chartBName: chartBName)
        let target = direction.targetName(chartAName: chartAName, chartBName: chartBName)
        var result = text
        let replacements = [
            ("La persona A", "«SOURCE_CAP»"),
            ("la persona A", "«SOURCE»"),
            ("Persona A", "«SOURCE_CAP»"),
            ("persona A", "«SOURCE»"),
            ("La persona B", "«TARGET_CAP»"),
            ("la persona B", "«TARGET»"),
            ("Persona B", "«TARGET_CAP»"),
            ("persona B", "«TARGET»"),
        ]
        for (original, placeholder) in replacements {
            result = result.replacingOccurrences(of: original, with: placeholder)
        }
        result = replacingStandaloneMarker(
            in: result,
            regex: standaloneSourceMarker,
            placeholder: "«SOURCE»"
        )
        result = replacingStandaloneMarker(
            in: result,
            regex: standaloneTargetMarker,
            placeholder: "«TARGET»"
        )
        return result
            .replacingOccurrences(of: "«SOURCE_CAP»", with: source)
            .replacingOccurrences(of: "«SOURCE»", with: source)
            .replacingOccurrences(of: "«TARGET_CAP»", with: target)
            .replacingOccurrences(of: "«TARGET»", with: target)
    }

    private static func replacingStandaloneMarker(
        in text: String,
        regex: NSRegularExpression,
        placeholder: String
    ) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: placeholder
        )
    }
}

/// El corpus cubre 10 × 10 planetas, así que los contactos a los ángulos no
/// tienen texto. Se redactan aquí a partir del significado del ángulo y del modo
/// del aspecto, con la misma línea editorial: sin predicciones ni diagnósticos.
enum SynastryAngleNarrative {
    static func text(
        for aspect: SynastryAspect,
        sourceName: String,
        targetName: String
    ) -> String? {
        guard aspect.involvesAngle else { return nil }
        let angleIsTarget = SynastryPointClass.isAngle(aspect.targetPlanetKey)
        let angleKey = angleIsTarget ? aspect.targetPlanetKey : aspect.sourcePlanetKey
        let otherLabel = plainName(
            angleIsTarget ? aspect.sourcePlanetLabel : aspect.targetPlanetLabel
        )
        let angleOwner = angleIsTarget ? targetName : sourceName
        let otherOwner = angleIsTarget ? sourceName : targetName

        let field = angleField(angleKey, aspectKey: aspect.aspectKey)
        let mode = aspectMode(aspect.aspectKey)

        return """
        \(otherLabel) de \(otherOwner) toca \(field.name) de \(angleOwner), es decir \
        \(field.meaning). El contacto se produce \(mode.contact).

        \(mode.potential) La zona que se activa no es una parcela lateral de \
        \(angleOwner): los ángulos describen por dónde entra y sale su relación con \
        el mundo, así que suele notarse desde los primeros encuentros.

        \(mode.tension) Conviene no leerlo como un veredicto sobre el vínculo: \
        describe un punto de contacto intenso, no su desenlace.

        Advertencia técnica: los ángulos dependen de la hora exacta de nacimiento. \
        Cuatro minutos de error desplazan el Ascendente cerca de un grado, así que \
        con una hora aproximada o rectificada este contacto debe ponderarse con \
        prudencia y confirmarse con el resto de la comparación.
        """
    }

    private struct AngleField {
        let name: String
        let meaning: String
    }

    private static func angleField(_ key: String, aspectKey: String) -> AngleField {
        // Una oposición al Ascendente es una conjunción al Descendente, y una
        // oposición al Medio cielo lo es al Fondo de cielo. Son los ejes que la
        // astrología relacional considera más elocuentes, así que se nombran.
        let isOpposition = aspectKey == "OPOSICION"
        switch key {
        case "ASC":
            return isOpposition
                ? AngleField(
                    name: "el Descendente",
                    meaning: "la cúspide de la casa VII, el eje del vínculo: qué busca, proyecta y encuentra en la otra persona"
                )
                : AngleField(
                    name: "el Ascendente",
                    meaning: "su manera de presentarse, el cuerpo y el modo espontáneo de abordar lo que llega"
                )
        default:
            return isOpposition
                ? AngleField(
                    name: "el Fondo de cielo",
                    meaning: "la casa IV: el origen, la intimidad doméstica y la base privada desde la que se sostiene"
                )
                : AngleField(
                    name: "el Medio cielo",
                    meaning: "la vocación, el papel público y la dirección que da a su trayectoria"
                )
        }
    }

    private struct AspectMode {
        let contact: String
        let potential: String
        let tension: String
    }

    private static func aspectMode(_ key: String) -> AspectMode {
        switch key {
        case "CONJUNCION":
            return AspectMode(
                contact: "por superposición directa: ambos puntos ocupan el mismo grado del zodiaco",
                potential: "Es el contacto más inmediato de los posibles: hay reconocimiento rápido y sensación de pertinencia, como si la presencia de la otra persona encajara sin explicación previa.",
                tension: "La misma proximidad puede borrar el matiz entre lo propio y lo ajeno, y hacer que la identidad de uno quede definida por la presencia del otro."
            )
        case "SEXTIL":
            return AspectMode(
                contact: "como una facilidad disponible que necesita iniciativa para concretarse",
                potential: "Ofrece una vía cómoda de colaboración y trato cotidiano, con poca fricción de partida.",
                tension: "Por ser cómodo, puede quedarse en simpatía sin llegar a articular nada concreto."
            )
        case "CUADRADO":
            return AspectMode(
                contact: "mediante una fricción que obliga a ajustar la posición propia",
                potential: "Genera movimiento y obliga a definirse: bien trabajado, afina la manera de estar en la relación.",
                tension: "Sin elaboración, el roce se repite en el mismo punto y cada parte lo atribuye a la otra."
            )
        case "TRIGONO":
            return AspectMode(
                contact: "con una circulación fluida que suele sentirse natural",
                potential: "Favorece que la presencia de la otra persona resulte compatible con la propia forma de moverse por el mundo.",
                tension: "La facilidad puede volverse inconsciente y evitar conversaciones que igualmente hacen falta."
            )
        default:
            return AspectMode(
                contact: "desde el polo opuesto, que en un ángulo equivale a ocupar el otro extremo del eje",
                potential: "Aporta una fuerte conciencia mutua y la posibilidad de completar un eje que en solitario queda a medias.",
                tension: "Favorece la proyección: es fácil depositar en la otra persona lo que corresponde al propio extremo."
            )
        }
    }

    private static func plainName(_ label: String) -> String {
        let parts = label.split(separator: " ").dropFirst()
        return parts.isEmpty ? label : parts.joined(separator: " ")
    }
}

/// Texto ya resuelto para una lente direccional: viene del corpus o, si el
/// contacto toca un ángulo, de `SynastryAngleNarrative`. En ambos casos los
/// roles genéricos aparecen ya sustituidos por los nombres de las cartas.
struct SynastryLensCopy: Equatable {
    var short: String
    var long: String
    var source: String

    var hasLongerText: Bool { long.count > short.count }

    static func make(
        for aspect: SynastryAspect,
        chartAName: String,
        chartBName: String
    ) -> SynastryLensCopy? {
        let sourceName = aspect.direction.sourceName(
            chartAName: chartAName,
            chartBName: chartBName
        )
        let targetName = aspect.direction.targetName(
            chartAName: chartAName,
            chartBName: chartBName
        )

        if let interpretation = aspect.interpretation {
            let long = interpretation.texto
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let short = interpretation.textoCorto?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !long.isEmpty || !short.isEmpty else { return nil }
            let present = { (text: String) in
                SynastryNaming.presentedText(
                    text,
                    direction: aspect.direction,
                    chartAName: chartAName,
                    chartBName: chartBName
                )
            }
            return SynastryLensCopy(
                short: present(short.isEmpty ? long : short),
                long: present(long.isEmpty ? short : long),
                source: interpretation.fuente
            )
        }

        guard let generated = SynastryAngleNarrative.text(
            for: aspect,
            sourceName: sourceName,
            targetName: targetName
        ) else { return nil }
        let firstParagraph = generated
            .components(separatedBy: "\n\n")
            .first ?? generated
        return SynastryLensCopy(
            short: firstParagraph,
            long: generated,
            source: "Síntesis AstroMalik"
        )
    }
}

struct SynastryReading: Identifiable, Codable, Equatable {
    var id: String { "\(chartA.id.uuidString)-\(chartB.id.uuidString)" }
    var chartA: NatalChart
    var chartB: NatalChart
    var aspects: [SynastryAspect]

    var aspectsWithText: [SynastryAspect] {
        aspects.filter(\.hasText)
    }

    var contacts: [SynastryContact] {
        SynastryContact.grouped(aspects)
    }

    var contactsWithText: [SynastryContact] {
        contacts.filter(\.hasText)
    }

    var synthesis: SynastrySynthesis {
        SynastrySynthesis.build(from: contactsWithText)
    }

    var missingTextCount: Int {
        aspects.count - aspectsWithText.count
    }

    var coverageSummary: String {
        "\(contactsWithText.count) contactos interpretados de \(contacts.count)"
    }
}
