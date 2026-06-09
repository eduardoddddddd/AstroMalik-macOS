import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AstroMalik")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.appPrimaryText)
                        Text("Cartas, direcciones, revoluciones y horaria")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        appState.toggleLightDarkMode()
                    } label: {
                        Image(systemName: appState.appearanceMode.quickToggleIcon)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(appState.appearanceMode.quickToggleLabel)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 14)

                List(selection: $appState.selectedNav) {
                    Section {
                        ForEach([NavItem.nuevaCarta, NavItem.cartas, NavItem.lectura]) { item in
                            sidebarItem(item)
                        }
                    } header: {
                        sidebarSectionHeader("Carta Natal")
                    }

                    Section {
                        ForEach([
                            NavItem.transitos,
                            NavItem.progresiones,
                            NavItem.direccionesPrimarias,
                            NavItem.profecciones,
                            NavItem.firdaria,
                            NavItem.zodiacalReleasing,
                        ]) { item in
                            sidebarItem(item)
                        }
                    } header: {
                        sidebarSectionHeader("Predictivas")
                    }

                    Section {
                        ForEach([NavItem.revolucionSolar, NavItem.revolucionLunar]) { item in
                            sidebarItem(item)
                        }
                    } header: {
                        sidebarSectionHeader("Retornos")
                    }

                    Section {
                        ForEach([NavItem.crossPersonal]) { item in
                            sidebarItem(item, highlighted: true)
                        }
                    } header: {
                        sidebarSectionHeader("Síntesis")
                    }

                    Section {
                        ForEach([NavItem.sinastria, NavItem.horaria]) { item in
                            sidebarItem(item)
                        }
                    } header: {
                        sidebarSectionHeader("Sinastría y Horaria")
                    }

                    Section {
                        ForEach([NavItem.efemerides, NavItem.misInformes, NavItem.ajustes]) { item in
                            sidebarItem(item)
                        }
                    } header: {
                        sidebarSectionHeader("Herramientas")
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background(Color.appSidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
        } detail: {
            detailView
                .id(appState.detailRoute.viewIdentity)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $appState.isHelpPresented) {
            HelpView()
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
        .alert("Error de base de datos", isPresented: Binding(
            get: { appState.migrationError != nil },
            set: { if !$0 { appState.migrationError = nil } }
        )) {
            Button("OK") { appState.migrationError = nil }
        } message: {
            Text(appState.migrationError ?? "")
        }
        .onChange(of: appState.selectedNav) { _, newValue in
            appState.showDefaultDetail(for: newValue)
        }
        .task {
            appState.showDefaultDetail(for: appState.selectedNav)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.detailRoute {
        case .birthForm:
            BirthChartForm(onChartCalculated: { chart in
                appState.showNatalResult(chart, returnTo: .nuevaCarta)
            })
            .environmentObject(appState)

        case .natalResult(let chart, let returnTo):
            NatalChartView(
                chart: chart,
                initialMode: returnTo == .lectura ? .reading : .wheel,
                onBack: { appState.showDefaultDetail(for: returnTo) }
            )
            .environmentObject(appState)

        case .reading:
            readingDetail

        case .synastry:
            SynastryView()
                .environmentObject(appState)

        case .solarReturn:
            SolarReturnView()
                .environmentObject(appState)

        case .lunarReturn:
            LunarReturnView()
                .environmentObject(appState)

        case .savedCharts:
            SavedChartsView(onOpenChart: { chart in
                appState.showNatalResult(chart, returnTo: .cartas)
            })
            .environmentObject(appState)

        case .transits:
            transitosDetail

        case .progressions:
            ProgressionsView(chart: appState.activeNatalChart)
                .environmentObject(appState)

        case .profections:
            ProfectionsView(chart: appState.activeNatalChart)
                .environmentObject(appState)

        case .firdaria:
            FirdariaView(chart: appState.activeNatalChart ?? appState.userStore.savedCharts.first)
                .environmentObject(appState)

        case .zodiacalReleasing:
            ZRView(chart: appState.activeNatalChart ?? appState.userStore.savedCharts.first)
                .environmentObject(appState)

        case .crossPersonal:
            crossPersonalDetail

        case .ephemeris:
            EphemerisCalendarView()
                .environmentObject(appState)

        case .horaryHome(let tab):
            HoraryHomeView(
                initialTab: tab,
                onOpenQuery: { query, returnTab in
                    appState.showHoraryResult(query, returnTo: returnTab)
                }
            )
            .environmentObject(appState)

        case .horaryResult(let query, let returnTo):
            HoraryResultView(
                query: query,
                onBack: { appState.detailRoute = .horaryHome(returnTo) }
            )

        case .primaryDirections(let chart):
            primaryDirectionsDetail(chart: chart)

        case .myReports:
            MyReportsView()

        case .settings:
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func sidebarItem(_ item: NavItem, highlighted: Bool = false) -> some View {
        Label(item.label, systemImage: item.systemImage)
            .font(.body.weight(.medium))
            .foregroundStyle(highlighted ? Color.appSecondaryAccent : Color.appPrimaryText)
            .tag(item)
            .padding(.vertical, 3)
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Color.appSecondaryAccent)
            .padding(.top, 4)
    }

    // MARK: - Cross Personal Detail

    @ViewBuilder
    private var crossPersonalDetail: some View {
        if let chart = appState.activeNatalChart ?? appState.userStore.savedCharts.first {
            CrossPersonalView(chart: chart)
                .environmentObject(appState)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Guarda o abre una carta natal para calcular el estado cross.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }

    // MARK: - Primary Directions Detail (Phase 6)

    @ViewBuilder
    private func primaryDirectionsDetail(chart: NatalChart) -> some View {
        if chart.id == NatalChart.placeholder.id {
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Guarda o abre una carta natal para calcular las Direcciones Primarias.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        } else {
            PDDetailContainer(chart: chart,
                              pdService: appState.pdService,
                              interpreter: appState.pdInterpreter)
        }
    }

    // MARK: - Reading Detail

    @ViewBuilder
    private var readingDetail: some View {
        if let chart = appState.activeNatalChart ?? appState.userStore.savedCharts.first {
            NatalChartView(
                chart: chart,
                initialMode: .reading,
                onBack: nil
            )
            .environmentObject(appState)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Abre o guarda una carta para iniciar una lectura.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
        }
    }

    // MARK: - Transits Detail

    @ViewBuilder
    private var transitosDetail: some View {
        let charts = appState.userStore.savedCharts
        if charts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Guarda una carta natal para ver sus tránsitos.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if charts.count > 1 {
                    Picker("Carta", selection: $appState.transitChartIndex) {
                        ForEach(charts.indices, id: \.self) { i in
                            Text(charts[i].name.isEmpty ? "Carta \(i + 1)" : charts[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                TransitsView(
                    natalChart: charts[min(appState.transitChartIndex, charts.count - 1)],
                    state: appState.transitState
                )
                    .environmentObject(appState)
            }
        }
    }
}
