import Foundation

/// Everything the PDF needs, as plain values. `curves` supplies the geometry for the
/// figure; `document` supplies every number and text, so the PDF cannot contradict
/// the Joplin note or the CLI JSON built from the same document.
struct AstrocartographyReportInput: Sendable {
    let document: AstroExportDocument
    let curves: AstrocartographyResult
    let placeCoordinate: GeoCoordinate?
}

struct AstrocartographyReportBuilder {
    static let templateName = "astrocartography"

    /// `baseMap` is consulted once; any failure degrades to the graticule figure
    /// with an explicit note. It is never required for the report to be produced.
    static func generate(input: AstrocartographyReportInput, pageSize: PDFPageSize = .a4Portrait,
                         baseMap: AstroBaseMapProvider? = nil, generatedAt: Date = Date()) async throws -> Data {
        let base = await baseMap?()
        let data = makeData(input: input, baseMap: base, generatedAt: generatedAt)
        return try await ReportService().generate(request: ReportRequest(templateName: templateName, data: data, pageSize: pageSize))
    }

    static func makeData(input: AstrocartographyReportInput, baseMap: AstroBaseMapResult?, generatedAt: Date = Date()) -> AstrocartographyReportData {
        let document = input.document
        let generatedDate = ReportFormatting.generatedDate(generatedAt)
        let chart = document.chart
        let chartName = chart.name.isEmpty ? "Carta \(chart.birthDate)" : chart.name
        let place = document.place
        var warnings = document.warnings

        // Figure: emphasis only when a place exists and something is nearby.
        var visualLines: [AstroVisualLine] = []
        for line in input.curves.lines {
            if let prepared = try? AstroMercatorGeometry.prepare(line) { visualLines.append(prepared) }
            else { warnings.append("La línea \(line.id.body.rawValue):\(line.id.angle.rawValue) no se pudo preparar para la figura.") }
        }
        let nearby: Set<AstroLineID>? = place.flatMap { place in
            let ids = place.lines.filter { $0.band != AstroProximityPolicy.Band.distant.rawValue }
                .compactMap { entry -> AstroLineID? in
                    guard let body = AstroBody(rawValue: entry.body), let angle = AstroAngle(rawValue: entry.angle) else { return nil }
                    return AstroLineID(body: body, angle: angle)
                }
            return ids.isEmpty ? nil : Set(ids)
        }
        let usesBase = baseMap?.dataURI != nil
        let svg = AstroMapSVGRenderer.render(lines: visualLines, emphasized: nearby, place: input.placeCoordinate,
                                             placeName: place?.name, baseImageDataURI: baseMap?.dataURI)
        var mapNote: String
        if usesBase {
            mapNote = AstroBaseMapSnapshot.attribution
        } else if let failure = baseMap?.failure {
            mapNote = "Sin mapa base: \(failure) Las líneas se muestran sobre una cuadrícula de 30°."
        } else {
            mapNote = "Figura sin mapa base: las líneas se muestran sobre una cuadrícula de 30°."
        }
        mapNote += nearby == nil
            ? " Todas las líneas con el mismo peso."
            : " En trazo grueso, las líneas a ≤ \(num(document.policy.regionalKm)) km del lugar; el resto, atenuado."
        mapNote += " Proyección Web Mercator (±85.0511°); la forma del trazo indica el ángulo, el color el planeta."

        var themes: [ReportMetricRow] = []
        var readings: [AstrocartographyReportData.Reading] = []
        var distances: [AstrocartographyReportData.Distance] = []
        var relocationAxes: [ReportMetricRow] = [], cusps: [ReportMetricRow] = [], bodies: [ReportMetricRow] = []
        var relocationNote = ""
        var hasRelocation = false
        if let place {
            themes = place.themes.map {
                var counts: [String] = []
                if $0.nearCount > 0 { counts.append("\($0.nearCount) cerca") }
                if $0.regionalCount > 0 { counts.append("\($0.regionalCount) regional") }
                var detail = ""
                if let line = $0.nearestLine, let distance = $0.nearestDistanceKm {
                    detail = "Más cercana: \(AstroExportDocumentBuilder.humanName(line)) (\(AstroPlaceSummaryBuilder.distance(distance)))"
                }
                return ReportMetricRow(label: $0.title, value: counts.joined(separator: " · "), detail: detail)
            }
            readings = place.readings.map { item in
                .init(title: item.title, meta: "\(item.band) · \(AstroPlaceSummaryBuilder.distance(item.distanceKm))",
                      mechanism: item.mechanism, potential: item.potential, shadow: item.shadow, practice: item.practice)
            }
            distances = place.lines.map {
                .init(line: AstroExportDocumentBuilder.tableName($0.key), distance: AstroPlaceSummaryBuilder.distance($0.distanceKm),
                      error: String(format: "± %.3f km", $0.estimatedErrorKm),
                      band: $0.band + ($0.crossesBoundary ? " *" : ""),
                      nearest: String(format: "%.3f°, %.3f° E", $0.nearestLatitude, $0.nearestLongitude))
            }
            if let relocation = place.relocation {
                hasRelocation = true
                relocationNote = "Mismo instante natal (JD \(String(format: "%.6f", document.instant.julianDay))); solo cambian casas y ángulos. Sistema \(relocation.houseSystem). Zona de presentación: \(relocation.timeZone)\(relocation.timeZoneVerified ? "" : " (no verificada)"). Las longitudes planetarias son las natales."
                relocationAxes = [
                    ReportMetricRow(label: "Ascendente", value: ReportFormatting.degree(relocation.ascendantDegrees, digits: 3),
                                    detail: "Natal: \(ReportFormatting.degree(chart.natalAscendantDegrees, digits: 3))"),
                    ReportMetricRow(label: "Medio Cielo", value: ReportFormatting.degree(relocation.mcDegrees, digits: 3),
                                    detail: "Natal: \(ReportFormatting.degree(chart.natalMCDegrees, digits: 3))"),
                ]
                cusps = relocation.cuspsDegrees.enumerated().map { index, value in
                    ReportMetricRow(label: "Casa \(index + 1)", value: ReportFormatting.degree(value, digits: 3),
                                    detail: index < chart.natalCuspsDegrees.count ? "Natal: \(ReportFormatting.degree(chart.natalCuspsDegrees[index], digits: 3))" : "")
                }
                bodies = relocation.bodies.map {
                    ReportMetricRow(label: $0.body, value: ReportFormatting.degree($0.longitudeDegrees, digits: 3), detail: "Casa relocada \($0.house)")
                }
            } else {
                relocationNote = place.relocationError ?? "Carta relocada no disponible."
            }
        }

        var placeDetails = ""
        if let place {
            placeDetails = String(format: "φ %.5f° · λ %.5f° E · zona %@%@", place.latitude, place.longitude, place.timeZone,
                                  place.timeZoneVerified ? "" : " (no verificada)")
        }
        let method: [String] = [
            "Convención: \(document.method.convention) (contrato v\(document.method.contractVersion)). Horizonte geométrico del centro del cuerpo, sin refracción ni paralaje topocéntrico; MC/IC son culminación, no visibilidad.",
            "Efemérides: \(document.method.ephemerisSource) \(document.method.ephemerisLibraryVersion). Instante natal JD \(String(format: "%.9f", document.instant.julianDay)) (\(document.instant.timeScale): UTC tratado como UT1, sin DUT1).",
            "Líneas: \(document.method.linesAlgorithm), tolerancia geométrica \(num(document.method.geometryToleranceKm)) km. Distancias: \(document.method.distanceAlgorithm), esfera de radio \(String(format: "%.4f", document.method.sphereRadiusKm)) km, medidas a la curva completa y no a píxeles. Estas cotas no son exactitud de efemérides ni de la hora natal.",
            "Umbrales del programa: cerca ≤ \(num(document.policy.nearKm)) km, regional ≤ \(num(document.policy.regionalKm)) km. No miden intensidad. * indica que la cota de error cruza un umbral.",
        ] + (document.method.relocationAlgorithm.map { ["Relocación: \($0)."] } ?? [])
          + (document.editorial.map { ["Textos: \($0.version), estado de revisión «\($0.reviewStatus)», redacción original de AstroMalik."] } ?? [])

        return AstrocartographyReportData(
            header: ReportHeaderData(chartName: place.map { "\(chartName) · \($0.name)" } ?? chartName,
                                     reportTitle: "Informe de astrocartografía", generatedDate: generatedDate),
            includeTOC: true, generatedDate: generatedDate, chartName: chartName,
            chartDetails: "\(chart.birthDate) \(chart.birthTime) · \(chart.timezone) · \(chart.placeName)",
            placeName: place?.name ?? "Mapa de la carta", placeDetails: placeDetails,
            headline: place?.headline ?? "Líneas de la carta sin lugar seleccionado.",
            themes: themes, readings: readings, hasReadings: !readings.isEmpty,
            readingsNote: place == nil ? "" : (readings.isEmpty ? "Ninguna línea queda dentro del umbral regional, o las lecturas no estaban disponibles." : "Textos simbólicos originales, ordenados por distancia. La distancia no los intensifica ni atenúa."),
            mapSVG: svg, mapNote: mapNote,
            legendBodies: AstroBody.allCases.map { .init(label: $0.spanishName, swatch: AstroMapSVGRenderer.bodyHex($0)) },
            legendAngles: AstroAngle.allCases.map { .init(label: $0.spanishName + " (" + $0.rawValue + ")", swatch: AstroMapSVGRenderer.legendSwatch($0)) },
            hasRelocation: hasRelocation, relocationNote: relocationNote, relocationAxes: relocationAxes,
            relocationCusps: cusps, relocationBodies: bodies, distances: distances,
            chartLines: document.chartLines.map {
                .init(line: AstroExportDocumentBuilder.tableName($0.key), rightAscension: ReportFormatting.degree($0.rightAscensionDegrees, digits: 4),
                      declination: ReportFormatting.degree($0.declinationDegrees, digits: 4), flags: String($0.returnedFlags),
                      trace: $0.hasTrace ? "sí" : "no")
            },
            method: method, hasWarnings: !warnings.isEmpty, warnings: warnings, disclaimer: document.disclaimer)
    }

    private static func num(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(value) }
}
