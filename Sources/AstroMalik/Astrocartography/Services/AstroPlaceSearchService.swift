import Foundation

enum AstroPlaceOrigin: String, Codable, Sendable { case localCatalog, nominatim, manual, map }
struct AstroPlace: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(origin.rawValue):\(name):\(coordinate.latitude):\(coordinate.longitude)" }
    let name: String
    let coordinate: GeoCoordinate
    let origin: AstroPlaceOrigin
    let timeZone: AstroDestinationTimeZone
}
struct AstroPlaceSearchResult: Equatable, Sendable {
    let places: [AstroPlace]
    let warning: String?
}
protocol AstroPlaceSearching: Sendable {
    func search(query: String, online: Bool) async throws -> AstroPlaceSearchResult
}

/// Local catalog is always available. Network lookup requires an explicit UI
/// opt-in; coordinates from either catalog are not historical timezone evidence.
struct AstroPlaceSearchService: AstroPlaceSearching {
    let catalog: [AstroPlace]
    init(data: Data) throws {
        struct City: Decodable { let label: String; let lat: Double; let lon: Double }
        catalog = try JSONDecoder().decode([City].self, from: data).map {
            try AstroPlace(name: $0.label, coordinate: GeoCoordinate(latitude: $0.lat, longitude: $0.lon),
                           origin: .localCatalog, timeZone: AstroDestinationTimeZone())
        }
    }
    init() throws {
        guard let url = AppResources.bundle.url(forResource: "cities_seed", withExtension: "json") else {
            throw AstrocartographyError.invalidValue("localPlaceCatalogMissing")
        }
        try self.init(data: Data(contentsOf: url))
    }
    func search(query: String, online: Bool = false) async throws -> AstroPlaceSearchResult {
        try Task.checkCancellation()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return AstroPlaceSearchResult(places: [], warning: nil) }
        let local = Array(catalog.filter { $0.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }.prefix(10))
        guard online else { return AstroPlaceSearchResult(places: local, warning: nil) }
        do {
            var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
            components.queryItems = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "limit", value: "10"), URLQueryItem(name: "featuretype", value: "city")]
            var request = URLRequest(url: components.url!); request.timeoutInterval = 15
            request.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AstrocartographyError.invalidValue("placeSearchHTTP")
            }
            struct Remote: Decodable { let display_name: String; let lat: String; let lon: String }
            let remote = try JSONDecoder().decode([Remote].self, from: data).compactMap { item -> AstroPlace? in
                guard let lat = Double(item.lat), let lon = Double(item.lon),
                      let coordinate = try? GeoCoordinate(latitude: lat, longitude: lon) else { return nil }
                return try AstroPlace(name: item.display_name, coordinate: coordinate, origin: .nominatim, timeZone: AstroDestinationTimeZone())
            }
            var merged = local
            for place in remote where !merged.contains(where: { $0.coordinate == place.coordinate }) { merged.append(place) }
            return AstroPlaceSearchResult(places: Array(merged.prefix(10)), warning: nil)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            return AstroPlaceSearchResult(places: local, warning: "Búsqueda online no disponible; se muestran solo coincidencias locales. Puedes introducir coordenadas manualmente.")
        }
    }
}
