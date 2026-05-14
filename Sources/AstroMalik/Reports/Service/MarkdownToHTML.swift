import Foundation

/// Convertidor minimalista de Markdown a HTML para incrustar la
/// narrativa generada por Anthropic dentro de las plantillas PDF.
///
/// Soporta sólo lo que el prompt narrativo produce de forma
/// determinista:
/// - Encabezados `# h1`, `## h2`, `### h3`.
/// - Párrafos separados por línea en blanco.
/// - Listas no ordenadas con `- ` o `* ` al inicio de línea.
/// - Énfasis `**negrita**` y `*cursiva*`.
/// - `código inline` con backticks.
///
/// No procesa tablas, bloques de código, blockquotes ni enlaces (el
/// prompt los prohíbe). El HTML escape se aplica antes de procesar
/// énfasis para evitar inyección.
enum MarkdownToHTML {

    static func convert(_ markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        var html = ""
        var paragraphBuffer: [String] = []
        var listBuffer: [String] = []
        var inList = false

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let joined = paragraphBuffer.joined(separator: " ")
            html += "<p>\(processInline(joined))</p>\n"
            paragraphBuffer = []
        }

        func flushList() {
            guard inList else { return }
            html += "<ul>\n"
            for item in listBuffer {
                html += "  <li>\(processInline(item))</li>\n"
            }
            html += "</ul>\n"
            listBuffer = []
            inList = false
        }

        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            if let level = headingLevel(of: line) {
                flushParagraph()
                flushList()
                let content = String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
                html += "<h\(level)>\(processInline(content))</h\(level)>\n"
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                inList = true
                let item = String(line.dropFirst(2))
                listBuffer.append(item)
                continue
            }

            if inList {
                flushList()
            }
            paragraphBuffer.append(line)
        }

        flushParagraph()
        flushList()

        return html
    }

    /// Parte un Markdown en secciones por encabezados `## h2`.
    /// Devuelve un diccionario título-normalizado → HTML del cuerpo de
    /// la sección. El título se normaliza a minúsculas sin tildes y sin
    /// puntuación final, para encajarlo con keys deterministas.
    static func sectionsByH2(_ markdown: String) -> [String: String] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        var sections: [String: String] = [:]
        var currentTitle: String? = nil
        var currentBody: [String] = []

        func flush() {
            guard let title = currentTitle else { return }
            let body = currentBody.joined(separator: "\n")
            sections[normalize(title)] = convert(body)
            currentBody = []
        }

        for line in normalized.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                flush()
                currentTitle = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else {
                currentBody.append(line)
            }
        }
        flush()
        return sections
    }

    /// Normaliza un título para usar como key de sección.
    static func normalize(_ title: String) -> String {
        let lower = title.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let cleaned = lower.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespaces).contains($0) }
        let collapsed = String(String.UnicodeScalarView(cleaned))
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return collapsed
    }

    // MARK: - Internals

    private static func headingLevel(of line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        var count = 0
        for char in line {
            if char == "#" { count += 1 } else { break }
        }
        guard (1...6).contains(count) else { return nil }
        let afterHashes = line.dropFirst(count)
        guard afterHashes.first == " " else { return nil }
        return count
    }

    private static func processInline(_ text: String) -> String {
        let escaped = htmlEscape(text)
        var result = escaped
        result = applyPairedDelimiter(result, delimiter: "**", openTag: "<strong>", closeTag: "</strong>")
        result = applyPairedDelimiter(result, delimiter: "*", openTag: "<em>", closeTag: "</em>")
        result = applyPairedDelimiter(result, delimiter: "`", openTag: "<code>", closeTag: "</code>")
        return result
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func applyPairedDelimiter(_ input: String, delimiter: String, openTag: String, closeTag: String) -> String {
        var output = ""
        var rest = Substring(input)
        var open = true
        while let range = rest.range(of: delimiter) {
            output += rest[..<range.lowerBound]
            output += open ? openTag : closeTag
            open.toggle()
            rest = rest[range.upperBound...]
        }
        output += rest
        if !open {
            // delimitador impar: cerramos para no dejar HTML inválido
            output += closeTag
        }
        return output
    }
}
