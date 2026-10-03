import SwiftUI
import MapKit

extension AstroBody {
    var mapLabel: String {
        switch self {
        case .sun: return "☉ Sol"
        case .moon: return "☽ Luna"
        case .mercury: return "☿ Mercurio"
        case .venus: return "♀ Venus"
        case .mars: return "♂ Marte"
        case .jupiter: return "♃ Júpiter"
        case .saturn: return "♄ Saturno"
        case .uranus: return "♅ Urano"
        case .neptune: return "♆ Neptuno"
        case .pluto: return "♇ Plutón"
        }
    }
    var mapColor: NSColor {
        switch self {
        case .sun: return .systemOrange
        case .moon: return .systemBlue
        case .mercury: return .systemTeal
        case .venus: return .systemGreen
        case .mars: return .systemRed
        case .jupiter: return .systemPurple
        case .saturn: return .systemBrown
        case .uranus: return .systemCyan
        case .neptune: return .systemIndigo
        case .pluto: return .systemPink
        }
    }
}

extension AstroAngle {
    var dash: [CGFloat] {
        switch self {
        case .mc: return []
        case .ic: return [9, 5]
        case .asc: return [2, 4]
        case .dsc: return [9, 4, 2, 4]
        }
    }
    var mapLabel: String {
        switch self {
        case .mc: return "MC · culminación · continua"
        case .ic: return "IC · anticulminación · rayas"
        case .asc: return "ASC · salida · puntos"
        case .dsc: return "DSC · puesta · raya y punto"
        }
    }
}

/// One overlay per LOGICAL line, including all its disjoint seam fragments.
final class AstroMapOverlay: NSObject, MKOverlay {
    let line: AstroVisualLine
    let paths: [[MKMapPoint]]
    let boundingMapRect: MKMapRect
    var coordinate: CLLocationCoordinate2D { MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate }

    init(line: AstroVisualLine) {
        self.line = line
        paths = line.segments.map { $0.coordinates.map(Self.point) }
        var bounds = MKMapRect.null
        for point in paths.flatMap({ $0 }) {
            bounds = bounds.union(MKMapRect(x: point.x, y: point.y, width: 0.01, height: 0.01))
        }
        boundingMapRect = bounds
        super.init()
    }
    static func point(_ coordinate: AstroVisualCoordinate) -> MKMapPoint {
        let width = MKMapSize.world.width
        // Explicit x preserves +180, which must NOT wrap to -180 here.
        return MKMapPoint(x: (coordinate.longitude + 180) / 360 * width,
                          y: (1 - AstroMercatorGeometry.y(coordinate.latitude) / .pi) / 2 * width)
    }
}

/// Explicit CGPath (no MKPolylineRenderer's undocumented simplification).
/// Every densified edge is a straight Mercator segment; never geodesic curves.
final class AstroMapRenderer: MKOverlayPathRenderer {
    override func createPath() {
        let path = CGMutablePath()
        if let overlay = overlay as? AstroMapOverlay {
            for segment in overlay.paths {
                guard let first = segment.first else { continue }
                path.move(to: point(for: first))
                for p in segment.dropFirst() { path.addLine(to: point(for: p)) }
            }
        }
        self.path = path
    }
    /// `emphasized`: nil = no emphasis mode; true = near the selected place; false = dimmed.
    /// Dimming changes only width/alpha, never the geometry or the dash pattern, so
    /// the angle remains identifiable without relying on colour or opacity.
    func style(selected: Bool, emphasized: Bool? = nil) {
        guard let line = (overlay as? AstroMapOverlay)?.line else { return }
        strokeColor = line.id.body.mapColor
        switch (selected, emphasized) {
        case (true, _): lineWidth = 5; alpha = 1
        case (false, true?): lineWidth = 3.5; alpha = 1
        case (false, false?): lineWidth = 1.5; alpha = 0.25
        case (false, nil): lineWidth = 2; alpha = 0.85
        }
        lineDashPattern = line.id.angle.dash.map { NSNumber(value: Double($0)) }
        lineCap = .round; lineJoin = .round
    }
}

/// What a line's renderer was last styled with. SwiftUI calls `updateNSView` on
/// every refresh of the parent (every tab switch, every keystroke); restyling 40
/// overlays of ~19k vertices each time forced a full redraw and froze the UI.
struct AstroOverlayStyleKey: Equatable {
    let selected: Bool
    let emphasized: Bool?
}

struct AstroMapStyleTracker {
    private var applied: [AstroLineID: AstroOverlayStyleKey] = [:]

    /// Lines whose style must be (re)applied. Lines no longer wanted are forgotten.
    mutating func stale(desired: [AstroLineID: AstroOverlayStyleKey]) -> [AstroLineID] {
        applied = applied.filter { desired[$0.key] != nil }
        return desired.filter { applied[$0.key] != $0.value }.map(\.key).sorted { $0.stableKey < $1.stableKey }
    }
    mutating func record(_ id: AstroLineID, _ key: AstroOverlayStyleKey) { applied[id] = key }
    mutating func reset() { applied.removeAll() }
}

struct AstroMapView: NSViewRepresentable {
    let lines: [AstroVisualLine]
    let revision: String
    @Binding var selectedLine: AstroLineID?
    @Binding var selectedPlace: GeoCoordinate?
    /// Lines to emphasize; nil disables emphasis (all lines drawn normally).
    var emphasizedLines: Set<AstroLineID>? = nil
    let cameraCommand: UUID
    let focusPlace: Bool
    let onMapError: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> MKMapView {
        let view = MKMapView()
        view.delegate = context.coordinator
        view.showsUserLocation = false
        view.isPitchEnabled = false; view.isRotateEnabled = false
        view.showsZoomControls = true; view.showsScale = true
        view.pointOfInterestFilter = .excludingAll
        view.setAccessibilityLabel("Mapa de astrocartografía. Selección equivalente en la lista de líneas y campos de coordenadas.")
        view.setVisibleMapRect(.world, animated: false)
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
        click.buttonMask = 0x1
        view.addGestureRecognizer(click)
        return view
    }
    func updateNSView(_ view: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(view)
    }
    static func dismantleNSView(_ view: MKMapView, coordinator: Coordinator) {
        view.delegate = nil
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AstroMapView
        private(set) var overlays: [AstroLineID: AstroMapOverlay] = [:]
        private var revision: String?
        private var cameraCommand: UUID?
        private var styles = AstroMapStyleTracker()
        private var pin: MKPointAnnotation?
        init(_ parent: AstroMapView) { self.parent = parent }

        func update(_ view: MKMapView) {
            if revision != parent.revision {
                view.removeOverlays(Array(overlays.values)); overlays.removeAll(); styles.reset()
                revision = parent.revision
            }
            let wanted = Set(parent.lines.filter { !$0.segments.isEmpty }.map(\.id))
            for id in Array(overlays.keys) where !wanted.contains(id) {
                if let removed = overlays.removeValue(forKey: id) { view.removeOverlay(removed) }
            }
            for line in parent.lines where wanted.contains(line.id) && overlays[line.id] == nil {
                let overlay = AstroMapOverlay(line: line)
                overlays[line.id] = overlay; view.addOverlay(overlay, level: .aboveLabels)
            }
            var desired: [AstroLineID: AstroOverlayStyleKey] = [:]
            for id in overlays.keys {
                desired[id] = AstroOverlayStyleKey(selected: id == parent.selectedLine,
                                                   emphasized: parent.emphasizedLines.map { $0.contains(id) })
            }
            for id in styles.stale(desired: desired) {
                guard let overlay = overlays[id], let key = desired[id],
                      let renderer = view.renderer(for: overlay) as? AstroMapRenderer else { continue }
                renderer.style(selected: key.selected, emphasized: key.emphasized)
                styles.record(id, key)
            }
            if let place = parent.selectedPlace {
                let annotation = pin ?? MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                annotation.title = "Lugar seleccionado"
                if pin == nil { view.addAnnotation(annotation); pin = annotation }
            } else if let pin { view.removeAnnotation(pin); self.pin = nil }
            if cameraCommand != parent.cameraCommand {
                cameraCommand = parent.cameraCommand
                if parent.focusPlace, let place = parent.selectedPlace {
                    view.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(
                        latitude: min(AstroMercatorGeometry.latitudeLimit, max(-AstroMercatorGeometry.latitudeLimit, place.latitude)),
                        longitude: place.longitude), span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 40)), animated: false)
                } else { view.setVisibleMapRect(.world, animated: false) }
            }
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            let renderer = AstroMapRenderer(overlay: overlay)
            let id = (overlay as? AstroMapOverlay)?.line.id
            let key = AstroOverlayStyleKey(selected: id == parent.selectedLine,
                                           emphasized: id.flatMap { id in parent.emphasizedLines.map { $0.contains(id) } })
            renderer.style(selected: key.selected, emphasized: key.emphasized)
            if let id { styles.record(id, key) }
            return renderer
        }
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            DispatchQueue.main.async { [weak self] in self?.parent.onMapError("El mapa base no se ha podido cargar. Cálculo y lista siguen disponibles sin red.") }
        }
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            DispatchQueue.main.async { [weak self] in self?.parent.onMapError(nil) }
        }
        @objc func clicked(_ gesture: NSClickGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            let click = gesture.location(in: map)
            let coordinate = map.convert(click, toCoordinateFrom: map)
            guard let place = try? GeoCoordinate(latitude: coordinate.latitude,
                longitude: MundaneAngles.canonicalLongitude(coordinate.longitude)) else { return }
            parent.selectedPlace = place
            // Screen hit testing only, not F4 geographic proximity. Stable tie order.
            var closest: (AstroLineID, Double)?
            for line in parent.lines {
                for segment in line.segments {
                    let screen = segment.coordinates.map {
                        map.convert(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), toPointTo: map)
                    }
                    for (a, b) in zip(screen, screen.dropFirst()) {
                        // Seam endpoints can wrap in map.convert; skip world-wide screen chords.
                        guard abs(a.x - b.x) < map.bounds.width / 2 else { continue }
                        let d = Self.distance(click, a, b)
                        if d <= 8 && (closest == nil || d < closest!.1) { closest = (line.id, d) }
                    }
                }
            }
            parent.selectedLine = closest?.0
        }
        static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
            let dx = b.x - a.x, dy = b.y - a.y
            let length = dx * dx + dy * dy
            let t = length == 0 ? 0 : min(1, max(0, ((p.x-a.x)*dx + (p.y-a.y)*dy) / length))
            return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
        }
    }
}

/// Wraps the map so SwiftUI skips it entirely when none of its real inputs changed
/// (e.g. when only the side-panel tab or a text field changes). Geometry is
/// identified by `revision` + the ids of the visible lines, never compared point
/// by point. Bindings and callbacks are excluded from equality on purpose.
struct AstroMapContainer: View, Equatable {
    let lines: [AstroVisualLine]
    let revision: String
    let selectedLine: Binding<AstroLineID?>
    let selectedPlace: Binding<GeoCoordinate?>
    let emphasizedLines: Set<AstroLineID>?
    let cameraCommand: UUID
    let focusPlace: Bool
    let onMapError: (String?) -> Void

    static func == (a: AstroMapContainer, b: AstroMapContainer) -> Bool {
        a.revision == b.revision
            && a.lines.map(\.id) == b.lines.map(\.id)
            && a.selectedLine.wrappedValue == b.selectedLine.wrappedValue
            && a.selectedPlace.wrappedValue == b.selectedPlace.wrappedValue
            && a.emphasizedLines == b.emphasizedLines
            && a.cameraCommand == b.cameraCommand
            && a.focusPlace == b.focusPlace
    }

    var body: some View {
        AstroMapView(lines: lines, revision: revision, selectedLine: selectedLine, selectedPlace: selectedPlace,
                     emphasizedLines: emphasizedLines, cameraCommand: cameraCommand, focusPlace: focusPlace, onMapError: onMapError)
    }
}
