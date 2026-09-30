import Foundation

/// Rendering-only densification. Never use these clipped vertices for F4.
/// For inverse Mercator φ(y)=atan(sinh(y)), |φ''| <= 1/2. Linear
/// interpolation's remainder is <= Δy²/16 radians. Longitude is already
/// linear in x, so R*Δy²/16 bounds the entire edge's spherical separation
/// from the F2 geographic polyline. This is NOT a raster/pixel accuracy claim.
enum AstroMercatorGeometry {
    static let radiusKm = 6371.0088
    static let projectionBudgetKm = 0.1
    static let coreBudgetKm = 0.9
    static let latitudeLimit = 85.0511287798066

    static func y(_ latitude: Double) -> Double {
        asinh(tan(latitude * .pi / 180))
    }

    static func edgeBoundKm(_ a: AstroVisualCoordinate, _ b: AstroVisualCoordinate) -> Double {
        radiusKm * pow(y(b.latitude) - y(a.latitude), 2) / 16 + 1e-7
    }

    static func prepare(_ line: AstroLine) throws -> AstroVisualLine {
        let clipped = try AstroVisualGeometry.adapt(line, domain: AstroVisualDomain())
        return try densify(clipped)
    }

    static func densify(_ line: AstroVisualLine) throws -> AstroVisualLine {
        var count = 0
        let segments = try line.segments.map { segment -> AstroVisualSegment in
            var points: [AstroVisualCoordinate] = []
            func appendEdge(_ a: AstroVisualCoordinate, _ b: AstroVisualCoordinate, depth: Int) throws {
                try Task.checkCancellation()
                guard depth < 40, count < 500_000 else {
                    throw AstrocartographyError.invalidValue("mercatorSubdivisionLimit")
                }
                if edgeBoundKm(a, b) <= projectionBudgetKm {
                    points.append(b); count += 1
                } else {
                    let mid = AstroVisualCoordinate(latitude: (a.latitude + b.latitude) / 2,
                                                    longitude: (a.longitude + b.longitude) / 2)
                    try appendEdge(a, mid, depth: depth + 1)
                    try appendEdge(mid, b, depth: depth + 1)
                }
            }
            for p in segment.coordinates {
                guard p.latitude.isFinite, abs(p.latitude) <= latitudeLimit,
                      p.longitude.isFinite, abs(p.longitude) <= 180 else {
                    throw AstrocartographyError.invalidValue("mercatorCoordinate")
                }
            }
            if let first = segment.coordinates.first { points.append(first) }
            for (a, b) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                guard abs(a.longitude - b.longitude) < 180 else {
                    throw AstrocartographyError.invalidValue("mercatorSeam")
                }
                try appendEdge(a, b, depth: 0)
            }
            return AstroVisualSegment(coordinates: points)
        }
        return AstroVisualLine(id: line.id, segments: segments)
    }
}
