import SwiftUI
import AppKit

public struct AstroMalikApp: App {
    @StateObject private var appState = AppState()

    public init() {
        // Forzar que el ejecutable SPM se registre como app GUI regular
        // y gane foco al arrancar, en lugar de quedar como proceso en segundo plano.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        ReportSmoke.runIfRequestedFromEnvironment()
    }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 920, idealWidth: 1100, minHeight: 640, idealHeight: 780)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .help) {
                Button("AstroMalik Help") {
                    appState.isHelpPresented = true
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    private static let appearanceKey = "appAppearanceMode"
    private static let joplinHostKey = "joplinHost"
    private static let joplinPortKey = "joplinPort"
    private static let joplinTokenKey = "joplinToken"
    private static let joplinNotebookKey = "joplinNotebook"

    let corpusStore: CorpusStore
    let userStore = UserStore()
    let readingNotesStore = ReadingNotesStore()
    let horaryStore = HoraryStore()
    let placesService = PlacesService()
    /// Servicio de cálculo de Direcciones Primarias (Sendable, reutilizable).
    let pdService: PrimaryDirectionsService
    /// Cliente compartido para OpenRouter.
    let openRouterClient: OpenRouterClient
    /// Descubrimiento local de la key en notas de Joplin (solo diagnóstico/importación).
    let joplinOpenRouterLocator: JoplinOpenRouterKeyLocator
    /// Intérprete contextual LLM con caché persistente en user.db cuando está disponible.
    let pdInterpreter: PrimaryDirectionContextualInterpreter
    let hasPersistentPDInterpretationCache: Bool

    @Published var selectedNav: NavItem = .nuevaCarta
    @Published var detailRoute: DetailRoute = .birthForm
    @Published var activeNatalChart: NatalChart? = nil
    @Published var transitChartIndex: Int = 0
    let transitState = TransitWorkspaceState()
    @Published var isHelpPresented = false
    /// Non-nil when migrations failed on startup — shown as alert in ContentView.
    @Published var migrationError: String? = nil
    @Published var appearanceMode: AppAppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceKey)
        }
    }
    @Published var joplinSettings: JoplinClipperSettings = .default {
        didSet { saveJoplinSettings() }
    }
    @Published private(set) var openRouterAvailability: OpenRouterAvailability = .notConfigured
    @Published private(set) var openRouterValidation: OpenRouterKeyValidation? = nil
    @Published private(set) var openRouterValidationMessage: String? = nil
    @Published private(set) var openRouterJoplinCredential: JoplinOpenRouterCredential? = nil
    @Published private(set) var isOpenRouterBusy = false

    func showDefaultDetail(for nav: NavItem) {
        switch nav {
        case .nuevaCarta:
            detailRoute = .birthForm
        case .cartas:
            detailRoute = .savedCharts
        case .lectura:
            detailRoute = .reading
        case .sinastria:
            detailRoute = .synastry
        case .revolucionSolar:
            detailRoute = .solarReturn
        case .revolucionLunar:
            detailRoute = .lunarReturn
        case .transitos:
            detailRoute = .transits
        case .progresiones:
            detailRoute = .progressions
        case .profecciones:
            detailRoute = .profections
        case .firdaria:
            detailRoute = .firdaria
        case .zodiacalReleasing:
            detailRoute = .zodiacalReleasing
        case .crossPersonal:
            detailRoute = .crossPersonal
        case .efemerides:
            detailRoute = .ephemeris
        case .horaria:
            detailRoute = .horaryHome(.nuevaConsulta)
        case .direccionesPrimarias:
            // Usa carta activa o la primera guardada; si no hay ninguna, muestra placeholder
            if let chart = activeNatalChart ?? userStore.savedCharts.first {
                detailRoute = .primaryDirections(chart)
            } else {
                detailRoute = .primaryDirections(NatalChart.placeholder)
            }
        case .misInformes:
            detailRoute = .myReports
        case .ajustes:
            detailRoute = .settings
        }
    }

    /// Navega directamente a las direcciones primarias de una carta específica.
    func showPrimaryDirections(for chart: NatalChart) {
        activeNatalChart = chart
        selectedNav = .direccionesPrimarias
        detailRoute = .primaryDirections(chart)
    }

    func showNatalResult(_ chart: NatalChart, returnTo nav: NavItem) {
        activeNatalChart = chart
        detailRoute = .natalResult(chart, returnTo: nav)
    }

    func showHoraryResult(_ query: SavedHoraryQuery, returnTo tab: HoraryHomeTab) {
        detailRoute = .horaryResult(query, returnTo: tab)
    }

    func toggleLightDarkMode() {
        appearanceMode = appearanceMode == .dark ? .light : .dark
    }

    init() {
        if let storedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey),
           let mode = AppAppearanceMode(rawValue: storedAppearance) {
            appearanceMode = mode
        }
        joplinSettings = Self.loadJoplinSettings().resolvingDetectedToken()
        let resolvedOpenRouterClient = OpenRouterClient()
        openRouterClient = resolvedOpenRouterClient
        joplinOpenRouterLocator = JoplinOpenRouterKeyLocator()

        guard let url = AppResources.bundle.url(forResource: "corpus", withExtension: "db") else {
            fatalError("corpus.db no encontrado en el bundle")
        }
        guard let store = try? CorpusStore(path: url.path) else {
            fatalError("No se pudo abrir corpus.db en \(url.path)")
        }
        corpusStore = store

        var resolvedPDService = PrimaryDirectionsService()
        var resolvedPDInterpreter = PrimaryDirectionContextualInterpreter()
        var resolvedPersistentPDCache = false

        // MARK: SQL Migrations
        // Aplica idempotentemente 001_*.sql (corpus.db) y 002_*.sql (user.db).
        // No hace fatalError — loguea y muestra alerta si algo falla.
        do {
            let migConfig = try MigrationRunner.Config.standard()
            let result = try MigrationRunner.applyAll(config: migConfig)
            resolvedPDService = Self.makePrimaryDirectionsService(
                corpusPath: migConfig.corpusWritableURL.path
            )
            if let userDB = try? SQLiteDB(path: migConfig.userDBURL.path, readonly: false) {
                resolvedPDInterpreter = PrimaryDirectionContextualInterpreter(db: userDB)
                resolvedPersistentPDCache = true
            }
            if !result.applied.isEmpty {
                print("[Migrations] Applied: \(result.applied.joined(separator: ", "))")
            }
            if !result.skipped.isEmpty {
                print("[Migrations] Skipped (already applied): \(result.skipped.joined(separator: ", "))")
            }
            if result.hasErrors {
                let details = result.failed
                    .map { "\($0.0): \($0.1.localizedDescription)" }
                    .joined(separator: "\n")
                print("[Migrations] ⚠️ Errors:\n\(details)")
                migrationError = "Algunas migraciones fallaron al iniciar.\n\(details)"
            }
        } catch {
            print("[Migrations] ❌ Fatal setup error: \(error)")
            migrationError = "Error al configurar la base de datos: \(error.localizedDescription)"
        }
        pdService = resolvedPDService
        pdInterpreter = resolvedPDInterpreter
        hasPersistentPDInterpretationCache = resolvedPersistentPDCache

        // Configurar Swiss Ephemeris con archivos de efemérides del bundle
        if let epheURL = AppResources.bundle.url(
            forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe"
        ) {
            AstroEngine.configure(ephePath: epheURL.deletingLastPathComponent().path)
        } else {
            // Fallback: Moshier (menos preciso pero sin archivos)
            AstroEngine.configure(ephePath: nil)
        }

        Task { @MainActor in
            await refreshOpenRouterDiagnostics()
        }
    }

    private static func loadJoplinSettings() -> JoplinClipperSettings {
        let defaults = UserDefaults.standard
        var settings = JoplinClipperSettings.default
        if let host = defaults.string(forKey: joplinHostKey), !host.isEmpty {
            settings.host = host
        }
        let port = defaults.integer(forKey: joplinPortKey)
        if port > 0 {
            settings.port = port
        }
        if let token = defaults.string(forKey: joplinTokenKey) {
            settings.token = token
        }
        if let notebook = defaults.string(forKey: joplinNotebookKey), !notebook.isEmpty {
            settings.notebook = notebook
        }
        return settings
    }

    private func saveJoplinSettings() {
        let defaults = UserDefaults.standard
        defaults.set(joplinSettings.host, forKey: Self.joplinHostKey)
        defaults.set(joplinSettings.port, forKey: Self.joplinPortKey)
        defaults.set(joplinSettings.token, forKey: Self.joplinTokenKey)
        defaults.set(joplinSettings.notebook, forKey: Self.joplinNotebookKey)
    }

    private static func makePrimaryDirectionsService(corpusPath: String) -> PrimaryDirectionsService {
        guard let db = try? SQLiteDB(path: corpusPath, readonly: true) else {
            return PrimaryDirectionsService()
        }
        let store = PrimaryDirectionCorpusStore(db: db)
        return PrimaryDirectionsService(corpusStore: store)
    }

    func refreshOpenRouterDiagnostics() async {
        let source = openRouterClient.credentialSource()
        let discovered = try? joplinOpenRouterLocator.locateFirstCredential()
        openRouterJoplinCredential = discovered

        if case .invalid = openRouterAvailability, source == nil {
            openRouterAvailability = .notConfigured
        } else if case .invalid = openRouterAvailability {
            openRouterAvailability = .invalid(source)
        } else if let source {
            openRouterAvailability = .ready(source)
        } else {
            openRouterAvailability = .notConfigured
        }

        if source == nil {
            openRouterValidation = nil
            openRouterValidationMessage = nil
        }
    }

    func validateOpenRouterKey() async {
        isOpenRouterBusy = true
        defer { isOpenRouterBusy = false }

        let source = openRouterClient.credentialSource()
        do {
            let validation = try await openRouterClient.validateCurrentKey()
            openRouterValidation = validation
            openRouterValidationMessage = "Key válida. Uso \(formatOpenRouterNumber(validation.usage)) / \(formatOpenRouterNumber(validation.limit))."
            openRouterAvailability = .ready(source ?? .keychain)
        } catch OpenRouterError.unauthorized {
            openRouterValidation = nil
            openRouterValidationMessage = OpenRouterError.unauthorized.localizedDescription
            openRouterAvailability = .invalid(source)
        } catch {
            openRouterValidation = nil
            openRouterValidationMessage = error.localizedDescription
            if source == nil {
                openRouterAvailability = .notConfigured
            }
        }
    }

    func importOpenRouterKeyFromJoplin() async {
        isOpenRouterBusy = true
        defer { isOpenRouterBusy = false }

        do {
            guard let credential = try joplinOpenRouterLocator.locateFirstCredential() else {
                openRouterValidationMessage = "No encontré una key de OpenRouter en las notas locales de Joplin."
                openRouterAvailability = .notConfigured
                return
            }

            try openRouterClient.saveAPIKey(credential.apiKey)
            openRouterJoplinCredential = credential
            await refreshOpenRouterDiagnostics()
            await validateOpenRouterKey()
        } catch {
            openRouterValidationMessage = error.localizedDescription
        }
    }

    private func formatOpenRouterNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }
}

enum OpenRouterAvailability: Equatable {
    case notConfigured
    case ready(OpenRouterCredentialSource)
    case invalid(OpenRouterCredentialSource?)

    var badgeLabel: String {
        switch self {
        case .notConfigured:
            return "Key no configurada"
        case .ready:
            return "Key lista"
        case .invalid:
            return "Key inválida"
        }
    }

    var sourceLabel: String {
        switch self {
        case .notConfigured:
            return "Sin fuente activa"
        case .ready(let source):
            return source.label
        case .invalid(let source):
            return source?.label ?? "Sin fuente activa"
        }
    }
}
