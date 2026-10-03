import Foundation

struct AstroBaseMapResult: Sendable, Equatable {
    /// `data:image/jpeg;base64,â€¦` of the whole Web-Mercator world, or nil.
    let dataURI: String?
    /// Human reason when the base map could not be obtained (offline, timeoutâ€¦).
    let failure: String?

    static func unavailable(_ reason: String) -> AstroBaseMapResult { AstroBaseMapResult(dataURI: nil, failure: reason) }
}

typealias AstroBaseMapProvider = @Sendable () async -> AstroBaseMapResult

#if !canImport(MapKit)
enum AstroBaseMapSnapshot {
    static let attribution = "Mapa base proporcionado por la aplicaciÃ³n."
    static func capture(timeout: TimeInterval = 20) async -> AstroBaseMapResult {
        .unavailable("MapKit no estÃ¡ disponible en Windows; se conserva la cuadrÃ­cula y todas las lÃ­neas calculadas.")
    }
}
#endif
