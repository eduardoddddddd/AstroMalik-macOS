import Foundation

struct ReportRequest<Payload: Codable>: Sendable where Payload: Sendable {
    let templateName: String
    let data: Payload
    let pageSize: PDFPageSize
    let landscape: Bool

    init(
        templateName: String,
        data: Payload,
        pageSize: PDFPageSize = .a4Portrait,
        landscape: Bool = false
    ) {
        self.templateName = templateName
        self.data = data
        self.pageSize = pageSize
        self.landscape = landscape
    }
}

actor ReportService {
    private let bundle: Bundle
    private let renderer: ReportRenderer

    init(bundle: Bundle = AppResources.bundle, renderer: ReportRenderer = ReportRenderer()) {
        self.bundle = bundle
        self.renderer = renderer
    }

    func generate<Payload: Codable & Sendable>(
        request: ReportRequest<Payload>,
        extraPartials: [String: String] = [:]
    ) async throws -> Foundation.Data {
        let html = try renderHTML(request: request, extraPartials: extraPartials)
        let effectivePageSize: PDFPageSize = request.landscape ? .a4Landscape : request.pageSize
        return try await renderer.render(html: html, pageSize: effectivePageSize, margins: .standard)
    }

    /// Renderiza solo HTML. Útil para pruebas rápidas de plantillas sin invocar WebKit.
    func renderHTML<Payload: Codable & Sendable>(
        request: ReportRequest<Payload>,
        extraPartials: [String: String] = [:]
    ) throws -> String {
        let template = try loadTemplate(named: request.templateName)
        let context = try makeContext(from: request.data)
        let loader = makePartialLoader(extraPartials: extraPartials)
        let engine = TemplateEngine(partialLoader: loader)
        return try engine.render(template: template, context: context)
    }

    private func makeContext<Payload: Codable>(from payload: Payload) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(payload)
        let object = try JSONSerialization.jsonObject(with: encoded, options: [])

        var context: [String: Any]
        if let dictionary = object as? [String: Any] {
            context = dictionary
        } else {
            context = ["data": object]
        }

        if context["generatedDate"] == nil,
           let header = context["header"] as? [String: Any],
           let generatedDate = header["generatedDate"] {
            context["generatedDate"] = generatedDate
        }

        return context
    }

    private func makePartialLoader(extraPartials: [String: String]) -> PartialLoader {
        { name in
            for key in Self.partialCandidateKeys(for: name) {
                if let partial = extraPartials[key] { return partial }
            }

            for resourceName in Self.partialCandidateResourceNames(for: name) {
                if let partial = try? self.loadTemplate(named: resourceName) {
                    return partial
                }
            }

            throw TemplateError.missingPartial(name: name)
        }
    }

    private func loadTemplate(named name: String) throws -> String {
        let normalized = Self.normalizedTemplateName(name)
        for subdirectory in ["Reports/templates", "Reports/Templates"] {
            if let url = bundle.url(forResource: normalized, withExtension: "html", subdirectory: subdirectory) {
                return try String(contentsOf: url, encoding: .utf8)
            }
        }

        for directory in Self.sourceTemplateDirectories() {
            let sourceURL = directory
                .appendingPathComponent(normalized)
                .appendingPathExtension("html")
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                return try String(contentsOf: sourceURL, encoding: .utf8)
            }
        }

        throw TemplateError.missingPartial(name: name)
    }

    private static func normalizedTemplateName(_ name: String) -> String {
        var normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix(".html") {
            normalized.removeLast(".html".count)
        }
        return normalized
    }

    private static func partialCandidateKeys(for name: String) -> [String] {
        var keys: [String] = []
        func append(_ value: String) {
            if !keys.contains(value) { keys.append(value) }
        }

        append(name)
        append(normalizedTemplateName(name))
        append(normalizedTemplateName(name) + ".html")

        for resourceName in partialCandidateResourceNames(for: name) {
            append(resourceName)
            append(resourceName + ".html")
        }
        return keys
    }

    private static func partialCandidateResourceNames(for name: String) -> [String] {
        let normalized = normalizedTemplateName(name)
        var names: [String] = []
        func append(_ value: String) {
            if !names.contains(value) { names.append(value) }
        }

        append(normalized)
        if normalized.hasSuffix("_css") {
            var dotted = normalized
            dotted.removeLast("_css".count)
            dotted += ".css"
            append(dotted)
        }
        return names
    }

    private static func sourceTemplateDirectories() -> [URL] {
        let astroMalikDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Service
            .deletingLastPathComponent() // Reports
            .deletingLastPathComponent() // AstroMalik
        return [
            astroMalikDirectory.appendingPathComponent("Resources/Reports/templates"),
            astroMalikDirectory.appendingPathComponent("Reports/Templates"),
        ]
    }
}
