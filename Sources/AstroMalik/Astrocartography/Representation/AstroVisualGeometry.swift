import Foundation

/// Presentation coordinates deliberately permit BOTH -180 and +180. Core v1
/// GeoCoordinate remains canonical. These DTOs contain no MapKit/UI types.
struct AstroVisualCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct AstroVisualSegment: Equatable, Sendable {
    let coordinates: [AstroVisualCoordinate]
}

struct AstroVisualLine: Equatable, Sendable {
    let id: AstroLineID
    let segments: [AstroVisualSegment]
}

struct AstroVisualDomain: Equatable, Sendable {
    let minimumLatitude: Double
    let maximumLatitude: Double

    /// Conventional Web-Mercator latitude extent, NOT a choice of map control.
    init(minimumLatitude: Double = -85.0511287798066,
         maximumLatitude: Double = 85.0511287798066) throws {
        guard minimumLatitude.isFinite, maximumLatitude.isFinite,
              minimumLatitude >= -90, maximumLatitude <= 90,
              minimumLatitude < maximumLatitude else {
            throw AstrocartographyError.invalidValue("visualLatitudeDomain")
        }
        self.minimumLatitude = minimumLatitude
        self.maximumLatitude = maximumLatitude
    }
}

/// Clips the certified geographic polyline, not the underlying astronomical
/// domain. Inserted endpoints interpolate an EXISTING edge; never extend a curve
/// to a pole or join separate source segments. Drawing in another projection
/// needs that renderer's error budget (F3); the km bound is not a pixel bound.
enum AstroVisualGeometry {
    static func adapt(_ line: AstroLine, domain: AstroVisualDomain) throws -> AstroVisualLine {
        var result: [AstroVisualSegment] = []
        var current: [AstroVisualCoordinate] = []
        func flush() {
            if current.count >= 2 { result.append(AstroVisualSegment(coordinates: current)) }
            current.removeAll(keepingCapacity: true)
        }
        func append(_ a: AstroVisualCoordinate, _ b: AstroVisualCoordinate) {
            guard a != b else { return }
            if current.last != a { flush(); current.append(a) }
            current.append(b)
        }
        for segment in line.segments {
            flush()
            for (a, b) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                try Task.checkCancellation()
                let deltaLongitude = MundaneAngles.canonicalLongitude(b.longitude - a.longitude)
                guard abs(deltaLongitude) < 180 else {
                    throw AstrocartographyError.invalidValue("ambiguousVisualEdge")
                }
                let deltaLatitude = b.latitude - a.latitude
                var lower = 0.0
                var upper = 1.0
                if deltaLatitude == 0 {
                    if a.latitude < domain.minimumLatitude || a.latitude > domain.maximumLatitude {
                        flush(); continue
                    }
                } else {
                    let t1 = (domain.minimumLatitude - a.latitude) / deltaLatitude
                    let t2 = (domain.maximumLatitude - a.latitude) / deltaLatitude
                    lower = max(0, min(t1, t2))
                    upper = min(1, max(t1, t2))
                    if lower >= upper { flush(); continue }
                }
                if lower > 0 { flush() }
                var cuts = [lower, upper]
                if deltaLongitude != 0 {
                    for boundary in [-180.0, 180.0] {
                        let t = (boundary - a.longitude) / deltaLongitude
                        if t > lower && t < upper { cuts.append(t) }
                    }
                }
                cuts.sort()
                for (start, end) in zip(cuts, cuts.dropFirst()) {
                    let midpointLongitude = a.longitude + deltaLongitude * (start + end) / 2
                    let world = floor((midpointLongitude + 180) / 360)
                    func point(_ t: Double) -> AstroVisualCoordinate {
                        let input = t == 0 ? a : (t == 1 ? b : nil)
                        let latitude = min(domain.maximumLatitude, max(domain.minimumLatitude,
                            input?.latitude ?? (a.latitude + deltaLatitude * t)))
                        var longitude = a.longitude + deltaLongitude * t - world * 360
                        // Preserve shared source vertices bit-for-bit; only the
                        // canonical seam needs a choice between the two borders.
                        if let input, input.longitude != -180 { longitude = input.longitude }
                        return AstroVisualCoordinate(latitude: latitude,
                            longitude: min(180, max(-180, longitude)))
                    }
                    append(point(start), point(end))
                }
                if upper < 1 { flush() }
            }
            flush()
        }
        return AstroVisualLine(id: line.id, segments: result)
    }
}
