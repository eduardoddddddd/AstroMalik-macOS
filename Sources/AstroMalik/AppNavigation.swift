import Foundation

enum NavItem: String, CaseIterable, Identifiable {
    case nuevaCarta  = "Nueva Carta"
    case cartas      = "Cartas Guardadas"
    case transitos   = "Tránsitos"
    case horaria     = "Horaria"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nuevaCarta: return "star.circle"
        case .cartas:     return "tray.full"
        case .transitos:  return "calendar.circle"
        case .horaria:    return "questionmark.bubble"
        }
    }
}

enum HoraryHomeTab: String, CaseIterable, Identifiable, Equatable {
    case nuevaConsulta = "Nueva Consulta"
    case historial = "Historial"

    var id: String { rawValue }
}

enum DetailRoute: Equatable {
    case birthForm
    case natalResult(NatalChart, returnTo: NavItem)
    case savedCharts
    case transits
    case horaryHome(HoraryHomeTab)
    case horaryResult(SavedHoraryQuery, returnTo: HoraryHomeTab)
}
