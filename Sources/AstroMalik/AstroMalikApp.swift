import SwiftUI
import AppKit

@main
struct AstroMalikApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Forzar que el ejecutable SPM se registre como app GUI regular
        // y gane foco al arrancar, en lugar de quedar como proceso en segundo plano.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
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

    let corpusStore: CorpusStore
    let userStore = UserStore()
    let horaryStore = HoraryStore()
    let placesService = PlacesService()

    /// Cartas calculadas en la sesión actual pero aún no guardadas,
    /// indexadas por UUID para que las ventanas secundarias las recuperen por id.
    @Published var sessionCharts: [UUID: NatalChart] = [:]
    @Published var sessionHoraryQueries: [UUID: SavedHoraryQuery] = [:]
    @Published var selectedNav: NavItem = .nuevaCarta
    @Published var detailRoute: DetailRoute = .birthForm
    @Published var isHelpPresented = false
    @Published var appearanceMode: AppAppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceKey)
        }
    }

    func register(_ chart: NatalChart) {
        sessionCharts[chart.id] = chart
    }

    func chart(for id: UUID) -> NatalChart? {
        if let c = sessionCharts[id] { return c }
        return userStore.savedCharts.first(where: { $0.id == id })
    }

    func registerHorary(_ query: SavedHoraryQuery) {
        sessionHoraryQueries[query.id] = query
    }

    func horaryQuery(for id: UUID) -> SavedHoraryQuery? {
        if let query = sessionHoraryQueries[id] { return query }
        return horaryStore.savedQueries.first(where: { $0.id == id })
    }

    func showDefaultDetail(for nav: NavItem) {
        switch nav {
        case .nuevaCarta:
            detailRoute = .birthForm
        case .cartas:
            detailRoute = .savedCharts
        case .transitos:
            detailRoute = .transits
        case .horaria:
            detailRoute = .horaryHome(.nuevaConsulta)
        }
    }

    func showNatalResult(_ chart: NatalChart, returnTo nav: NavItem) {
        register(chart)
        detailRoute = .natalResult(chart, returnTo: nav)
    }

    func showHoraryResult(_ query: SavedHoraryQuery, returnTo tab: HoraryHomeTab) {
        registerHorary(query)
        detailRoute = .horaryResult(query, returnTo: tab)
    }

    init() {
        if let storedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey),
           let mode = AppAppearanceMode(rawValue: storedAppearance) {
            appearanceMode = mode
        }

        guard let url = AppResources.bundle.url(forResource: "corpus", withExtension: "db") else {
            fatalError("corpus.db no encontrado en el bundle")
        }
        guard let store = try? CorpusStore(path: url.path) else {
            fatalError("No se pudo abrir corpus.db en \(url.path)")
        }
        corpusStore = store

        // Configurar Swiss Ephemeris con archivos de efemérides del bundle
        if let epheURL = AppResources.bundle.url(
            forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe"
        ) {
            AstroEngine.configure(ephePath: epheURL.deletingLastPathComponent().path)
        } else {
            // Fallback: Moshier (menos preciso pero sin archivos)
            AstroEngine.configure(ephePath: nil)
        }
    }
}
