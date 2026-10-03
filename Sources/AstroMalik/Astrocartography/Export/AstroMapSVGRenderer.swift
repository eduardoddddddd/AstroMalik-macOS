import Foundation

/// Deterministic, offline map of the lines as SVG (F6.2). It works with or without
/// a base map: with one, the same Mercator mapping used by the on-screen overlays
/// places the lines over the image; without one, a plain graticule is drawn and the
/// report says so. Pure string output, so it is testable and identical across runs.
///
/// Geometry comes from the already densified visual lines (F2/F3 budgets); this
/// renderer only projects them. It is a figure, not a measurement tool.
enum AstroMapSVGRenderer {
    static let side = 1000.0

    static func x(_ longitude: Double) -> Double { (longitude + 180) / 360 * side }
    static func y(_ latitude: Double) -> Double {
        let clamped = min(AstroMercatorGeometry.latitudeLimit, max(-AstroMercatorGeometry.latitudeLimit, latitude))
        return (1 - AstroMercatorGeometry.y(clamped) / .pi) / 2 * side
    }

    static func bodyHex(_ body: AstroBody) -> String {
        switch body {
        case .sun: return "#D97706"
        case .moon: return "#2563EB"
        case .mercury: return "#0E8E8E"
        case .venus: return "#2F9E44"
        case .mars: return "#C92A2A"
        case .jupiter: return "#7048E8"
        case .saturn: return "#8A5A2B"
        case .uranus: return "#0891B2"
        case .neptune: return "#3B4CC0"
        case .pluto: return "#C2255C"
        }
    }

    /// Same dash grammar as the screen so the angle never depends on colour alone.
    static func dashArray(_ angle: AstroAngle) -> String {
        switch angle {
        case .mc: return ""
        case .ic: return "9 5"
        case .asc: return "2 4"
        case .dsc: return "9 4 2 4"
        }
    }

    static func legendSwatch(_ angle: AstroAngle) -> String {
        let dash = dashArray(angle)
        return "<svg width=\"46\" height=\"8\" viewBox=\"0 0 46 8\" aria-hidden=\"true\"><line x1=\"0\" y1=\"4\" x2=\"46\" y2=\"4\" stroke=\"#1B1B1F\" stroke-width=\"2\"\(dash.isEmpty ? "" : " stroke-dasharray=\"\(dash)\"")/></svg>"
    }

    private static func n(_ value: Double) -> String { String(format: "%.2f", value) }

    /// `emphasized`: nil draws every line normally; otherwise those in the set are
    /// thick and the rest thin and faint (never removed, never altered in shape).
    static func render(lines: [AstroVisualLine], emphasized: Set<AstroLineID>?, place: GeoCoordinate?, placeName: String?,
                       baseImageDataURI: String?) -> String {
        var out: [String] = []
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(Int(side)) \(Int(side))\" width=\"100%\" role=\"img\" aria-label=\"Mapa de líneas de astrocartografía\">")
        if let baseImageDataURI {
            out.append("<image href=\"\(baseImageDataURI)\" x=\"0\" y=\"0\" width=\"\(Int(side))\" height=\"\(Int(side))\" preserveAspectRatio=\"none\"/>")
        } else {
            out.append("<rect x=\"0\" y=\"0\" width=\"\(Int(side))\" height=\"\(Int(side))\" fill=\"#EFE8D6\"/>")
        }
        let gridOpacity = baseImageDataURI == nil ? "0.9" : "0.35"
        for longitude in stride(from: -150.0, through: 150.0, by: 30.0) {
            out.append("<line x1=\"\(n(x(longitude)))\" y1=\"0\" x2=\"\(n(x(longitude)))\" y2=\"\(Int(side))\" stroke=\"#B9AD8F\" stroke-width=\"0.8\" opacity=\"\(gridOpacity)\"/>")
            out.append("<text x=\"\(n(x(longitude) + 3))\" y=\"\(Int(side) - 6)\" font-size=\"13\" fill=\"#5A5340\">\(Int(longitude))°</text>")
        }
        for latitude in stride(from: -60.0, through: 60.0, by: 30.0) {
            out.append("<line x1=\"0\" y1=\"\(n(y(latitude)))\" x2=\"\(Int(side))\" y2=\"\(n(y(latitude)))\" stroke=\"#B9AD8F\" stroke-width=\"0.8\" opacity=\"\(gridOpacity)\"\(latitude == 0 ? "" : " stroke-dasharray=\"3 5\"")/>")
            out.append("<text x=\"4\" y=\"\(n(y(latitude) - 4))\" font-size=\"13\" fill=\"#5A5340\">\(Int(latitude))°</text>")
        }
        let ordered = lines.sorted { a, b in
            let ea = emphasized?.contains(a.id) ?? false, eb = emphasized?.contains(b.id) ?? false
            return ea == eb ? a.id.stableKey < b.id.stableKey : !ea && eb // emphasized drawn last (on top)
        }
        for line in ordered {
            let strong = emphasized?.contains(line.id)
            let (width, opacity): (String, String) = {
                switch strong {
                case nil: return ("2.2", "0.9")
                case true?: return ("4.0", "1")
                case false?: return ("1.2", "0.3")
                }
            }()
            let dash = dashArray(line.id.angle)
            for segment in line.segments where segment.coordinates.count > 1 {
                let points = segment.coordinates.map { "\(n(x($0.longitude))),\(n(y($0.latitude)))" }.joined(separator: " ")
                out.append("<polyline data-line=\"\(line.id.body.rawValue):\(line.id.angle.rawValue)\" points=\"\(points)\" fill=\"none\" stroke=\"\(bodyHex(line.id.body))\" stroke-width=\"\(width)\" opacity=\"\(opacity)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"\(dash.isEmpty ? "" : " stroke-dasharray=\"\(dash)\"")/>")
            }
        }
        if let place {
            let px = x(place.longitude), py = y(place.latitude)
            out.append("<circle cx=\"\(n(px))\" cy=\"\(n(py))\" r=\"9\" fill=\"#FFFFFF\" stroke=\"#1B1B1F\" stroke-width=\"3\"/>")
            out.append("<circle cx=\"\(n(px))\" cy=\"\(n(py))\" r=\"3\" fill=\"#1B1B1F\"/>")
            if let placeName {
                let anchorEnd = px > side * 0.7
                out.append("<text x=\"\(n(anchorEnd ? px - 14 : px + 14))\" y=\"\(n(py - 12))\" font-size=\"20\" font-weight=\"bold\" fill=\"#1B1B1F\" stroke=\"#FFFFFF\" stroke-width=\"4\" paint-order=\"stroke\" text-anchor=\"\(anchorEnd ? "end" : "start")\">\(ReportFormatting.htmlEscape(placeName))</text>")
            }
        }
        out.append("<rect x=\"0.5\" y=\"0.5\" width=\"\(Int(side) - 1)\" height=\"\(Int(side) - 1)\" fill=\"none\" stroke=\"#1B1B1F\" stroke-width=\"1\"/>")
        out.append("</svg>")
        return out.joined(separator: "\n")
    }
}
