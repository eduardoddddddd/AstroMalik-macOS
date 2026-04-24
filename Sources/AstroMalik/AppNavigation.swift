import Foundation

enum NavItem: String, CaseIterable, Identifiable {
    case nuevaCarta  = "Nueva Carta"
    case cartas      = "Cartas Guardadas"
    case lectura     = "Lectura"
    case sinastria   = "Sinastría"
    case transitos   = "Tránsitos"
    case horaria     = "Horaria"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nuevaCarta: return "star.circle"
        case .cartas:     return "tray.full"
        case .lectura:    return "book.pages"
        case .sinastria:  return "person.2.circle"
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
    case reading
    case synastry
    case savedCharts
    case transits
    case horaryHome(HoraryHomeTab)
    case horaryResult(SavedHoraryQuery, returnTo: HoraryHomeTab)

    var viewIdentity: String {
        switch self {
        case .birthForm:
            return "birthForm"
        case .natalResult(let chart, _):
            return "natalResult-\(chart.id.uuidString)"
        case .reading:
            return "reading"
        case .synastry:
            return "synastry"
        case .savedCharts:
            return "savedCharts"
        case .transits:
            return "transits"
        case .horaryHome(let tab):
            return "horaryHome-\(tab.id)"
        case .horaryResult(let query, _):
            return "horaryResult-\(query.id.uuidString)"
        }
    }
}
