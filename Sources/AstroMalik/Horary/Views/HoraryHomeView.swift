import SwiftUI

struct HoraryHomeView: View {
    let initialTab: HoraryHomeTab
    var onOpenQuery: (SavedHoraryQuery, HoraryHomeTab) -> Void

    @State private var selectedTab: HoraryHomeTab

    init(
        initialTab: HoraryHomeTab,
        onOpenQuery: @escaping (SavedHoraryQuery, HoraryHomeTab) -> Void
    ) {
        self.initialTab = initialTab
        self.onOpenQuery = onOpenQuery
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sección", selection: $selectedTab) {
                ForEach(HoraryHomeTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch selectedTab {
                case .nuevaConsulta:
                    HoraryFormView(onQueryCalculated: { query in
                        onOpenQuery(query, .nuevaConsulta)
                    })
                case .historial:
                    SavedHoraryView(onOpenQuery: { query in
                        onOpenQuery(query, .historial)
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle("Horaria")
    }
}
