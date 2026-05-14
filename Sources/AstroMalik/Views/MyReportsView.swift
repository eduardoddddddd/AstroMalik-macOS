import SwiftUI
import AppKit

struct MyReportsView: View {
    @State private var reports: [PDFReportFile] = []
    @State private var errorMessage: String?
    @State private var folderURL: URL = PDFReportPersistence.defaultReportsFolderURL

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color.appBackground)
        .navigationTitle("Mis informes")
        .task { reload() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mis informes")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                Text(folderURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button { reload() } label: {
                Label("Refrescar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            Button { NSWorkspace.shared.activateFileViewerSelecting([folderURL]) } label: {
                Label("Ver carpeta", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.appWarning)
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reports.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No hay PDFs en la carpeta de informes.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Exporta un informe o cambia la carpeta en Ajustes > Informes PDF.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(reports) { report in
                Button {
                    NSWorkspace.shared.open(report.url)
                } label: {
                    reportRow(report)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Abrir") { NSWorkspace.shared.open(report.url) }
                    Button("Revelar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([report.url]) }
                    Divider()
                    Button("Eliminar", role: .destructive) { delete(report) }
                }
            }
            .listStyle(.inset)
        }
    }

    private func reportRow(_ report: PDFReportFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title3)
                .foregroundColor(.appAccentFill)
            VStack(alignment: .leading, spacing: 3) {
                Text(report.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.appPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(format(report.modifiedAt)) · \(formatBytes(report.sizeBytes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func reload() {
        do {
            folderURL = try PDFReportPersistence.reportsFolderURL()
            reports = try PDFReportPersistence.listPDFs(in: folderURL)
            errorMessage = nil
        } catch {
            reports = []
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ report: PDFReportFile) {
        do {
            try FileManager.default.removeItem(at: report.url)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func format(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
