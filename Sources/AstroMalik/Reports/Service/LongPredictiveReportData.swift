import Foundation

// MARK: - Long Predictive Report Payloads

struct PrimaryDirectionsLongReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}

struct SolarArcLongReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}

struct ProgressionsLongReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}

struct FirdariaLongReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}

struct ZodiacalReleasingLongReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let body: String
}

struct PrimaryDirectionsLongReportSettings: Codable, Equatable, Sendable {
    let presetName: String
    let method: String
    let timeKey: String
    let aspectPlane: String
    let minimumWeight: String
    let includeConverse: Bool

    init(
        presetName: String,
        method: String,
        timeKey: String,
        aspectPlane: String,
        minimumWeight: String,
        includeConverse: Bool
    ) {
        self.presetName = presetName
        self.method = method
        self.timeKey = timeKey
        self.aspectPlane = aspectPlane
        self.minimumWeight = minimumWeight
        self.includeConverse = includeConverse
    }

    init(
        preset: PDFilterPreset?,
        method: PrimaryDirectionMethod,
        key: PrimaryDirectionKey,
        aspectPlane: PDAspectPlane,
        minimumWeight: PDWeight,
        includeConverse: Bool
    ) {
        self.init(
            presetName: preset?.rawValue ?? "Personalizado",
            method: method.rawValue,
            timeKey: key.rawValue,
            aspectPlane: aspectPlane.displayName,
            minimumWeight: minimumWeight.label,
            includeConverse: includeConverse
        )
    }
}
