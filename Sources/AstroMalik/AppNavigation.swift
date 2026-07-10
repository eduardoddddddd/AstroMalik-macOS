import Foundation

enum NavItem: String, CaseIterable, Identifiable {
    // Carta Natal
    case nuevaCarta  = "Nueva Carta"
    case cartas      = "Cartas Guardadas"
    case lectura     = "Lectura"
    case rectificacion = "Rectificación"
    // Predictivas
    case transitos   = "Tránsitos"
    case progresiones = "Progresiones"
    case direccionesPrimarias = "Direcciones Primarias"
    case profecciones = "Profecciones"
    case firdaria    = "Firdaria"
    case zodiacalReleasing = "Zodiacal Releasing"
    // Retornos
    case revolucionSolar = "Revolución Solar"
    case revolucionLunar = "Revolución Lunar"
    // Síntesis
    case crossPersonal = "Estado cross"
    // Sinastría y Horaria
    case sinastria   = "Sinastría"
    case horaria     = "Horaria"
    // Herramientas
    case efemerides  = "Efemérides"
    case misInformes = "Mis informes"
    case ajustes     = "Ajustes"

    var id: String { rawValue }

    /// Texto visible en el sidebar. Separado de `rawValue` para poder
    /// renombrar etiquetas sin afectar la identidad estable del caso.
    var label: String {
        switch self {
        case .crossPersonal: return "Panorama Predictivo"
        case .misInformes:   return "Informes"
        default:             return rawValue
        }
    }

    var systemImage: String {
        switch self {
        case .nuevaCarta: return "star.circle"
        case .cartas:     return "tray.full"
        case .lectura:    return "book.pages"
        case .rectificacion: return "clock.badge.questionmark"
        case .sinastria:  return "person.2.circle"
        case .revolucionSolar: return "sun.max.circle"
        case .revolucionLunar: return "moon.circle"
        case .transitos:  return "calendar.circle"
        case .progresiones: return "moonphase.waxing.crescent"
        case .profecciones: return "clock.arrow.circlepath"
        case .firdaria: return "hourglass.circle"
        case .zodiacalReleasing: return "arrow.triangle.branch"
        case .crossPersonal: return "scope"
        case .efemerides: return "calendar.day.timeline.leading"
        case .horaria:    return "questionmark.bubble"
        case .direccionesPrimarias: return "arrow.triangle.swap"
        case .misInformes: return "doc.richtext"
        case .ajustes: return "gearshape"
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
    case rectification
    case synastry
    case solarReturn
    case lunarReturn
    case savedCharts
    case transits
    case progressions
    case profections
    case firdaria
    case zodiacalReleasing
    case crossPersonal
    case ephemeris
    case horaryHome(HoraryHomeTab)
    case horaryResult(SavedHoraryQuery, returnTo: HoraryHomeTab)
    case primaryDirections(NatalChart)
    case myReports
    case settings

    var viewIdentity: String {
        switch self {
        case .birthForm:
            return "birthForm"
        case .natalResult(let chart, _):
            return "natalResult-\(chart.id.uuidString)"
        case .reading:
            return "reading"
        case .rectification:
            return "rectification"
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
        case .progressions:
            return "progressions"
        case .profections:
            return "profections"
        case .firdaria:
            return "firdaria"
        case .zodiacalReleasing:
            return "zodiacalReleasing"
        case .crossPersonal:
            return "crossPersonal"
        case .ephemeris:
            return "ephemeris"
        case .horaryHome(let tab):
            return "horaryHome-\(tab.id)"
        case .horaryResult(let query, _):
            return "horaryResult-\(query.id.uuidString)"
        case .primaryDirections(let chart):
            return "primaryDirections-\(chart.id.uuidString)"
        case .myReports:
            return "myReports"
        case .settings:
            return "settings"
        }
    }
}
