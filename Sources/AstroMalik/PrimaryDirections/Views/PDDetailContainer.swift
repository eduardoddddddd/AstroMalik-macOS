import SwiftUI

/// Contenedor stateful para el módulo de Direcciones Primarias.
/// Crea el ViewModel con @StateObject (vive mientras la view esté montada)
/// y dispara el cálculo al aparecer o cuando cambia la carta.
struct PDDetailContainer: View {
    let chart: NatalChart
    let pdService: PrimaryDirectionsService
    let interpreter: PrimaryDirectionContextualInterpreter?

    @StateObject private var vm: PrimaryDirectionsViewModel

    init(chart: NatalChart,
         pdService: PrimaryDirectionsService,
         interpreter: PrimaryDirectionContextualInterpreter?) {
        self.chart = chart
        self.pdService = pdService
        self.interpreter = interpreter
        _vm = StateObject(wrappedValue:
            PrimaryDirectionsViewModel(service: pdService, interpreter: interpreter)
        )
    }

    var body: some View {
        PrimaryDirectionsView(vm: vm)
            .onAppear { triggerCalculation() }
            .onChange(of: chart.id) { triggerCalculation() }
    }

    // MARK: - Trigger Calculation

    private func triggerCalculation() {
        guard let jdResult = try? julianDayFromLocal(
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            timezoneName: chart.timezone
        ) else { return }

        // Reconstruct a Date from the chart fields for birthDate parameter
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: chart.timezone) ?? .current
        let parts = chart.birthDate.split(separator: "-").compactMap { Int($0) }
        let timeParts = chart.birthTime.split(separator: ":").compactMap { Int($0) }
        var comps = DateComponents()
        if parts.count == 3 {
            comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        }
        if timeParts.count >= 2 {
            comps.hour = timeParts[0]; comps.minute = timeParts[1]
        }
        let birthDate = cal.date(from: comps) ?? Date()

        vm.loadDirections(chart: chart, jd: jdResult.jd, birthDate: birthDate)
    }
}
