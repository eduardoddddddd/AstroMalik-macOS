import XCTest
#if canImport(MapKit)
import MapKit
#endif
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstroMercatorGeometryTests: XCTestCase {
    #if canImport(MapKit)
    func testWholeProjectedEdgesUsingMapKitInverse() throws {
        var maximum = 0.0, edges = 0
        for declination in [-89.999, -45, -23.4, -0.000001, 0, 0.000001, 23.4, 45, 89.999] {
            for origin in [-180.0, -179.9, 0, 179.9] {
                let p = try AstroEquatorialPosition(body: .sun, rightAscensionDegrees: origin < 0 ? origin + 360 : origin,
                                                   declinationDegrees: declination, returnedFlags: 0)
                let h = try AdaptiveAstroGeometry.horizon(position: p, siderealDegrees: 0, toleranceKm: 0.9)
                for points in [h.ascendant, h.descendant] {
                    let line = AstroLine(id: AstroLineID(body: .sun, angle: .asc),
                        segments: [AstroLineSegment(coordinates: points)], diagnostics: [])
                    let prepared = try AstroMercatorGeometry.prepare(line)
                    for segment in prepared.segments {
                        for (a, b) in zip(segment.coordinates, segment.coordinates.dropFirst()) {
                            let bound = AstroMercatorGeometry.edgeBoundKm(a, b)
                            XCTAssertLessThanOrEqual(bound, 0.1)
                            let u = AstroMapOverlay.point(a), v = AstroMapOverlay.point(b)
                            XCTAssertLessThan(abs(a.longitude - b.longitude), 180)
                            for step in 0...32 {
                                let t = Double(step) / 32
                                let inverse = MKMapPoint(x: u.x + (v.x-u.x)*t, y: u.y+(v.y-u.y)*t).coordinate
                                let geographicLatitude = a.latitude + (b.latitude-a.latitude)*t
                                let error = abs(inverse.latitude-geographicLatitude) * .pi / 180 * 6371.0088
                                maximum = max(maximum, error)
                                XCTAssertLessThanOrEqual(error, bound + 1e-8)
                                let expectedLongitude = a.longitude + (b.longitude-a.longitude)*t
                                XCTAssertEqual(MundaneAngles.canonicalLongitude(inverse.longitude-expectedLongitude), 0, accuracy: 1e-9)
                            }
                            edges += 1
                        }
                    }
                }
            }
        }
        print("F3 Mercator vs geographic: \(edges) edges × 33 samples, maximum=\(maximum) km (budget0.1)")
    }
    #endif

    func testInclusiveSeamAndUnclippedCore() throws {
        let points = try [GeoCoordinate(latitude: -90, longitude: 179), GeoCoordinate(latitude: 0, longitude: -179),
                          GeoCoordinate(latitude: 90, longitude: -178)]
        let line = AstroLine(id: AstroLineID(body: .sun, angle: .mc), segments: [AstroLineSegment(coordinates: points)], diagnostics: [])
        let prepared = try AstroMercatorGeometry.prepare(line)
        XCTAssertEqual(line.segments[0].coordinates.first?.latitude, -90)
        XCTAssertEqual(line.segments[0].coordinates.last?.latitude, 90)
        let vertices = prepared.segments.flatMap(\.coordinates)
        XCTAssertTrue(vertices.contains { $0.longitude == 180 })
        XCTAssertTrue(vertices.contains { $0.longitude == -180 })
        #if canImport(MapKit)
        XCTAssertEqual(AstroMapOverlay.point(AstroVisualCoordinate(latitude: 0, longitude: 180)).x, MKMapSize.world.width)
        XCTAssertEqual(AstroMapOverlay.point(AstroVisualCoordinate(latitude: 0, longitude: -180)).x, 0)
        #endif
        XCTAssertTrue(vertices.allSatisfy { abs($0.latitude) <= AstroMercatorGeometry.latitudeLimit })
    }

    func testInvalidProjectionInputIsRejected() {
        for p in [AstroVisualCoordinate(latitude: 90, longitude: 0), AstroVisualCoordinate(latitude: .nan, longitude: 0),
                  AstroVisualCoordinate(latitude: 0, longitude: 181)] {
            XCTAssertThrowsError(try AstroMercatorGeometry.densify(AstroVisualLine(id: AstroLineID(body: .sun, angle: .asc),
                segments: [AstroVisualSegment(coordinates: [p])])) )
        }
    }

    #if canImport(MapKit)
    @MainActor func testMapSpikeIdentityFilteringZoomSelectionAndExplicitPath() throws {
        _ = NSApplication.shared
        let lines = AstroBody.allCases.flatMap { body in AstroAngle.allCases.map { angle in
            AstroVisualLine(id: AstroLineID(body: body, angle: angle), segments: [AstroVisualSegment(coordinates: [
                AstroVisualCoordinate(latitude: -40, longitude: -10), AstroVisualCoordinate(latitude: 0, longitude: 0),
                AstroVisualCoordinate(latitude: 40, longitude: 10)])])
        } }
        let map = MKMapView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let parent = AstroMapView(lines: lines, revision: "a", selectedLine: .constant(nil), selectedPlace: .constant(nil),
            cameraCommand: UUID(), focusPlace: false, onMapError: { _ in })
        let coordinator = parent.makeCoordinator()
        map.delegate = coordinator
        coordinator.update(map)
        XCTAssertEqual(map.overlays.count, 40)
        let identities = coordinator.overlays.mapValues(ObjectIdentifier.init)
        for _ in 0..<20 { coordinator.update(map) }
        XCTAssertEqual(map.overlays.count, 40)
        XCTAssertEqual(coordinator.overlays.mapValues(ObjectIdentifier.init), identities)
        let id = lines[0].id
        let renderer = AstroMapRenderer(overlay: try XCTUnwrap(coordinator.overlays[id]))
        renderer.createPath()
        var moves = 0, edges = 0
        renderer.path?.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { moves += 1 }
            if element.pointee.type == .addLineToPoint { edges += 1 }
        }
        XCTAssertEqual(moves, 1); XCTAssertEqual(edges, 2)
        renderer.style(selected: true); XCTAssertEqual(renderer.lineWidth, 5)
        renderer.style(selected: false); XCTAssertEqual(renderer.lineWidth, 2)
        coordinator.parent = AstroMapView(lines: Array(lines.prefix(4)), revision: "a", selectedLine: .constant(id),
            selectedPlace: .constant(try GeoCoordinate(latitude: 40, longitude: -3)), cameraCommand: UUID(), focusPlace: true, onMapError: { _ in })
        coordinator.update(map)
        XCTAssertEqual(map.overlays.count, 4)
        XCTAssertEqual(map.annotations.count, 1)
        XCTAssertLessThan(map.region.span.latitudeDelta, 100)
        XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(coordinator.overlays[id])), identities[id])
        coordinator.parent = parent; coordinator.update(map)
        XCTAssertEqual(map.overlays.count, 40); XCTAssertEqual(map.annotations.count, 0)
        XCTAssertEqual(AstroMapView.Coordinator.distance(CGPoint(x: 4, y: 3), .zero, CGPoint(x: 10, y: 0)), 3)
        XCTAssertEqual(Set(AstroAngle.allCases.map(\.dash)).count, 4)
        map.delegate = nil
    }
    #endif
}
