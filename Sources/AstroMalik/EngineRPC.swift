import Foundation

/// Public JSON boundary; no internal calculation types escape AstroMalikCore.
public enum EngineJSON: Codable, Sendable, Equatable {
    case null, bool(Bool), integer(Int64), number(Double), string(String)
    case array([EngineJSON]), object([String: EngineJSON])
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let x = try? c.decode(Bool.self) { self = .bool(x) }
        else if let x = try? c.decode(Int64.self) { self = .integer(x) }
        else if let x = try? c.decode(Double.self), x.isFinite { self = .number(x) }
        else if let x = try? c.decode(String.self) { self = .string(x) }
        else if let x = try? c.decode([EngineJSON].self) { self = .array(x) }
        else { self = .object(try c.decode([String: EngineJSON].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let x): try c.encode(x)
        case .integer(let x): try c.encode(x)
        case .number(let x): try c.encode(x)
        case .string(let x): try c.encode(x)
        case .array(let x): try c.encode(x)
        case .object(let x): try c.encode(x)
        }
    }
    public subscript(_ key: String) -> EngineJSON { if case .object(let o) = self { return o[key] ?? .null }; return .null }
    public var string: String? { if case .string(let s) = self { return s }; return nil }
    public var object: [String: EngineJSON]? { if case .object(let o) = self { return o }; return nil }
    public var array: [EngineJSON]? { if case .array(let a) = self { return a }; return nil }
    public var double: Double? { switch self { case .number(let n): return n; case .integer(let n): return Double(n); default: return nil } }
    public var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    public static func value<T: Encodable>(_ value: T) throws -> EngineJSON {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        return try JSONDecoder().decode(Self.self, from: e.encode(value))
    }
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer(); let s = try c.decode(String.self)
            guard let date = Self.date(s) else { throw EngineRPCError.invalid("Fecha ISO 8601 con zona obligatoria") }
            return date
        }
        do { return try d.decode(type, from: JSONEncoder().encode(self)) }
        catch let error as EngineRPCError { throw error }
        catch { throw EngineRPCError.invalid("Estructura incompatible: \(type)") }
    }
    static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
    func required(_ key: String) throws -> String {
        guard let s = self[key].string, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EngineRPCError.invalid("Falta \(key)") }
        return s
    }
    func integer(_ key: String, default fallback: Int, range: ClosedRange<Int>) throws -> Int {
        if self[key] == .null { return fallback }
        guard case .integer(let n) = self[key], let value = Int(exactly: n), range.contains(value) else { throw EngineRPCError.invalid("\(key) fuera de rango") }
        return value
    }
}

public struct EngineRPCError: Error, LocalizedError, Sendable {
    public let code: String
    public let message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
    static func invalid(_ message: String) -> Self { Self("INVALID_PARAMS", message) }
}

/// Host serializes calls, including suspension points, to preserve Swiss state.
public actor EngineRPCService {
    public static let methods = [
        "system.hello", "charts.list", "charts.get", "charts.save", "charts.delete", "charts.importFromMac",
        "places.search", "natal.compute", "natal.extended", "natal.wheelSvg", "reading.compose",
        "transits.range", "transits.timelineSvg", "progressions", "primaryDirections", "primaryDirections.speculum",
        "solarArc", "profections", "firdaria", "zodiacalReleasing", "solarReturn", "lunarReturn", "synastry",
        "synastry.doubleWheelSvg", "crossPersonal", "ephemeris.month", "ephemeris.day", "monthlySummary",
        "horary.compute", "horary.list", "horary.get", "horary.save", "rectification.run", "rectification.sessions",
        "astrocartography.lines", "astrocartography.place", "astrocartography.mapSvg", "reports.html", "settings.get", "settings.set"
    ]
    private let dataDirectory: URL
    private let macCommit: String
    private let ephemerisPath: String?
    private let backend: String
    private var database: SQLiteDB?
    private var corpus: CorpusStore?
    public init(dataDirectory: String, macCommit: String, moshier: Bool = false) throws {
        self.dataDirectory = URL(fileURLWithPath: dataDirectory, isDirectory: true).standardizedFileURL
        self.macCommit = macCommit
        let bundled = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe")?.deletingLastPathComponent().path
        guard moshier || bundled != nil else { throw EngineRPCError("RESOURCE_MISSING", "Faltan las efemérides empaquetadas") }
        ephemerisPath = moshier ? nil : bundled
        backend = moshier ? "moshier" : "swiss-files"
    }
    private func db() throws -> SQLiteDB {
        if let database { return database }
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let d = try SQLiteDB(path: dataDirectory.appendingPathComponent("user.db").path)
        try SavedChartRecord.createTable(db: d); try SavedChartRecord.migrateMetadataColumns(db: d)
        try EngineHoraryPersistence.create(db: d)
        try d.execute("CREATE TABLE IF NOT EXISTS engine_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        database = d; return d
    }
    private func corpusStore() throws -> CorpusStore {
        if let corpus { return corpus }
        guard let url = AppResources.bundle.url(forResource: "corpus", withExtension: "db") else { throw EngineRPCError("RESOURCE_MISSING", "Falta corpus.db") }
        let c = try CorpusStore(path: url.path); corpus = c; return c
    }
    private func date(_ params: EngineJSON, _ key: String) throws -> Date {
        let s = try params.required(key)
        guard let date = EngineJSON.date(s), (1800...3000).contains(Calendar(identifier: .gregorian).component(.year, from: date)) else { throw EngineRPCError.invalid("\(key): ISO 8601 con zona, años 1800–3000") }
        return date
    }
    private func uuid(_ params: EngineJSON, _ key: String = "id") throws -> UUID {
        guard let id = UUID(uuidString: try params.required(key)) else { throw EngineRPCError.invalid("\(key): UUID obligatorio") }; return id
    }
    private func validateChart(_ chart: NatalChart) throws {
        try validateBirthDate(chart.birthDate)
        _ = try AstroRelocationEngine.houseCode(chart.houseSystem)
        _ = try julianDayFromLocal(birthDate: chart.birthDate, birthTime: chart.birthTime, timezoneName: chart.timezone)
        guard (-90...90).contains(chart.latitude), (-180...180).contains(chart.longitude),
              chart.cusps.count == 12, chart.cusps.allSatisfy({ $0.isFinite && (0..<360).contains($0) }),
              chart.ascendant.longitude.isFinite, (0..<360).contains(chart.ascendant.longitude),
              chart.mc.longitude.isFinite, (0..<360).contains(chart.mc.longitude),
              Set(chart.bodies.map(\.key)).count == chart.bodies.count,
              Set(PLANET_LIST.map(\.key)).isSubset(of: Set(chart.bodies.map(\.key))),
              chart.bodies.allSatisfy({ $0.longitude.isFinite && (0..<360).contains($0.longitude) && (1...12).contains($0.house) })
        else { throw EngineRPCError.invalid("Carta incompleta, coordenadas, casas o longitudes inválidas") }
    }
    private func loadChart(_ id: UUID) throws -> NatalChart {
        guard let row = try db().queryOne("SELECT chart_json FROM saved_charts WHERE id=?", args: [.text(id.uuidString)]),
              let json = row["chart_json"]?.string,
              let chart = try? JSONDecoder().decode(NatalChart.self, from: Data(json.utf8))
        else { throw EngineRPCError("NOT_FOUND", "Carta no encontrada") }
        return chart
    }
    private func chart(_ params: EngineJSON, key: String = "chart", idKey: String = "chartId") throws -> NatalChart {
        guard !(params[key] != .null && params[idKey] != .null) else { throw EngineRPCError.invalid("Usa \(key) o \(idKey)") }
        let c: NatalChart
        if params[key] != .null { c = try params[key].decode(NatalChart.self) }
        else { c = try loadChart(uuid(params, idKey)) }
        try validateChart(c); return c
    }
    private func saveChart(_ chart: NatalChart, params: EngineJSON) throws {
        try validateChart(chart)
        let d = try db()
        var record = SavedChartRecord(from: chart)
        // Preserve annotations on a calculation-only save.
        if let row = try d.queryOne("SELECT notes,tags FROM saved_charts WHERE id=?", args: [.text(chart.id.uuidString)]) {
            record.notes = row["notes"]?.string ?? ""
            record.tags = (row["tags"]?.string ?? "").split(separator: ",").map(String.init)
        }
        if params["notes"] != .null {
            guard let notes = params["notes"].string else { throw EngineRPCError.invalid("notes debe ser un texto") }
            record.notes = notes
        }
        if params["tags"] != .null {
            guard let values = params["tags"].array, values.allSatisfy({ $0.string != nil && !$0.string!.contains(",") }) else { throw EngineRPCError.invalid("tags debe ser una lista de textos sin comas") }
            record.tags = values.compactMap(\.string)
        }
        let places = try AstroSavedPlaceRepository(db: d)
        try d.execute("BEGIN IMMEDIATE")
        do {
            try record.save(to: d)
            try places.invalidateResults(for: chart.id, matching: AstroNatalFingerprint.make(chart))
            try d.execute("COMMIT")
        } catch { try? d.execute("ROLLBACK"); throw error }
    }
    private func natal(_ p: EngineJSON) throws -> NatalChart {
        guard let lat = p["latitude"].double, let lon = p["longitude"].double, (-90...90).contains(lat), (-180...180).contains(lon) else { throw EngineRPCError.invalid("Coordenadas obligatorias y dentro de rango") }
        let birthDate = try p.required("birthDate"), birthTime = try p.required("birthTime"), timezone = try p.required("timezone")
        try validateBirthDate(birthDate)
        let jd = try julianDayFromLocal(birthDate: birthDate, birthTime: birthTime, timezoneName: timezone).jd
        let houseSystem = p["houseSystem"].string ?? "Placidus"
        let c = try AstroEngine.computeNatalChart(jd: jd, lat: lat, lon: lon, houseSystem: AstroRelocationEngine.houseCode(houseSystem))
        return NatalChart(id: p["id"] == .null ? UUID() : try uuid(p), name: try p.required("name"), birthDate: birthDate, birthTime: birthTime,
                          timezone: timezone, latitude: lat, longitude: lon, placeName: p["placeName"].string ?? "", houseSystem: houseSystem,
                          ascendant: c.ascendant, mc: c.mc, cusps: c.cusps, bodies: c.bodies)
    }
    private func validateBirthDate(_ value: String) throws {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), (1800...3000).contains(year) else { throw EngineRPCError.invalid("birthDate: YYYY-MM-DD, años 1800–3000") }
    }
    private func range(_ p: EngineJSON) throws -> (Date, Date) {
        let from = try date(p, "from"), to = try date(p, "to")
        guard to >= from, to.timeIntervalSince(from) < 3660 * 86400 else { throw EngineRPCError.invalid("Rango de 0 a 3659 días") }; return (from, to)
    }
    private func astro(_ chart: NatalChart) throws -> AstrocartographyResult {
        try AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: ephemerisPath ?? dataDirectory.appendingPathComponent("moshier").path))
            .calculate(request: AstroChartInput(chart).request())
    }
    public func invoke(method: String, params p: EngineJSON = .object([:]),
                       progress: @escaping @Sendable (Double, String) async -> Void = { _, _ in }) async throws -> EngineJSON {
        guard p.object != nil else { throw EngineRPCError.invalid("params debe ser un objeto") }
        try Task.checkCancellation()
        guard Self.methods.contains(method) else { throw EngineRPCError("METHOD_NOT_FOUND", "Método desconocido") }
        // Configure every serialized request; relocation may have reset the library.
        AstroEngine.configure(ephePath: ephemerisPath)
        switch method {
        case "system.hello":
            return .object(["engineVersion": .string("0.3.0"), "protocolVersion": .integer(1), "macCommit": .string(macCommit),
                            "swissVersion": .string(try SwissAstrocartographyEphemeris.libraryVersion()), "ephemerisBackend": .string(backend),
                            "dataDirectory": .string(dataDirectory.path), "methods": .array(Self.methods.map(EngineJSON.string)),
                            "networkEnabled": .bool(false)])
        case "charts.list":
            let records = try SavedChartRecord.fetchAll(from: db())
            return .array(try records.map { r in
                guard let c = r.toNatalChart() else { throw EngineRPCError("STORAGE_ERROR", "Carta almacenada ilegible") }
                return .object(["chart": try .value(c), "notes": .string(r.notes), "tags": .array(r.tags.map(EngineJSON.string))])
            })
        case "charts.get": return try .value(loadChart(uuid(p)))
        case "charts.save":
            let c = try p["chart"].decode(NatalChart.self); try saveChart(c, params: p); return try .value(c)
        case "charts.delete":
            let id = try uuid(p); _ = try loadChart(id)
            let d = try db(), places = try AstroSavedPlaceRepository(db: db())
            try d.execute("BEGIN IMMEDIATE")
            do {
                try places.deletePlaces(for: id)
                try d.run("DELETE FROM saved_charts WHERE id=?", args: [.text(id.uuidString)])
                try d.execute("COMMIT")
            } catch { try? d.execute("ROLLBACK"); throw error }
            return .object(["deleted": .bool(true)])
        case "charts.importFromMac":
            guard let charts = p["charts"].array, !charts.isEmpty, charts.count <= 1000 else { throw EngineRPCError.invalid("charts: entre 1 y 1000 cartas exportadas") }
            let decoded = try charts.map { try $0.decode(NatalChart.self) }
            for c in decoded { try validateChart(c) }
            guard Set(decoded.map(\.id)).count == decoded.count else { throw EngineRPCError.invalid("UUID duplicado en importación") }
            let d = try db()
            // Existing IDs require an explicit overwrite; never silently replace personal data.
            for c in decoded where p["overwrite"].bool != true {
                if try d.queryOne("SELECT id FROM saved_charts WHERE id=?", args: [.text(c.id.uuidString)]) != nil { throw EngineRPCError("CONFLICT", "La carta ya existe; usa overwrite=true") }
            }
            let places = try AstroSavedPlaceRepository(db: d)
            try d.execute("BEGIN IMMEDIATE")
            do {
                for c in decoded {
                    var record = SavedChartRecord(from: c)
                    if let existing = try d.queryOne("SELECT notes,tags FROM saved_charts WHERE id=?", args: [.text(c.id.uuidString)]) {
                        record.notes = existing["notes"]?.string ?? ""; record.tags = (existing["tags"]?.string ?? "").split(separator: ",").map(String.init)
                    }
                    try record.save(to: d); try places.invalidateResults(for: c.id, matching: AstroNatalFingerprint.make(c))
                }
                try d.execute("COMMIT")
            } catch { try? d.execute("ROLLBACK"); throw error }
            return .object(["imported": .integer(Int64(decoded.count)), "ids": .array(decoded.map { .string($0.id.uuidString) })])
        case "places.search":
            let query = try p.required("query")
            guard query.count <= 200 else { throw EngineRPCError.invalid("query demasiado larga") }
            let result = try await AstroPlaceSearchService().search(query: query, online: false)
            return .object(["places": try .value(result.places), "warning": result.warning.map(EngineJSON.string) ?? .null])
        case "natal.compute": return try .value(natal(p))
        case "natal.extended": return try .value(NatalExtendedAnalysis.compute(chart: chart(p)))
        case "natal.wheelSvg": return .object(["svg": .string(wheel(chart: try chart(p), theme: .default, size: try p.integer("size", default: 600, range: 256...2048)))])
        case "synastry", "synastry.doubleWheelSvg":
            let a = try chart(p, key: "chartA", idKey: "chartAId"), b = try chart(p, key: "chartB", idKey: "chartBId")
            if method == "synastry" { return try .value(AstroEngine.computeSynastryAspects(chartA: a, chartB: b)) }
            return .object(["svg": .string(doubleWheel(natal: a, secondary: b, theme: .default, size: try p.integer("size", default: 700, range: 256...2048)))])
        case "primaryDirections.speculum":
            let c = try chart(p), jd = try julianDayFromLocal(birthDate: c.birthDate, birthTime: c.birthTime, timezoneName: c.timezone).jd
            return try .value(PrimaryDirectionCalculator().computeFullSpeculum(chart: c, jd: jd))
        case "transits.range", "transits.timelineSvg":
            let c = try chart(p), (from, to) = try range(p)
            let corpus = try corpusStore(), exclude = p["excludeMoon"].bool ?? true
            let events = try await computeTransitPeriod(natalChart: c, fromDate: from, toDate: to, timezone: c.timezone, excludeMoon: exclude, corpusStore: corpus, progress: { fraction in await progress(fraction * 0.9, "Calculando tránsitos") })
            try Task.checkCancellation()
            if method == "transits.timelineSvg" { return .object(["svg": .string(transitsTimeline(events: events, from: from, to: to, theme: .default, width: try p.integer("width", default: 800, range: 256...2048), height: try p.integer("height", default: 400, range: 128...2048)))]) }
            let ingresses = try detectHouseIngresses(natalChart: c, fromDate: from, toDate: to, excludeMoon: exclude, corpusStore: corpus)
            await progress(1, "Tránsitos calculados")
            return .object(["transits": try .value(events), "houseIngresses": try .value(ingresses)])
        case "ephemeris.day", "ephemeris.month":
            let tz = try p.required("timezone"); guard TimeZone(identifier: tz) != nil else { throw EngineRPCError.invalid("timezone inválida") }
            if method == "ephemeris.month" {
                let year = try p.integer("year", default: 0, range: 1800...3000), month = try p.integer("month", default: 0, range: 1...12)
                guard year != 0, month != 0 else { throw EngineRPCError.invalid("year y month obligatorios") }
                let result = try await EphemerisEngine.computeMonth(year: year, month: month, timezone: tz)
                return .object(["id": .string(result.id), "year": .integer(Int64(result.year)), "month": .integer(Int64(result.month)), "events": try .value(result.events), "dailyRows": try .value(result.dailyRows)])
            }
            let day = try p.required("date")
            try validateBirthDate(day)
            let jd = try julianDayFromLocal(birthDate: day, birthTime: "00:00", timezoneName: "UTC").jd
            return try .value(EphemerisEngine.rpcDailyRow(jd: jd, timezone: tz))
        case "horary.compute":
            let req = try p["request"].decode(HoraryRequest.self)
            guard !req.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (1...12).contains(req.questionHouse), (-90...90).contains(req.latitude), (-180...180).contains(req.longitude) else { throw EngineRPCError.invalid("Pregunta, casa o coordenadas inválidas") }
            let parts = req.datetimeLocal.split(separator: "T", omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw EngineRPCError.invalid("datetimeLocal: YYYY-MM-DDTHH:mm[:ss] y timezone IANA separado") }
            try validateBirthDate(String(parts[0]))
            _ = try julianDayFromLocal(birthDate: String(parts[0]), birthTime: String(parts[1]), timezoneName: req.timezone)
            return try .value(HoraryNativeEngine.calculate(req))
        case "horary.list": return try .value(EngineHoraryPersistence.list(db: db()))
        case "horary.get":
            let id = try uuid(p)
            guard let q = try EngineHoraryPersistence.list(db: db()).first(where: { $0.id == id }) else { throw EngineRPCError("NOT_FOUND", "Consulta horaria no encontrada") }
            return try .value(q)
        case "horary.save":
            let input = try p["query"].decode(SavedHoraryQuery.self)
            // Decode both payloads before persisting an archive.
            let q = try SavedHoraryQuery(id: input.id, request: input.request, response: input.response, createdAt: input.createdAt)
            try EngineHoraryPersistence.save(q, db: db()); return try .value(q)
        case "rectification.run":
            let session = try p["session"].decode(RectificationSession.self)
            try validateBirthDate(session.birthDate)
            let config = p["config"] == .null ? RectificationConfig.default : try p["config"].decode(RectificationConfig.self)
            return try .value(await RectificationEngine().analyze(session: session, config: config, progress: { fraction in await progress(fraction, "Analizando rectificación") }))
        case "rectification.sessions":
            let store = try RectificationSessionStore(path: db().path)
            switch p["action"].string ?? "list" {
            case "list":
                return .array(try store.list().map { item in
                    .object(["id": .string(item.id.uuidString), "name": .string(item.name), "baseChartID": item.baseChartID.map { .string($0.uuidString) } ?? .null,
                             "updatedAt": try .value(item.updatedAt), "hasResult": .bool(item.hasResult), "versionCount": .integer(Int64(item.versionCount))])
                })
            case "get":
                let id = try uuid(p)
                guard try store.list().contains(where: { $0.id == id }) else { throw EngineRPCError("NOT_FOUND", "Sesión no encontrada") }
                return try .value(store.load(id: id))
            case "save":
                let archive = try p["archive"].decode(RectificationSessionArchive.self)
                guard archive.schemaVersion == 1, archive.session.schemaVersion == 1 else { throw EngineRPCError.invalid("Versión de sesión incompatible") }
                try validateBirthDate(archive.session.birthDate)
                _ = try julianDayFromLocal(birthDate: archive.session.birthDate, birthTime: archive.session.reportedBirthTime, timezoneName: archive.session.timezone)
                guard (-90...90).contains(archive.session.latitude), (-180...180).contains(archive.session.longitude) else { throw EngineRPCError.invalid("Coordenadas inválidas") }
                try archive.session.searchRange.validate()
                let v = try store.rpcSave(session: archive.session, result: archive.result, narrative: archive.narrative)
                return .object(["id": .string(archive.session.id.uuidString), "version": .integer(Int64(v))])
            case "delete":
                let id = try uuid(p); guard try store.list().contains(where: { $0.id == id }) else { throw EngineRPCError("NOT_FOUND", "Sesión no encontrada") }
                try store.delete(id: id); return .object(["deleted": .bool(true)])
            default: throw EngineRPCError.invalid("action: list, get, save o delete")
            }
        case "astrocartography.lines", "astrocartography.mapSvg", "astrocartography.place":
            let c = try chart(p), curves = try astro(c)
            if method == "astrocartography.lines" { return try .value(curves) }
            if method == "astrocartography.mapSvg" {
                let lines = try curves.lines.map { try AstroVisualGeometry.adapt($0, domain: AstroVisualDomain()) }
                return .object(["svg": .string(AstroMapSVGRenderer.render(lines: lines, emphasized: nil, place: nil, placeName: nil, baseImageDataURI: nil))])
            }
            guard let lat = p["latitude"].double, let lon = p["longitude"].double else { throw EngineRPCError.invalid("Coordenadas del destino obligatorias") }
            let destination = try GeoCoordinate(latitude: lat, longitude: lon)
            let timeZone = try AstroDestinationTimeZone(verifiedIdentifier: p["timezone"].string)
            let source = try AstroRelocationSource(chart: c, instant: curves.snapshot.request.instant)
            let calculator = AstroLocationCalculator(relocator: AstroRelocationEngine(ephemerisDirectory: ephemerisPath ?? dataDirectory.appendingPathComponent("moshier").path))
            return try .value(calculator.calculate(AstroLocationCalculationRequest(curves: curves, source: source, sourceError: nil, destination: destination, timeZone: timeZone)))
        case "reports.html":
            let type = try p.required("type")
            let templates = ["astrocartography", "calendar", "firdaria", "lunar_return", "monthly_summary", "primary_directions", "profections", "progressions", "solar_arc", "solar_return", "transits", "zodiacal_releasing", "natal", "synastry", "extended_natal", "horary", "cross_personal"]
            guard templates.contains(type), p["data"].object != nil else { throw EngineRPCError.invalid("Tipo de informe o datos inválidos") }
            let html = try await ReportService().renderHTML(request: ReportRequest(templateName: type, data: p["data"]))
            return .object(["html": .string(html), "type": .string(type)])
        case "settings.get", "settings.set": return try settings(method, p)
        default:
            let c = try chart(p)
            let commands: [String: AstroMalikCLICommandKind] = ["reading.compose": .natal, "progressions": .progressions, "primaryDirections": .primaryDirections,
                "solarArc": .solarArc, "profections": .profections, "firdaria": .firdaria, "zodiacalReleasing": .zodiacalReleasing,
                "solarReturn": .solarReturn, "lunarReturn": .lunarReturn, "crossPersonal": .crossPersonal, "monthlySummary": .monthly]
            guard let command = commands[method] else { throw EngineRPCError("METHOD_NOT_FOUND", "Método sin implementación") }
            let reference = method == "reading.compose" ? c.createdAt : try date(p, "referenceDate")
            let month = p["month"].string
            if method == "monthlySummary", let month {
                let parts = month.split(separator: "-"); guard parts.count == 2, parts[0].count == 4, parts[1].count == 2, let y = Int(parts[0]), (1800...3000).contains(y), let m = Int(parts[1]), (1...12).contains(m) else { throw EngineRPCError.invalid("month: YYYY-MM") }
            }
            let scope = p["scope"].string ?? "complete"
            guard let cliScope = AstroMalikCLIScope(rawValue: scope) else { throw EngineRPCError.invalid("scope inválido") }
            let request = AstroMalikCLIRequest(command: command, referenceDate: reference, month: month, scope: cliScope, narrative: method == "reading.compose" ? .local : .none)
            return try await AstroMalikCLIRunner.rpcOutput(chart: c, request: request, corpus: corpusStore())
        }
    }
    private func settings(_ method: String, _ p: EngineJSON) throws -> EngineJSON {
        let defaults: [String: EngineJSON] = ["theme": .string("system"), "houseSystem": .string("Placidus"), "language": .string("es"), "excludeMoon": .bool(true)]
        let d = try db()
        if method == "settings.set" {
            guard let values = p["values"].object, !values.isEmpty else { throw EngineRPCError.invalid("values obligatorio") }
            for (key, value) in values {
                guard defaults[key] != nil else { throw EngineRPCError.invalid("Ajuste no admitido: \(key)") }
                switch key {
                case "theme": guard ["system", "light", "dark"].contains(value.string ?? "") else { throw EngineRPCError.invalid("theme inválido") }
                case "language": guard value == .string("es") else { throw EngineRPCError.invalid("Solo castellano en esta versión") }
                case "houseSystem": _ = try AstroRelocationEngine.houseCode(value.string ?? "")
                default: guard value.bool != nil else { throw EngineRPCError.invalid("excludeMoon debe ser booleano") }
                }
            }
            try d.execute("BEGIN IMMEDIATE")
            do {
                for (key, value) in values {
                    let json = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
                    try d.run("INSERT INTO engine_settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", args: [.text(key), .text(json)])
                }
                try d.execute("COMMIT")
            } catch { try? d.execute("ROLLBACK"); throw error }
        }
        var result = defaults
        for row in try d.query("SELECT key,value FROM engine_settings") {
            if let key = row["key"]?.string, defaults[key] != nil, let raw = row["value"]?.string { result[key] = try JSONDecoder().decode(EngineJSON.self, from: Data(raw.utf8)) }
        }
        return .object(result)
    }
}
