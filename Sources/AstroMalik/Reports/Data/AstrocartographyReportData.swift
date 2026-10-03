import Foundation

struct AstrocartographyReportData: Codable, Equatable, Sendable {
    struct Legend: Codable, Equatable, Sendable {
        let label: String
        let swatch: String
    }

    struct Reading: Codable, Equatable, Sendable {
        let title: String
        let meta: String
        let mechanism: String
        let potential: String
        let shadow: String
        let practice: String
    }

    struct Distance: Codable, Equatable, Sendable {
        let line: String
        let distance: String
        let error: String
        let band: String
        let nearest: String
    }

    struct ChartLine: Codable, Equatable, Sendable {
        let line: String
        let rightAscension: String
        let declination: String
        let flags: String
        let trace: String
    }

    let header: ReportHeaderData
    let includeTOC: Bool
    let generatedDate: String
    let chartName: String
    let chartDetails: String
    let placeName: String
    let placeDetails: String
    let headline: String
    let themes: [ReportMetricRow]
    let readings: [Reading]
    let hasReadings: Bool
    let readingsNote: String
    let mapSVG: String
    let mapNote: String
    let legendBodies: [Legend]
    let legendAngles: [Legend]
    let hasRelocation: Bool
    let relocationNote: String
    let relocationAxes: [ReportMetricRow]
    let relocationCusps: [ReportMetricRow]
    let relocationBodies: [ReportMetricRow]
    let distances: [Distance]
    let chartLines: [ChartLine]
    let method: [String]
    let hasWarnings: Bool
    let warnings: [String]
    let disclaimer: String
}
