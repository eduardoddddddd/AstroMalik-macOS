import Foundation

// MARK: - Place Model

struct Place: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String
    let latitude: Double
    let longitude: Double
    let timezone: String
}

// MARK: - Places Service
// Porta places.py: busca ciudades primero en seed local, luego Nominatim.

final class PlacesService {
    private var seedCities: [SeedCity] = []

    init() {
        loadSeed()
    }

    // MARK: - Seed

    private struct SeedCity: Codable {
        let label: String     // "Madrid, España"
        let lat: Double
        let lon: Double
    }

    private func loadSeed() {
        guard let url = AppResources.bundle.url(forResource: "cities_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cities = try? JSONDecoder().decode([SeedCity].self, from: data)
        else {
            print("[PlacesService] No se pudo cargar cities_seed.json")
            return
        }
        seedCities = cities
    }

    // MARK: - Search

    func search(query: String) async -> [Place] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let fromSeed = searchSeed(query: query)
        if fromSeed.count >= 3 { return fromSeed }

        let fromNominatim = await searchNominatim(query: query)
        var merged = fromSeed
        let seedNames = Set(fromSeed.map { $0.name.lowercased() })
        merged += fromNominatim.filter { !seedNames.contains($0.name.lowercased()) }
        return Array(merged.prefix(10))
    }

    private func searchSeed(query: String) -> [Place] {
        let q = query.lowercased()
        return seedCities
            .filter { $0.label.lowercased().contains(q) }
            .prefix(5)
            .map { city in
                let namePart = city.label.components(separatedBy: ",").first ?? city.label
                return Place(
                    name: namePart.trimmingCharacters(in: .whitespaces),
                    displayName: city.label,
                    latitude: city.lat,
                    longitude: city.lon,
                    timezone: timezoneForCoordinates(lat: city.lat, lon: city.lon)
                )
            }
    }

    // MARK: - Nominatim

    private func searchNominatim(query: String) async -> [Place] {
        guard var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search") else {
            return []
        }
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "featuretype", value: "city"),
        ]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let items = try JSONDecoder().decode([NominatimResult].self, from: data)
            return items.compactMap { item -> Place? in
                guard let lat = Double(item.lat), let lon = Double(item.lon) else { return nil }
                let tz = timezoneForCoordinates(lat: lat, lon: lon)
                return Place(
                    name: item.name ?? item.displayName.components(separatedBy: ",").first ?? query,
                    displayName: item.displayName,
                    latitude: lat,
                    longitude: lon,
                    timezone: tz
                )
            }
        } catch {
            print("[PlacesService] Nominatim error: \(error)")
            return []
        }
    }

    private struct NominatimResult: Decodable {
        let displayName: String
        let lat: String
        let lon: String
        let name: String?
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case lat, lon, name
        }
    }

    // MARK: - Timezone inference
    // Aproximación offline determinista: primero zonas conocidas, luego bandas no solapadas.

    func timezoneForCoordinates(lat: Double, lon: Double) -> String {
        let knownZones: [(lat: Double, lon: Double, radius: Double, tz: String)] = [
            (40.4168, -3.7038, 2.5, "Europe/Madrid"),
            (48.8566, 2.3522, 2.5, "Europe/Paris"),
            (51.5072, -0.1276, 2.5, "Europe/London"),
            (52.5200, 13.4050, 2.5, "Europe/Berlin"),
            (41.9028, 12.4964, 2.5, "Europe/Rome"),
            (37.9838, 23.7275, 2.5, "Europe/Athens"),
            (40.7128, -74.0060, 3.0, "America/New_York"),
            (41.8781, -87.6298, 3.0, "America/Chicago"),
            (39.7392, -104.9903, 3.0, "America/Denver"),
            (34.0522, -118.2437, 3.0, "America/Los_Angeles"),
            (35.6762, 139.6503, 3.0, "Asia/Tokyo"),
            (28.6139, 77.2090, 3.0, "Asia/Kolkata"),
            (-33.8688, 151.2093, 3.0, "Australia/Sydney"),
        ]
        if let known = knownZones.first(where: {
            abs(lat - $0.lat) <= $0.radius && abs(lon - $0.lon) <= $0.radius
        }) {
            return known.tz
        }

        let regions: [(latRange: ClosedRange<Double>, lonRange: ClosedRange<Double>, tz: String)] = [
            (35...44, -10 ... -1, "Europe/Madrid"),
            (42...51, -1 ... 8,   "Europe/Paris"),
            (47...55, 8...16,     "Europe/Berlin"),
            (35...47, 10...19,    "Europe/Rome"),
            (36...42, 19...30,    "Europe/Athens"),
            (50...60, -8 ... 1.5, "Europe/London"),
            (51...71, 24...31,    "Europe/Helsinki"),
            (55...70, 10...24,    "Europe/Stockholm"),
            (55...60, 23...27,    "Europe/Tallinn"),
            (39...47, -9.5 ... -6, "Atlantic/Azores"),
            (24...50, -82.5 ... -66, "America/New_York"),
            (24...50, -97.5 ... -82.5, "America/Chicago"),
            (24...50, -115 ... -97.5, "America/Denver"),
            (20...65, -170 ... -115, "America/Los_Angeles"),
            (-55...12, -80 ... -35, "America/Sao_Paulo"),
            (23...45, 100...145,  "Asia/Tokyo"),
            (8...53,  70...90,   "Asia/Kolkata"),
            (18...54, 90...135,  "Asia/Shanghai"),
            (-44...(-10), 110...155, "Australia/Sydney"),
            (-45...(-10), 115...130, "Australia/Perth"),
        ]
        for r in regions {
            if r.latRange.contains(lat) && r.lonRange.contains(lon) {
                return r.tz
            }
        }
        // Fallback: offset numérico
        let offsetHours = Int((lon / 15).rounded())
        let clampedOffset = min(12, max(-12, offsetHours))
        return TimeZone(secondsFromGMT: clampedOffset * 3600)?.identifier ?? "UTC"
    }
}
