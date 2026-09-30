import Foundation

/// Closed-form mundane longitudes for contract v1.
/// East-positive degrees. MC/IC are culmination, not visibility.
enum MundaneAngles {
    /// |φ| + |δ| within this many degrees of 90° counts as the tangent boundary.
    static let boundaryEpsilonDegrees = 1e-9
    /// |cos| may exceed 1 by this much from rounding before the case is not a root.
    /// A value still inside [-1, 1] stays a crossing even when it is very close to ±1.
    static let cosineExcessEpsilon = 1e-10

    struct Horizon: Equatable {
        enum Status: String, Equatable {
            case crossing
            case tangent
            case noCrossing
            case nonUniquePolarHorizon
        }

        let status: Status
        /// Canonical longitude [-180, 180). Nil when the horizon has no unique root.
        let ascendantLongitude: Double?
        let descendantLongitude: Double?
    }

    static func meridians(rightAscensionDegrees: Double, greenwichSiderealDegrees: Double) throws -> (mc: Double, ic: Double) {
        guard rightAscensionDegrees.isFinite, greenwichSiderealDegrees.isFinite else {
            throw AstrocartographyError.invalidValue("meridian")
        }
        let mc = canonicalLongitude(rightAscensionDegrees - greenwichSiderealDegrees)
        let ic = canonicalLongitude(mc + 180)
        guard mc.isFinite, ic.isFinite else { throw AstrocartographyError.invalidValue("meridian") }
        return (mc, ic)
    }

    static func horizon(rightAscensionDegrees: Double,
                         declinationDegrees: Double,
                         greenwichSiderealDegrees: Double,
                         latitude: Double) throws -> Horizon {
        guard [rightAscensionDegrees, declinationDegrees, greenwichSiderealDegrees, latitude].allSatisfy(\.isFinite),
              (-90...90).contains(latitude),
              (-90...90).contains(declinationDegrees) else {
            throw AstrocartographyError.invalidValue("horizon")
        }

        let absLatitude = abs(latitude)
        let absDeclination = abs(declinationDegrees)
        if (absLatitude >= 90 - boundaryEpsilonDegrees && absDeclination <= boundaryEpsilonDegrees)
            || (absDeclination >= 90 - boundaryEpsilonDegrees && absLatitude <= boundaryEpsilonDegrees) {
            return Horizon(status: .nonUniquePolarHorizon, ascendantLongitude: nil, descendantLongitude: nil)
        }
        if absLatitude + absDeclination > 90 + boundaryEpsilonDegrees {
            return Horizon(status: .noCrossing, ascendantLongitude: nil, descendantLongitude: nil)
        }

        let tangent = abs(absLatitude + absDeclination - 90) <= boundaryEpsilonDegrees
        let phi = latitude * .pi / 180
        let delta = declinationDegrees * .pi / 180
        var cosine = -tan(phi) * tan(delta)
        if !cosine.isFinite {
            return Horizon(status: .noCrossing, ascendantLongitude: nil, descendantLongitude: nil)
        }
        let excess = abs(cosine) - 1
        let origin = rightAscensionDegrees - greenwichSiderealDegrees
        if tangent {
            let longitude = canonicalLongitude(origin + (cosine < 0 ? 180 : 0))
            return Horizon(status: .tangent, ascendantLongitude: longitude, descendantLongitude: longitude)
        }
        if excess > cosineExcessEpsilon {
            return Horizon(status: .noCrossing, ascendantLongitude: nil, descendantLongitude: nil)
        }
        if excess > 0 {
            cosine = cosine > 0 ? 1 : -1
        }
        let hourAngle = acos(min(1, max(-1, cosine))) * 180 / .pi
        let ascendant = canonicalLongitude(origin - hourAngle)
        let descendant = canonicalLongitude(origin + hourAngle)
        guard ascendant.isFinite, descendant.isFinite else {
            throw AstrocartographyError.invalidValue("horizon")
        }
        return Horizon(status: .crossing, ascendantLongitude: ascendant, descendantLongitude: descendant)
    }

    /// [-180, 180). +180 and values that land on that cut by rounding become -180.
    static func canonicalLongitude(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return degrees }
        let shifted = (degrees + 180).truncatingRemainder(dividingBy: 360)
        let positive = shifted < 0 ? shifted + 360 : shifted
        var value = positive - 180
        if value >= 180 || abs(value - 180) <= 1e-10 { value = -180 }
        if value < -180 || abs(value + 180) <= 1e-10 { value = -180 }
        return value
    }
}
