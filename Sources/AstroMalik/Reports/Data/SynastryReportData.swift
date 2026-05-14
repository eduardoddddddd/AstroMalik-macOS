import Foundation

struct SynastryReportData: Codable, Equatable, Sendable {
    let header: ReportHeaderData
    let includeTOC: Bool
    let generatedDate: String
    let chartAName: String
    let chartBName: String
    let chartADetails: String
    let chartBDetails: String
    let doubleWheelSVG: String
    let aspectsAToB: [ReportAspectRow]
    let aspectsBToA: [ReportAspectRow]
    let housesBInA: [ReportMetricRow]
    let housesAInB: [ReportMetricRow]
    let narrative: [ReportTextBlock]
}
