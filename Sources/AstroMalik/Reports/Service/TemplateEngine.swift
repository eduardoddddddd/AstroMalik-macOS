import Foundation

typealias PartialLoader = (String) throws -> String

enum TemplateError: Error, Equatable, LocalizedError {
    case unknownVariable(String)
    case malformedSyntax(line: Int)
    case missingPartial(name: String)

    var errorDescription: String? {
        switch self {
        case .unknownVariable(let name):
            return "Variable de plantilla desconocida: \(name)"
        case .malformedSyntax(let line):
            return "Sintaxis de plantilla mal formada en la línea \(line)."
        case .missingPartial(let name):
            return "Partial de plantilla no encontrado: \(name)"
        }
    }
}

struct TemplateEngine {
    private let partialLoader: PartialLoader
    private let maxPartialDepth = 32

    init(partialLoader: @escaping PartialLoader = { name in throw TemplateError.missingPartial(name: name) }) {
        self.partialLoader = partialLoader
    }

    func render(template: String, context: [String: Any]) throws -> String {
        var parser = TemplateParser(template: template)
        let nodes = try parser.parse()
        let renderContext = TemplateRenderContext(frames: [context])
        return try render(nodes: nodes, context: renderContext, partialDepth: 0)
    }

    private func render(
        nodes: [TemplateNode],
        context: TemplateRenderContext,
        partialDepth: Int
    ) throws -> String {
        var output = ""

        for node in nodes {
            switch node {
            case .text(let text):
                output += text

            case .variable(let path, let escaped):
                let value = try context.resolve(path, strict: true)
                let string = stringify(value)
                output += escaped ? Self.escapeHTML(string) : string

            case .each(let path, let children):
                guard let value = try context.resolve(path, strict: false),
                      let items = Self.array(from: value) else { continue }
                for item in items {
                    output += try render(
                        nodes: children,
                        context: context.pushing(item: item),
                        partialDepth: partialDepth
                    )
                }

            case .ifSection(let path, let children):
                let value = try context.resolve(path, strict: false)
                if Self.isTruthy(value) {
                    output += try render(nodes: children, context: context, partialDepth: partialDepth)
                }

            case .unlessSection(let path, let children):
                let value = try context.resolve(path, strict: false)
                if !Self.isTruthy(value) {
                    output += try render(nodes: children, context: context, partialDepth: partialDepth)
                }

            case .partial(let name):
                guard partialDepth < maxPartialDepth else {
                    throw TemplateError.malformedSyntax(line: 1)
                }
                let partialTemplate: String
                do {
                    partialTemplate = try partialLoader(name)
                } catch TemplateError.missingPartial {
                    throw TemplateError.missingPartial(name: name)
                } catch {
                    throw TemplateError.missingPartial(name: name)
                }

                var parser = TemplateParser(template: partialTemplate)
                let partialNodes = try parser.parse()
                output += try render(nodes: partialNodes, context: context, partialDepth: partialDepth + 1)
            }
        }

        return output
    }

    private static func escapeHTML(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func stringify(_ value: Any?) -> String {
        guard let value = TemplateRenderContext.unwrapOptional(value), !(value is NSNull) else { return "" }
        if let string = value as? String { return string }
        if let character = value as? Character { return String(character) }
        if let number = value as? NSNumber { return number.stringValue }
        if let value = value as? CustomStringConvertible { return value.description }
        return String(describing: value)
    }

    private static func array(from value: Any) -> [Any]? {
        guard let unwrapped = TemplateRenderContext.unwrapOptional(value), !(unwrapped is NSNull) else {
            return nil
        }
        if let array = unwrapped as? [Any] { return array }
        if let strings = unwrapped as? [String] { return strings.map { $0 as Any } }
        if let dictionaries = unwrapped as? [[String: Any]] { return dictionaries.map { $0 as Any } }
        return nil
    }

    private static func isTruthy(_ value: Any?) -> Bool {
        guard let value = TemplateRenderContext.unwrapOptional(value), !(value is NSNull) else { return false }
        if let bool = value as? Bool { return bool }
        if let string = value as? String { return !string.isEmpty }
        if let array = value as? [Any] { return !array.isEmpty }
        if let dictionary = value as? [String: Any] { return !dictionary.isEmpty }
        if let number = value as? NSNumber { return number.doubleValue != 0 }
        return true
    }
}

private indirect enum TemplateNode {
    case text(String)
    case variable(path: String, escaped: Bool)
    case each(path: String, children: [TemplateNode])
    case ifSection(path: String, children: [TemplateNode])
    case unlessSection(path: String, children: [TemplateNode])
    case partial(name: String)
}

private struct TemplateParser {
    let template: String
    var index: String.Index

    init(template: String) {
        self.template = template
        self.index = template.startIndex
    }

    mutating func parse(until expectedClosingTag: String? = nil) throws -> [TemplateNode] {
        var nodes: [TemplateNode] = []

        while index < template.endIndex {
            guard let openRange = template.range(of: "{{", range: index..<template.endIndex) else {
                if index < template.endIndex {
                    nodes.append(.text(String(template[index..<template.endIndex])))
                }
                index = template.endIndex
                if expectedClosingTag != nil {
                    throw TemplateError.malformedSyntax(line: lineNumber(at: template.endIndex))
                }
                return nodes
            }

            if openRange.lowerBound > index {
                nodes.append(.text(String(template[index..<openRange.lowerBound])))
            }

            if template[openRange.lowerBound...].hasPrefix("{{{") {
                try parseTripleMustache(openAt: openRange.lowerBound, into: &nodes)
                continue
            }

            let tagContentStart = openRange.upperBound
            guard let closeRange = template.range(of: "}}", range: tagContentStart..<template.endIndex) else {
                throw TemplateError.malformedSyntax(line: lineNumber(at: openRange.lowerBound))
            }

            let tag = String(template[tagContentStart..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else {
                throw TemplateError.malformedSyntax(line: lineNumber(at: openRange.lowerBound))
            }

            index = closeRange.upperBound

            if tag.hasPrefix("/") {
                if let expectedClosingTag, tag == expectedClosingTag {
                    return nodes
                }
                throw TemplateError.malformedSyntax(line: lineNumber(at: openRange.lowerBound))
            }

            if tag.hasPrefix("#each") {
                let path = try sectionPath(from: tag, prefix: "#each", line: lineNumber(at: openRange.lowerBound))
                let children = try parse(until: "/each")
                nodes.append(.each(path: path, children: children))
            } else if tag.hasPrefix("#if") {
                let path = try sectionPath(from: tag, prefix: "#if", line: lineNumber(at: openRange.lowerBound))
                let children = try parse(until: "/if")
                nodes.append(.ifSection(path: path, children: children))
            } else if tag.hasPrefix("#unless") {
                let path = try sectionPath(from: tag, prefix: "#unless", line: lineNumber(at: openRange.lowerBound))
                let children = try parse(until: "/unless")
                nodes.append(.unlessSection(path: path, children: children))
            } else if tag.hasPrefix(">") {
                let name = tag.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    throw TemplateError.malformedSyntax(line: lineNumber(at: openRange.lowerBound))
                }
                nodes.append(.partial(name: name))
            } else if tag.hasPrefix("#") {
                throw TemplateError.malformedSyntax(line: lineNumber(at: openRange.lowerBound))
            } else {
                nodes.append(.variable(path: tag, escaped: true))
            }
        }

        if expectedClosingTag != nil {
            throw TemplateError.malformedSyntax(line: lineNumber(at: template.endIndex))
        }
        return nodes
    }

    private mutating func parseTripleMustache(
        openAt openIndex: String.Index,
        into nodes: inout [TemplateNode]
    ) throws {
        let contentStart = template.index(openIndex, offsetBy: 3)
        guard let closeRange = template.range(of: "}}}", range: contentStart..<template.endIndex) else {
            throw TemplateError.malformedSyntax(line: lineNumber(at: openIndex))
        }
        let tag = String(template[contentStart..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty,
              !tag.hasPrefix("#"),
              !tag.hasPrefix("/"),
              !tag.hasPrefix(">") else {
            throw TemplateError.malformedSyntax(line: lineNumber(at: openIndex))
        }
        nodes.append(.variable(path: tag, escaped: false))
        index = closeRange.upperBound
    }

    private func sectionPath(from tag: String, prefix: String, line: Int) throws -> String {
        guard tag == prefix || tag.hasPrefix(prefix + " ") || tag.hasPrefix(prefix + "\t") else {
            throw TemplateError.malformedSyntax(line: line)
        }
        let start = tag.index(tag.startIndex, offsetBy: prefix.count)
        let path = tag[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { throw TemplateError.malformedSyntax(line: line) }
        return path
    }

    private func lineNumber(at position: String.Index) -> Int {
        var line = 1
        var cursor = template.startIndex
        while cursor < position && cursor < template.endIndex {
            if template[cursor] == "\n" { line += 1 }
            cursor = template.index(after: cursor)
        }
        return line
    }
}

private struct TemplateRenderContext {
    let frames: [[String: Any]]

    func pushing(item: Any) -> TemplateRenderContext {
        let unwrapped = Self.unwrapOptional(item) ?? NSNull()
        var frame: [String: Any]
        if let dictionary = unwrapped as? [String: Any] {
            frame = dictionary
        } else {
            frame = [:]
        }
        frame["."] = unwrapped
        frame["this"] = unwrapped
        return TemplateRenderContext(frames: frames + [frame])
    }

    func resolve(_ path: String, strict: Bool) throws -> Any? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if strict { throw TemplateError.unknownVariable(path) }
            return nil
        }

        if trimmed == "." {
            if let current = frames.reversed().compactMap({ $0["."] }).first {
                return current
            }
            if strict { throw TemplateError.unknownVariable(path) }
            return nil
        }

        let components = trimmed.split(separator: ".").map(String.init)
        guard let first = components.first else {
            if strict { throw TemplateError.unknownVariable(path) }
            return nil
        }

        for frame in frames.reversed() {
            guard var current = frame[first] else { continue }
            current = Self.unwrapOptional(current) ?? NSNull()
            var found = true
            for component in components.dropFirst() {
                guard let next = Self.child(named: component, in: current) else {
                    found = false
                    break
                }
                current = Self.unwrapOptional(next) ?? NSNull()
            }
            if found { return current }
        }

        if strict { throw TemplateError.unknownVariable(path) }
        return nil
    }

    static func unwrapOptional(_ value: Any?) -> Any? {
        guard let value else { return nil }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }

    private static func child(named key: String, in value: Any) -> Any? {
        guard let unwrapped = unwrapOptional(value), !(unwrapped is NSNull) else { return nil }
        if let dictionary = unwrapped as? [String: Any] {
            return dictionary[key]
        }
        if let dictionary = unwrapped as? [String: String] {
            return dictionary[key]
        }
        if let array = unwrapped as? [Any], let index = Int(key), array.indices.contains(index) {
            return array[index]
        }
        if let array = unwrapped as? [String], let index = Int(key), array.indices.contains(index) {
            return array[index]
        }
        return nil
    }
}
