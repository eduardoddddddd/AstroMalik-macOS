import Foundation

// Contract v1: degrees, east-positive terrestrial longitude, immutable UTC-as-UT1
// natal instant. No Swiss constants or UI framework types cross this boundary.
enum AstrocartographyContract {
    static let version = 1
    static let convention = "geocentric-apparent-of-date-geometric-center-v1"
}

enum AstrocartographyError: Error, Equatable, LocalizedError {
    case invalidValue(String)
    case unsupportedInstant
    case snapshotMismatch
    case ephemerisFailure(String)
    case housesUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let field): return "Valor de astrocartografía inválido: \(field)."
        case .unsupportedInstant: return "Astrocartografía v1 admite fechas desde 1800 hasta 2999."
        case .snapshotMismatch: return "Las efemérides no corresponden a la petición de astrocartografía."
        case .ephemerisFailure(let message), .housesUnavailable(let message): return message
        }
    }
}

enum AstroBody: String, CaseIterable, Codable, Sendable {
    case sun = "SOL", moon = "LUNA", mercury = "MERCURIO", venus = "VENUS"
    case mars = "MARTE", jupiter = "JUPITER", saturn = "SATURNO"
    case uranus = "URANO", neptune = "NEPTUNO", pluto = "PLUTON"
}

enum AstroAngle: String, CaseIterable, Codable, Sendable {
    case asc = "ASC", dsc = "DSC", mc = "MC", ic = "IC"
}

enum AstroTimeScale: String, Codable, Sendable {
    /// Current application conversion does not apply DUT1. Do not label exact UT1.
    case utcApproximatedAsUT1
}

struct AstroNatalInstant: Codable, Equatable, Sendable {
    let julianDay: Double
    let timeScale: AstroTimeScale

    init(julianDay: Double, timeScale: AstroTimeScale = .utcApproximatedAsUT1) throws {
        guard julianDay.isFinite else { throw AstrocartographyError.invalidValue("julianDay") }
        // Proleptic Gregorian: 1800-01-01 inclusive, 3000-01-01 exclusive.
        guard (2_378_496.5..<2_816_787.5).contains(julianDay) else {
            throw AstrocartographyError.unsupportedInstant
        }
        self.julianDay = julianDay
        self.timeScale = timeScale
    }

    private enum CodingKeys: String, CodingKey { case julianDay, timeScale }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(julianDay: c.decode(Double.self, forKey: .julianDay),
                      timeScale: c.decode(AstroTimeScale.self, forKey: .timeScale))
    }
}

struct GeoCoordinate: Codable, Equatable, Sendable {
    let latitude: Double
    /// Canonical longitude [-180, 180); +180 is represented as -180.
    let longitude: Double

    init(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite, (-90...90).contains(latitude) else {
            throw AstrocartographyError.invalidValue("latitude")
        }
        guard longitude.isFinite, (-180...180).contains(longitude) else {
            throw AstrocartographyError.invalidValue("longitude")
        }
        self.latitude = latitude
        self.longitude = longitude == 180 ? -180 : longitude
    }

    private enum CodingKeys: String, CodingKey { case latitude, longitude }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(latitude: c.decode(Double.self, forKey: .latitude),
                      longitude: c.decode(Double.self, forKey: .longitude))
    }
}

struct AstrocartographyRequest: Codable, Equatable, Sendable {
    let instant: AstroNatalInstant
    /// Canonical PLANET_LIST order, independent of selection order.
    let bodies: [AstroBody]
    let geometryToleranceKm: Double
    let convention: String
    let contractVersion: Int

    init(instant: AstroNatalInstant, bodies: [AstroBody] = AstroBody.allCases,
         geometryToleranceKm: Double = 1) throws {
        guard !bodies.isEmpty, Set(bodies).count == bodies.count else {
            throw AstrocartographyError.invalidValue("bodies")
        }
        guard geometryToleranceKm.isFinite, geometryToleranceKm > 0 else {
            throw AstrocartographyError.invalidValue("geometryToleranceKm")
        }
        self.instant = instant
        self.bodies = AstroBody.allCases.filter { bodies.contains($0) }
        self.geometryToleranceKm = geometryToleranceKm
        self.convention = AstrocartographyContract.convention
        self.contractVersion = AstrocartographyContract.version
    }

    private enum CodingKeys: String, CodingKey {
        case instant, bodies, geometryToleranceKm, convention, contractVersion
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .contractVersion) == AstrocartographyContract.version,
              try c.decode(String.self, forKey: .convention) == AstrocartographyContract.convention else {
            throw AstrocartographyError.invalidValue("contractVersion/convention")
        }
        try self.init(instant: c.decode(AstroNatalInstant.self, forKey: .instant),
                      bodies: c.decode([AstroBody].self, forKey: .bodies),
                      geometryToleranceKm: c.decode(Double.self, forKey: .geometryToleranceKm))
    }
}

struct AstroEquatorialPosition: Codable, Equatable, Sendable {
    let body: AstroBody
    let rightAscensionDegrees: Double
    let declinationDegrees: Double
    /// Actual returned Swiss flags, not merely requested flags. Zero for mocks.
    let returnedFlags: Int32

    init(body: AstroBody, rightAscensionDegrees: Double, declinationDegrees: Double, returnedFlags: Int32) throws {
        guard rightAscensionDegrees.isFinite, (0..<360).contains(rightAscensionDegrees),
              declinationDegrees.isFinite, (-90...90).contains(declinationDegrees) else {
            throw AstrocartographyError.invalidValue("equatorialPosition")
        }
        self.body = body
        self.rightAscensionDegrees = rightAscensionDegrees
        self.declinationDegrees = declinationDegrees
        self.returnedFlags = returnedFlags
    }

    private enum CodingKeys: String, CodingKey { case body, rightAscensionDegrees, declinationDegrees, returnedFlags }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(body: c.decode(AstroBody.self, forKey: .body),
                      rightAscensionDegrees: c.decode(Double.self, forKey: .rightAscensionDegrees),
                      declinationDegrees: c.decode(Double.self, forKey: .declinationDegrees),
                      returnedFlags: c.decode(Int32.self, forKey: .returnedFlags))
    }
}

struct AstroDiagnostic: Codable, Equatable, Sendable {
    enum Severity: String, Codable, Sendable { case information, warning }
    let code: String
    let severity: Severity
    let message: String
}

struct AstroProvenance: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable { case swissEphemeris, syntheticFixture }
    let source: Source
    let libraryVersion: String
    let algorithmVersion: String
    let diagnostics: [AstroDiagnostic]
}

struct EquatorialSnapshot: Codable, Equatable, Sendable {
    let request: AstrocartographyRequest
    let greenwichSiderealDegrees: Double
    let positions: [AstroEquatorialPosition]
    let provenance: AstroProvenance

    init(request: AstrocartographyRequest, greenwichSiderealDegrees: Double,
         positions: [AstroEquatorialPosition], provenance: AstroProvenance) throws {
        guard greenwichSiderealDegrees.isFinite, (0..<360).contains(greenwichSiderealDegrees) else {
            throw AstrocartographyError.invalidValue("greenwichSiderealDegrees")
        }
        guard positions.count == request.bodies.count,
              Set(positions.map(\.body)) == Set(request.bodies) else {
            throw AstrocartographyError.snapshotMismatch
        }
        self.request = request
        self.greenwichSiderealDegrees = greenwichSiderealDegrees
        self.positions = request.bodies.compactMap { body in positions.first { $0.body == body } }
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey { case request, greenwichSiderealDegrees, positions, provenance }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(request: c.decode(AstrocartographyRequest.self, forKey: .request),
                      greenwichSiderealDegrees: c.decode(Double.self, forKey: .greenwichSiderealDegrees),
                      positions: c.decode([AstroEquatorialPosition].self, forKey: .positions),
                      provenance: c.decode(AstroProvenance.self, forKey: .provenance))
    }
}

struct AstroLineID: Codable, Equatable, Hashable, Sendable {
    let body: AstroBody
    let angle: AstroAngle
    var convention: String { AstrocartographyContract.convention }
    var stableKey: String { "\(convention):\(body.rawValue):\(angle.rawValue)" }
}

/// Domain segments are not MapKit-clipped polylines. Visual splitting belongs to UI.
struct AstroLineSegment: Codable, Equatable, Sendable {
    let coordinates: [GeoCoordinate]
}

struct AstroLine: Codable, Equatable, Sendable {
    let id: AstroLineID
    let segments: [AstroLineSegment]
    let diagnostics: [AstroDiagnostic]
}

struct AstrocartographyResult: Codable, Equatable, Sendable {
    let snapshot: EquatorialSnapshot
    let lines: [AstroLine]
}

protocol AstrocartographyEphemerisProviding: Sendable {
    func snapshot(for request: AstrocartographyRequest) throws -> EquatorialSnapshot
}

protocol AstrocartographyCalculating: Sendable {
    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult
}

/// Usable by UI and contract tests before the real Swiss adapter exists.
struct StaticAstrocartographyEphemeris: AstrocartographyEphemerisProviding {
    let fixture: EquatorialSnapshot
    func snapshot(for request: AstrocartographyRequest) throws -> EquatorialSnapshot {
        guard request == fixture.request else { throw AstrocartographyError.snapshotMismatch }
        return fixture
    }
}

// F4/F5 data transfer shapes: compiled now, detailed behavioral validation in
// their owning phase. They do not reuse non-Sendable persistence/UI models.
struct AstroLineProximity: Codable, Equatable, Sendable {
    let lineID: AstroLineID
    let distanceKm: Double
    let nearestPoint: GeoCoordinate
    let estimatedErrorKm: Double
}

struct LocationAnalysis: Codable, Equatable, Sendable {
    let request: AstrocartographyRequest
    let location: GeoCoordinate
    let proximities: [AstroLineProximity]
    let sphereRadiusKm: Double
}

struct AstroRelocatedBody: Codable, Equatable, Sendable {
    let body: AstroBody
    let longitudeDegrees: Double
    let house: Int
}

struct RelocatedChartResult: Codable, Equatable, Sendable {
    let natalChartID: UUID
    let instant: AstroNatalInstant
    let destination: GeoCoordinate
    let houseSystem: String
    let cuspsDegrees: [Double]
    let ascendantDegrees: Double
    let mcDegrees: Double
    let bodies: [AstroRelocatedBody]
    let diagnostics: [AstroDiagnostic]
}

struct AstrocartographyReading: Codable, Equatable, Sendable {
    let lineID: AstroLineID
    let text: String
    let editorialVersion: String
    let sourceReferences: [String]
}
