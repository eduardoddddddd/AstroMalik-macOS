import SwiftUI

struct HoraryWindowHost: View {
    @EnvironmentObject var appState: AppState
    let queryId: UUID?

    var body: some View {
        Group {
            if let id = queryId, let query = appState.horaryQuery(for: id) {
                HoraryResultView(query: query)
                    .environmentObject(appState)
            } else {
                missingQueryView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var missingQueryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("Consulta horaria no disponible")
                .font(.title3)
            Text("Esta consulta ya no está en memoria. Ábrela de nuevo desde el historial.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
