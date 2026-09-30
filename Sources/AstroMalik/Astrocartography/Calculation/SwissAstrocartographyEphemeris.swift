import Foundation
import CSwissEph

/// Equatorial snapshot for contract v1. Path, sidereal time and every body share
/// one Swiss transaction. Callers pass an already validated natal instant.
struct SwissAstrocartographyEphemeris: AstrocartographyEphemerisProviding {
    static let algorithmVersion = "f1.1-equatorial-snapshot"
    static let requestedFlags: Int32 = SEFLG_SWIEPH | SEFLG_EQUATORIAL
    static let fallbackDiagnosticCode = "swiss-file-fallback"

    /// Directory containing the vendored Swiss files. The snapshot sets this
    /// path inside the transaction and leaves it as the process path.
    let ephemerisDirectory: String

    func snapshot(for request: AstrocartographyRequest) throws -> EquatorialSnapshot {
        try Task.checkCancellation()
        guard !ephemerisDirectory.isEmpty else {
            throw AstrocartographyError.ephemerisFailure("Falta la ruta explícita de efemérides Swiss.")
        }
        return try SwissEphemerisAccess.transaction {
            try Task.checkCancellation()
            AstroEngine.configure(ephePath: ephemerisDirectory)
            let julianDay = request.instant.julianDay
            let sidereal = Self.normalizedCircle(SwissEphemerisAccess.swe_sidtime(julianDay) * 15)
            var positions: [AstroEquatorialPosition] = []
            var diagnostics: [AstroDiagnostic] = []
            positions.reserveCapacity(request.bodies.count)
            for body in request.bodies {
                try Task.checkCancellation()
                let calculated = try Self.position(body: body, julianDay: julianDay)
                if calculated.returnedFlags & SEFLG_SWIEPH == 0 {
                    diagnostics.append(AstroDiagnostic(
                        code: Self.fallbackDiagnosticCode,
                        severity: .warning,
                        message: "\(body.rawValue): cálculo sin fichero Swiss (flags \(calculated.returnedFlags))."
                    ))
                }
                positions.append(calculated)
            }
            let provenance = AstroProvenance(
                source: .swissEphemeris,
                libraryVersion: try Self.libraryVersion(),
                algorithmVersion: Self.algorithmVersion,
                diagnostics: diagnostics
            )
            return try EquatorialSnapshot(
                request: request,
                greenwichSiderealDegrees: sidereal,
                positions: positions,
                provenance: provenance
            )
        }
    }

    private static func position(body: AstroBody, julianDay: Double) throws -> AstroEquatorialPosition {
        guard let planetID = PLANET_LIST.first(where: { $0.key == body.rawValue })?.id else {
            throw AstrocartographyError.ephemerisFailure("Cuerpo sin identificador Swiss: \(body.rawValue).")
        }
        var values = [Double](repeating: 0, count: 6)
        var error = [CChar](repeating: 0, count: 256)
        let returned = SwissEphemerisAccess.swe_calc_ut(julianDay, planetID, requestedFlags, &values, &error)
        guard returned >= 0 else {
            let message = String(cString: error).trimmingCharacters(in: .whitespacesAndNewlines)
            throw AstrocartographyError.ephemerisFailure(
                message.isEmpty ? "Swiss no calculó \(body.rawValue)." : message
            )
        }
        return try AstroEquatorialPosition(
            body: body,
            rightAscensionDegrees: normalizedCircle(values[0]),
            declinationDegrees: values[1],
            returnedFlags: returned
        )
    }

    private static func libraryVersion() throws -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        _ = SwissEphemerisAccess.swe_version(&buffer)
        let version = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else {
            throw AstrocartographyError.ephemerisFailure("Swiss no informó la versión de la librería.")
        }
        return version
    }

    private static func normalizedCircle(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return degrees }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
