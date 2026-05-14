import Foundation

struct ReportHeaderData: Codable, Equatable, Sendable {
    let chartName: String
    let reportTitle: String
    let generatedDate: String
}

struct ReportFooterData: Codable, Equatable, Sendable {
    let mark: String
    let dateLabel: String
}

struct ReportCoverData: Codable, Equatable, Sendable {
    let chartName: String
    let birthDate: String
    let birthTime: String
    let place: String
    let generatedDate: String
    let ascSign: String
    let ascGlyph: String
}
