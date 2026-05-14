import Foundation

struct ExtendedNatalReportData: Codable, Equatable, Sendable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let lotRows: [ReportMetricRow]
    let almutenRows: [ReportMetricRow]
    let almutenPointRows: [ReportMetricRow]
    let rulerRows: [ReportMetricRow]
    let aspectPatternRows: [ReportMetricRow]
    let distributionBars: [ReportDistributionBar]
    let receptionRows: [ReportMetricRow]
    let antisciaRows: [ReportMetricRow]
    let declinationRows: [ReportMetricRow]
    let fixedStarRows: [ReportMetricRow]
}
