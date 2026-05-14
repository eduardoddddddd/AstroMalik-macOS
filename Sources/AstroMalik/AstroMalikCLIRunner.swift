import Foundation

// MARK: - Public facade for the standalone CLI

public enum AstroMalikCLIModel: String, Sendable {
    case sonnet
    case opus
}

public enum AstroMalikCLIScope: String, Sendable {
    case complete
    case annual
    case monthly
    case weekly
}

public enum AstroMalikCLIOutput: Equatable, Sendable {
    case stdout
    case file(String)
    case joplin(String)
}

public struct AstroMalikCLIRequest: Sendable {
    public var chartQuery: String
    public var referenceDate: Date
    public var scope: AstroMalikCLIScope
    public var model: AstroMalikCLIModel
    public var output: AstroMalikCLIOutput
    public var userDBPath: String?
    public var corpusDBPath: String?
    public var verbose: Bool

    public init(
        chartQuery: String,
        referenceDate: Date,
        scope: AstroMalikCLIScope,
        model: AstroMalikCLIModel,
        output: AstroMalikCLIOutput,
        userDBPath: String? = nil,
        corpusDBPath: String? = nil,
        verbose: Bool = false
    ) {
        self.chartQuery = chartQuery
        self.referenceDate = referenceDate
        self.scope = scope
        self.model = model
        self.output = output
        self.userDBPath = userDBPath
        self.corpusDBPath = corpusDBPath
        self.verbose = verbose
    }
}

public struct AstroMalikCLIResult: Sendable {
    public let markdown: String
    public let model: String
    public let estimatedCostUSD: Double
    public let outputDescription: String

    public init(markdown: String, model: String, estimatedCostUSD: Double, outputDescription: String) {
        self.markdown = markdown
        self.model = model
        self.estimatedCostUSD = estimatedCostUSD
        self.outputDescription = outputDescription
    }
}

public enum AstroMalikCLIRunnerError: LocalizedError, Sendable {
    case chartNotFound(String)
    case anthropic(String)
    case joplin(String)
    case io(String)
    case generic(String)

    public var errorDescription: String? {
        switch self {
        case .chartNotFound(let query):
            return "Carta no encontrada en user.db: \(query)"
        case .anthropic(let detail):
            return "Error de Anthropic: \(detail)"
        case .joplin(let detail):
            return "Error de Joplin: \(detail)"
        case .io(let detail):
            return "Error de I/O: \(detail)"
        case .generic(let detail):
            return detail
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .chartNotFound: return 2
        case .anthropic: return 3
        case .joplin: return 4
        case .io: return 5
        case .generic: return 1
        }
    }
}

public enum AstroMalikCLIRunner {
    public static func run(
        request: AstroMalikCLIRequest,
        log: @escaping (String) -> Void = { _ in }
    ) async throws -> AstroMalikCLIResult {
        do {
            if request.verbose { log("[cli] resolviendo rutas") }
            let userDBURL = try resolveUserDBURL(request.userDBPath)
            let corpusDBURL = try resolveCorpusDBURL(request.corpusDBPath)

            if request.verbose { log("[cli] configurando efemérides") }
            configureEphemeris()

            if request.verbose { log("[cli] cargando UserStore/user.db: \(userDBURL.path)") }
            let chart = try loadChart(query: request.chartQuery, userDBURL: userDBURL)

            if request.verbose { log("[cli] abriendo corpus: \(corpusDBURL.path)") }
            let corpusStore = try CorpusStore(path: corpusDBURL.path)

            if request.verbose { log("[cli] assemble → CrossPersonalAssembler.state") }
            let state = try await CrossPersonalAssembler.state(
                chart: chart,
                referenceDate: request.referenceDate,
                corpusStore: corpusStore
            )

            if request.verbose { log("[cli] builder → Anthropic \(request.model.rawValue)") }
            let client = AnthropicClient(config: request.model.anthropicConfig)
            guard client.hasAPIKey() else {
                throw AstroMalikCLIRunnerError.anthropic(AnthropicError.missingAPIKey.localizedDescription)
            }
            let builder = CrossPersonalNarrativeBuilder(client: client)
            let narrative = try await builder.build(state: state, scope: request.scope.narrativeScope)

            if request.verbose { log("[cli] output → \(request.output.descriptionForLogs)") }
            let outputDescription = try await write(narrative: narrative, to: request.output)

            return AstroMalikCLIResult(
                markdown: narrative.markdown,
                model: narrative.model,
                estimatedCostUSD: narrative.estimatedCostUSD,
                outputDescription: outputDescription
            )
        } catch let error as AstroMalikCLIRunnerError {
            throw error
        } catch let error as CrossPersonalNarrativeError {
            throw classifyNarrativeError(error)
        } catch let error as AnthropicError {
            throw AstroMalikCLIRunnerError.anthropic(error.localizedDescription)
        } catch let error as JoplinClipperError {
            throw AstroMalikCLIRunnerError.joplin(error.localizedDescription)
        } catch let error as CocoaError {
            throw AstroMalikCLIRunnerError.io(error.localizedDescription)
        } catch {
            throw AstroMalikCLIRunnerError.generic(error.localizedDescription)
        }
    }
}

// MARK: - Path resolution

private extension AstroMalikCLIRunner {
    static func resolveUserDBURL(_ override: String?) throws -> URL {
        let url: URL
        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            url = URL(fileURLWithPath: expandTilde(override))
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw AstroMalikCLIRunnerError.io("No se pudo localizar Application Support.")
            }
            url = appSupport
                .appendingPathComponent("AstroMalik", isDirectory: true)
                .appendingPathComponent("user.db")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AstroMalikCLIRunnerError.io("No existe user.db en \(url.path)")
        }
        return url
    }

    static func resolveCorpusDBURL(_ override: String?) throws -> URL {
        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: expandTilde(override))
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw AstroMalikCLIRunnerError.io("No existe corpus.db en \(url.path)")
            }
            return url
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AstroMalikCLIRunnerError.io("No se pudo localizar Application Support.")
        }
        let dir = appSupport.appendingPathComponent("AstroMalik", isDirectory: true)
        let writableURL = dir.appendingPathComponent("corpus.db")
        if !FileManager.default.fileExists(atPath: writableURL.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            guard let bundled = AppResources.bundle.url(forResource: "corpus", withExtension: "db") else {
                throw AstroMalikCLIRunnerError.io("No se encontró corpus.db en el bundle.")
            }
            try FileManager.default.copyItem(at: bundled, to: writableURL)
        }
        return writableURL
    }

    static func expandTilde(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}

// MARK: - Chart loading

private extension AstroMalikCLIRunner {
    static func loadChart(query: String, userDBURL: URL) throws -> NatalChart {
        let db = try SQLiteDB(path: userDBURL.path, readonly: true)
        let records = try SavedChartRecord.fetchAll(from: db)
        let charts = records.compactMap { $0.toNatalChart() }

        if let byName = charts.first(where: { $0.name == query }) {
            return byName
        }
        if let uuid = UUID(uuidString: query), let byID = charts.first(where: { $0.id == uuid }) {
            return byID
        }
        throw AstroMalikCLIRunnerError.chartNotFound(query)
    }

    static func configureEphemeris() {
        if let epheURL = AppResources.bundle.url(
            forResource: "sepl_18",
            withExtension: "se1",
            subdirectory: "ephe"
        ) {
            AstroEngine.configure(ephePath: epheURL.deletingLastPathComponent().path)
        } else {
            AstroEngine.configure(ephePath: nil)
        }
    }
}

// MARK: - Output

private extension AstroMalikCLIRunner {
    static func write(narrative: CrossPersonalNarrative, to output: AstroMalikCLIOutput) async throws -> String {
        switch output {
        case .stdout:
            return "stdout"
        case .file(let rawPath):
            let path = expandTilde(rawPath)
            let url = URL(fileURLWithPath: path)
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try narrative.joplinMarkdown().write(to: url, atomically: true, encoding: .utf8)
            return "file:\(url.path)"
        case .joplin(let notebook):
            var settings = JoplinClipperSettings.default
            settings.notebook = notebook
            let service = JoplinClipperService(settings: settings)
            do {
                try await service.createNote(
                    title: narrative.suggestedJoplinTitle(),
                    body: narrative.joplinMarkdown()
                )
            } catch {
                throw AstroMalikCLIRunnerError.joplin(error.localizedDescription)
            }
            return "joplin:\(notebook)"
        }
    }

    static func classifyNarrativeError(_ error: CrossPersonalNarrativeError) -> AstroMalikCLIRunnerError {
        switch error {
        case .anthropic(let underlying):
            return .anthropic(underlying.localizedDescription)
        case .missingTemplate, .encodingFailure:
            return .generic(error.localizedDescription)
        }
    }
}

private extension AstroMalikCLIModel {
    var anthropicConfig: AnthropicClient.Config {
        switch self {
        case .sonnet: return .default
        case .opus: return .opusLong
        }
    }
}

private extension AstroMalikCLIScope {
    var narrativeScope: CrossPersonalNarrativeScope {
        switch self {
        case .complete: return .complete
        case .annual: return .annual
        case .monthly: return .monthly
        case .weekly: return .weekly
        }
    }
}

private extension AstroMalikCLIOutput {
    var descriptionForLogs: String {
        switch self {
        case .stdout: return "stdout"
        case .file(let path): return "file:\(path)"
        case .joplin(let notebook): return "joplin:\(notebook)"
        }
    }
}
