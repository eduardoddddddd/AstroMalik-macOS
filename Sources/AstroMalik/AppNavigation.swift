import Foundation

enum NavItem: String, CaseIterable, Identifiable {
    case nuevaCarta  = "Nueva Carta"
    case cartas      = "Cartas Guardadas"
    case lectura     = "Lectura"
    case sinastria   = "Sinastría"
    case revolucionSolar = "Revolución Solar"
    case revolucionLunar = "Revolución Lunar"
    case transitos   = "Tránsitos"
    case efemerides  = "Efemérides"
    case horaria     = "Horaria"
    case direccionesPrimarias = "Direcciones Primarias"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nuevaCarta: return "star.circle"
        case .cartas:     return "tray.full"
        case .lectura:    return "book.pages"
        case .sinastria:  return "person.2.circle"
        case .revolucionSolar: return "sun.max.circle"
        case .revolucionLunar: return "moon.circle"
        case .transitos:  return "calendar.circle"
        case .efemerides: return "calendar.day.timeline.leading"
        case .horaria:    return "questionmark.bubble"
        case .direccionesPrimarias: return "arrow.triangle.swap"
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
    case solarReturn
    case lunarReturn
    case savedCharts
    case transits
    case ephemeris
    case horaryHome(HoraryHomeTab)
    case horaryResult(SavedHoraryQuery, returnTo: HoraryHomeTab)
    case primaryDirections(NatalChart)

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
        case .solarReturn:
            return "solarReturn"
        case .lunarReturn:
            return "lunarReturn"
        case .savedCharts:
            return "savedCharts"
        case .transits:
            return "transits"
        case .ephemeris:
            return "ephemeris"
        case .horaryHome(let tab):
            return "horaryHome-\(tab.id)"
        case .horaryResult(let query, _):
            return "horaryResult-\(query.id.uuidString)"
        case .primaryDirections(let chart):
            return "primaryDirections-\(chart.id.uuidString)"
        }
    }
}
