import Foundation

/// Product thresholds, not scientific constants or astrological intensity.
struct AstroProximityPolicy: Codable, Equatable, Sendable {
    let nearKm: Double
    let regionalKm: Double
    init(nearKm: Double = 100, regionalKm: Double = 300) throws {
        guard nearKm.isFinite, regionalKm.isFinite, nearKm >= 0, regionalKm > nearKm else {
            throw AstrocartographyError.invalidValue("proximityPolicy")
        }
        self.nearKm = nearKm; self.regionalKm = regionalKm
    }
    enum Band: String, Sendable { case near = "Cerca", regional = "Regional", distant = "Lejos" }
    func band(for distanceKm: Double) -> Band {
        distanceKm <= nearKm ? .near : distanceKm <= regionalKm ? .regional : .distant
    }
    func crossesBoundary(_ proximity: AstroLineProximity) -> Bool {
        [nearKm, regionalKm].contains { abs(proximity.distanceKm - $0) <= proximity.estimatedErrorKm }
    }
    private enum CodingKeys: String, CodingKey { case nearKm, regionalKm }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(nearKm: c.decode(Double.self, forKey: .nearKm), regionalKm: c.decode(Double.self, forKey: .regionalKm))
    }
}

/// Analyzes COMPLETE domain segments, never MapKit fragments. Each F2 edge's
/// endpoints lie on the ideal great circle; projection onto its minor spherical
/// arc gives the exact ideal-curve minimum (including its endpoints), not a
/// vertex minimum. The F2 whole-edge Hausdorff bound also bounds the difference
/// from geographic lat/lon interpolation by geometryToleranceKm. No claim of
/// ephemeris accuracy. Empty/non-unique branches have no defined proximity.
enum AstroLocationAnalyzer {
    static let algorithmVersion = "f4.1-spherical-arcs-v1"
    static let sphereRadiusKm = 6371.0088
    static let numericalAllowanceKm = 0.000001 // 1 mm; measured separately in tests.

    static func analyze(location: GeoCoordinate, result: AstrocartographyResult) throws -> LocationAnalysis {
        let p = Vector(location)
        var proximities: [AstroLineProximity] = []
        for line in result.lines {
            try Task.checkCancellation()
            var best: (distance: Double, point: Vector)?
            func consider(_ v: Vector) {
                let distance = sphereRadiusKm * p.angle(v)
                if best == nil || distance < best!.distance { best = (distance, v) }
            }
            for segment in line.segments {
                for coordinate in segment.coordinates { consider(Vector(coordinate)) }
                for (first, second) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                    try Task.checkCancellation()
                    let a = Vector(first), b = Vector(second)
                    let cross = a.cross(b), norm = cross.length
                    let arc = a.angle(b)
                    guard arc < .pi - 1e-10 else { throw AstrocartographyError.invalidValue("antipodalDistanceEdge") }
                    guard norm > 1e-15 else { continue } // duplicate, including pole longitudes
                    let n = cross / norm
                    let projection = p - n * p.dot(n)
                    guard projection.length > 1e-15 else { continue } // every circle point is equally far
                    let q = projection / projection.length
                    // Directed parameter on minor arc avoids unstable sum-of-angles
                    // membership at tiny edges and correctly handles ±180 seams.
                    for candidate in [q, q * -1] {
                        let t = atan2(n.dot(a.cross(candidate)), a.dot(candidate))
                        if t >= 0, t <= arc { consider(candidate) }
                    }
                }
            }
            if let best {
                proximities.append(AstroLineProximity(lineID: line.id, distanceKm: best.distance,
                    nearestPoint: try best.point.coordinate(),
                    estimatedErrorKm: result.snapshot.request.geometryToleranceKm + numericalAllowanceKm))
            }
        }
        proximities.sort {
            if $0.distanceKm == $1.distanceKm { return $0.lineID.stableKey < $1.lineID.stableKey }
            return $0.distanceKm < $1.distanceKm
        }
        return LocationAnalysis(request: result.snapshot.request, location: location,
                                proximities: proximities, sphereRadiusKm: sphereRadiusKm)
    }

    /// Filters are presentation only. The global analysis always includes hidden lines.
    static func filtered(_ analysis: LocationAnalysis, bodies: Set<AstroBody>, angles: Set<AstroAngle>) -> [AstroLineProximity] {
        analysis.proximities.filter { bodies.contains($0.lineID.body) && angles.contains($0.lineID.angle) }
    }

    private struct Vector {
        let x: Double, y: Double, z: Double
        init(_ c: GeoCoordinate) {
            let phi = c.latitude * .pi / 180, lambda = c.longitude * .pi / 180
            x = cos(phi) * cos(lambda); y = cos(phi) * sin(lambda); z = sin(phi)
        }
        init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
        var length: Double { sqrt(dot(self)) }
        func dot(_ b: Vector) -> Double { x*b.x + y*b.y + z*b.z }
        func cross(_ b: Vector) -> Vector { Vector(y*b.z-z*b.y, z*b.x-x*b.z, x*b.y-y*b.x) }
        func angle(_ b: Vector) -> Double { atan2(cross(b).length, dot(b)) }
        static func - (a: Vector, b: Vector) -> Vector { Vector(a.x-b.x, a.y-b.y, a.z-b.z) }
        static func * (a: Vector, b: Double) -> Vector { Vector(a.x*b, a.y*b, a.z*b) }
        static func / (a: Vector, b: Double) -> Vector { a * (1/b) }
        func coordinate() throws -> GeoCoordinate {
            try GeoCoordinate(latitude: atan2(z, hypot(x,y)) * 180 / .pi,
                              longitude: MundaneAngles.canonicalLongitude(atan2(y,x) * 180 / .pi))
        }
    }
}
