import Foundation

/// Zona IANA de unas coordenadas a partir de los límites reales de las zonas
/// horarias (timezone-boundary-builder, conjunto completo con océanos, ODbL),
/// simplificados y empaquetados en `timezone_boundaries.bin` por
/// `scripts/build-timezone-boundaries.py`. La zona IANA aporta el historial de
/// cambios de hora; los límites son los actuales.
struct TimeZoneBoundaries: Sendable {
    struct Lookup: Equatable, Sendable {
        /// Primera zona que contiene el punto (orden del conjunto de datos).
        let identifier: String
        /// Todas las zonas que lo contienen; más de una solo en zonas en disputa
        /// del propio conjunto de datos (p. ej. Asia/Shanghai y Asia/Urumqi).
        let candidates: [String]
        var isUnambiguous: Bool { candidates.count == 1 }
    }

    private struct Polygon: Sendable {
        let zone: Int
        let minX: Int32, minY: Int32, maxX: Int32, maxY: Int32
        /// Anillos como pares consecutivos (x, y) en 1e-4 grados.
        let rings: [[Int32]]
    }

    let dataLabel: String
    private let zones: [String]
    private let polygons: [Polygon]

    static let shared: TimeZoneBoundaries? = {
        guard let url = AppResources.bundle.url(forResource: "timezone_boundaries", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? TimeZoneBoundaries(data: data)
    }()

    init(data: Data) throws {
        var reader = Reader(bytes: [UInt8](data))
        guard reader.bytes.count >= 6, Array(reader.bytes[0..<4]) == Array("AMTZ".utf8) else { throw Reader.Failure() }
        reader.offset = 4
        guard try reader.u16() == 1 else { throw Reader.Failure() }
        dataLabel = try reader.string()
        var zones: [String] = []
        for _ in 0..<(try reader.u32()) { zones.append(try reader.string()) }
        var polygons: [Polygon] = []
        for _ in 0..<(try reader.u32()) {
            let zone = Int(try reader.u16())
            guard zone < zones.count else { throw Reader.Failure() }
            let minX = try reader.i32(), minY = try reader.i32(), maxX = try reader.i32(), maxY = try reader.i32()
            var rings: [[Int32]] = []
            for _ in 0..<(try reader.u16()) {
                let count = Int(try reader.u32())
                rings.append(try reader.i32s(count * 2))
            }
            polygons.append(Polygon(zone: zone, minX: minX, minY: minY, maxX: maxX, maxY: maxY, rings: rings))
        }
        guard reader.offset == reader.bytes.count else { throw Reader.Failure() }
        self.zones = zones
        self.polygons = polygons
    }

    func lookup(latitude: Double, longitude: Double) -> Lookup? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        let x = longitude * 10_000, y = latitude * 10_000
        var found: [String] = []
        for polygon in polygons {
            guard x >= Double(polygon.minX), x <= Double(polygon.maxX),
                  y >= Double(polygon.minY), y <= Double(polygon.maxY) else { continue }
            var inside = false
            for ring in polygon.rings {
                let count = ring.count / 2
                var j = count - 1
                for i in 0..<count {
                    let xi = Double(ring[2 * i]), yi = Double(ring[2 * i + 1])
                    let xj = Double(ring[2 * j]), yj = Double(ring[2 * j + 1])
                    if (yi > y) != (yj > y), x < (xj - xi) * (y - yi) / (yj - yi) + xi { inside.toggle() }
                    j = i
                }
            }
            if inside, !found.contains(zones[polygon.zone]) { found.append(zones[polygon.zone]) }
        }
        guard let first = found.first else { return nil }
        return Lookup(identifier: first, candidates: found)
    }

    /// Zona del destino para `AstroPlace`: verificada solo si el punto cae en
    /// una única zona que Foundation conoce; si no, UTC sin verificar.
    static func destinationTimeZone(latitude: Double, longitude: Double) throws -> AstroDestinationTimeZone {
        if let found = shared?.lookup(latitude: latitude, longitude: longitude), found.isUnambiguous,
           let zone = try? AstroDestinationTimeZone(verifiedIdentifier: found.identifier) {
            return zone
        }
        return try AstroDestinationTimeZone()
    }

    /// The same place with the zone of its coordinates. Used by the JSON host
    /// for `places.search` (birth places); the astrocartography search keeps
    /// its UTC rule because its zone is display metadata only.
    static func resolving(_ place: AstroPlace) throws -> AstroPlace {
        try AstroPlace(name: place.name, coordinate: place.coordinate, origin: place.origin,
                       timeZone: destinationTimeZone(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
    }

    private struct Reader {
        struct Failure: Error {}
        let bytes: [UInt8]
        var offset = 0
        mutating func take(_ count: Int) throws -> ArraySlice<UInt8> {
            guard count >= 0, offset + count <= bytes.count else { throw Failure() }
            defer { offset += count }
            return bytes[offset..<(offset + count)]
        }
        mutating func u16() throws -> UInt16 {
            let b = try take(2); return UInt16(b[b.startIndex]) | UInt16(b[b.startIndex + 1]) << 8
        }
        mutating func u32() throws -> UInt32 {
            let b = try take(4)
            return b.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
        }
        mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }
        mutating func i32s(_ count: Int) throws -> [Int32] {
            let raw = try take(count * 4)
            var values = [Int32](repeating: 0, count: count)
            var index = raw.startIndex
            for k in 0..<count {
                values[k] = Int32(bitPattern: UInt32(raw[index]) | UInt32(raw[index + 1]) << 8
                    | UInt32(raw[index + 2]) << 16 | UInt32(raw[index + 3]) << 24)
                index += 4
            }
            return values
        }
        mutating func string() throws -> String {
            let length = Int(try u16())
            guard let value = String(bytes: try take(length), encoding: .utf8) else { throw Failure() }
            return value
        }
    }
}
