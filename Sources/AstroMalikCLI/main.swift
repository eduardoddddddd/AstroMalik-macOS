import Foundation
import AstroMalik

let EX_USAGE: Int32 = 64

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

public enum CLIOutputDestination: Equatable {
    case stdout
    case file(String)
    case joplin(String)
}

public struct CLIOptions: Equatable {
    public var chartQuery: String
    public var referenceDate: Date
    public var scope: CLIScope
    public var model: CLIModel
    public var output: CLIOutputDestination
    public var userDBPath: String?
    public var corpusDBPath: String?
    public var verbose: Bool
}

public enum CLICommand: Equatable {
    case help
    case run(CLIOptions)
}

public enum CLIParseError: LocalizedError, Equatable {
    case missingValue(String)
    case unknownFlag(String)
    case missingChart
    case invalidDate(String)
    case invalidScope(String)
    case invalidModel(String)
    case invalidOutput(String)
    case positionalArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingValue(let flag): return "Falta valor para \(flag)."
        case .unknownFlag(let flag): return "Flag no reconocido: \(flag)."
        case .missingChart: return "Falta --chart <nombre|UUID>."
        case .invalidDate(let value): return "Fecha inválida para --date: \(value). Usa YYYY-MM-DD."
        case .invalidScope(let value): return "Scope inválido: \(value). Usa complete, annual, monthly o weekly."
        case .invalidModel(let value): return "Modelo inválido: \(value). Usa sonnet u opus."
        case .invalidOutput(let value): return "Output inválido: \(value). Usa stdout, file:/ruta.md o joplin:Cuaderno."
        case .positionalArgument(let value): return "Argumento posicional no permitido: \(value)."
        }
    }
}

public enum AstroMalikCLIParser {
    public static func parse(
        arguments: [String],
        defaultDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> CLICommand {
        var chartQuery: String?
        var referenceDate = startOfDay(defaultDate, calendar: calendar)
        var scope: CLIScope = .complete
        var model: CLIModel = .sonnet
        var output: CLIOutputDestination = .stdout
        var notebook: String?
        var userDBPath: String?
        var corpusDBPath: String?
        var verbose = false

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help", "-h":
                return .help
            case "--verbose":
                verbose = true
                index += 1
            case "--chart":
                chartQuery = try value(after: arg, in: arguments, index: &index)
            case "--date":
                let raw = try value(after: arg, in: arguments, index: &index)
                guard let parsed = parseDate(raw, calendar: calendar) else {
                    throw CLIParseError.invalidDate(raw)
                }
                referenceDate = parsed
            case "--scope":
                let raw = try value(after: arg, in: arguments, index: &index)
                guard let parsed = CLIScope(rawValue: raw) else {
                    throw CLIParseError.invalidScope(raw)
                }
                scope = parsed
            case "--model":
                let raw = try value(after: arg, in: arguments, index: &index)
                guard let parsed = CLIModel(rawValue: raw) else {
                    throw CLIParseError.invalidModel(raw)
                }
                model = parsed
            case "--output":
                let raw = try value(after: arg, in: arguments, index: &index)
                output = try parseOutput(raw)
            case "--notebook":
                notebook = try value(after: arg, in: arguments, index: &index)
            case "--user-db":
                userDBPath = try value(after: arg, in: arguments, index: &index)
            case "--corpus-db":
                corpusDBPath = try value(after: arg, in: arguments, index: &index)
            default:
                if arg.hasPrefix("--") { throw CLIParseError.unknownFlag(arg) }
                throw CLIParseError.positionalArgument(arg)
            }
        }

        if let notebook { output = .joplin(notebook) }
        guard let chartQuery, !chartQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIParseError.missingChart
        }

        return .run(CLIOptions(
            chartQuery: chartQuery,
            referenceDate: referenceDate,
            scope: scope,
            model: model,
            output: output,
            userDBPath: userDBPath,
            corpusDBPath: corpusDBPath,
            verbose: verbose
        ))
    }

    public static func parseOutput(_ raw: String) throws -> CLIOutputDestination {
        if raw == "stdout" { return .stdout }
        if raw.hasPrefix("file:") {
            let path = String(raw.dropFirst("file:".count))
            guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CLIParseError.invalidOutput(raw)
            }
            return .file(path)
        }
        if raw.hasPrefix("joplin:") {
            let notebook = String(raw.dropFirst("joplin:".count))
            guard !notebook.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CLIParseError.invalidOutput(raw)
            }
            return .joplin(notebook)
        }
        throw CLIParseError.invalidOutput(raw)
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

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}

@discardableResult
private func fputsStderr(_ message: String) -> Int32 {
    fputs(message + "\n", stderr)
}

private func printHelp() {
    print("""
    astromalik-cli — genera informes cross-personal end-to-end

    Uso:
      astromalik-cli --chart <nombre|UUID> [opciones]

    Opciones:
      --chart <nombre|UUID>     Obligatorio. Busca primero por nombre exacto y luego por UUID en user.db.
      --date <YYYY-MM-DD>       Opcional. Default: hoy en zona local del Mac.
      --scope <complete|annual|monthly|weekly>  Default: complete.
      --model <sonnet|opus>     Default: sonnet.
      --output <destino>        Default: stdout. Formatos: stdout, file:/ruta/fichero.md, joplin:Cuaderno.
      --notebook <nombre>       Conveniencia equivalente a --output joplin:<nombre>.
      --user-db <ruta>          Default: ~/Library/Application Support/AstroMalik/user.db.
      --corpus-db <ruta>        Default: copia writable de corpus.db desde el bundle.
      --verbose                 Logs detallados a stderr.
      --help                    Muestra esta ayuda y sale 0.
    """)
}

private func map(_ options: CLIOptions) -> AstroMalikCLIRequest {
    AstroMalikCLIRequest(
        chartQuery: options.chartQuery,
        referenceDate: options.referenceDate,
        scope: AstroMalikCLIScope(rawValue: options.scope.rawValue) ?? .complete,
        model: AstroMalikCLIModel(rawValue: options.model.rawValue) ?? .sonnet,
        output: map(options.output),
        userDBPath: options.userDBPath,
        corpusDBPath: options.corpusDBPath,
        verbose: options.verbose
    )
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
        let formatter = ISO8601DateFormatter()
        fputsStderr("[astromalik-cli] inicio chart=\(options.chartQuery) scope=\(options.scope.rawValue) model=\(options.model.rawValue) at=\(formatter.string(from: start))")
        do {
            let result = try await AstroMalikCLIRunner.run(request: map(options)) { line in
                fputsStderr(line)
            }
            if case .stdout = options.output {
                print(result.markdown)
            }
            let elapsed = Date().timeIntervalSince(start)
            fputsStderr(String(format: "[astromalik-cli] fin output=%@ model=%@ coste=$%.4f elapsed=%.1fs", result.outputDescription, result.model, result.estimatedCostUSD, elapsed))
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
