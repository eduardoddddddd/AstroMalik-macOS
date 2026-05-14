import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PDFExportButton: View {
    @EnvironmentObject private var appState: AppState

    let chartName: String
    let reportType: String
    var prominent: Bool = false
    var disabled: Bool = false
    let generate: (PDFPageSize) async throws -> Data

    @State private var isExporting = false
    @State private var exportAlert: PDFExportAlert?

    var body: some View {
        Button {
            startExport()
        } label: {
            if isExporting {
                Label("Generando…", systemImage: "hourglass")
            } else {
                Label("Exportar PDF", systemImage: "doc.richtext")
            }
        }
        .buttonStyle(.bordered)
        .tint(prominent ? Color.appAccentFill : nil)
        .disabled(disabled || isExporting)
        .alert(item: $exportAlert) { alert in
            switch alert.kind {
            case .success(let url):
                return Alert(
                    title: Text("PDF guardado"),
                    message: Text(url.lastPathComponent),
                    primaryButton: .default(Text("Abrir")) { NSWorkspace.shared.open(url) },
                    secondaryButton: .cancel(Text("OK"))
                )
            case .error(let message):
                return Alert(title: Text("No se pudo exportar el PDF"), message: Text(message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func startExport() {
        PDFReportLastJobStore.shared.remember(chartName: chartName, reportType: reportType, generate: generate)
        isExporting = true
        let settings = appState.joplinSettings
        Task {
            do {
                if let result = try await PDFReportExportCoordinator.export(
                    chartName: chartName,
                    reportType: reportType,
                    joplinSettings: settings,
                    generate: generate
                ) {
                    exportAlert = PDFExportAlert(kind: .success(result.url))
                }
            } catch {
                exportAlert = PDFExportAlert(kind: .error(error.localizedDescription))
            }
            isExporting = false
        }
    }
}

private struct PDFExportAlert: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case success(URL)
        case error(String)
    }
}

struct PDFReportExportResult: Sendable {
    let url: URL
}

enum PDFReportExportViewError: LocalizedError {
    case missingData(String)

    var errorDescription: String? {
        switch self {
        case .missingData(let message): return message
        }
    }
}

@MainActor
enum PDFReportExportCoordinator {
    static func export(
        chartName: String,
        reportType: String,
        joplinSettings: JoplinClipperSettings,
        generate: (PDFPageSize) async throws -> Data
    ) async throws -> PDFReportExportResult? {
        let pageSize = PDFReportPersistence.currentPagePreference().pageSize
        let generated = try await generate(pageSize)
        let folder = try PDFReportPersistence.reportsFolderURL()
        let suggested = PDFReportPersistence.suggestedFileName(chartName: chartName, reportType: reportType)
        guard let destination = await chooseDestination(defaultFolder: folder, suggestedName: suggested) else {
            return nil
        }
        let savedURL = try PDFReportPersistence.save(pdfData: generated, to: destination)

        if PDFReportPersistence.shouldUploadToJoplin() {
            try await JoplinClipperService(settings: joplinSettings).createNoteWithPDFResource(
                title: "PDF — \(chartName) — \(reportType)",
                body: "Informe PDF generado por AstroMalik: [\(savedURL.lastPathComponent)](:/resource)",
                fileURL: savedURL
            )
        }

        if PDFReportPersistence.shouldOpenAutomatically() {
            NSWorkspace.shared.open(savedURL)
        }
        return PDFReportExportResult(url: savedURL)
    }

    private static func chooseDestination(defaultFolder: URL, suggestedName: String) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSSavePanel()
            panel.title = "Guardar informe PDF"
            panel.nameFieldStringValue = suggestedName
            panel.directoryURL = defaultFolder
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}

@MainActor
final class PDFReportLastJobStore: ObservableObject {
    static let shared = PDFReportLastJobStore()

    @Published private(set) var lastJob: PDFReportLastJob?

    private init() {}

    func remember(
        chartName: String,
        reportType: String,
        generate: @escaping (PDFPageSize) async throws -> Data
    ) {
        lastJob = PDFReportLastJob(chartName: chartName, reportType: reportType, generate: generate)
    }
}

struct PDFReportLastJob: Identifiable {
    let id = UUID()
    let chartName: String
    let reportType: String
    let generate: (PDFPageSize) async throws -> Data

    var label: String { "\(chartName) — \(reportType)" }
}
