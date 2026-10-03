import Foundation

/// F6: the single, versioned and deterministic description of an astrocartography
/// result. PDF, Joplin Markdown and the CLI JSON are all rendered from it, so
/// they can never disagree. It carries NO timestamp: the same chart, place and
/// resources give byte-identical JSON. Presentation dates belong to each output.
///
/// Reuses the real calculation outputs (snapshot flags, provenance, diagnostics,
/// distances, relocation); nothing is recomputed or rounded for display here.
struct AstroExportDocument: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let kind = "astromalik.astrocartography"

    struct Chart: Codable, Equatable, Sendable {
        let id: UUID
        let name: String
        let birthDate: String
        let birthTime: String
        let timezone: String
        let placeName: String
        let houseSystem: String
        let natalAscendantDegrees: Double
        let natalMCDegrees: Double
        let natalCuspsDegrees: [Double]
    }

    struct Instant: Codable, Equatable, Sendable {
        let julianDay: Double
        let timeScale: String
    }

    struct Method: Codable, Equatable, Sendable {
        let contractVersion: Int
        let convention: String
        let linesAlgorithm: String
        let distanceAlgorithm: String
        let relocationAlgorithm: String?
        let ephemerisSource: String
        let ephemerisLibraryVersion: String
        let sphereRadiusKm: Double
        let geometryToleranceKm: Double
        let diagnostics: [AstroDiagnostic]
    }

    struct Editorial: Codable, Equatable, Sendable {
        let version: String
        let reviewStatus: String
    }

    struct Policy: Codable, Equatable, Sendable {
        let nearKm: Double
        let regionalKm: Double
    }

    struct ChartLine: Codable, Equatable, Sendable {
        let key: String
        let body: String
        let angle: String
        let rightAscensionDegrees: Double
        let declinationDegrees: Double
        let returnedFlags: Int32
        let hasTrace: Bool
        let diagnostics: [String]
    }

    struct ThemeEntry: Codable, Equatable, Sendable {
        let theme: String
        let title: String
        let nearCount: Int
        let regionalCount: Int
        let nearestLine: String?
        let nearestDistanceKm: Double?
    }

    struct LineEntry: Codable, Equatable, Sendable {
        let key: String
        let body: String
        let angle: String
        let distanceKm: Double
        let estimatedErrorKm: Double
        let nearestLatitude: Double
        let nearestLongitude: Double
        let band: String
        let crossesBoundary: Bool
    }

    struct RelocatedBody: Codable, Equatable, Sendable {
        let body: String
        let longitudeDegrees: Double
        let house: Int
    }

    struct Relocation: Codable, Equatable, Sendable {
        let houseSystem: String
        let ascendantDegrees: Double
        let mcDegrees: Double
        let cuspsDegrees: [Double]
        let bodies: [RelocatedBody]
        let timeZone: String
        let timeZoneVerified: Bool
        let diagnostics: [String]
    }

    struct Reading: Codable, Equatable, Sendable {
        let key: String
        let title: String
        let band: String
        let distanceKm: Double
        let mechanism: String
        let potential: String
        let shadow: String
        let practice: String
        let sourceReferences: [String]
    }

    struct Place: Codable, Equatable, Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
        let origin: String
        let timeZone: String
        let timeZoneVerified: Bool
        let headline: String
        let themes: [ThemeEntry]
        let lines: [LineEntry]
        let relocation: Relocation?
        let relocationError: String?
        /// Near and regional lines only, in distance order; empty if readings were not requested.
        let readings: [Reading]
        let missingReadings: [String]
    }

    let schemaVersion: Int
    let kind: String
    let chart: Chart
    let instant: Instant
    let method: Method
    let editorial: Editorial?
    let policy: Policy
    let chartLines: [ChartLine]
    let place: Place?
    let warnings: [String]
    let disclaimer: String

    static func chart(from chart: NatalChart) -> Chart {
        Chart(id: chart.id, name: chart.name, birthDate: chart.birthDate, birthTime: chart.birthTime, timezone: chart.timezone,
              placeName: chart.placeName, houseSystem: chart.houseSystem, natalAscendantDegrees: chart.ascendant.longitude,
              natalMCDegrees: chart.mc.longitude, natalCuspsDegrees: chart.cusps)
    }

    static let disclaimerText = "Lecturas simbólicas de una tradición interpretativa: no demuestran efectos causales ni predicen resultados. Las distancias son geográficas (esfera de radio 6371.0088 km) y las bandas «cerca/regional» son parámetros del programa, no una medida de intensidad."
}

enum AstroExportDocumentBuilder {
    /// Pure assembly from real results. `place` and `calculation` go together.
    static func build(chart: AstroExportDocument.Chart, curves: AstrocartographyResult, place: AstroPlace? = nil,
                      calculation: AstroLocationCalculation? = nil, policy: AstroProximityPolicy? = nil,
                      catalog: AstroReadingCatalog, includeReadings: Bool = true,
                      extraWarnings: [String] = []) throws -> AstroExportDocument {
        guard (place == nil) == (calculation == nil) else { throw AstrocartographyError.invalidValue("exportPlaceAndCalculation") }
        let policy = try policy ?? AstroProximityPolicy()
        let snapshot = curves.snapshot
        var warnings: [String] = extraWarnings + snapshot.provenance.diagnostics.map(\.message)

        let chartLines: [AstroExportDocument.ChartLine] = curves.lines.map { line in
            let position = snapshot.positions.first { $0.body == line.id.body }
            return .init(key: key(line.id), body: line.id.body.rawValue, angle: line.id.angle.rawValue,
                         rightAscensionDegrees: position?.rightAscensionDegrees ?? 0,
                         declinationDegrees: position?.declinationDegrees ?? 0,
                         returnedFlags: position?.returnedFlags ?? 0,
                         hasTrace: line.segments.contains { !$0.coordinates.isEmpty },
                         diagnostics: line.diagnostics.map(\.message))
        }

        var placeSection: AstroExportDocument.Place?
        var relocationAlgorithm: String?
        if let place, let calculation {
            guard calculation.analysis.request == snapshot.request else { throw AstrocartographyError.snapshotMismatch }
            let analysis = calculation.analysis
            let summary = AstroPlaceSummaryBuilder.build(placeName: place.name, analysis: analysis, policy: policy, catalog: catalog)
            let readingSet = AstroPlaceReadingBuilder.build(analysis: analysis, policy: policy, catalog: catalog)
            let lines: [AstroExportDocument.LineEntry] = analysis.proximities.map {
                .init(key: key($0.lineID), body: $0.lineID.body.rawValue, angle: $0.lineID.angle.rawValue,
                      distanceKm: $0.distanceKm, estimatedErrorKm: $0.estimatedErrorKm,
                      nearestLatitude: $0.nearestPoint.latitude, nearestLongitude: $0.nearestPoint.longitude,
                      band: policy.band(for: $0.distanceKm).rawValue, crossesBoundary: policy.crossesBoundary($0))
            }
            var readings: [AstroExportDocument.Reading] = []
            var missing: [String] = []
            if includeReadings {
                for item in readingSet.items {
                    if let entry = item.lookup.entry {
                        readings.append(.init(key: key(item.proximity.lineID), title: entry.title, band: item.band.rawValue,
                                              distanceKm: item.proximity.distanceKm, mechanism: entry.mechanism,
                                              potential: entry.potential, shadow: entry.shadow, practice: entry.practice,
                                              sourceReferences: entry.sourceReferences))
                    } else { missing.append(key(item.proximity.lineID)) }
                }
            }
            var relocation: AstroExportDocument.Relocation?
            if let relocated = calculation.relocation {
                relocationAlgorithm = relocated.provenance.algorithmVersion
                let chartResult = relocated.chart
                relocation = .init(houseSystem: chartResult.houseSystem, ascendantDegrees: chartResult.ascendantDegrees,
                                   mcDegrees: chartResult.mcDegrees, cuspsDegrees: chartResult.cuspsDegrees,
                                   bodies: chartResult.bodies.map { .init(body: $0.body.rawValue, longitudeDegrees: $0.longitudeDegrees, house: $0.house) },
                                   timeZone: relocated.destinationTimeZone.identifier,
                                   timeZoneVerified: relocated.destinationTimeZone.isVerified,
                                   diagnostics: chartResult.diagnostics.map(\.message))
            }
            if !place.timeZone.isVerified {
                warnings.append("Zona horaria del destino no verificada: se presenta en UTC y nunca cambia el instante natal.")
            }
            if let error = calculation.relocationError { warnings.append("Carta relocada no disponible: \(error)") }
            if !missing.isEmpty { warnings.append("Sin lectura editorial para: \(missing.joined(separator: ", ")).") }
            if analysis.proximities.count < curves.lines.count {
                warnings.append("\(curves.lines.count - analysis.proximities.count) líneas sin solución única no tienen distancia definida.")
            }
            placeSection = .init(name: place.name, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude,
                                 origin: place.origin.rawValue, timeZone: place.timeZone.identifier,
                                 timeZoneVerified: place.timeZone.isVerified, headline: summary.headline,
                                 themes: summary.themes.map {
                                     .init(theme: $0.theme.rawValue, title: $0.theme.title, nearCount: $0.nearCount,
                                           regionalCount: $0.regionalCount, nearestLine: $0.nearest.map { key($0.lineID) },
                                           nearestDistanceKm: $0.nearest?.distanceKm)
                                 },
                                 lines: lines, relocation: relocation, relocationError: calculation.relocationError,
                                 readings: readings, missingReadings: missing)
        }
        var editorial: AstroExportDocument.Editorial?
        if case .loaded(let library) = catalog {
            editorial = .init(version: library.editorialVersion, reviewStatus: library.reviewStatus)
        } else if case .unavailable(let reason) = catalog {
            warnings.append("Lecturas no disponibles: \(reason)")
        }
        return AstroExportDocument(
            schemaVersion: AstroExportDocument.schemaVersion, kind: AstroExportDocument.kind,
            chart: chart,
            instant: .init(julianDay: snapshot.request.instant.julianDay, timeScale: snapshot.request.instant.timeScale.rawValue),
            method: .init(contractVersion: snapshot.request.contractVersion, convention: snapshot.request.convention,
                          linesAlgorithm: "\(snapshot.provenance.algorithmVersion)/\(AstrocartographyEngine.algorithmVersion)",
                          distanceAlgorithm: AstroLocationAnalyzer.algorithmVersion, relocationAlgorithm: relocationAlgorithm,
                          ephemerisSource: snapshot.provenance.source.rawValue,
                          ephemerisLibraryVersion: snapshot.provenance.libraryVersion,
                          sphereRadiusKm: AstroLocationAnalyzer.sphereRadiusKm,
                          geometryToleranceKm: snapshot.request.geometryToleranceKm,
                          diagnostics: snapshot.provenance.diagnostics),
            editorial: editorial, policy: .init(nearKm: policy.nearKm, regionalKm: policy.regionalKm),
            chartLines: chartLines, place: placeSection, warnings: warnings, disclaimer: AstroExportDocument.disclaimerText)
    }

    static func key(_ id: AstroLineID) -> String { "\(id.body.rawValue):\(id.angle.rawValue)" }

    /// «Júpiter en el Ascendente» from a `JUPITER:ASC` key; the key itself if unknown.
    static func humanName(_ key: String) -> String {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2, let body = AstroBody(rawValue: parts[0]), let angle = AstroAngle(rawValue: parts[1]) else { return key }
        return "\(body.spanishName) en el \(angle.spanishName)"
    }

    /// «Júpiter · Ascendente», compact form for tables.
    static func tableName(_ key: String) -> String {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2, let body = AstroBody(rawValue: parts[0]), let angle = AstroAngle(rawValue: parts[1]) else { return key }
        return "\(body.spanishName) · \(angle.spanishName)"
    }

    /// Stable, human-diffable JSON: sorted keys, no timestamps.
    static func json(_ document: AstroExportDocument) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(document), as: UTF8.self)
    }
}
