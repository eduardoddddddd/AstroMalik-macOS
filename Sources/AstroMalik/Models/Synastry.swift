import Foundation

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
    private static let luminaryKeys: Set<String> = ["SOL", "LUNA"]
    private static let outerPlanetKeys: Set<String> = ["URANO", "NEPTUNO", "PLUTON"]

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

    var hasText: Bool { interpretation != nil }

    /// Orden editorial: luminarias, contactos interpersonales/sociales,
    /// personal-lento y, al final, contactos puramente generacionales.
    var interpretivePriority: Int {
        if Self.luminaryKeys.contains(sourcePlanetKey)
            || Self.luminaryKeys.contains(targetPlanetKey) {
            return 0
        }
        let sourceIsOuter = Self.outerPlanetKeys.contains(sourcePlanetKey)
        let targetIsOuter = Self.outerPlanetKeys.contains(targetPlanetKey)
        if !sourceIsOuter && !targetIsOuter { return 1 }
        if sourceIsOuter != targetIsOuter { return 2 }
        return 3
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
    private static let personalKeys: Set<String> = ["SOL", "LUNA", "MERCURIO", "VENUS", "MARTE"]
    private static let harmoniousAspectKeys: Set<String> = ["SEXTIL", "TRIGONO"]
    private static let frictionAspectKeys: Set<String> = ["CUADRADO", "OPOSICION"]

    var contactCount: Int
    var harmonyScore: Double
    var frictionScore: Double
    var conjunctionScore: Double
    var centralContact: SynastryContact?
    var doubleWhammies: [SynastryDoubleWhammy]

    var balanceText: String {
        if harmonyScore == 0, frictionScore == 0 {
            return conjunctionScore > 0
                ? "El conjunto se articula sobre todo mediante contactos de integración: no son fáciles o tensos por sí mismos y dependen de cómo se encaucen."
                : "No hay suficiente información ponderada para describir un balance entre facilidad y fricción."
        }
        let total = harmonyScore + frictionScore
        let harmonyShare = harmonyScore / total
        if harmonyShare >= 0.62 {
            return "Predomina la facilidad de intercambio, con fricciones puntuales que pueden aportar contraste y ajuste."
        }
        if harmonyShare <= 0.38 {
            return "Predomina la fricción movilizadora: conviene leerla como diferencia de ritmos y necesidades, no como un desenlace fijo."
        }
        return "El balance es mixto: hay apoyos claros y tensiones de peso semejante que piden negociación consciente."
    }

    static func build(from contacts: [SynastryContact]) -> SynastrySynthesis {
        var harmony = 0.0
        var friction = 0.0
        var conjunction = 0.0
        for contact in contacts {
            let weight = importanceWeight(for: contact)
            if harmoniousAspectKeys.contains(contact.aspectKey) {
                harmony += weight
            } else if frictionAspectKeys.contains(contact.aspectKey) {
                friction += weight
            } else if contact.aspectKey == "CONJUNCION" {
                conjunction += weight
            }
        }
        let central = contacts
            .filter {
                personalKeys.contains($0.chartAPlanetKey)
                    || personalKeys.contains($0.chartBPlanetKey)
            }
            .min {
                if $0.orb != $1.orb { return $0.orb < $1.orb }
                return $0.interpretivePriority < $1.interpretivePriority
            }
        return SynastrySynthesis(
            contactCount: contacts.count,
            harmonyScore: harmony,
            frictionScore: friction,
            conjunctionScore: conjunction,
            centralContact: central,
            doubleWhammies: findDoubleWhammies(in: contacts)
        )
    }

    private static func importanceWeight(for contact: SynastryContact) -> Double {
        let keys = [contact.chartAPlanetKey, contact.chartBPlanetKey]
        if keys.contains("SOL") || keys.contains("LUNA") { return 3.0 }
        if keys.contains(where: personalKeys.contains) { return 2.25 }
        switch contact.interpretivePriority {
        case 1: return 1.5
        case 2: return 1.0
        default: return 0.5
        }
    }

    private static func findDoubleWhammies(
        in contacts: [SynastryContact]
    ) -> [SynastryDoubleWhammy] {
        var groups: [String: [SynastryContact]] = [:]
        for contact in contacts where contact.chartAPlanetKey != contact.chartBPlanetKey {
            let keys = [contact.chartAPlanetKey, contact.chartBPlanetKey].sorted()
            groups["\(keys[0])|\(keys[1])", default: []].append(contact)
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
