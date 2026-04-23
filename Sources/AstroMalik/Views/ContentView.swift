import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var transitChartIndex: Int = 0

    var body: some View {
        NavigationSplitView {
            List(NavItem.allCases, selection: $appState.selectedNav) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("AstroMalik")
        } detail: {
            detailView
        }
        .background(Color.appBackground)
        .sheet(isPresented: $appState.isHelpPresented) {
            HelpView()
                .preferredColorScheme(appState.appearanceMode.colorScheme)
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
                onBack: { appState.showDefaultDetail(for: returnTo) }
            )
            .environmentObject(appState)

        case .savedCharts:
            SavedChartsView(onOpenChart: { chart in
                appState.showNatalResult(chart, returnTo: .cartas)
            })
            .environmentObject(appState)

        case .transits:
            transitosDetail

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
        }
    }

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
                    Picker("Carta", selection: $transitChartIndex) {
                        ForEach(charts.indices, id: \.self) { i in
                            Text(charts[i].name.isEmpty ? "Carta \(i + 1)" : charts[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                TransitsView(natalChart: charts[min(transitChartIndex, charts.count - 1)])
                    .environmentObject(appState)
            }
        }
    }
}
