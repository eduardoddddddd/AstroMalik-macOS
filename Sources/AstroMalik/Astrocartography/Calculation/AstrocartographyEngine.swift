import Foundation
import CSwissEph

/// Phase-1 mundane lines. Samples are exact roots on a fixed latitude grid.
/// They are not an adaptive map polyline and do not claim the kilometre tolerance.
struct AstrocartographyEngine: AstrocartographyCalculating {
    static let algorithmVersion = "f1.3-mundane-angles"
    static let latitudeStepDegrees = 1.0
    static let meridianDiagnosticCode = "meridian"
    static let horizonDomainDiagnosticCode = "horizon-domain"
    static let nonUniqueHorizonDiagnosticCode = "non-unique-horizon"

    let ephemeris: any AstrocartographyEphemerisProviding

    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        let snapshot = try ephemeris.snapshot(for: request)
        var lines: [AstroLine] = []
        lines.reserveCapacity(snapshot.positions.count * AstroAngle.allCases.count)
        for position in snapshot.positions {
            for angle in AstroAngle.allCases {
                lines.append(try line(angle: angle, position: position, snapshot: snapshot))
            }
        }
        return AstrocartographyResult(snapshot: snapshot, lines: lines)
    }

    private func line(angle: AstroAngle, position: AstroEquatorialPosition, snapshot: EquatorialSnapshot) throws -> AstroLine {
        let sidereal = snapshot.greenwichSiderealDegrees
        var diagnostics = fallbackDiagnostics(position: position, snapshot: snapshot)
        let points: [(latitude: Double, longitude: Double)]
        switch angle {
        case .mc, .ic:
            let meridians = try MundaneAngles.meridians(
                rightAscensionDegrees: position.rightAscensionDegrees,
                greenwichSiderealDegrees: sidereal
            )
            let longitude = angle == .mc ? meridians.mc : meridians.ic
            points = [-45, 0, 45].map { (latitude: $0, longitude: longitude) }
            diagnostics.append(AstroDiagnostic(
                code: Self.meridianDiagnosticCode,
                severity: .information,
                message: "Meridiano de culminación. La longitud es la misma en ambos hemisferios y no implica visibilidad sobre el horizonte."
            ))
        case .asc, .dsc:
            let sampled = try Self.horizonSamples(position: position, greenwichSiderealDegrees: sidereal)
            points = angle == .asc ? sampled.ascendant : sampled.descendant
            diagnostics.append(sampled.diagnostic)
        }
        diagnostics.append(AstroDiagnostic(
            code: "line-algorithm",
            severity: .information,
            message: Self.algorithmVersion
        ))
        return AstroLine(
            id: AstroLineID(body: position.body, angle: angle),
            segments: try Self.segments(from: points),
            diagnostics: diagnostics
        )
    }

    private func fallbackDiagnostics(position: AstroEquatorialPosition, snapshot: EquatorialSnapshot) -> [AstroDiagnostic] {
        guard snapshot.provenance.source == .swissEphemeris,
              position.returnedFlags & SEFLG_SWIEPH == 0 else { return [] }
        return [AstroDiagnostic(
            code: SwissAstrocartographyEphemeris.fallbackDiagnosticCode,
            severity: .warning,
            message: "\(position.body.rawValue): cálculo sin fichero Swiss (flags \(position.returnedFlags))."
        )]
    }

    private static func horizonSamples(position: AstroEquatorialPosition,
                                       greenwichSiderealDegrees: Double) throws -> (ascendant: [(latitude: Double, longitude: Double)],
                                                                                     descendant: [(latitude: Double, longitude: Double)],
                                                                                     diagnostic: AstroDiagnostic) {
        if abs(position.declinationDegrees) >= 90 - MundaneAngles.boundaryEpsilonDegrees {
            return ([], [], AstroDiagnostic(
                code: nonUniqueHorizonDiagnosticCode,
                severity: .warning,
                message: "El horizonte no determina un ascendente único para declinación \(position.declinationDegrees)°."
            ))
        }

        var ascendant: [(latitude: Double, longitude: Double)] = []
        var descendant: [(latitude: Double, longitude: Double)] = []
        func record(latitude: Double) throws {
            if ascendant.contains(where: { abs($0.latitude - latitude) <= 1e-8 }) { return }
            let event = try MundaneAngles.horizon(
                rightAscensionDegrees: position.rightAscensionDegrees,
                declinationDegrees: position.declinationDegrees,
                greenwichSiderealDegrees: greenwichSiderealDegrees,
                latitude: latitude
            )
            guard let east = event.ascendantLongitude, let west = event.descendantLongitude else { return }
            guard event.status == .crossing || event.status == .tangent else { return }
            ascendant.append((latitude, east))
            descendant.append((latitude, west))
        }

        var latitude = -89.0
        while latitude <= 89 {
            try record(latitude: latitude)
            latitude += latitudeStepDegrees
        }
        let limit = 90 - abs(position.declinationDegrees)
        if limit > MundaneAngles.boundaryEpsilonDegrees && limit < 90 - MundaneAngles.boundaryEpsilonDegrees {
            try record(latitude: limit)
            try record(latitude: -limit)
        }
        return (ascendant, descendant, AstroDiagnostic(
            code: horizonDomainDiagnosticCode,
            severity: .information,
            message: "Hay cruce donde |latitud| + |declinación| < 90°, tangencia en la igualdad y ningún cruce fuera. Declinación \(position.declinationDegrees)°."
        ))
    }

    /// Splits the canonical chart where a continuous root crosses ±180.
    /// A jump above 180° is a cut, not a chord across the map.
    private static func segments(from points: [(latitude: Double, longitude: Double)]) throws -> [AstroLineSegment] {
        let ordered = points.sorted { lhs, rhs in
            if lhs.latitude == rhs.latitude { return lhs.longitude < rhs.longitude }
            return lhs.latitude < rhs.latitude
        }
        var segments: [AstroLineSegment] = []
        var current: [GeoCoordinate] = []
        for point in ordered {
            let coordinate = try GeoCoordinate(latitude: point.latitude, longitude: point.longitude)
            if let previous = current.last, abs(previous.longitude - coordinate.longitude) > 180 {
                segments.append(AstroLineSegment(coordinates: current))
                current = [coordinate]
            } else {
                current.append(coordinate)
            }
        }
        if !current.isEmpty {
            segments.append(AstroLineSegment(coordinates: current))
        }
        return segments
    }
}
