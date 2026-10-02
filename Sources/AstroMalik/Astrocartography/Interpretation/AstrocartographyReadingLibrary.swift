import Foundation

// F5.3: offline reading repository. Editorial text lives in a versionable JSON
// resource (not corpus.db). The library is read-only value data; it never
// calls a network service or an LLM, and it never alters distances or lines.

enum AstroReadingError: Error, Equatable, LocalizedError {
    case resourceMissing
    case malformed(String)
    case unsupportedSchema(Int)
    case incompleteCoverage([String])
    case duplicateKey(String)
    case keyMismatch(String)
    case editorialViolation(key: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .resourceMissing: return "No se encuentra el recurso de lecturas de astrocartografía."
        case .malformed(let detail): return "Recurso de lecturas ilegible: \(detail)"
        case .unsupportedSchema(let version): return "Esquema de lecturas \(version) no soportado."
        case .incompleteCoverage(let keys): return "Faltan lecturas: \(keys.joined(separator: ", "))."
        case .duplicateKey(let key): return "Lectura duplicada: \(key)."
        case .keyMismatch(let key): return "La clave \(key) no coincide con su cuerpo y ángulo."
        case .editorialViolation(let key, let reason): return "Lectura \(key) no cumple la guía editorial: \(reason)."
        }
    }
}

/// One planet × angle text with four editorial layers. Content is symbolic
/// tradition, never a measurement of effect, and carries its own provenance.
struct AstroReadingEntry: Codable, Equatable, Sendable, Identifiable {
    let key: String
    let body: AstroBody
    let angle: AstroAngle
    let title: String
    let mechanism: String
    let potential: String
    let shadow: String
    let practice: String
    let sourceReferences: [String]

    var id: String { key }
    var lineID: AstroLineID { AstroLineID(body: body, angle: angle) }
    var layers: [String] { [mechanism, potential, shadow, practice] }
    var fullText: String { layers.joined(separator: "\n\n") }
    var characterCount: Int { layers.reduce(0) { $0 + $1.count } + 3 }
}

enum AstroReadingLookup: Equatable, Sendable {
    case available(AstroReadingEntry)
    /// Visible fallback: the line exists but no editorial text can be shown.
    case missing(AstroLineID, reason: String)

    var entry: AstroReadingEntry? {
        if case .available(let entry) = self { return entry }
        return nil
    }
}

struct AstroReadingCoverage: Equatable, Sendable {
    let total: Int
    let covered: Int
    let missing: [AstroLineID]
    var isComplete: Bool { missing.isEmpty && total == covered }
}

struct AstrocartographyReadingLibrary: Equatable, Sendable {
    static let supportedSchemaVersion = 1
    static let minimumCharacters = 650
    /// Editorial policy: deterministic or transit-time language and promises are
    /// rejected automatically. Kept in sync with the generator by a test.
    static let forbiddenPatterns = [
        "\\bahora\\b", "\\bhoy\\b", "\\beste momento\\b", "\\bactualmente\\b", "\\bsiempre\\b", "\\bnunca\\b",
        "\\bdestino\\b", "\\bgarantiz", "\\binevitabl", "\\bmaldici", "\\bcondena", "\\bsufrir[aá]s\\b",
        "\\bocurrir[aá]\\b", "\\bseguro que\\b",
    ]
    static let expectedKeys: [String] = AstroBody.allCases.flatMap { body in
        AstroAngle.allCases.map { angle in "\(body.rawValue):\(angle.rawValue)" }
    }

    let editorialVersion: String
    let reviewStatus: String
    let entries: [AstroReadingEntry]
    private let index: [String: AstroReadingEntry]

    private struct Document: Decodable {
        let schemaVersion: Int
        let editorialVersion: String
        let reviewStatus: String
        let readings: [AstroReadingEntry]
    }

    init(data: Data) throws {
        let document: Document
        do { document = try JSONDecoder().decode(Document.self, from: data) }
        catch { throw AstroReadingError.malformed(error.localizedDescription) }
        guard document.schemaVersion == Self.supportedSchemaVersion else {
            throw AstroReadingError.unsupportedSchema(document.schemaVersion)
        }
        guard !document.editorialVersion.isEmpty, !document.reviewStatus.isEmpty else {
            throw AstroReadingError.malformed("versión editorial o estado de revisión vacío")
        }
        var seen = Set<String>()
        for entry in document.readings {
            guard entry.key == "\(entry.body.rawValue):\(entry.angle.rawValue)" else {
                throw AstroReadingError.keyMismatch(entry.key)
            }
            guard seen.insert(entry.key).inserted else { throw AstroReadingError.duplicateKey(entry.key) }
            try Self.validateEditorial(entry)
        }
        let missing = Self.expectedKeys.filter { !seen.contains($0) }
        guard missing.isEmpty else { throw AstroReadingError.incompleteCoverage(missing) }
        guard seen.count == Self.expectedKeys.count else {
            throw AstroReadingError.malformed("claves fuera del conjunto de 40")
        }
        editorialVersion = document.editorialVersion
        reviewStatus = document.reviewStatus
        entries = Self.expectedKeys.compactMap { key in document.readings.first { $0.key == key } }
        index = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0) })
    }

    static func bundled(bundle: Bundle = AppResources.bundle) throws -> AstrocartographyReadingLibrary {
        guard let url = bundle.url(forResource: "readings_v1", withExtension: "json", subdirectory: "Astrocartography") else {
            throw AstroReadingError.resourceMissing
        }
        return try AstrocartographyReadingLibrary(data: Data(contentsOf: url))
    }

    func entry(for id: AstroLineID) -> AstroReadingEntry? {
        index["\(id.body.rawValue):\(id.angle.rawValue)"]
    }

    func lookup(_ id: AstroLineID) -> AstroReadingLookup {
        entry(for: id).map(AstroReadingLookup.available)
            ?? .missing(id, reason: "No hay lectura editorial para esta línea; la distancia y los datos siguen siendo válidos.")
    }

    func coverage(of ids: [AstroLineID]) -> AstroReadingCoverage {
        let missing = ids.filter { entry(for: $0) == nil }
        return AstroReadingCoverage(total: ids.count, covered: ids.count - missing.count, missing: missing)
    }

    /// Contract-v1 projection, so exports (F6) can reuse the frozen DTO.
    func reading(for id: AstroLineID) -> AstrocartographyReading? {
        entry(for: id).map {
            AstrocartographyReading(lineID: id, text: $0.fullText, editorialVersion: editorialVersion,
                                    sourceReferences: $0.sourceReferences)
        }
    }

    private static func validateEditorial(_ entry: AstroReadingEntry) throws {
        func fail(_ reason: String) -> AstroReadingError { .editorialViolation(key: entry.key, reason: reason) }
        guard !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw fail("título vacío") }
        guard entry.layers.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw fail("capa vacía")
        }
        guard !entry.sourceReferences.isEmpty, entry.sourceReferences.allSatisfy({ !$0.isEmpty }) else {
            throw fail("sin trazabilidad de fuentes")
        }
        guard entry.characterCount >= minimumCharacters else {
            throw fail("longitud \(entry.characterCount) < \(minimumCharacters)")
        }
        let text = ([entry.title] + entry.layers).joined(separator: " ")
        let range = NSRange(text.startIndex..., in: text)
        for pattern in forbiddenPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                throw fail("patrón editorial inválido")
            }
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                throw fail("lenguaje prohibido \(pattern)")
            }
        }
    }
}

/// Visible state of the editorial resource. A failed load degrades to explicit
/// per-line fallbacks; it never hides lines or distances.
enum AstroReadingCatalog: Equatable, Sendable {
    case loaded(AstrocartographyReadingLibrary)
    case unavailable(String)

    static func bundled() -> AstroReadingCatalog {
        do { return .loaded(try AstrocartographyReadingLibrary.bundled()) }
        catch { return .unavailable(error.localizedDescription) }
    }

    var editorialVersion: String? {
        if case .loaded(let library) = self { return library.editorialVersion }
        return nil
    }

    func lookup(_ id: AstroLineID) -> AstroReadingLookup {
        switch self {
        case .loaded(let library): return library.lookup(id)
        case .unavailable(let reason):
            return .missing(id, reason: "Lecturas no disponibles (\(reason)) Las distancias siguen siendo válidas.")
        }
    }

    func coverage(of ids: [AstroLineID]) -> AstroReadingCoverage {
        switch self {
        case .loaded(let library): return library.coverage(of: ids)
        case .unavailable: return AstroReadingCoverage(total: ids.count, covered: 0, missing: ids)
        }
    }
}
