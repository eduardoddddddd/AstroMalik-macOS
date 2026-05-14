import Foundation

struct HoraryReportData: Codable, Equatable, Sendable {
    let header: ReportHeaderData
    let includeTOC: Bool
    let generatedDate: String
    let question: String
    let placeAndTime: String
    let chartSVG: String
    let significators: [ReportMetricRow]
    let dignityRows: [ReportDignityRow]
    let verdictRows: [ReportMetricRow]
    let supportingFactors: [ReportMetricRow]
    let blockingFactors: [ReportMetricRow]
    let technicalNotes: [ReportMetricRow]
    let speculumRows: [ReportPositionRow]
    let aspectRows: [ReportAspectRow]
}
