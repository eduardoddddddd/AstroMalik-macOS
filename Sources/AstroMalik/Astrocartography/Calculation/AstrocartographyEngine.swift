import Foundation
import CSwissEph

/// Phase-2 full geographic curves. Domain segments stay continuous across the
/// canonical longitude cut; use AstroVisualGeometry for renderable segments.
struct AstrocartographyEngine: AstrocartographyCalculating {
    static let algorithmVersion = "f2.1-adaptive-great-circle"
    static let meridianDiagnosticCode = "meridian"
    static let horizonDomainDiagnosticCode = "horizon-domain"
    static let nonUniqueHorizonDiagnosticCode = "non-unique-horizon"

    let ephemeris: any AstrocartographyEphemerisProviding

    func calculate(request: AstrocartographyRequest) throws -> AstrocartographyResult {
        try Task.checkCancellation()
        try AdaptiveAstroGeometry.validate(toleranceKm: request.geometryToleranceKm)
        let snapshot = try ephemeris.snapshot(for: request)
        guard snapshot.request == request else { throw AstrocartographyError.snapshotMismatch }
        try Task.checkCancellation()
        var lines: [AstroLine] = []
        lines.reserveCapacity(snapshot.positions.count * AstroAngle.allCases.count)
        for position in snapshot.positions {
            let horizon = try AdaptiveAstroGeometry.horizon(position: position,
                siderealDegrees: snapshot.greenwichSiderealDegrees, toleranceKm: request.geometryToleranceKm)
            for angle in AstroAngle.allCases {
                lines.append(try line(angle: angle, position: position, snapshot: snapshot, horizon: horizon))
            }
        }
        return AstrocartographyResult(snapshot: snapshot, lines: lines)
    }

    private func line(angle: AstroAngle, position: AstroEquatorialPosition, snapshot: EquatorialSnapshot,
                      horizon: AdaptiveAstroGeometry.Samples) throws -> AstroLine {
        let sidereal = snapshot.greenwichSiderealDegrees
        var diagnostics = fallbackDiagnostics(position: position, snapshot: snapshot)
        let points: [GeoCoordinate]
        switch angle {
        case .mc, .ic:
            let meridians = try MundaneAngles.meridians(
                rightAscensionDegrees: position.rightAscensionDegrees,
                greenwichSiderealDegrees: sidereal
            )
            let longitude = angle == .mc ? meridians.mc : meridians.ic
            points = try [-90, -45, 0, 45, 90].map { try GeoCoordinate(latitude: $0, longitude: longitude) }
            diagnostics.append(AstroDiagnostic(
                code: Self.meridianDiagnosticCode,
                severity: .information,
                message: "Meridiano de culminación. La longitud es la misma en ambos hemisferios y no implica visibilidad sobre el horizonte."
            ))
        case .asc, .dsc:
            points = angle == .asc ? horizon.ascendant : horizon.descendant
            diagnostics.append(AstroDiagnostic(
                code: points.isEmpty ? Self.nonUniqueHorizonDiagnosticCode : Self.horizonDomainDiagnosticCode,
                severity: points.isEmpty ? .warning : .information,
                message: points.isEmpty
                    ? "El horizonte no determina un ascendente único para declinación \(position.declinationDegrees)°."
                    : "Cruce en |latitud| + |declinación| < 90°, tangencia en la igualdad; sin cruce fuera."
            ))
            if horizon.excludesNonUniquePoles {
                diagnostics.append(AstroDiagnostic(code: "open-polar-endpoints", severity: .information,
                    message: "Polos no únicos excluidos; extremos abiertos aproximados a menos de 0.5 mm de arco de cada polo."))
            }
            diagnostics.append(AstroDiagnostic(code: "geometry-bound", severity: .information,
                message: "Cota de discretización latitud/longitud: \(horizon.maximumBoundKm) km; esfera R=\(AdaptiveAstroGeometry.sphereRadiusKm) km. No es precisión astronómica ni de proyección."))
        }
        diagnostics.append(AstroDiagnostic(
            code: "line-algorithm",
            severity: .information,
            message: Self.algorithmVersion
        ))
        return AstroLine(
            id: AstroLineID(body: position.body, angle: angle),
            segments: points.isEmpty ? [] : [AstroLineSegment(coordinates: points)],
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

}
