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
    // Approximación por región geográfica → zona IANA más cercana

    func timezoneForCoordinates(lat: Double, lon: Double) -> String {
        // Tabla de regiones comunes → IANA timezone
        let regions: [(latRange: ClosedRange<Double>, lonRange: ClosedRange<Double>, tz: String)] = [
            (35...44, -10...5,   "Europe/Madrid"),
            (41...52, -5...10,   "Europe/Paris"),
            (47...55, 5...15,    "Europe/Berlin"),
            (35...47, 10...20,   "Europe/Rome"),
            (36...42, 25...35,   "Europe/Athens"),
            (50...60, -8...2,    "Europe/London"),
            (51...71, 24...30,   "Europe/Helsinki"),
            (55...70, 10...24,   "Europe/Stockholm"),
            (55...60, 23...27,   "Europe/Tallinn"),
            (39...47, -9.5 ... -6, "Atlantic/Azores"),
            (25...50, -130 ... -60, "America/New_York"),
            (25...50, -100 ... -80, "America/Chicago"),
            (25...50, -125 ... -100, "America/Denver"),
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
