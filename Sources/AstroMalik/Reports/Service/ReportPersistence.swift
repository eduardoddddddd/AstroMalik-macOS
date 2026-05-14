import Foundation

struct PDFReportFile: Identifiable, Equatable, Sendable {
    let url: URL
    let name: String
    let modifiedAt: Date
    let sizeBytes: Int64

    var id: String { url.path }
}

enum PDFReportPagePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case a4
    case letter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        }
    }

    var pageSize: PDFPageSize {
        switch self {
        case .a4: return .a4Portrait
        case .letter: return .letter
        }
    }
}

enum PDFReportPreferenceKeys {
    static let defaultFolderBookmark = "pdfReportsDefaultFolderBookmark"
    static let uploadToJoplin = "pdfReportsUploadToJoplin"
    static let openAutomatically = "pdfReportsOpenAutomatically"
    static let pageSize = "pdfReportsPageSize"
}

enum PDFReportPersistenceError: LocalizedError, Equatable {
    case invalidBookmark
    case notDirectory(URL)
    case invalidFileName

    var errorDescription: String? {
        switch self {
        case .invalidBookmark:
            return "No se pudo resolver la carpeta configurada para informes PDF."
        case .notDirectory(let url):
            return "La ruta configurada no es una carpeta: \(url.path)"
        case .invalidFileName:
            return "No se pudo construir un nombre de archivo válido para el informe."
        }
    }
}

enum PDFReportPersistence {
    static let defaultFolderName = "AstroMalik"

    static var defaultReportsFolderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(defaultFolderName, isDirectory: true)
    }

    static func reportsFolderURL(defaults: UserDefaults = .standard) throws -> URL {
        if let data = defaults.data(forKey: PDFReportPreferenceKeys.defaultFolderBookmark), !data.isEmpty {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                if stale {
                    try storeReportsFolder(url, defaults: defaults)
                }
                try ensureDirectory(url)
                return url
            } catch {
                throw PDFReportPersistenceError.invalidBookmark
            }
        }

        let url = defaultReportsFolderURL
        try ensureDirectory(url)
        return url
    }

    static func storeReportsFolder(_ url: URL, defaults: UserDefaults = .standard) throws {
        try ensureDirectory(url)
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: PDFReportPreferenceKeys.defaultFolderBookmark)
    }

    static func suggestedFileName(chartName: String, reportType: String, date: Date = Date()) -> String {
        let name = sanitizedComponent(chartName, fallback: "Carta")
        let type = sanitizedComponent(reportType, fallback: "Informe")
        let day = fileDateFormatter.string(from: date)
        return "\(name) - \(type) - \(day).pdf"
    }

    @discardableResult
    static func save(pdfData: Data, to url: URL) throws -> URL {
        let directory = url.deletingLastPathComponent()
        try ensureDirectory(directory)
        guard !url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDFReportPersistenceError.invalidFileName
        }
        try pdfData.write(to: url, options: [.atomic])
        return url
    }

    @discardableResult
    static func save(pdfData: Data, fileName: String, in folder: URL) throws -> URL {
        try ensureDirectory(folder)
        let cleanName = sanitizedFileName(fileName)
        guard !cleanName.isEmpty else { throw PDFReportPersistenceError.invalidFileName }
        return try save(pdfData: pdfData, to: folder.appendingPathComponent(cleanName))
    }

    static func listPDFs(in folder: URL) throws -> [PDFReportFile] {
        try ensureDirectory(folder)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .compactMap { url in
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile != false else { return nil }
                return PDFReportFile(
                    url: url,
                    name: url.lastPathComponent,
                    modifiedAt: values.contentModificationDate ?? .distantPast,
                    sizeBytes: Int64(values.fileSize ?? 0)
                )
            }
            .sorted {
                if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    static func currentPagePreference(defaults: UserDefaults = .standard) -> PDFReportPagePreference {
        guard let raw = defaults.string(forKey: PDFReportPreferenceKeys.pageSize),
              let value = PDFReportPagePreference(rawValue: raw) else {
            return .a4
        }
        return value
    }

    static func shouldUploadToJoplin(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: PDFReportPreferenceKeys.uploadToJoplin)
    }

    static func shouldOpenAutomatically(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: PDFReportPreferenceKeys.openAutomatically) == nil { return true }
        return defaults.bool(forKey: PDFReportPreferenceKeys.openAutomatically)
    }

    private static func ensureDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw PDFReportPersistenceError.notDirectory(url) }
            return
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func sanitizedComponent(_ value: String, fallback: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = value.components(separatedBy: forbidden)
            .joined(separator: "-")
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? fallback : cleaned
    }

    static func sanitizedFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let components = value.components(separatedBy: forbidden)
        let joined = components.joined(separator: "-")
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return joined.isEmpty ? "Informe.pdf" : (joined.lowercased().hasSuffix(".pdf") ? joined : joined + ".pdf")
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension ReportRequest {
    func withPageSize(_ pageSize: PDFPageSize) -> ReportRequest<Payload> {
        ReportRequest(templateName: templateName, data: data, pageSize: pageSize, landscape: landscape)
    }
}
