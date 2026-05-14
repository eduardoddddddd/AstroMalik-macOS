import Foundation

struct NatalReportData: Codable, Equatable, Sendable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let wheelSVG: String
    let technicalRows: [ReportPositionRow]
    let signInterpretations: [ReportTextBlock]
    let houseInterpretations: [ReportTextBlock]
    let aspectRows: [ReportAspectRow]
    let guidedReading: [ReportTextBlock]
    let dignityRows: [ReportDignityRow]
}
