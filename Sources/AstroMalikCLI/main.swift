import Foundation
import AstroMalik

let EX_USAGE: Int32 = 64

public enum CLIFormat: String, Equatable {
    case json
    case markdown
}

public enum CLIModel: String, Equatable {
    case sonnet
    case opus
}

public enum CLIScope: String, Equatable {
    case complete
    case annual
    case monthly
    case weekly
}

public enum CLINarrative: String, Equatable {
    case none
    case local
    case anthropic
    case openrouter
}

public enum CLICommandKind: Equatable {
    case chartsList
    case chartShow
    case natal
    case transits
    case monthly
    case weekly
    case crossPersonal
    case profections
    case firdaria
    case zodiacalReleasing
    case progressions
    case solarReturn
    case lunarReturn
    case primaryDirections
    case solarArc

    public var rawValue: String {
        switch self {
        case .chartsList: return "charts list"
        case .chartShow: return "chart show"
        case .natal: return "natal"
        case .transits: return "transits"
        case .monthly: return "monthly"
        case .weekly: return "weekly"
        case .crossPersonal: return "cross-personal"
        case .profections: return "profections"
        case .firdaria: return "firdaria"
        case .zodiacalReleasing: return "zodiacal-releasing"
        case .progressions: return "progressions"
        case .solarReturn: return "solar-return"
        case .lunarReturn: return "lunar-return"
        case .primaryDirections: return "primary-directions"
        case .solarArc: return "solar-arc"
        }
    }
}

public enum CLIOutputDestination: Equatable {
    case stdout
    case file(String)
    case joplin(String)
}

public struct CLIOptions: Equatable {
    public var command: CLICommandKind
    public var chartQuery: String?
    public var referenceDate: Date
    public var fromDate: Date?
    public var toDate: Date?
    public var month: String?
    public var scope: CLIScope
    public var model: CLIModel
    public var format: CLIFormat
    public var output: CLIOutputDestination
    public var userDBPath: String?
    public var corpusDBPath: String?
    public var verbose: Bool
    public var allowNetwork: Bool
    public var narrative: CLINarrative
}

public enum CLICommand: Equatable {
    case help
    case run(CLIOptions)
}

public enum CLIParseError: LocalizedError, Equatable {
    case missingValue(String)
    case unknownFlag(String)
    case missingChart
    case missingRange(String)
    case invalidDate(String)
    case invalidMonth(String)
    case invalidScope(String)
    case invalidModel(String)
    case invalidFormat(String)
    case invalidNarrative(String)
    case invalidOutput(String)
    case positionalArgument(String)
    case invalidCommand(String)
    case networkDenied(String)

    public var errorDescription: String? {
        switch self {
        case .missingValue(let flag): return "Falta valor para \(flag)."
        case .unknownFlag(let flag): return "Flag no reconocido: \(flag)."
        case .missingChart: return "Falta --chart <nombre|UUID>."
        case .missingRange(let command): return "Falta rango obligatorio para \(command)."
        case .invalidDate(let value): return "Fecha inválida: \(value). Usa YYYY-MM-DD."
        case .invalidMonth(let value): return "Mes inválido: \(value). Usa YYYY-MM."
        case .invalidScope(let value): return "Scope inválido: \(value). Usa complete, annual, monthly o weekly."
        case .invalidModel(let value): return "Modelo inválido: \(value). Usa sonnet u opus."
        case .invalidFormat(let value): return "Formato inválido: \(value). Usa json o markdown."
        case .invalidNarrative(let value): return "Narrative inválido: \(value). Usa none, local, anthropic u openrouter."
        case .invalidOutput(let value): return "Output inválido: \(value). Usa stdout, file:/ruta.md o joplin:Cuaderno."
        case .positionalArgument(let value): return "Argumento posicional no permitido: \(value)."
        case .invalidCommand(let value): return "Comando inválido: \(value)."
        case .networkDenied(let message): return message
        }
    }
}

public enum AstroMalikCLIParser {
    public static func parse(
        arguments: [String],
        defaultDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> CLICommand {
        if arguments.contains("--help") || arguments.contains("-h") { return .help }

        var remaining = arguments
        let command = try parseLeadingCommand(from: &remaining)
        var chartQuery: String?
        var referenceDate = startOfDay(defaultDate, calendar: calendar)
        var fromDate: Date?
        var toDate: Date?
        var month: String?
        var scope: CLIScope = .complete
        var model: CLIModel = .sonnet
        var format: CLIFormat = .json
        var output: CLIOutputDestination = .stdout
        var userDBPath: String?
        var corpusDBPath: String?
        var verbose = false
        var allowNetwork = false
        var narrative: CLINarrative = .none

        var index = 0
        while index < remaining.count {
            let arg = remaining[index]
            switch arg {
            case "--verbose":
                verbose = true
                index += 1
            case "--no-network":
                allowNetwork = false
                index += 1
            case "--allow-network":
                allowNetwork = true
                index += 1
            case "--chart":
                chartQuery = try value(after: arg, in: remaining, index: &index)
            case "--date":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = parseDate(raw, calendar: calendar) else { throw CLIParseError.invalidDate(raw) }
                referenceDate = parsed
            case "--from":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = parseDate(raw, calendar: calendar) else { throw CLIParseError.invalidDate(raw) }
                fromDate = parsed
            case "--to":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = parseDate(raw, calendar: calendar) else { throw CLIParseError.invalidDate(raw) }
                toDate = parsed
            case "--month":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard isValidMonth(raw) else { throw CLIParseError.invalidMonth(raw) }
                month = raw
            case "--scope":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = CLIScope(rawValue: raw) else { throw CLIParseError.invalidScope(raw) }
                scope = parsed
            case "--model":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = CLIModel(rawValue: raw) else { throw CLIParseError.invalidModel(raw) }
                model = parsed
            case "--format":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = CLIFormat(rawValue: raw) else { throw CLIParseError.invalidFormat(raw) }
                format = parsed
            case "--output":
                let raw = try value(after: arg, in: remaining, index: &index)
                output = try parseOutput(raw)
            case "--notebook":
                let notebook = try value(after: arg, in: remaining, index: &index)
                output = .joplin(notebook)
            case "--user-db":
                userDBPath = try value(after: arg, in: remaining, index: &index)
            case "--corpus-db":
                corpusDBPath = try value(after: arg, in: remaining, index: &index)
            case "--narrative", "--llm":
                let raw = try value(after: arg, in: remaining, index: &index)
                guard let parsed = CLINarrative(rawValue: raw) else { throw CLIParseError.invalidNarrative(raw) }
                narrative = parsed
            default:
                if arg.hasPrefix("--") { throw CLIParseError.unknownFlag(arg) }
                throw CLIParseError.positionalArgument(arg)
            }
        }

        if command.requiresChart {
            guard let chartQuery, !chartQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CLIParseError.missingChart }
        }
        if command == .transits && (fromDate == nil || toDate == nil) {
            throw CLIParseError.missingRange("transits: usa --from YYYY-MM-DD --to YYYY-MM-DD")
        }
        if command == .weekly && fromDate == nil {
            throw CLIParseError.missingRange("weekly: usa --from YYYY-MM-DD")
        }
        if command == .monthly && month == nil {
            let comps = calendar.dateComponents([.year, .month], from: referenceDate)
            if let year = comps.year, let m = comps.month { month = String(format: "%04d-%02d", year, m) }
        }
        if narrative == .anthropic && !allowNetwork {
            throw CLIParseError.networkDenied("La narrativa Anthropic requiere --allow-network y --narrative anthropic explícitos.")
        }
        if narrative == .openrouter && !allowNetwork {
            throw CLIParseError.networkDenied("La narrativa OpenRouter requiere --allow-network y --narrative openrouter explícitos.")
        }

        return .run(CLIOptions(
            command: command,
            chartQuery: chartQuery,
            referenceDate: referenceDate,
            fromDate: fromDate,
            toDate: toDate,
            month: month,
            scope: scope,
            model: model,
            format: format,
            output: output,
            userDBPath: userDBPath,
            corpusDBPath: corpusDBPath,
            verbose: verbose,
            allowNetwork: allowNetwork,
            narrative: narrative
        ))
    }

    public static func parseOutput(_ raw: String) throws -> CLIOutputDestination {
        if raw == "stdout" { return .stdout }
        if raw.hasPrefix("file:") {
            let path = String(raw.dropFirst("file:".count))
            guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CLIParseError.invalidOutput(raw) }
            return .file(path)
        }
        if raw.hasPrefix("joplin:") {
            let notebook = String(raw.dropFirst("joplin:".count))
            guard !notebook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CLIParseError.invalidOutput(raw) }
            return .joplin(notebook)
        }
        throw CLIParseError.invalidOutput(raw)
    }

    private static func parseLeadingCommand(from arguments: inout [String]) throws -> CLICommandKind {
        let valueFlags: Set<String> = [
            "--chart", "--date", "--from", "--to", "--month", "--scope", "--model",
            "--format", "--output", "--notebook", "--user-db", "--corpus-db", "--narrative", "--llm",
        ]

        var index = 0
        while index < arguments.count {
            let token = arguments[index]
            if valueFlags.contains(token) {
                index += 2
                continue
            }
            if token.hasPrefix("--") {
                index += 1
                continue
            }

            switch token {
            case "charts":
                guard index + 1 < arguments.count, arguments[index + 1] == "list" else {
                    throw CLIParseError.invalidCommand("charts requiere subcomando list")
                }
                arguments.remove(at: index + 1)
                arguments.remove(at: index)
                return .chartsList
            case "chart":
                guard index + 1 < arguments.count, arguments[index + 1] == "show" else {
                    throw CLIParseError.invalidCommand("chart requiere subcomando show")
                }
                arguments.remove(at: index + 1)
                arguments.remove(at: index)
                return .chartShow
            case "natal": arguments.remove(at: index); return .natal
            case "transits": arguments.remove(at: index); return .transits
            case "monthly": arguments.remove(at: index); return .monthly
            case "weekly": arguments.remove(at: index); return .weekly
            case "cross-personal": arguments.remove(at: index); return .crossPersonal
            case "profections": arguments.remove(at: index); return .profections
            case "firdaria": arguments.remove(at: index); return .firdaria
            case "zodiacal-releasing": arguments.remove(at: index); return .zodiacalReleasing
            case "progressions": arguments.remove(at: index); return .progressions
            case "solar-return": arguments.remove(at: index); return .solarReturn
            case "lunar-return": arguments.remove(at: index); return .lunarReturn
            case "primary-directions": arguments.remove(at: index); return .primaryDirections
            case "solar-arc": arguments.remove(at: index); return .solarArc
            default: throw CLIParseError.invalidCommand(token)
            }
        }
        return .crossPersonal
    }

    private static func value(after flag: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else { throw CLIParseError.missingValue(flag) }
        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else { throw CLIParseError.missingValue(flag) }
        index += 2
        return value
    }

    private static func parseDate(_ raw: String, calendar: Calendar) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else { return nil }
        return date
    }

    private static func isValidMonth(_ raw: String) -> Bool {
        let parts = raw.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return false }
        return (1...9999).contains(year) && (1...12).contains(month)
    }

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}

private extension CLICommandKind {
    var requiresChart: Bool {
        switch self {
        case .chartsList: return false
        default: return true
        }
    }
}

@discardableResult
private func fputsStderr(_ message: String) -> Int32 {
    fputs(message + "\n", stderr)
}

private func printHelp() {
    print("""
    astromalik-cli — CLI local determinista para AstroMalik

    Filosofía por defecto:
      --format json --output stdout --narrative none --no-network
      Sin Anthropic, sin OpenRouter, sin coste y sin llamadas externas salvo flag explícito.

    Uso:
      astromalik-cli charts list [opciones]
      astromalik-cli chart show --chart <nombre|UUID> [opciones]
      astromalik-cli natal --chart <nombre|UUID> [opciones]
      astromalik-cli transits --chart <nombre|UUID> --from YYYY-MM-DD --to YYYY-MM-DD [opciones]
      astromalik-cli monthly --chart <nombre|UUID> --month YYYY-MM [opciones]
      astromalik-cli weekly --chart <nombre|UUID> --from YYYY-MM-DD [opciones]
      astromalik-cli cross-personal --chart <nombre|UUID> --date YYYY-MM-DD [opciones]

    Técnicas adicionales:
      profections | firdaria | zodiacal-releasing | progressions | solar-return | lunar-return | primary-directions | solar-arc

    Flags globales:
      --format <json|markdown>                Default: json.
      --output <stdout|file:/ruta|joplin:Cuaderno>  Default: stdout.
      --user-db <ruta>                        Default: ~/Library/Application Support/AstroMalik/user.db.
      --corpus-db <ruta>                      Default: copia writable de corpus.db desde bundle.
      --verbose                               Logs a stderr.
      --no-network                            Default; impide Anthropic/OpenRouter/Joplin.
      --allow-network                         Permite red solo para opciones explícitas.
      --narrative <none|local|anthropic|openrouter>  Default: none. Alias: --llm.
      --scope <complete|annual|monthly|weekly>       Para cross-personal. Default: complete.
      --model <sonnet|opus>                   Solo para Anthropic explícito.
      --help                                  Muestra ayuda.

    Ejemplos seguros:
      astromalik-cli charts list
      astromalik-cli natal --chart "Edu" --format markdown
      astromalik-cli transits --chart "Edu" --from 2026-06-15 --to 2026-06-21 --format json
      astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --format markdown --narrative none

    IA explícita con coste:
      astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --narrative anthropic --allow-network
    """)
}

private func map(_ options: CLIOptions) -> AstroMalikCLIRequest {
    AstroMalikCLIRequest(
        command: map(options.command),
        chartQuery: options.chartQuery,
        referenceDate: options.referenceDate,
        fromDate: options.fromDate,
        toDate: options.toDate,
        month: options.month,
        scope: AstroMalikCLIScope(rawValue: options.scope.rawValue) ?? .complete,
        model: AstroMalikCLIModel(rawValue: options.model.rawValue) ?? .sonnet,
        format: AstroMalikCLIFormat(rawValue: options.format.rawValue) ?? .json,
        output: map(options.output),
        userDBPath: options.userDBPath,
        corpusDBPath: options.corpusDBPath,
        verbose: options.verbose,
        allowNetwork: options.allowNetwork,
        narrative: AstroMalikCLINarrative(rawValue: options.narrative.rawValue) ?? .none
    )
}

private func map(_ command: CLICommandKind) -> AstroMalikCLICommandKind {
    switch command {
    case .chartsList: return .chartsList
    case .chartShow: return .chartShow
    case .natal: return .natal
    case .transits: return .transits
    case .monthly: return .monthly
    case .weekly: return .weekly
    case .crossPersonal: return .crossPersonal
    case .profections: return .profections
    case .firdaria: return .firdaria
    case .zodiacalReleasing: return .zodiacalReleasing
    case .progressions: return .progressions
    case .solarReturn: return .solarReturn
    case .lunarReturn: return .lunarReturn
    case .primaryDirections: return .primaryDirections
    case .solarArc: return .solarArc
    }
}

private func map(_ output: CLIOutputDestination) -> AstroMalikCLIOutput {
    switch output {
    case .stdout: return .stdout
    case .file(let path): return .file(path)
    case .joplin(let notebook): return .joplin(notebook)
    }
}

private func runMain() async -> Int32 {
    let rawArguments = Array(CommandLine.arguments.dropFirst())
    let command: CLICommand
    do {
        command = try AstroMalikCLIParser.parse(arguments: rawArguments)
    } catch {
        fputsStderr("astromalik-cli: \(error.localizedDescription)")
        fputsStderr("Usa --help para ver uso.")
        return EX_USAGE
    }

    switch command {
    case .help:
        printHelp()
        return 0
    case .run(let options):
        let start = Date()
        if options.verbose {
            let formatter = ISO8601DateFormatter()
            fputsStderr("[astromalik-cli] inicio command=\(options.command.rawValue) chart=\(options.chartQuery ?? "-") format=\(options.format.rawValue) narrative=\(options.narrative.rawValue) network=\(options.allowNetwork ? "allow" : "no") at=\(formatter.string(from: start))")
        }
        do {
            let result = try await AstroMalikCLIRunner.run(request: map(options)) { line in
                fputsStderr(line)
            }
            if case .stdout = options.output {
                print(result.content)
            }
            if options.verbose {
                let elapsed = Date().timeIntervalSince(start)
                fputsStderr(String(format: "[astromalik-cli] fin output=%@ model=%@ narrative=%@ networkUsed=%@ coste=$%.4f elapsed=%.1fs", result.outputDescription, result.model, result.narrative, result.networkUsed ? "true" : "false", result.estimatedCostUSD, elapsed))
            }
            return 0
        } catch let error as AstroMalikCLIRunnerError {
            fputsStderr("astromalik-cli: \(error.localizedDescription)")
            return error.exitCode
        } catch {
            fputsStderr("astromalik-cli: \(error.localizedDescription)")
            return 1
        }
    }
}

@main
private enum AstroMalikCLIEntrypoint {
    static func main() async {
        Foundation.exit(await runMain())
    }
}
