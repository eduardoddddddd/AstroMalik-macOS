import SwiftUI

/// Anfitrión de la ventana secundaria "Carta".
/// Recibe un UUID opcional desde `openWindow(id: "chart", value: id)`
/// y resuelve la carta desde AppState (sesión actual o cartas guardadas).
struct ChartWindowHost: View {
    @EnvironmentObject var appState: AppState
    let chartId: UUID?

    var body: some View {
        Group {
            if let id = chartId, let chart = appState.chart(for: id) {
                NatalChartView(chart: chart)
                    .environmentObject(appState)
            } else {
                missingChartView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var missingChartView: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            Text("Carta no disponible")
                .font(.title3)
            Text("Esta carta ya no está en memoria. Calcúlala de nuevo desde la ventana principal.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
