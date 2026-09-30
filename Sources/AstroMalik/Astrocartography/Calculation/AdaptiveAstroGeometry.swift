import Foundation

enum AstroGeometryError: Error, Equatable, LocalizedError {
    case toleranceBelowNumericalFloor
    case refinementLimit

    var errorDescription: String? {
        switch self {
        case .toleranceBelowNumericalFloor:
            return "La geometría F2 requiere tolerancia de al menos 0.000001 km (1 mm)."
        case .refinementLimit:
            return "No se alcanzó la tolerancia geométrica dentro de los límites de refinamiento; no se devuelve una curva degradada."
        }
    }
}

/// Geographic (not projected/pixel) interpolation on a sphere. All lengths in km.
/// An edge means linear latitude and locally unwrapped longitude, NOT a chord
/// joining canonical longitudes across the map. The true horizon is a great circle.
enum AdaptiveAstroGeometry {
    static let sphereRadiusKm = 6371.0088
    static let minimumToleranceKm = 0.000001
    static let roundingAllowanceKm = 0.0000001
    static let maximumVertices = 262_145
    static let maximumDepth = 52

    struct Samples {
        let ascendant: [GeoCoordinate]
        let descendant: [GeoCoordinate]
        let maximumBoundKm: Double
        let excludesNonUniquePoles: Bool
    }

    private struct Sample {
        let parameter: Double
        let latitude: Double
        /// DSC hour angle before rotating by RA - GST. ASC is its reflection.
        let hour: Double
    }

    /// A bound for the WHOLE edge, not a midpoint error estimate.
    /// q(s) = unit vector at linearly interpolated latitude/longitude and r(s)
    /// = constant-speed great-circle arc between the same endpoints, s in [0,1].
    /// ||q''|| <= (|Δφ|+|Δλ|)^2; ||r''|| = arcRadians^2.
    /// The linear-interpolation remainder is <= sup||f''||/8. Comparing both
    /// curves with their common Cartesian chord gives ||q-r|| <= E below.
    /// Unit-vector separation converts to surface distance as 2R asin(E/2).
    /// This is also a two-sided Hausdorff bound, since s pairs the whole curves.
    static func interpolationBoundKm(latitudeDelta: Double, longitudeDelta: Double,
                                     arcRadians: Double) -> Double {
        let angular = (abs(latitudeDelta) + abs(longitudeDelta)) * .pi / 180
        let chordError = (angular * angular + arcRadians * arcRadians) / 8
        return 2 * sphereRadiusKm * asin(min(1, chordError / 2)) + roundingAllowanceKm
    }

    static func validate(toleranceKm: Double) throws {
        guard toleranceKm.isFinite, toleranceKm >= minimumToleranceKm else {
            throw AstroGeometryError.toleranceBelowNumericalFloor
        }
    }

    static func horizon(position: AstroEquatorialPosition, siderealDegrees: Double,
                        toleranceKm: Double) throws -> Samples {
        try validate(toleranceKm: toleranceKm)
        try Task.checkCancellation()
        let declination = position.declinationDegrees
        guard abs(declination) < 90 - MundaneAngles.boundaryEpsilonDegrees else {
            return Samples(ascendant: [], descendant: [], maximumBoundKm: 0, excludesNonUniquePoles: false)
        }
        let delta = declination * .pi / 180
        let origin = position.rightAscensionDegrees - siderealDegrees
        let openPoles = abs(declination) <= MundaneAngles.boundaryEpsilonDegrees
        // At δ=0 the pole has no unique longitude. Keep the open ends outside
        // F1's epsilon band, never claim a root at either pole. Omitted length
        // is < 0.5 millimetres per end, separately declared in the diagnostic.
        let limit = .pi / 2 - (openPoles ? 4 * MundaneAngles.boundaryEpsilonDegrees * .pi / 180 : 0)
        func sample(_ t: Double) -> Sample {
            let endpoint = abs(t) == .pi / 2
            let sine = endpoint ? (t < 0 ? -1.0 : 1.0) : sin(t)
            let cosine = endpoint ? 0 : cos(t)
            // Orthonormal basis: a=(-sinδ,0,cosδ), b=(0,1,0).
            // r(t)=a sin(t) ± b cos(t), t∈[-π/2,π/2]. No acos near ±1.
            let x = -sin(delta) * sine
            let z = cos(delta) * sine
            let latitude = endpoint ? (t < 0 ? -1.0 : 1.0) * (90 - abs(declination))
                : atan2(z, hypot(x, cosine)) * 180 / .pi
            return Sample(parameter: t, latitude: latitude, hour: atan2(cosine, x) * 180 / .pi)
        }
        var output = [sample(-limit)]
        var maximumBound = 0.0
        func refine(_ a: Sample, _ b: Sample, depth: Int) throws {
            try Task.checkCancellation()
            let arc = b.parameter - a.parameter
            let bound = interpolationBoundKm(latitudeDelta: b.latitude - a.latitude,
                                              longitudeDelta: b.hour - a.hour, arcRadians: arc)
            // Never hand an ambiguous antipodal edge to downstream consumers.
            if arc <= .pi / 4 && bound <= toleranceKm {
                guard output.count < maximumVertices else { throw AstroGeometryError.refinementLimit }
                output.append(b)
                maximumBound = max(maximumBound, bound)
                return
            }
            guard depth < maximumDepth else { throw AstroGeometryError.refinementLimit }
            let midpoint = sample((a.parameter + b.parameter) / 2)
            guard midpoint.parameter > a.parameter, midpoint.parameter < b.parameter else {
                throw AstroGeometryError.refinementLimit
            }
            try refine(a, midpoint, depth: depth + 1)
            try refine(midpoint, b, depth: depth + 1)
        }
        // Retain the equator exactly and use an identical subdivision for ASC/DSC.
        let equator = sample(0)
        try refine(output[0], equator, depth: 0)
        try refine(equator, sample(limit), depth: 0)
        let asc = try output.map { try GeoCoordinate(latitude: $0.latitude,
            longitude: MundaneAngles.canonicalLongitude(origin - $0.hour)) }
        let dsc = try output.map { try GeoCoordinate(latitude: $0.latitude,
            longitude: MundaneAngles.canonicalLongitude(origin + $0.hour)) }
        return Samples(ascendant: asc, descendant: dsc, maximumBoundKm: maximumBound,
                       excludesNonUniquePoles: openPoles)
    }
}
