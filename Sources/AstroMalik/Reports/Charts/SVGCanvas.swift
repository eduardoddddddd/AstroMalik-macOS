import Foundation

/// Minimal, immutable SVG string builder used by report chart renderers.
/// Methods return a new canvas value, keeping the renderer functions pure and free of global mutable state.
struct SVGCanvas: Equatable {
    let width: Double
    let height: Double
    let viewBox: String

    private let elements: [String]

    init(width: Double, height: Double, viewBox: String? = nil) {
        self.width = width
        self.height = height
        self.viewBox = viewBox ?? "0 0 \(SVGChartSupport.format(width)) \(SVGChartSupport.format(height))"
        self.elements = []
    }

    private init(width: Double, height: Double, viewBox: String, elements: [String]) {
        self.width = width
        self.height = height
        self.viewBox = viewBox
        self.elements = elements
    }

    func circle(
        cx: Double,
        cy: Double,
        r: Double,
        fill: String = "none",
        stroke: String = "none",
        strokeWidth: Double = 1
    ) -> SVGCanvas {
        append("""
        <circle cx="\(f(cx))" cy="\(f(cy))" r="\(f(r))" fill="\(a(fill))" stroke="\(a(stroke))" stroke-width="\(f(strokeWidth))"/>
        """)
    }

    func line(
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double,
        stroke: String,
        strokeWidth: Double = 1
    ) -> SVGCanvas {
        append("""
        <line x1="\(f(x1))" y1="\(f(y1))" x2="\(f(x2))" y2="\(f(y2))" stroke="\(a(stroke))" stroke-width="\(f(strokeWidth))" stroke-linecap="round"/>
        """)
    }

    func path(
        d: String,
        fill: String = "none",
        stroke: String = "none",
        strokeWidth: Double = 1
    ) -> SVGCanvas {
        append("""
        <path d="\(a(d))" fill="\(a(fill))" stroke="\(a(stroke))" stroke-width="\(f(strokeWidth))" stroke-linecap="round" stroke-linejoin="round"/>
        """)
    }

    func text(
        x: Double,
        y: Double,
        text: String,
        fontSize: Double,
        fill: String,
        anchor: String = "middle"
    ) -> SVGCanvas {
        append("""
        <text x="\(f(x))" y="\(f(y))" font-size="\(f(fontSize))" fill="\(a(fill))" text-anchor="\(a(anchor))" dominant-baseline="middle">\(SVGChartSupport.escapeText(text))</text>
        """)
    }

    func group(transform: String, _ content: (SVGCanvas) -> SVGCanvas) -> SVGCanvas {
        let child = content(SVGCanvas(width: width, height: height, viewBox: viewBox))
        guard !child.elements.isEmpty else { return self }
        return append("""
        <g transform="\(a(transform))">
        \(child.elements.joined(separator: "\n"))
        </g>
        """)
    }

    func rect(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fill: String = "none",
        stroke: String = "none",
        strokeWidth: Double = 1,
        rx: Double = 0,
        attributes: [String: String] = [:]
    ) -> SVGCanvas {
        let extra = SVGChartSupport.attributes(attributes)
        return append("""
        <rect x="\(f(x))" y="\(f(y))" width="\(f(width))" height="\(f(height))" rx="\(f(rx))" fill="\(a(fill))" stroke="\(a(stroke))" stroke-width="\(f(strokeWidth))"\(extra)/>
        """)
    }

    func polygon(points: [(Double, Double)], fill: String, stroke: String = "none", strokeWidth: Double = 1, attributes: [String: String] = [:]) -> SVGCanvas {
        let pointText = points.map { "\(f($0.0)),\(f($0.1))" }.joined(separator: " ")
        let extra = SVGChartSupport.attributes(attributes)
        return append("""
        <polygon points="\(a(pointText))" fill="\(a(fill))" stroke="\(a(stroke))" stroke-width="\(f(strokeWidth))"\(extra)/>
        """)
    }

    func raw(_ element: String) -> SVGCanvas {
        append(element)
    }

    func build() -> String {
        """
        <svg width="\(f(width))" height="\(f(height))" viewBox="\(a(viewBox))" xmlns="http://www.w3.org/2000/svg" role="img">
        \(elements.joined(separator: "\n"))
        </svg>
        """
    }

    private func append(_ element: String) -> SVGCanvas {
        SVGCanvas(width: width, height: height, viewBox: viewBox, elements: elements + [element])
    }

    private func f(_ value: Double) -> String { SVGChartSupport.format(value) }
    private func a(_ value: String) -> String { SVGChartSupport.escapeAttribute(value) }
}

enum SVGChartSupport {
    static func format(_ value: Double) -> String {
        let clean = abs(value) < 0.000_001 ? 0 : value
        if clean.rounded() == clean { return String(Int(clean)) }
        return String(format: "%.2f", clean)
    }

    static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ value: String) -> String {
        escapeText(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func attributes(_ values: [String: String]) -> String {
        guard !values.isEmpty else { return "" }
        return values
            .sorted { $0.key < $1.key }
            .map { " \(escapeAttribute($0.key))=\"\(escapeAttribute($0.value))\"" }
            .joined()
    }

    static func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    static func angularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = abs((normalizedLongitude(a) - normalizedLongitude(b) + 360).truncatingRemainder(dividingBy: 360))
        if diff > 180 { diff = 360 - diff }
        return diff
    }

    static func point(longitude: Double, centerX: Double, centerY: Double, radius: Double) -> (x: Double, y: Double) {
        let radians = (normalizedLongitude(longitude) - 90) * .pi / 180
        return (centerX + cos(radians) * radius, centerY + sin(radians) * radius)
    }

    static func degreeInSignText(_ longitude: Double) -> String {
        let normalized = normalizedLongitude(longitude)
        let inSign = normalized.truncatingRemainder(dividingBy: 30)
        let degrees = Int(floor(inSign))
        let minutes = Int(((inSign - Double(degrees)) * 60).rounded())
        return "\(String(format: "%02d", degrees))°\(String(format: "%02d", minutes))'"
    }

    static func signIndex(for longitude: Double) -> Int {
        max(0, min(11, Int(normalizedLongitude(longitude) / 30)))
    }

    static func monthDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }

    static func isoDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func parseISODate(_ value: String) -> Date? {
        if let date = isoDayFormatter().date(from: String(value.prefix(10))) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
