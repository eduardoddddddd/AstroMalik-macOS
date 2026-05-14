import Foundation

struct ReportPositionRow: Codable, Equatable, Sendable {
    let body: String
    let glyph: String
    let position: String
    let sign: String
    let house: String
    let retrograde: String
}

struct ReportTextBlock: Codable, Equatable, Sendable {
    let title: String
    let subtitle: String
    let text: String
    let source: String
}

struct ReportAspectRow: Codable, Equatable, Sendable {
    let left: String
    let aspect: String
    let right: String
    let orb: String
    let corpusKey: String
    let text: String
}

struct ReportMetricRow: Codable, Equatable, Sendable {
    let label: String
    let value: String
    let detail: String
}

struct ReportDignityRow: Codable, Equatable, Sendable {
    let planet: String
    let position: String
    let dignities: String
    let score: String
}

struct ReportDistributionBar: Codable, Equatable, Sendable {
    let category: String
    let name: String
    let count: String
    let detail: String
    let percent: String
}

enum ReportFormatting {
    static func generatedDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func decimal(_ value: Double, digits: Int = 2) -> String {
        String(format: "%.*f", digits, value)
    }

    static func degree(_ value: Double, digits: Int = 2) -> String {
        "\(decimal(value, digits: digits))°"
    }

    static func signLabel(for longitude: Double) -> String {
        SIGN_LABELS[SVGChartSupport.signIndex(for: longitude)]
    }

    static func signGlyph(for longitude: Double) -> String {
        SIGN_LABELS[SVGChartSupport.signIndex(for: longitude)].split(separator: " ").first.map(String.init) ?? ""
    }

    static func plainPlanetName(_ label: String) -> String {
        let pieces = label.split(separator: " ")
        return pieces.count > 1 ? pieces.dropFirst().joined(separator: " ") : label
    }

    static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
