import Foundation
import MapKit
import AppKit

struct AstroBaseMapResult: Sendable, Equatable {
    /// `data:image/jpeg;base64,…` of the whole Web-Mercator world, or nil.
    let dataURI: String?
    /// Human reason when the base map could not be obtained (offline, timeout…).
    let failure: String?

    static func unavailable(_ reason: String) -> AstroBaseMapResult { AstroBaseMapResult(dataURI: nil, failure: reason) }
}

typealias AstroBaseMapProvider = @Sendable () async -> AstroBaseMapResult

/// Best-effort Apple Maps capture of the full Mercator world (F6.2). It needs a
/// connection for tiles, so every failure is expected and degrades to the plain
/// graticule figure; it never blocks the export beyond `timeout`.
///
/// A single `MKMapSnapshotter` request for `MKMapRect.world` does NOT return the
/// whole world (measured: it shows only ±90° of longitude, at twice the requested
/// scale), so using it directly would misalign the lines. Instead the world is
/// captured as four quadrants and each is placed using MapKit's own
/// `Snapshot.point(for:)`; the scale of every tile is verified and any mismatch
/// aborts to the graticule figure rather than drawing misaligned lines.
/// The snapshotter draws no attribution, so the report prints it beside the figure.
enum AstroBaseMapSnapshot {
    static let attribution = "Mapa base: Apple Maps (© Apple y proveedores de datos cartográficos)."
    /// Canvas side in points; the SVG then maps its 1000-unit square onto it.
    static let canvas = 2000
    private static let tilePoints = 1000

    private enum SnapshotError: Error { case timeout, scaleMismatch(String), encoding }

    @MainActor
    static func capture(timeout: TimeInterval = 20) async -> AstroBaseMapResult {
        do {
            let image = try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask { @MainActor in try await composeWorld() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SnapshotError.timeout
                }
                defer { group.cancelAll() }
                guard let first = try await group.next() else { throw SnapshotError.timeout }
                return first
            }
            return AstroBaseMapResult(dataURI: "data:image/jpeg;base64,\(image.base64EncodedString())", failure: nil)
        } catch SnapshotError.timeout {
            return .unavailable("El mapa base de Apple tardó más de \(Int(timeout)) s (¿sin conexión?).")
        } catch SnapshotError.scaleMismatch(let detail) {
            return .unavailable("El mapa base de Apple no coincide con la proyección esperada (\(detail)); no se usa para no desalinear las líneas.")
        } catch SnapshotError.encoding {
            return .unavailable("No se pudo codificar la imagen del mapa base.")
        } catch {
            return .unavailable("El mapa base de Apple no está disponible: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func composeWorld() async throws -> Data {
        let side = Double(canvas)
        let world = MKMapRect.world.size.width
        let half = world / 2
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw SnapshotError.encoding }
        context.setFillColor(CGColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.current = previous }

        // Same mapping as AstroMapSVGRenderer, scaled to the canvas (top-left origin).
        func expected(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
            CGPoint(x: (coordinate.longitude + 180) / 360 * side,
                    y: (1 - AstroMercatorGeometry.y(coordinate.latitude) / .pi) / 2 * side)
        }

        for row in 0..<2 {
            for column in 0..<2 {
                try Task.checkCancellation()
                let rect = MKMapRect(x: Double(column) * half, y: Double(row) * half, width: half, height: half)
                let options = MKMapSnapshotter.Options()
                options.mapRect = rect
                options.size = CGSize(width: tilePoints, height: tilePoints)
                options.mapType = .mutedStandard
                options.showsBuildings = false
                options.pointOfInterestFilter = .excludingAll
                options.appearance = NSAppearance(named: .aqua)
                let snapshot = try await MKMapSnapshotter(options: options).start()
                let height = snapshot.image.size.height

                // MapKit's own mapping. point(for:) uses a bottom-left origin.
                func topLeftPoint(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
                    let p = snapshot.point(for: coordinate)
                    return CGPoint(x: p.x, y: height - p.y)
                }
                let a = MKMapPoint(x: rect.minX + half * 0.05, y: rect.minY + half * 0.05).coordinate
                let b = MKMapPoint(x: rect.maxX - half * 0.05, y: rect.maxY - half * 0.05).coordinate
                let pa = topLeftPoint(a), pb = topLeftPoint(b)
                let expectedSpan = Double(tilePoints) * 0.9
                let sx = (pb.x - pa.x) / expectedSpan, sy = (pb.y - pa.y) / expectedSpan
                guard abs(sx - 1) < 0.01, abs(sy - 1) < 0.01 else {
                    throw SnapshotError.scaleMismatch(String(format: "escala %.4f×%.4f en el cuadrante %d,%d", sx, sy, column, row))
                }
                // Place the tile so MapKit's pixel for `a` lands where the SVG puts it.
                let target = expected(a)
                let originX = target.x - pa.x
                let originYTop = target.y - pa.y
                let drawRect = CGRect(x: originX, y: side - originYTop - height, width: snapshot.image.size.width, height: height)
                snapshot.image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
            }
        }
        guard let image = context.makeImage() else { throw SnapshotError.encoding }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else { throw SnapshotError.encoding }
        return jpeg
    }
}
