import Foundation

// MARK: - SavedChart (sin GRDB — guardado via SQLiteDB directo)

struct SavedChartRecord {
    let id: String              // UUID string
    var name: String
    var birthDate: String
    var birthTime: String
    var timezone: String
    var latitude: Double
    var longitude: Double
    var placeName: String
    var chartJSON: String
    var createdAt: Double       // Unix timestamp

    init(from chart: NatalChart) {
        self.id = chart.id.uuidString
        self.name = chart.name
        self.birthDate = chart.birthDate
        self.birthTime = chart.birthTime
        self.timezone = chart.timezone
        self.latitude = chart.latitude
        self.longitude = chart.longitude
        self.placeName = chart.placeName
        let encoder = JSONEncoder()
        self.chartJSON = (try? String(data: encoder.encode(chart), encoding: .utf8)) ?? "{}"
        self.createdAt = chart.createdAt.timeIntervalSince1970
    }

    func toNatalChart() -> NatalChart? {
        guard let data = chartJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NatalChart.self, from: data)
    }

    static func createTable(db: SQLiteDB) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS saved_charts (
                id          TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                birth_date  TEXT NOT NULL,
                birth_time  TEXT NOT NULL,
                timezone    TEXT NOT NULL,
                latitude    REAL NOT NULL,
                longitude   REAL NOT NULL,
                place_name  TEXT NOT NULL DEFAULT '',
                chart_json  TEXT NOT NULL,
                created_at  REAL NOT NULL
            )
        """)
    }

    func save(to db: SQLiteDB) throws {
        let sql = """
            INSERT OR REPLACE INTO saved_charts
            (id, name, birth_date, birth_time, timezone, latitude, longitude, place_name, chart_json, created_at)
            VALUES (?,?,?,?,?,?,?,?,?,?)
        """
        try db.run(sql, args: [
            .text(id), .text(name), .text(birthDate), .text(birthTime),
            .text(timezone), .real(latitude), .real(longitude), .text(placeName),
            .text(chartJSON), .real(createdAt)
        ])
    }

    static func fetchAll(from db: SQLiteDB) throws -> [SavedChartRecord] {
        let rows = try db.query("SELECT * FROM saved_charts ORDER BY created_at DESC")
        return rows.compactMap { row -> SavedChartRecord? in
            guard let id = row["id"]?.string,
                  let name = row["name"]?.string,
                  let bd = row["birth_date"]?.string,
                  let bt = row["birth_time"]?.string,
                  let tz = row["timezone"]?.string,
                  let lat = row["latitude"]?.double,
                  let lon = row["longitude"]?.double,
                  let json = row["chart_json"]?.string,
                  let ca = row["created_at"]?.double
            else { return nil }
            return SavedChartRecord(
                id: id, name: name, birthDate: bd, birthTime: bt,
                timezone: tz, latitude: lat, longitude: lon,
                placeName: row["place_name"]?.string ?? "",
                chartJSON: json, createdAt: ca
            )
        }
    }
}

// Allow init with individual fields for fetchAll
extension SavedChartRecord {
    init(id: String, name: String, birthDate: String, birthTime: String,
         timezone: String, latitude: Double, longitude: Double,
         placeName: String, chartJSON: String, createdAt: Double) {
        self.id = id; self.name = name; self.birthDate = birthDate
        self.birthTime = birthTime; self.timezone = timezone
        self.latitude = latitude; self.longitude = longitude
        self.placeName = placeName; self.chartJSON = chartJSON
        self.createdAt = createdAt
    }
}
