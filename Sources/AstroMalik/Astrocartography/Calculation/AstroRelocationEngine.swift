import Foundation

struct AstroNatalBody: Codable, Equatable, Sendable {
    let body: AstroBody
    let longitudeDegrees: Double
}

/// Immutable value snapshot, NOT a NatalChart reference. Longitudes are copied
/// literally from the natal calculation: relocation cannot change geocentric
/// planets, recompute birth time in a destination zone, or mutate persistence.
struct AstroRelocationSource: Codable, Equatable, Sendable {
    let natalChartID: UUID
    let instant: AstroNatalInstant
    let houseSystem: String
    let bodies: [AstroNatalBody]

    init(natalChartID: UUID, instant: AstroNatalInstant, houseSystem: String, bodies: [AstroNatalBody]) throws {
        _ = try AstroRelocationEngine.houseCode(houseSystem)
        guard bodies.count == AstroBody.allCases.count, Set(bodies.map(\.body)) == Set(AstroBody.allCases),
              bodies.allSatisfy({ $0.longitudeDegrees.isFinite && (0..<360).contains($0.longitudeDegrees) }) else {
            throw AstrocartographyError.invalidValue("natalGeocentricBodies")
        }
        self.natalChartID = natalChartID; self.instant = instant; self.houseSystem = houseSystem
        self.bodies = AstroBody.allCases.compactMap { body in bodies.first { $0.body == body } }
    }
    init(chart: NatalChart, instant: AstroNatalInstant) throws {
        try self.init(natalChartID: chart.id, instant: instant, houseSystem: chart.houseSystem,
            bodies: chart.bodies.compactMap { p in
                AstroBody(rawValue: p.key).map { AstroNatalBody(body: $0, longitudeDegrees: p.longitude) }
            })
    }
    private enum CodingKeys: String, CodingKey { case natalChartID, instant, houseSystem, bodies }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(natalChartID: c.decode(UUID.self, forKey: .natalChartID), instant: c.decode(AstroNatalInstant.self, forKey: .instant),
                      houseSystem: c.decode(String.self, forKey: .houseSystem), bodies: c.decode([AstroNatalBody].self, forKey: .bodies))
    }
}

struct AstroDestinationTimeZone: Codable, Equatable, Sendable {
    /// Only explicitly verified IANA identifiers are used. Inferred or unknown
    /// zones fall back to UTC; this is display metadata, never a JD input.
    let identifier: String
    let isVerified: Bool
    init(verifiedIdentifier: String? = nil) throws {
        if let verifiedIdentifier {
            guard TimeZone(identifier: verifiedIdentifier) != nil else { throw AstrocartographyError.invalidValue("destinationTimeZone") }
            identifier = verifiedIdentifier; isVerified = true
        } else { identifier = "UTC"; isVerified = false }
    }
    private enum CodingKeys: String, CodingKey { case identifier, isVerified }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let verified = try c.decode(Bool.self, forKey: .isVerified)
        let identifier = try c.decode(String.self, forKey: .identifier)
        guard verified || identifier == "UTC" else { throw AstrocartographyError.invalidValue("unverifiedDestinationZone") }
        try self.init(verifiedIdentifier: verified ? identifier : nil)
    }
}

struct AstroRelocationCalculation: Codable, Equatable, Sendable {
    let source: AstroRelocationSource
    let chart: RelocatedChartResult
    let destinationTimeZone: AstroDestinationTimeZone
    let provenance: AstroProvenance
}

protocol AstroRelocationCalculating: Sendable {
    func relocate(source: AstroRelocationSource, destination: GeoCoordinate,
                  timeZone: AstroDestinationTimeZone) throws -> AstroRelocationCalculation
}

struct AstroRelocationEngine: AstroRelocationCalculating {
    static let algorithmVersion = "f4.2-retained-natal-houses-v1"
    let ephemerisDirectory: String

    func relocate(source: AstroRelocationSource, destination: GeoCoordinate,
                  timeZone: AstroDestinationTimeZone = try! AstroDestinationTimeZone()) throws -> AstroRelocationCalculation {
        try Task.checkCancellation()
        guard !ephemerisDirectory.isEmpty else { throw AstrocartographyError.invalidValue("relocationEphemerisDirectory") }
        let system = try Self.houseCode(source.houseSystem)
        // No suspension inside the process-wide facade; houses and version
        // share configuration. A running Swiss transaction completes atomically.
        return try SwissEphemerisAccess.transaction {
            try Task.checkCancellation()
            AstroEngine.configure(ephePath: ephemerisDirectory)
            let houses: (cusps: [Double], asc: Double, mc: Double)
            do {
                houses = try AstroEngine.calcHouses(jd: source.instant.julianDay, lat: destination.latitude,
                                                   lon: destination.longitude, system: system)
            } catch { throw AstrocartographyError.housesUnavailable(error.localizedDescription) }
            try Task.checkCancellation()
            guard houses.cusps.count == 12,
                  (houses.cusps + [houses.asc, houses.mc]).allSatisfy({ $0.isFinite && (0..<360).contains($0) }) else {
                throw AstrocartographyError.housesUnavailable("Casas/ángulos no finitos; no se entrega carta degradada.")
            }
            var diagnostics = [AstroDiagnostic(code: "retained-natal-geocentric", severity: .information,
                message: "Longitudes geocéntricas copiadas sin cambio de la natal; solo se recalculan casas y ángulos en el mismo JD. Casas de cuerpos por longitud eclíptica, no prueba de coincidencia mundana con una línea.")]
            if !timeZone.isVerified {
                diagnostics.append(AstroDiagnostic(code: "destination-zone-utc", severity: .warning,
                    message: "Zona del destino no verificada: se usa UTC solo para presentación; el instante natal no cambia."))
            }
            let chart = RelocatedChartResult(natalChartID: source.natalChartID, instant: source.instant, destination: destination,
                houseSystem: source.houseSystem, cuspsDegrees: houses.cusps, ascendantDegrees: houses.asc, mcDegrees: houses.mc,
                bodies: source.bodies.map { AstroRelocatedBody(body: $0.body, longitudeDegrees: $0.longitudeDegrees,
                    house: AstroEngine.planetHouse(deg: $0.longitudeDegrees, cusps: houses.cusps)) }, diagnostics: diagnostics)
            return AstroRelocationCalculation(source: source, chart: chart, destinationTimeZone: timeZone,
                provenance: AstroProvenance(source: .swissEphemeris, libraryVersion: try SwissAstrocartographyEphemeris.libraryVersion(),
                                           algorithmVersion: Self.algorithmVersion, diagnostics: diagnostics))
        }
    }

    static func houseCode(_ name: String) throws -> Character {
        switch name.lowercased() {
        case "placidus", "p": return "P"
        case "regiomontanus", "regiomontano", "r": return "R"
        case "koch", "k": return "K"
        case "whole sign", "whole signs", "whole", "signo entero", "signos enteros", "w": return "W"
        case "equal", "equal house", "iguales", "e": return "E"
        case "porphyry", "porfirio", "o": return "O"
        case "campanus", "c": return "C"
        default: throw AstrocartographyError.invalidValue("unsupportedRelocationHouseSystem: \(name)")
        }
    }
}
