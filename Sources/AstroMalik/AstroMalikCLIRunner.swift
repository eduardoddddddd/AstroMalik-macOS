import Foundation

// MARK: - Public facade for the standalone CLI

public enum AstroMalikCLIModel: String, Sendable, Codable, Equatable {
    case sonnet
    case opus
}

public enum AstroMalikCLIScope: String, Sendable, Codable, Equatable {
    case complete
    case annual
    case monthly
    case weekly
}

public enum AstroMalikCLIFormat: String, Sendable, Codable, Equatable {
    case json
    case markdown
}

public enum AstroMalikCLINarrative: String, Sendable, Codable, Equatable {
    case none
    case local
    case anthropic
    case openrouter
}

public enum AstroMalikCLICommandKind: String, Sendable, Codable, Equatable {
    case chartsList = "charts list"
    case chartShow = "chart show"
    case natal
    case transits
    case monthly
    case weekly
    case crossPersonal = "cross-personal"
    case profections
    case firdaria
    case zodiacalReleasing = "zodiacal-releasing"
    case progressions
    case solarReturn = "solar-return"
    case lunarReturn = "lunar-return"
    case primaryDirections = "primary-directions"
    case solarArc = "solar-arc"
}

public enum AstroMalikCLIOutput: Equatable, Sendable {
    case stdout
    case file(String)
    case joplin(String)
}

public struct AstroMalikCLIRequest: Sendable {
    public var command: AstroMalikCLICommandKind
    public var chartQuery: String?
    public var referenceDate: Date
    public var fromDate: Date?
    public var toDate: Date?
    public var month: String?
    public var scope: AstroMalikCLIScope
    public var model: AstroMalikCLIModel
    public var format: AstroMalikCLIFormat
    public var output: AstroMalikCLIOutput
    public var userDBPath: String?
    public var corpusDBPath: String?
    public var verbose: Bool
    public var allowNetwork: Bool
    public var narrative: AstroMalikCLINarrative

    public init(
        command: AstroMalikCLICommandKind = .crossPersonal,
        chartQuery: String? = nil,
        referenceDate: Date,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        month: String? = nil,
        scope: AstroMalikCLIScope = .complete,
        model: AstroMalikCLIModel = .sonnet,
        format: AstroMalikCLIFormat = .json,
        output: AstroMalikCLIOutput = .stdout,
        userDBPath: String? = nil,
        corpusDBPath: String? = nil,
        verbose: Bool = false,
        allowNetwork: Bool = false,
        narrative: AstroMalikCLINarrative = .none
    ) {
        self.command = command
        self.chartQuery = chartQuery
        self.referenceDate = referenceDate
        self.fromDate = fromDate
        self.toDate = toDate
        self.month = month
        self.scope = scope
        self.model = model
        self.format = format
        self.output = output
        self.userDBPath = userDBPath
        self.corpusDBPath = corpusDBPath
        self.verbose = verbose
        self.allowNetwork = allowNetwork
        self.narrative = narrative
    }
}

public struct AstroMalikCLIResult: Sendable {
    public let content: String
    public let format: String
    public let narrative: String
    public let networkUsed: Bool
    public let model: String
    public let estimatedCostUSD: Double
    public let outputDescription: String

    public var markdown: String { content }

    public init(
        content: String,
        format: String,
        narrative: String,
        networkUsed: Bool,
        model: String,
        estimatedCostUSD: Double,
        outputDescription: String
    ) {
        self.content = content
        self.format = format
        self.narrative = narrative
        self.networkUsed = networkUsed
        self.model = model
        self.estimatedCostUSD = estimatedCostUSD
        self.outputDescription = outputDescription
    }
}

public enum AstroMalikCLIRunnerError: LocalizedError, Sendable, Equatable {
    case chartNotFound(String)
    case networkDenied(String)
    case unsupported(String)
    case anthropic(String)
    case openRouter(String)
    case joplin(String)
    case io(String)
    case generic(String)

    public var errorDescription: String? {
        switch self {
        case .chartNotFound(let query):
            return "Carta no encontrada en user.db: \(query)"
        case .networkDenied(let detail):
            return detail
        case .unsupported(let detail):
            return detail
        case .anthropic(let detail):
            return "Error de Anthropic: \(detail)"
        case .openRouter(let detail):
            return "Error de OpenRouter: \(detail)"
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
        case .networkDenied: return 6
        case .anthropic, .openRouter: return 3
        case .joplin: return 4
        case .io: return 5
        case .unsupported, .generic: return 1
        }
    }
}

public enum AstroMalikCLIRunner {
    public static func run(
        request: AstroMalikCLIRequest,
        log: @escaping (String) -> Void = { _ in }
    ) async throws -> AstroMalikCLIResult {
        do {
            try validateNetworkPolicy(request)
            if request.verbose { log("[cli] resolviendo rutas") }
            let userDBURL = try resolveUserDBURL(request.userDBPath)
            let corpusDBURL = try resolveCorpusDBURLIfNeeded(request)

            if request.verbose { log("[cli] configurando efemérides") }
            configureEphemeris()

            let startedAt = Date()
            let rendered: RenderedLocalOutput
            switch request.command {
            case .chartsList:
                if request.verbose { log("[cli] cargando cartas: \(userDBURL.path)") }
                let records = try loadChartRecords(userDBURL: userDBURL)
                rendered = try renderChartsList(records: records, request: request, generatedAt: startedAt)
            default:
                guard let query = request.chartQuery, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AstroMalikCLIRunnerError.generic("Falta --chart <nombre|UUID>.")
                }
                if request.verbose { log("[cli] cargando carta '\(query)' desde \(userDBURL.path)") }
                let chart = try loadChart(query: query, userDBURL: userDBURL)
                let corpusStore = try corpusDBURL.map { try CorpusStore(path: $0.path) }
                rendered = try await renderChartCommand(
                    chart: chart,
                    corpusStore: corpusStore,
                    request: request,
                    generatedAt: startedAt,
                    log: log
                )
            }

            if request.verbose { log("[cli] output → \(request.output.descriptionForLogs)") }
            let outputDescription = try await write(content: rendered.content, title: rendered.title, to: request.output)

            return AstroMalikCLIResult(
                content: rendered.content,
                format: request.format.rawValue,
                narrative: request.narrative.rawValue,
                networkUsed: rendered.networkUsed,
                model: rendered.model,
                estimatedCostUSD: rendered.estimatedCostUSD,
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

// MARK: - Rendering pipeline

private struct RenderedLocalOutput {
    var content: String
    var title: String
    var networkUsed: Bool
    var model: String
    var estimatedCostUSD: Double
}

private extension AstroMalikCLIRunner {
    static func renderChartCommand(
        chart: NatalChart,
        corpusStore: CorpusStore?,
        request: AstroMalikCLIRequest,
        generatedAt: Date,
        log: @escaping (String) -> Void
    ) async throws -> RenderedLocalOutput {
        switch request.command {
        case .chartShow:
            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(chart: chart),
                events: [],
                interpretations: [],
                warnings: [],
                source: "local",
                networkUsed: false
            )
            return try render(envelope: envelope, markdown: chartMarkdown(chart), request: request, title: "Carta — \(chart.name)")

        case .natal:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para natal.") }
            let interpretations = corpusStore.buildNatalInterpretations(chart: chart)
            let extended = try? NatalExtendedAnalysis.compute(chart: chart, configuration: .default)
            let reading = NatalReadingComposer.compose(.init(chart: chart, interpretations: interpretations, extended: extended, density: .complete))
            let readingSummary = CLINatalReadingSummary(reading)
            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(chart: chart, natalReading: readingSummary),
                events: natalEvents(chart: chart),
                interpretations: interpretations.map(CLIInterpretation.init),
                warnings: reading.missingKeys.map { "Clave de corpus natal ausente: \($0)" },
                source: "local",
                networkUsed: false
            )
            return try render(envelope: envelope, markdown: natalMarkdown(chart: chart, reading: reading), request: request, title: "Natal — \(chart.name)")

        case .transits:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para tránsitos.") }
            let from = request.fromDate ?? request.referenceDate
            let to = request.toDate ?? from
            let events = try await computeTransitPeriod(natalChart: chart, fromDate: from, toDate: to, timezone: chart.timezone, excludeMoon: true, corpusStore: corpusStore)
            let ingresses = try detectHouseIngresses(natalChart: chart, fromDate: from, toDate: to, excludeMoon: true, corpusStore: corpusStore)
            let visible = Array(events.prefix(40))
            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt, from: from, to: to),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(transits: events, houseIngresses: ingresses),
                events: transitEventSummaries(events, ingresses: ingresses),
                interpretations: transitInterpretations(events),
                warnings: [],
                source: "local",
                networkUsed: false
            )
            let markdown = TransitsNoteBuilder.markdown(natalChart: chart, fromDate: from, toDate: to, excludeMoon: true, focusFilter: .all, visibleEvents: visible, allEvents: events, houseIngresses: ingresses)
            return try render(envelope: envelope, markdown: markdown, request: request, title: "Tránsitos — \(chart.name)")

        case .weekly:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para semanal.") }
            let from = request.fromDate ?? request.referenceDate
            let to = request.toDate ?? addDays(6, to: from) ?? from
            let events = try await computeTransitPeriod(natalChart: chart, fromDate: from, toDate: to, timezone: chart.timezone, excludeMoon: true, corpusStore: corpusStore)
            let ingresses = try detectHouseIngresses(natalChart: chart, fromDate: from, toDate: to, excludeMoon: true, corpusStore: corpusStore)
            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt, from: from, to: to),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(transits: events, houseIngresses: ingresses),
                events: transitEventSummaries(events, ingresses: ingresses),
                interpretations: transitInterpretations(events),
                warnings: [],
                source: "local",
                networkUsed: false
            )
            let markdown = weeklyMarkdown(chart: chart, from: from, to: to, events: events, ingresses: ingresses)
            return try render(envelope: envelope, markdown: markdown, request: request, title: "Semana — \(chart.name)")

        case .monthly:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para mensual.") }
            let (year, month) = try resolveMonth(request)
            guard let bounds = MonthlySummaryEngine.monthBounds(year: year, month: month) else { throw AstroMalikCLIRunnerError.generic("Mes inválido: \(request.month ?? "")") }
            let ephemeris = try await EphemerisEngine.computeMonth(year: year, month: month, timezone: chart.timezone)
            let transits = try await computeTransitPeriod(natalChart: chart, fromDate: bounds.start, toDate: bounds.end, timezone: chart.timezone, excludeMoon: true, corpusStore: corpusStore)
            let ingresses = try detectHouseIngresses(natalChart: chart, fromDate: bounds.start, toDate: bounds.end, excludeMoon: true, corpusStore: corpusStore)
            let summary = MonthlySummaryEngine.generateSummary(ephemeris: ephemeris, natalChart: chart, transits: transits, ingresses: ingresses)
            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt, from: bounds.start, to: bounds.end),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(transits: transits, houseIngresses: ingresses, monthlySummary: CLIMonthlySummary(summary)),
                events: monthlyEventSummaries(summary),
                interpretations: monthlyInterpretations(summary),
                warnings: [],
                source: "local",
                networkUsed: false
            )
            let title = String(format: "%04d-%02d", year, month)
            let markdown = MonthlySummaryNoteBuilder.markdown(summary: summary, monthTitle: title)
            return try render(envelope: envelope, markdown: markdown, request: request, title: "Mensual — \(chart.name) — \(title)")

        case .crossPersonal:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para cross-personal.") }
            if request.verbose { log("[cli] CrossPersonalAssembler.state local") }
            let state = try await CrossPersonalAssembler.state(chart: chart, referenceDate: request.referenceDate, corpusStore: corpusStore)
            var warnings: [String] = []
            var interpretations = crossInterpretations(state)
            var networkUsed = false
            var model = "local"
            var cost = 0.0

            if request.narrative == .anthropic {
                if request.verbose { log("[cli] narrativa Anthropic explícita") }
                let client = AnthropicClient(config: request.model.anthropicConfig)
                guard client.hasAPIKey() else {
                    throw AstroMalikCLIRunnerError.anthropic(AnthropicError.missingAPIKey.localizedDescription)
                }
                let builder = CrossPersonalNarrativeBuilder(client: client)
                let narrative = try await builder.build(state: state, scope: request.scope.narrativeScope)
                interpretations.insert(CLIInterpretation(id: "anthropic-narrative", title: "Narrativa Anthropic", text: narrative.markdown, source: narrative.model), at: 0)
                networkUsed = true
                model = narrative.model
                cost = narrative.estimatedCostUSD
            } else if request.narrative == .openrouter {
                throw AstroMalikCLIRunnerError.openRouter("La narrativa OpenRouter aún no está implementada para astromalik-cli; usa --narrative none/local o implementa un proveedor explícito.")
            } else if request.narrative == .none {
                warnings.append("Narrativa LLM desactivada explícitamente o por defecto; salida local/state-only.")
            }

            let envelope = LocalCLIEnvelope(
                metadata: metadata(chart: chart, request: request, generatedAt: generatedAt),
                chart: ChartSummary(chart),
                technicalData: LocalTechnicalData(crossPersonal: state),
                events: crossEventSummaries(state),
                interpretations: interpretations,
                warnings: warnings,
                source: networkUsed ? "anthropic" : "local",
                networkUsed: networkUsed
            )
            let markdown = request.narrative == .anthropic && !interpretations.isEmpty
                ? interpretations[0].text
                : crossPersonalMarkdown(state: state, narrative: request.narrative)
            return try render(envelope: envelope, markdown: markdown, request: request, title: "Cross-personal — \(chart.name)", networkUsed: networkUsed, model: model, cost: cost)

        case .profections:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para profecciones.") }
            let result = try await ProfectionEngine(corpusStore: corpusStore).profections(for: chart, at: request.referenceDate)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(profections: result), events: profectionEvents(result), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: profectionsMarkdown(chart: chart, result: result), request: request, title: "Profecciones — \(chart.name)")

        case .firdaria:
            let engine = FirdariaEngine()
            let timeline = engine.firdariaTimeline(chart: chart, at: request.referenceDate)
            let current = engine.currentFirdaria(chart: chart, at: request.referenceDate)
            let upcoming = engine.upcomingMinorChanges(chart: chart, at: request.referenceDate, limit: 8)
            let snapshot = CLIFirdariaSnapshot(timeline: timeline, currentMajor: current.major, currentMinor: current.minor, upcomingMinorChanges: upcoming)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(firdaria: snapshot), events: firdariaEvents(snapshot), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: firdariaMarkdown(chart: chart, snapshot: snapshot), request: request, title: "Firdaria — \(chart.name)")

        case .zodiacalReleasing:
            let engine = ZodiacalReleasingEngine()
            let spirit = engine.zr(chart: chart, lot: .spirit, depth: 2)
            let fortune = engine.zr(chart: chart, lot: .fortune, depth: 2)
            let snapshot = CLIZodiacalReleasingSnapshot(spirit: spirit, fortune: fortune, spiritCurrentL1: spirit.currentL1(at: request.referenceDate), fortuneCurrentL1: fortune.currentL1(at: request.referenceDate), upcomingSpirit: spirit.upcomingHighlightedEvents(after: request.referenceDate, limit: 8), upcomingFortune: fortune.upcomingHighlightedEvents(after: request.referenceDate, limit: 8))
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(zodiacalReleasing: snapshot), events: zrEvents(snapshot), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: zrMarkdown(chart: chart, snapshot: snapshot), request: request, title: "Zodiacal Releasing — \(chart.name)")

        case .progressions:
            let engine = SecondaryProgressionEngine()
            let snapshot = engine.progressions(chart: chart, at: request.referenceDate, ascendantMode: .naibod)
            let aspects = engine.progressedAspects(chart: chart, from: addMonths(-6, to: request.referenceDate) ?? request.referenceDate, to: addMonths(6, to: request.referenceDate) ?? request.referenceDate)
            let data = CLIProgressionsSnapshot(snapshot: snapshot, aspects: aspects)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(progressions: data), events: progressionEvents(data), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: progressionsMarkdown(chart: chart, data: data), request: request, title: "Progresiones — \(chart.name)")

        case .solarReturn:
            guard let corpusStore else { throw AstroMalikCLIRunnerError.io("No se pudo abrir corpus.db para revolución solar.") }
            let year = Calendar(identifier: .gregorian).component(.year, from: request.referenceDate)
            let reading = try SolarReturnEngine.calculate(request: SolarReturnRequest(natalChart: chart, year: year, placeName: chart.placeName, latitude: chart.latitude, longitude: chart.longitude, timezone: chart.timezone), corpusStore: corpusStore)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(solarReturn: reading), events: solarReturnEvents(reading), interpretations: reading.interpretations.map(CLIInterpretation.init), warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: solarReturnMarkdown(reading), request: request, title: "Revolución Solar — \(chart.name)")

        case .lunarReturn:
            let reading = try LunarReturnEngine.calculate(request: LunarReturnRequest(natalChart: chart, startDate: request.referenceDate, count: 3, placeName: chart.placeName, latitude: chart.latitude, longitude: chart.longitude, timezone: chart.timezone))
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(lunarReturn: reading), events: lunarReturnEvents(reading), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: lunarReturnMarkdown(reading), request: request, title: "Revolución Lunar — \(chart.name)")

        case .primaryDirections:
            let directions = primaryDirections(chart: chart, referenceDate: request.referenceDate)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(primaryDirections: directions), events: primaryDirectionEvents(directions), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: primaryDirectionsMarkdown(chart: chart, directions: directions), request: request, title: "Direcciones Primarias — \(chart.name)")

        case .solarArc:
            let directions = solarArcDirections(chart: chart, referenceDate: request.referenceDate)
            let envelope = LocalCLIEnvelope(metadata: metadata(chart: chart, request: request, generatedAt: generatedAt), chart: ChartSummary(chart), technicalData: LocalTechnicalData(solarArc: directions), events: solarArcEvents(directions), interpretations: [], warnings: [], source: "local", networkUsed: false)
            return try render(envelope: envelope, markdown: solarArcMarkdown(chart: chart, directions: directions), request: request, title: "Arco Solar — \(chart.name)")

        case .chartsList:
            throw AstroMalikCLIRunnerError.generic("Comando interno inválido.")
        }
    }

    static func renderChartsList(records: [SavedChartRecord], request: AstroMalikCLIRequest, generatedAt: Date) throws -> RenderedLocalOutput {
        let charts = records.compactMap { record -> ChartListItem? in
            guard let chart = record.toNatalChart() else { return nil }
            return ChartListItem(chart: chart)
        }
        let envelope = LocalCLIEnvelope(
            metadata: CLIMetadata(chartName: nil, chartID: nil, generatedAt: generatedAt, timezone: TimeZone.current.identifier, command: request.command.rawValue, scope: nil, date: nil, from: nil, to: nil, month: nil, format: request.format.rawValue, narrative: request.narrative.rawValue),
            chart: nil,
            technicalData: LocalTechnicalData(charts: charts),
            events: [],
            interpretations: [],
            warnings: [],
            source: "local",
            networkUsed: false
        )
        let markdown = chartsListMarkdown(charts)
        return try render(envelope: envelope, markdown: markdown, request: request, title: "Cartas guardadas")
    }

    static func render(
        envelope: LocalCLIEnvelope,
        markdown: String,
        request: AstroMalikCLIRequest,
        title: String,
        networkUsed: Bool = false,
        model: String = "local",
        cost: Double = 0
    ) throws -> RenderedLocalOutput {
        let content: String
        switch request.format {
        case .json:
            content = try encodeJSON(envelope)
        case .markdown:
            content = markdown
        }
        return RenderedLocalOutput(content: content, title: title, networkUsed: networkUsed || envelope.networkUsed, model: model, estimatedCostUSD: cost)
    }
}

// MARK: - JSON envelope

private struct LocalCLIEnvelope: Encodable {
    var metadata: CLIMetadata
    var chart: ChartSummary?
    var technicalData: LocalTechnicalData
    var events: [CLIEvent]
    var interpretations: [CLIInterpretation]
    var warnings: [String]
    var source: String
    var networkUsed: Bool
}

private struct CLIMetadata: Encodable {
    var chartName: String?
    var chartID: UUID?
    var generatedAt: Date
    var timezone: String
    var command: String
    var scope: String?
    var date: Date?
    var from: Date?
    var to: Date?
    var month: String?
    var format: String
    var narrative: String
}

private struct LocalTechnicalData: Encodable {
    var charts: [ChartListItem]?
    var chart: NatalChart?
    var natalReading: CLINatalReadingSummary?
    var transits: [TransitEvent]?
    var houseIngresses: [TransitHouseIngress]?
    var monthlySummary: CLIMonthlySummary?
    var crossPersonal: CrossPersonalState?
    var profections: ProfectionResult?
    var firdaria: CLIFirdariaSnapshot?
    var zodiacalReleasing: CLIZodiacalReleasingSnapshot?
    var progressions: CLIProgressionsSnapshot?
    var solarReturn: SolarReturnReading?
    var lunarReturn: LunarReturnReading?
    var primaryDirections: [PrimaryDirection]?
    var solarArc: [SolarArcDirection]?

    init(
        charts: [ChartListItem]? = nil,
        chart: NatalChart? = nil,
        natalReading: CLINatalReadingSummary? = nil,
        transits: [TransitEvent]? = nil,
        houseIngresses: [TransitHouseIngress]? = nil,
        monthlySummary: CLIMonthlySummary? = nil,
        crossPersonal: CrossPersonalState? = nil,
        profections: ProfectionResult? = nil,
        firdaria: CLIFirdariaSnapshot? = nil,
        zodiacalReleasing: CLIZodiacalReleasingSnapshot? = nil,
        progressions: CLIProgressionsSnapshot? = nil,
        solarReturn: SolarReturnReading? = nil,
        lunarReturn: LunarReturnReading? = nil,
        primaryDirections: [PrimaryDirection]? = nil,
        solarArc: [SolarArcDirection]? = nil
    ) {
        self.charts = charts
        self.chart = chart
        self.natalReading = natalReading
        self.transits = transits
        self.houseIngresses = houseIngresses
        self.monthlySummary = monthlySummary
        self.crossPersonal = crossPersonal
        self.profections = profections
        self.firdaria = firdaria
        self.zodiacalReleasing = zodiacalReleasing
        self.progressions = progressions
        self.solarReturn = solarReturn
        self.lunarReturn = lunarReturn
        self.primaryDirections = primaryDirections
        self.solarArc = solarArc
    }
}

private struct ChartListItem: Encodable, Equatable {
    var id: UUID
    var name: String
    var birthDate: String
    var birthTime: String
    var timezone: String
    var placeName: String
    var latitude: Double
    var longitude: Double

    init(chart: NatalChart) {
        id = chart.id
        name = chart.name
        birthDate = chart.birthDate
        birthTime = chart.birthTime
        timezone = chart.timezone
        placeName = chart.placeName
        latitude = chart.latitude
        longitude = chart.longitude
    }
}

private struct ChartSummary: Encodable, Equatable {
    var id: UUID
    var name: String
    var birthDate: String
    var birthTime: String
    var timezone: String
    var placeName: String
    var latitude: Double
    var longitude: Double
    var houseSystem: String
    var ascendant: String
    var mc: String

    init(_ chart: NatalChart) {
        id = chart.id
        name = chart.name
        birthDate = chart.birthDate
        birthTime = chart.birthTime
        timezone = chart.timezone
        placeName = chart.placeName
        latitude = chart.latitude
        longitude = chart.longitude
        houseSystem = chart.houseSystem
        ascendant = chart.ascendant.formatted
        mc = chart.mc.formatted
    }
}

private struct CLIEvent: Encodable, Equatable {
    var id: String
    var date: String?
    var from: String?
    var to: String?
    var priority: Double
    var title: String
    var detail: String?
    var source: String
}

private struct CLIInterpretation: Encodable, Equatable {
    var id: String
    var title: String
    var text: String
    var source: String

    init(id: String, title: String, text: String, source: String) {
        self.id = id
        self.title = title
        self.text = text
        self.source = source
    }

    init(_ interpretation: Interpretation) {
        id = interpretation.clave
        title = interpretation.titulo
        text = interpretation.texto
        source = interpretation.fuente
    }
}

private struct CLINatalReadingSummary: Encodable, Equatable {
    var chartId: String
    var chapters: [Chapter]
    var synthesisDraft: [String]
    var missingKeys: [String]

    struct Chapter: Encodable, Equatable {
        var id: String
        var title: String
        var subtitle: String?
        var blocks: [String]
    }

    init(_ reading: NatalReading) {
        chartId = reading.chartId
        synthesisDraft = reading.synthesisDraft
        missingKeys = reading.missingKeys
        chapters = reading.chapters.map { chapter in
            Chapter(id: chapter.id.rawValue, title: chapter.title, subtitle: chapter.subtitle, blocks: chapter.blocks.map(Self.blockText))
        }
    }

    private static func blockText(_ block: ReadingBlock) -> String {
        switch block.kind {
        case .lead(let text): return text
        case .pointHeader(let data): return "\(data.title) — \(data.detail)" + (data.badges.isEmpty ? "" : " [\(data.badges.joined(separator: ", "))]")
        case .corpus(let title, let paragraphs, let source): return [title, paragraphs.joined(separator: "\n\n"), source.isEmpty ? nil : "Fuente: \(source)"].compactMap { $0 }.joined(separator: "\n")
        case .chips(let chips): return chips.map { "\($0.label): \($0.value)" }.joined(separator: " · ")
        case .aspectLine(let data): return data.text
        case .groupedList(let title, let items): return "\(title): \(items.joined(separator: ", "))"
        }
    }
}

private struct CLIMonthlySummary: Encodable, Equatable {
    var id: String
    var year: Int
    var month: Int
    var chartName: String
    var climateSummary: String
    var lunations: [String]
    var eclipses: [String]
    var stations: [String]
    var activeTransitIDs: [UUID]
    var houseIngressIDs: [UUID]

    init(_ summary: MonthlySummary) {
        id = summary.id
        year = summary.year
        month = summary.month
        chartName = summary.chartName
        climateSummary = summary.climateSummary
        lunations = summary.lunationHits.map { "\($0.event.dateLocal) — \($0.event.title) — casa \($0.natalHouse): \($0.narrative)" }
        eclipses = summary.eclipseHits.map { "\($0.event.dateLocal) — \($0.event.title) — casa \($0.natalHouse): \($0.narrative)" }
        stations = summary.stationHits.map { "\($0.event.dateLocal) — \($0.event.title) — \($0.natalPlanetLabel): \($0.narrative)" }
        activeTransitIDs = summary.activeTransits.map(\.id)
        houseIngressIDs = summary.houseIngresses.map(\.id)
    }
}

private struct CLIFirdariaSnapshot: Encodable, Equatable {
    var timeline: FirdariaTimeline
    var currentMajor: FirdariaPeriod
    var currentMinor: FirdariaPeriod?
    var upcomingMinorChanges: [FirdariaMinorChange]
}

private struct CLIZodiacalReleasingSnapshot: Encodable, Equatable {
    var spirit: ZRTimeline
    var fortune: ZRTimeline
    var spiritCurrentL1: ZRPeriod?
    var fortuneCurrentL1: ZRPeriod?
    var upcomingSpirit: [ZREvent]
    var upcomingFortune: [ZREvent]
}

private struct CLIProgressionsSnapshot: Encodable, Equatable {
    var snapshot: ProgressionSnapshot
    var aspects: [ProgressedAspect]
}

// MARK: - Data helpers

private extension AstroMalikCLIRunner {
    static func metadata(chart: NatalChart, request: AstroMalikCLIRequest, generatedAt: Date, from: Date? = nil, to: Date? = nil) -> CLIMetadata {
        CLIMetadata(
            chartName: chart.name,
            chartID: chart.id,
            generatedAt: generatedAt,
            timezone: chart.timezone,
            command: request.command.rawValue,
            scope: request.scope.rawValue,
            date: request.referenceDate,
            from: from ?? request.fromDate,
            to: to ?? request.toDate,
            month: request.month,
            format: request.format.rawValue,
            narrative: request.narrative.rawValue
        )
    }

    static func natalEvents(chart: NatalChart) -> [CLIEvent] {
        chart.bodies.map { body in
            CLIEvent(id: "natal-\(body.key)", date: chart.birthDate, from: nil, to: nil, priority: body.house == 1 || body.house == 10 ? 2 : 1, title: "\(body.label) en \(body.formatted)", detail: "Casa \(body.house)\(body.retrograde ? " · retrógrado" : "")", source: "natal")
        }
    }

    static func transitEventSummaries(_ events: [TransitEvent], ingresses: [TransitHouseIngress]) -> [CLIEvent] {
        let transitEvents = events.map { event in
            CLIEvent(id: event.id.uuidString, date: event.exactDate, from: event.fromDate, to: event.toDate, priority: event.priorityScore, title: "\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)", detail: event.text ?? event.metricReasons.joined(separator: ", "), source: "transit")
        }
        let ingressEvents = ingresses.map { ingress in
            CLIEvent(id: ingress.id.uuidString, date: ingress.date, from: nil, to: nil, priority: ingress.score, title: "\(ingress.transitLabel) ingresa en casa \(ingress.house)", detail: ingress.text, source: "house-ingress")
        }
        return (transitEvents + ingressEvents).sorted(by: eventSort)
    }

    static func transitInterpretations(_ events: [TransitEvent]) -> [CLIInterpretation] {
        events.compactMap { event in
            guard let text = event.text, !text.isEmpty else { return nil }
            return CLIInterpretation(id: event.id.uuidString, title: "\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)", text: text, source: event.source ?? "corpus")
        }
    }

    static func monthlyEventSummaries(_ summary: MonthlySummary) -> [CLIEvent] {
        let lunations = summary.lunationHits.map { hit in CLIEvent(id: hit.id.uuidString, date: String(hit.event.dateLocal.prefix(10)), from: nil, to: nil, priority: 20, title: hit.event.title, detail: hit.narrative, source: "lunation") }
        let eclipses = summary.eclipseHits.map { hit in CLIEvent(id: hit.id.uuidString, date: String(hit.event.dateLocal.prefix(10)), from: nil, to: nil, priority: hit.isAngular ? 40 : 30, title: hit.event.title, detail: hit.narrative, source: "eclipse") }
        let stations = summary.stationHits.map { hit in CLIEvent(id: hit.id.uuidString, date: String(hit.event.dateLocal.prefix(10)), from: nil, to: nil, priority: 25 - hit.orb, title: hit.event.title, detail: hit.narrative, source: "station") }
        return (lunations + eclipses + stations + transitEventSummaries(summary.activeTransits, ingresses: summary.houseIngresses)).sorted(by: eventSort)
    }

    static func monthlyInterpretations(_ summary: MonthlySummary) -> [CLIInterpretation] {
        var result = [CLIInterpretation(id: "climate", title: "Clima del mes", text: summary.climateSummary, source: "local-template")]
        result += transitInterpretations(summary.activeTransits)
        return result
    }

    static func crossEventSummaries(_ state: CrossPersonalState) -> [CLIEvent] {
        state.layers.flatMap { layer in
            layer.signals.map { signal in
                CLIEvent(id: signal.id, date: signal.exactAt.map(dayString), from: signal.startsAt.map(dayString), to: signal.endsAt.map(dayString), priority: signal.weight, title: signal.summary, detail: signal.detail, source: signal.source)
            }
        }.sorted(by: eventSort)
    }

    static func crossInterpretations(_ state: CrossPersonalState) -> [CLIInterpretation] {
        state.topics.map { topic in
            CLIInterpretation(id: topic.id, title: topic.title, text: topic.summary, source: "cross-personal-local")
        }
    }

    static func profectionEvents(_ result: ProfectionResult) -> [CLIEvent] {
        var events: [CLIEvent] = [periodEvent(result.annual, source: "profection-annual", priority: 30)]
        events += result.monthly.map { periodEvent($0, source: "profection-monthly", priority: 20) }
        events += result.daily.map { periodEvent($0, source: "profection-daily", priority: 10) }
        events += transitEventSummaries(Array(result.activations.prefix(20)), ingresses: [])
        return events.sorted(by: eventSort)
    }

    static func periodEvent(_ period: ProfectionPeriod, source: String, priority: Double) -> CLIEvent {
        CLIEvent(id: period.id, date: nil, from: dayString(period.startDate), to: dayString(period.endDate), priority: priority, title: "\(period.kind.rawValue): casa \(period.house) \(period.signLabel)", detail: "Regente: \(period.lordLabel)", source: source)
    }

    static func firdariaEvents(_ snapshot: CLIFirdariaSnapshot) -> [CLIEvent] {
        var events = snapshot.timeline.majorPeriods.map { p in CLIEvent(id: p.id, date: nil, from: dayString(p.startDate), to: dayString(p.endDate), priority: p.id == snapshot.currentMajor.id ? 30 : 10, title: "Firdaria mayor: \(p.ruler.label)", detail: "\(p.nominalYears) años nominales", source: "firdaria") }
        events += snapshot.upcomingMinorChanges.map { change in CLIEvent(id: change.id, date: dayString(change.date), from: nil, to: nil, priority: 20, title: "Cambio menor a \(change.period.ruler.label)", detail: nil, source: "firdaria") }
        return events.sorted(by: eventSort)
    }

    static func zrEvents(_ snapshot: CLIZodiacalReleasingSnapshot) -> [CLIEvent] {
        (snapshot.upcomingSpirit.map { zrEvent($0, lot: "spirit") } + snapshot.upcomingFortune.map { zrEvent($0, lot: "fortune") }).sorted(by: eventSort)
    }

    static func zrEvent(_ event: ZREvent, lot: String) -> CLIEvent {
        CLIEvent(id: "\(lot)-\(event.id)", date: dayString(event.date), from: nil, to: nil, priority: event.kind == .loosingOfBond ? 35 : event.kind == .peak ? 25 : 15, title: "\(lot): \(event.title)", detail: event.detail, source: "zodiacal-releasing")
    }

    static func progressionEvents(_ data: CLIProgressionsSnapshot) -> [CLIEvent] {
        var events = data.snapshot.highlightedChanges.map { ingress in CLIEvent(id: ingress.id, date: ingress.dateLabel, from: nil, to: nil, priority: Double(ingress.priority), title: ingress.description, detail: "\(ingress.fromValue) → \(ingress.toValue)", source: "progression") }
        events += data.aspects.prefix(30).map { aspect in CLIEvent(id: aspect.id, date: aspect.exactDate, from: nil, to: nil, priority: Double(aspect.priority), title: aspect.title, detail: "Orbe \(aspect.orb)", source: "progressed-aspect") }
        return events.sorted(by: eventSort)
    }

    static func solarReturnEvents(_ reading: SolarReturnReading) -> [CLIEvent] {
        [CLIEvent(id: reading.id, date: String(reading.exactLocalDateTime.prefix(10)), from: nil, to: nil, priority: 30, title: reading.yearThemeTitle, detail: reading.yearThemeText, source: "solar-return")]
    }

    static func lunarReturnEvents(_ reading: LunarReturnReading) -> [CLIEvent] {
        reading.events.map { event in CLIEvent(id: "lunar-return-\(event.index)", date: String(event.exactLocalDateTime.prefix(10)), from: nil, to: nil, priority: Double(event.intensityScore), title: "Revolución lunar #\(event.index) — \(event.intensityLabel)", detail: event.miniNarrative, source: "lunar-return") }
    }

    static func primaryDirectionEvents(_ directions: [PrimaryDirection]) -> [CLIEvent] {
        directions.map { d in CLIEvent(id: d.id.uuidString, date: dayString(d.estimatedDate), from: nil, to: nil, priority: Double(d.weight.rawValue), title: "\(d.promissorLabel) \(d.aspect.label) \(d.significatorLabel)", detail: "Edad estimada \(String(format: "%.2f", d.estimatedAge))", source: "primary-direction") }.sorted(by: eventSort)
    }

    static func solarArcEvents(_ directions: [SolarArcDirection]) -> [CLIEvent] {
        directions.map { d in CLIEvent(id: d.id.uuidString, date: dayString(d.exactDate), from: nil, to: nil, priority: Double(d.weight.rawValue), title: "\(d.directedPointLabel) \(d.aspect.label) \(d.natalPointLabel)", detail: "Edad exacta \(String(format: "%.2f", d.exactAge)) · arco \(String(format: "%.2f", d.solarArc))°", source: "solar-arc") }.sorted(by: eventSort)
    }

    static func eventSort(_ lhs: CLIEvent, _ rhs: CLIEvent) -> Bool {
        let ld = lhs.date ?? lhs.from ?? "9999-99-99"
        let rd = rhs.date ?? rhs.from ?? "9999-99-99"
        if ld != rd { return ld < rd }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.title < rhs.title
    }
}

// MARK: - Markdown helpers

private extension AstroMalikCLIRunner {
    static func chartsListMarkdown(_ charts: [ChartListItem]) -> String {
        var lines = ["# Cartas guardadas", "", "Total: \(charts.count)", ""]
        for chart in charts.sorted(by: { $0.name < $1.name }) {
            lines.append("- **\(chart.name)** (`\(chart.id.uuidString)`) — \(chart.birthDate) \(chart.birthTime), \(chart.placeName), \(chart.timezone)")
        }
        return lines.joined(separator: "\n")
    }

    static func chartMarkdown(_ chart: NatalChart) -> String {
        var lines = [
            "# Carta — \(chart.name)", "",
            "- ID: `\(chart.id.uuidString)`",
            "- Nacimiento: \(chart.birthDate) \(chart.birthTime) (\(chart.timezone))",
            "- Lugar: \(chart.placeName) (\(chart.latitude), \(chart.longitude))",
            "- Casas: \(chart.houseSystem)",
            "- Ascendente: \(chart.ascendant.formatted)",
            "- Medio Cielo: \(chart.mc.formatted)", "",
            "## Planetas"
        ]
        for body in chart.bodies {
            lines.append("- \(body.label): \(body.formatted), casa \(body.house)\(body.retrograde ? " ℞" : "")")
        }
        return lines.joined(separator: "\n")
    }

    static func natalMarkdown(chart: NatalChart, reading: NatalReading) -> String {
        var lines = ["# Lectura natal — \(chart.name)", "", "## Datos base", "- Nacimiento: \(chart.birthDate) \(chart.birthTime) (\(chart.timezone))", "- Ascendente: \(chart.ascendant.formatted)", "- Medio Cielo: \(chart.mc.formatted)", ""]
        let summary = CLINatalReadingSummary(reading)
        for chapter in summary.chapters {
            lines.append("## \(chapter.title)")
            if let subtitle = chapter.subtitle { lines.append("_\(subtitle)_") }
            lines.append("")
            for block in chapter.blocks { lines.append(block + "\n") }
        }
        if !reading.missingKeys.isEmpty {
            lines.append("## Warnings")
            lines += reading.missingKeys.map { "- Clave de corpus ausente: \($0)" }
        }
        return lines.joined(separator: "\n")
    }

    static func weeklyMarkdown(chart: NatalChart, from: Date, to: Date, events: [TransitEvent], ingresses: [TransitHouseIngress]) -> String {
        var lines = ["# Resumen semanal — \(chart.name)", "", "Periodo: \(dayString(from)) → \(dayString(to))", "", "## Tránsitos prioritarios"]
        if events.isEmpty { lines.append("No se detectaron tránsitos prioritarios en la semana.") }
        for event in events.prefix(12) {
            lines.append("- \(event.priorityStarsDisplay) **\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)** — exacto \(event.exactDate), prioridad \(event.priorityLabel)")
            if let text = event.text, !text.isEmpty { lines.append("  \(text)") }
        }
        if !ingresses.isEmpty {
            lines.append("\n## Ingresos por casa")
            for ingress in ingresses { lines.append("- \(ingress.transitLabel) a casa \(ingress.house) — \(ingress.date)") }
        }
        return lines.joined(separator: "\n")
    }

    static func crossPersonalMarkdown(state: CrossPersonalState, narrative: AstroMalikCLINarrative) -> String {
        var lines = ["# Cross-personal local — \(state.metadata.chartName)", "", "Fecha de referencia: \(dayString(state.metadata.referenceDate))", "Narrativa: \(narrative.rawValue) (sin LLM externo)", "", "## Temas prioritarios"]
        for topic in state.topics {
            lines.append("- **\(topic.title)** — score \(String(format: "%.2f", topic.convergenceScore)), capas: \(topic.layers.map(\.rawValue).joined(separator: ", "))")
            lines.append("  \(topic.summary)")
        }
        lines.append("\n## Señales por capa")
        for layer in state.layers {
            lines.append("### \(layer.label)")
            if layer.signals.isEmpty { lines.append("Sin señales destacadas.") }
            for signal in layer.signals.prefix(12) {
                let when = signal.exactAt.map(dayString) ?? signal.startsAt.map(dayString) ?? "sin fecha exacta"
                lines.append("- \(when) — **\(signal.summary)** (\(signal.source), peso \(String(format: "%.2f", signal.weight)))")
                if let detail = signal.detail { lines.append("  \(detail)") }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func profectionsMarkdown(chart: NatalChart, result: ProfectionResult) -> String {
        var lines = ["# Profecciones — \(chart.name)", "", "## Anual", "Casa \(result.annual.house) — \(result.annual.signLabel) — regente \(result.annual.lordLabel)", "\(dayString(result.annual.startDate)) → \(dayString(result.annual.endDate))", "", "## Mensuales"]
        for period in result.monthly { lines.append("- Casa \(period.house) \(period.signLabel), regente \(period.lordLabel): \(dayString(period.startDate)) → \(dayString(period.endDate))") }
        return lines.joined(separator: "\n")
    }

    static func firdariaMarkdown(chart: NatalChart, snapshot: CLIFirdariaSnapshot) -> String {
        var lines = ["# Firdaria — \(chart.name)", "", "Mayor actual: **\(snapshot.currentMajor.ruler.label)** (\(dayString(snapshot.currentMajor.startDate)) → \(dayString(snapshot.currentMajor.endDate)))"]
        if let minor = snapshot.currentMinor { lines.append("Menor actual: **\(minor.ruler.label)** (\(dayString(minor.startDate)) → \(dayString(minor.endDate)))") }
        lines.append("\n## Próximos cambios menores")
        for change in snapshot.upcomingMinorChanges { lines.append("- \(dayString(change.date)): \(change.period.ruler.label)") }
        return lines.joined(separator: "\n")
    }

    static func zrMarkdown(chart: NatalChart, snapshot: CLIZodiacalReleasingSnapshot) -> String {
        var lines = ["# Zodiacal Releasing — \(chart.name)", ""]
        if let spirit = snapshot.spiritCurrentL1 { lines.append("- Espíritu L1 actual: **\(spirit.signLabel)** — \(dayString(spirit.startDate)) → \(dayString(spirit.endDate))") }
        if let fortune = snapshot.fortuneCurrentL1 { lines.append("- Fortuna L1 actual: **\(fortune.signLabel)** — \(dayString(fortune.startDate)) → \(dayString(fortune.endDate))") }
        lines.append("\n## Próximos hitos")
        for event in zrEvents(snapshot).prefix(12) { lines.append("- \(event.date ?? "") — \(event.title): \(event.detail ?? "")") }
        return lines.joined(separator: "\n")
    }

    static func progressionsMarkdown(chart: NatalChart, data: CLIProgressionsSnapshot) -> String {
        var lines = ["# Progresiones secundarias — \(chart.name)", "", "Fecha objetivo: \(dayString(data.snapshot.targetDate))", "Edad progresada: \(String(format: "%.2f", data.snapshot.ageYears))", "Sol progresado: \(data.snapshot.progressedSun?.formatted ?? "—")", "Luna progresada: \(data.snapshot.progressedMoon?.formatted ?? "—")", "Fase lunar: \(data.snapshot.lunarPhase.name.rawValue)", "", "## Aspectos próximos"]
        for aspect in data.aspects.prefix(20) { lines.append("- \(aspect.exactDate) — \(aspect.title), orbe \(String(format: "%.2f", aspect.orb))°") }
        return lines.joined(separator: "\n")
    }

    static func solarReturnMarkdown(_ reading: SolarReturnReading) -> String {
        ["# Revolución Solar — \(reading.natalChart.name) \(reading.year)", "", "Exacta: \(reading.exactLocalDateTime) (\(reading.timezone))", "Tema: **\(reading.yearThemeTitle)**", reading.yearThemeText, "", "Ascendente RS: \(reading.solarChart.ascendant.formatted) — casa natal \(reading.natalHouseForSolarAsc)", "Luna RS: casa \(reading.moonHouse), \(reading.moonFormatted)", reading.moonText].joined(separator: "\n")
    }

    static func lunarReturnMarkdown(_ reading: LunarReturnReading) -> String {
        var lines = ["# Revoluciones lunares — \(reading.natalChart.name)", "", "Desde: \(dayString(reading.startDate))", ""]
        for event in reading.events { lines.append("- #\(event.index) \(event.exactLocalDateTime) — \(event.intensityLabel): \(event.miniNarrative)") }
        return lines.joined(separator: "\n")
    }

    static func primaryDirectionsMarkdown(chart: NatalChart, directions: [PrimaryDirection]) -> String {
        var lines = ["# Direcciones primarias — \(chart.name)", "", "## Ventana cercana"]
        for d in directions.prefix(40) { lines.append("- \(dayString(d.estimatedDate)) — \(d.promissorLabel) \(d.aspect.label) \(d.significatorLabel), edad \(String(format: "%.2f", d.estimatedAge))") }
        return lines.joined(separator: "\n")
    }

    static func solarArcMarkdown(chart: NatalChart, directions: [SolarArcDirection]) -> String {
        var lines = ["# Direcciones por arco solar — \(chart.name)", "", "## Ventana cercana"]
        for d in directions.prefix(40) { lines.append("- \(dayString(d.exactDate)) — \(d.directedPointLabel) \(d.aspect.label) \(d.natalPointLabel), edad \(String(format: "%.2f", d.exactAge))") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Path, charts and policy

private extension AstroMalikCLIRunner {
    static func validateNetworkPolicy(_ request: AstroMalikCLIRequest) throws {
        if request.narrative == .anthropic && !request.allowNetwork {
            throw AstroMalikCLIRunnerError.networkDenied("La narrativa Anthropic requiere --allow-network y --narrative anthropic explícitos.")
        }
        if request.narrative == .openrouter && !request.allowNetwork {
            throw AstroMalikCLIRunnerError.networkDenied("La narrativa OpenRouter requiere --allow-network y --narrative openrouter explícitos.")
        }
        if case .joplin = request.output, !request.allowNetwork {
            throw AstroMalikCLIRunnerError.networkDenied("La salida Joplin usa el Web Clipper local y requiere --allow-network explícito; con --no-network usa --output stdout o file:/ruta.")
        }
    }

    static func resolveUserDBURL(_ override: String?) throws -> URL {
        let url: URL
        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            url = URL(fileURLWithPath: expandTilde(override))
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw AstroMalikCLIRunnerError.io("No se pudo localizar Application Support.")
            }
            url = appSupport.appendingPathComponent("AstroMalik", isDirectory: true).appendingPathComponent("user.db")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AstroMalikCLIRunnerError.io("No existe user.db en \(url.path)")
        }
        return url
    }

    static func resolveCorpusDBURLIfNeeded(_ request: AstroMalikCLIRequest) throws -> URL? {
        switch request.command {
        case .chartsList, .chartShow, .firdaria, .zodiacalReleasing, .progressions, .lunarReturn, .primaryDirections, .solarArc:
            return nil
        default:
            return try resolveCorpusDBURL(request.corpusDBPath)
        }
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

    static func loadChartRecords(userDBURL: URL) throws -> [SavedChartRecord] {
        let db = try SQLiteDB(path: userDBURL.path, readonly: true)
        return try SavedChartRecord.fetchAll(from: db)
    }

    static func loadChart(query: String, userDBURL: URL) throws -> NatalChart {
        let records = try loadChartRecords(userDBURL: userDBURL)
        let charts = records.compactMap { $0.toNatalChart() }

        if let byName = charts.first(where: { $0.name == query }) { return byName }
        if let byNameCaseInsensitive = charts.first(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) { return byNameCaseInsensitive }
        if let uuid = UUID(uuidString: query), let byID = charts.first(where: { $0.id == uuid }) { return byID }
        throw AstroMalikCLIRunnerError.chartNotFound(query)
    }

    static func configureEphemeris() {
        if let epheURL = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe") {
            AstroEngine.configure(ephePath: epheURL.deletingLastPathComponent().path)
        } else {
            AstroEngine.configure(ephePath: nil)
        }
    }

    static func write(content: String, title: String, to output: AstroMalikCLIOutput) async throws -> String {
        switch output {
        case .stdout:
            return "stdout"
        case .file(let rawPath):
            let path = expandTilde(rawPath)
            let url = URL(fileURLWithPath: path)
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "file:\(url.path)"
        case .joplin(let notebook):
            var settings = JoplinClipperSettings.default
            settings.notebook = notebook
            let service = JoplinClipperService(settings: settings)
            do {
                try await service.createNote(title: title, body: content)
            } catch {
                throw AstroMalikCLIRunnerError.joplin(error.localizedDescription)
            }
            return "joplin:\(notebook)"
        }
    }

    static func classifyNarrativeError(_ error: CrossPersonalNarrativeError) -> AstroMalikCLIRunnerError {
        switch error {
        case .anthropic(let underlying): return .anthropic(underlying.localizedDescription)
        case .missingTemplate, .encodingFailure: return .generic(error.localizedDescription)
        }
    }
}

// MARK: - Calculation helpers

private extension AstroMalikCLIRunner {
    static func primaryDirections(chart: NatalChart, referenceDate: Date) -> [PrimaryDirection] {
        guard let birth = birthDate(for: chart),
              let jd = try? julianDayFromLocal(birthDate: chart.birthDate, birthTime: chart.birthTime, timezoneName: chart.timezone).jd else { return [] }
        let age = max(1, Int(floor(ageYearsLocal(chart: chart, at: referenceDate) ?? 1)))
        let config = PrimaryDirectionCalculator.Config(method: .regiomontanus, key: .naibod, natalSolarSpeed: nil, maxYears: Double(min(120, max(age + 2, 2))), aspects: PDaspect.allCases, promissors: [], significators: [], includeConverse: true, aspectPlane: .zodiacal)
        let result = PrimaryDirectionsService().compute(chart: chart, jd: jd, birthDate: birth, config: config)
        let lower = addMonths(-12, to: referenceDate) ?? referenceDate.addingTimeInterval(-365 * 86_400)
        let upper = addMonths(12, to: referenceDate) ?? referenceDate.addingTimeInterval(365 * 86_400)
        return result.enrichedDirections.map { $0.direction }.filter { lower...upper ~= $0.estimatedDate }.sorted { $0.estimatedDate < $1.estimatedDate }
    }

    static func solarArcDirections(chart: NatalChart, referenceDate: Date) -> [SolarArcDirection] {
        let age = ageYearsLocal(chart: chart, at: referenceDate) ?? 0
        return SolarArcEngine().solarArc(chart: chart, from: max(0, age - 1), to: max(0, age + 1), mode: .real, orb: 1.0).sorted { $0.exactDate < $1.exactDate }
    }

    static func resolveMonth(_ request: AstroMalikCLIRequest) throws -> (Int, Int) {
        if let raw = request.month {
            let parts = raw.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2, (1...12).contains(parts[1]) else { throw AstroMalikCLIRunnerError.generic("Mes inválido: \(raw). Usa YYYY-MM.") }
            return (parts[0], parts[1])
        }
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: request.referenceDate)
        return (comps.year ?? 1970, comps.month ?? 1)
    }

    static func ageYearsLocal(chart: NatalChart, at date: Date) -> Double? {
        guard let birth = birthDate(for: chart) else { return nil }
        return max(0, date.timeIntervalSince(birth) / (365.2422 * 86_400))
    }

    static func birthDate(for chart: NatalChart) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: chart.timezone) ?? .gmt
        let dateParts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let timeParts = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count >= 2 else { return nil }
        return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: dateParts[0], month: dateParts[1], day: dateParts[2], hour: timeParts[0], minute: timeParts[1]))
    }
}

// MARK: - Formatting utilities

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

private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

private func dayString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func addDays(_ days: Int, to date: Date) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar.date(byAdding: .day, value: days, to: date)
}

private func addMonths(_ months: Int, to date: Date) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar.date(byAdding: .month, value: months, to: date)
}
