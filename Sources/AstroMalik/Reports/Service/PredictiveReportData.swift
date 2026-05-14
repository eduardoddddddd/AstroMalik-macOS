import Foundation

// MARK: - Shared DTOs for short predictive PDF reports

struct ReportMetricCard: Codable, Equatable, Sendable {
    let label: String
    let value: String
    let detail: String
}

struct ReportTableRow: Codable, Equatable, Sendable {
    let cells: [String]
}

struct ReportSectionData: Codable, Equatable, Sendable {
    let title: String
    let html: String
}

protocol PredictiveReportPayload: Codable, Sendable {
    var header: ReportHeaderData { get }
    var cover: ReportCoverData { get }
    var includeTOC: Bool { get }
    var generatedDate: String { get }
    var body: String { get }
}

struct TransitsReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let periodLabel: String
    let focusCount: Int
    let importantCount: Int
    let allCount: Int
    let technicalCount: Int
    let body: String
}

struct SolarReturnReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let year: Int
    let exactLocalDateTime: String
    let placeName: String
    let body: String
}

struct LunarReturnReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let periodLabel: String
    let returnCount: Int
    let body: String
}

struct CalendarReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let monthLabel: String
    let landscape: Bool
    let body: String
}

struct MonthlySummaryReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let monthLabel: String
    let body: String
}

struct ProfectionsReportData: PredictiveReportPayload, Equatable {
    let header: ReportHeaderData
    let cover: ReportCoverData
    let includeTOC: Bool
    let generatedDate: String
    let yearLabel: String
    let house: Int
    let lordOfYear: String
    let body: String
}

// MARK: - Builders

enum TransitsReportBuilder {
    static func makeData(
        chart: NatalChart,
        events: [TransitEvent],
        houseIngresses: [TransitHouseIngress],
        from: Date,
        to: Date,
        generatedAt: Date = Date(),
        theme: ReportTheme = .default
    ) -> TransitsReportData {
        let generated = ReportHTML.longDateTime(generatedAt, timezone: chart.timezone)
        let periodLabel = "\(ReportHTML.day(from, timezone: chart.timezone)) — \(ReportHTML.day(to, timezone: chart.timezone))"
        let sorted = events.sorted(by: ReportHTML.transitPrioritySort)
        let focus = sorted.filter { [.critical, .high].contains($0.priorityBand) }
        let important = sorted.filter { [.critical, .high, .medium].contains($0.priorityBand) }
        let technical = sorted.filter { $0.technicalScore >= 7 || $0.minOrb <= 0.5 || $0.retrogradeOnExact }
        let timeline = transitsTimeline(events: sorted, from: from, to: to, theme: theme, width: 900, height: 420)

        var body = """
        <section class="report-section transits-summary">
          <h2>Resumen del período</h2>
          <p><strong>Período:</strong> \(ReportHTML.escape(periodLabel)). El informe separa foco, importantes, todos y técnicos para distinguir prioridad práctica de precisión astrológica.</p>
          \(ReportHTML.metricGrid([
            ReportMetricCard(label: "Foco", value: "\(focus.count)", detail: "críticos y altos"),
            ReportMetricCard(label: "Importantes", value: "\(important.count)", detail: "media o superior"),
            ReportMetricCard(label: "Todos", value: "\(sorted.count)", detail: "eventos calculados"),
            ReportMetricCard(label: "Técnicos", value: "\(technical.count)", detail: "orbe, estación o puntuación"),
          ]))
        </section>
        <section class="report-section">
          <h2>Timeline SVG</h2>
          <figure class="chart-figure">\(timeline)<figcaption>Bandas por planeta transitante y bloques coloreados por prioridad.</figcaption></figure>
        </section>
        <section class="report-section">
          <h2>Eventos por banda de prioridad</h2>
          \(priorityTables(events: sorted))
        </section>
        <section class="report-section page-break">
          <h2>Texto corpus por evento priorizado</h2>
          \(eventCorpus(events: Array(important.prefix(18))))
        </section>
        <section class="report-section page-break">
          <h2>Ingresos por casa</h2>
          \(houseIngressTable(houseIngresses))
        </section>
        """
        if sorted.isEmpty {
            body += "<p class=\"callout\">No hay eventos de tránsito para el período seleccionado.</p>"
        }
        return TransitsReportData(
            header: ReportHTML.header(chart: chart, title: "Informe de tránsitos"),
            cover: ReportHTML.cover(chart: chart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            periodLabel: periodLabel,
            focusCount: focus.count,
            importantCount: important.count,
            allCount: sorted.count,
            technicalCount: technical.count,
            body: body
        )
    }

    static func makeRequest(
        chart: NatalChart,
        events: [TransitEvent],
        houseIngresses: [TransitHouseIngress],
        from: Date,
        to: Date,
        generatedAt: Date = Date(),
        theme: ReportTheme = .default
    ) -> ReportRequest<TransitsReportData> {
        ReportRequest(
            templateName: "transits",
            data: makeData(chart: chart, events: events, houseIngresses: houseIngresses, from: from, to: to, generatedAt: generatedAt, theme: theme),
            pageSize: .a4Portrait
        )
    }

    private static func priorityTables(events: [TransitEvent]) -> String {
        [TransitPriorityBand.critical, .high, .medium, .low].map { band in
            let rows = events.filter { $0.priorityBand == band }
            guard !rows.isEmpty else { return "" }
            return """
            <h3><span class="badge priority-\(band.rawValue)">\(ReportHTML.escape(band.label))</span></h3>
            \(ReportHTML.table(headers: ["Exactitud", "Evento", "Orbe", "℞", "Razones técnicas"], rows: rows.map { event in
                [event.exactDate, "\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)", ReportHTML.degree(event.minOrb), event.retrogradeOnExact ? "Sí" : "No", event.compactReason]
            }))
            """
        }.joined(separator: "\n")
    }

    private static func eventCorpus(events: [TransitEvent]) -> String {
        guard !events.isEmpty else { return "<p>Sin eventos priorizados para lectura narrativa.</p>" }
        return events.map { event in
            """
            <article class="event-reading no-break">
              <h3>\(ReportHTML.escape(event.transitLabel)) \(ReportHTML.escape(event.aspectLabel)) \(ReportHTML.escape(event.natalLabel))</h3>
              <p><span class="badge priority-\(event.priorityBand.rawValue)">\(ReportHTML.escape(event.priorityBand.label))</span> Exacto: \(ReportHTML.escape(event.exactDate)) · Orbe mínimo: \(ReportHTML.escape(ReportHTML.degree(event.minOrb))) · \(event.retrogradeOnExact ? "con retrogradación" : "directo")</p>
              <p>\(ReportHTML.escape(event.text ?? "Lectura pendiente de corpus: priorizar el significado del planeta transitante, el planeta natal activado, el aspecto y la casa natal implicada."))</p>
              <p class="caption">Razones: \(ReportHTML.escape(event.metricReasons.joined(separator: " · ").isEmpty ? event.compactReason : event.metricReasons.joined(separator: " · ")))</p>
            </article>
            """
        }.joined(separator: "\n")
    }

    private static func houseIngressTable(_ ingresses: [TransitHouseIngress]) -> String {
        guard !ingresses.isEmpty else { return "<p>No se registran ingresos por casa en el período.</p>" }
        let rows = ingresses.sorted { $0.date < $1.date }.map { ingress in
            [ingress.date, ingress.transitLabel, "Casa \(ingress.fromHouse) → \(ingress.house)", "\(ingress.stars)/5", ingress.text ?? "Cambio de escenario operativo de la casa natal."]
        }
        return ReportHTML.table(headers: ["Fecha", "Planeta", "Ingreso", "Peso", "Lectura"], rows: rows)
    }
}

enum SolarReturnReportBuilder {
    static func makeData(reading: SolarReturnReading, generatedAt: Date = Date(), theme: ReportTheme = .default) -> SolarReturnReportData {
        let generated = ReportHTML.longDateTime(generatedAt, timezone: reading.natalChart.timezone)
        let natalInSolar = reading.natalChart.bodies.map { body in
            [body.label, body.formatted, "Casa RS \(AstroEngine.planetHouse(deg: body.longitude, cusps: reading.solarChart.cusps))"]
        }
        let body = """
        <section class="report-section">
          <h2>Carta de revolución solar</h2>
          <figure class="chart-figure">\(wheel(chart: reading.solarChart, theme: theme, size: 620))<figcaption>Rueda de la revolución solar calculada para \(ReportHTML.escape(reading.exactLocalDateTime)) en \(ReportHTML.escape(reading.placeName)).</figcaption></figure>
        </section>
        <section class="report-section page-break">
          <h2>ASC y MC en casas natales</h2>
          \(ReportHTML.table(headers: ["Ángulo RS", "Posición", "Casa natal"], rows: [
            ["ASC", reading.solarChart.ascendant.formatted, "Casa \(reading.natalHouseForSolarAsc)"],
            ["MC", reading.solarChart.mc.formatted, "Casa \(reading.natalHouseForSolarMC)"],
          ]))
          <h2>Planetas RS en casas natales</h2>
          \(ReportHTML.table(headers: ["Planeta RS", "Posición", "Casa natal", "Casa RS"], rows: reading.solarPlanetsInNatalHouses.map { [$0.planetLabel, $0.formatted, "Casa \($0.natalHouse)", "Casa \($0.solarHouse)"] }))
          <h2>Planetas natales en casas RS</h2>
          \(ReportHTML.table(headers: ["Planeta natal", "Posición natal", "Casa RS"], rows: natalInSolar))
        </section>
        <section class="report-section page-break">
          <h2>Angulares y repeticiones</h2>
          <h3>Planetas angulares RS</h3>
          \(ReportHTML.table(headers: ["Planeta", "Casa RS", "Casa natal", "Posición"], rows: reading.angularPlanets.map { [$0.planetLabel, "Casa \($0.solarHouse)", "Casa \($0.natalHouse)", $0.formatted] }))
          <h3>Repeticiones con la natal</h3>
          \(ReportHTML.table(headers: ["Planeta", "Casa repetida", "Posición"], rows: reading.natalRepetitions.map { [$0.planetLabel, "Casa \($0.house)", $0.formatted] }))
          <h3>Aspectos dominantes</h3>
          \(ReportHTML.table(headers: ["Aspecto", "Orbe", "Clave"], rows: reading.dominantAspects.map { ["\($0.labelA) \($0.aspLabel) \($0.labelB)", ReportHTML.degree($0.orb), $0.corpusClave] }))
        </section>
        <section class="report-section page-break">
          <h2>Lectura guiada del año</h2>
          <article class="callout"><h3>\(ReportHTML.escape(reading.yearThemeTitle))</h3><p>\(ReportHTML.escape(reading.yearThemeText))</p></article>
          <p><strong>Tono del ASC RS en \(ReportHTML.escape(reading.ascSignLabel)):</strong> \(ReportHTML.escape(reading.yearToneText))</p>
          <p><strong>Regente del ASC RS:</strong> \(ReportHTML.escape(reading.rulerLabel)) en casa natal \(reading.rulerNatalHouse). \(ReportHTML.escape(reading.rulerText))</p>
          <p><strong>Luna RS:</strong> \(ReportHTML.escape(reading.moonFormatted)) en casa \(reading.moonHouse). \(ReportHTML.escape(reading.moonText))</p>
        </section>
        """
        return SolarReturnReportData(
            header: ReportHTML.header(chart: reading.natalChart, title: "Revolución solar \(reading.year)"),
            cover: ReportHTML.cover(chart: reading.natalChart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            year: reading.year,
            exactLocalDateTime: reading.exactLocalDateTime,
            placeName: reading.placeName,
            body: body
        )
    }

    static func makeRequest(reading: SolarReturnReading, generatedAt: Date = Date(), theme: ReportTheme = .default) -> ReportRequest<SolarReturnReportData> {
        ReportRequest(templateName: "solar_return", data: makeData(reading: reading, generatedAt: generatedAt, theme: theme))
    }
}

enum LunarReturnReportBuilder {
    static func makeData(reading: LunarReturnReading, generatedAt: Date = Date(), theme: ReportTheme = .default) -> LunarReturnReportData {
        let generated = ReportHTML.longDateTime(generatedAt, timezone: reading.natalChart.timezone)
        let first = reading.events.first
        let chartHTML = first.map { wheel(chart: $0.returnChart, theme: theme, size: 560) } ?? "<p>Sin carta de retorno.</p>"
        let period = first?.exactLocalDateTime ?? ReportHTML.day(reading.startDate, timezone: reading.timezone)
        let intensityRows = reading.events.map { event in
            [event.exactLocalDateTime, event.intensityLabel, "\(event.intensityScore)/10", "ASC \(event.ascSignLabel)", "Luna casa \(event.moon.house)"]
        }
        let activated = first?.returnPlanetsInNatalHouses.map { [$0.planetLabel, "Casa natal \($0.natalHouse)", "Casa retorno \($0.returnHouse)", $0.formatted] } ?? []
        let body = """
        <section class="report-section">
          <h2>Carta del retorno</h2>
          <figure class="chart-figure">\(chartHTML)<figcaption>Retorno lunar exacto: \(ReportHTML.escape(period)).</figcaption></figure>
        </section>
        <section class="report-section page-break">
          <h2>Resumen del mes lunar</h2>
          <p><strong>Luna natal:</strong> \(ReportHTML.escape(reading.natalMoon.formatted)) en casa \(reading.natalMoon.house). Promedio de intensidad: \(String(format: "%.1f", reading.statistics.averageIntensity)).</p>
          <p>\(ReportHTML.escape(first?.miniNarrative ?? "Sin narrativa mensual disponible."))</p>
          <h2>Casas activadas</h2>
          \(ReportHTML.table(headers: ["Planeta retorno", "Casa natal", "Casa retorno", "Posición"], rows: activated))
        </section>
        <section class="report-section page-break">
          <h2>Métricas técnicas</h2>
          \(ReportHTML.metricGrid([
            ReportMetricCard(label: "Precisión media", value: String(format: "%.0f″", reading.statistics.meanPrecisionArcseconds), detail: "arco lunar"),
            ReportMetricCard(label: "Velocidad máx.", value: String(format: "%.2f", reading.statistics.maxSpeed), detail: "Luna"),
            ReportMetricCard(label: "Distancia máx.", value: String(format: "%.2f", reading.statistics.maxDistance), detail: "unidades SE"),
            ReportMetricCard(label: "Casa lunar frecuente", value: reading.statistics.mostFrequentMoonHouse.map { "\($0)" } ?? "—", detail: "retornos"),
          ]))
          <h2>Intensidad diaria</h2>
          \(ReportHTML.table(headers: ["Fecha", "Etiqueta", "Intensidad", "ASC", "Luna"], rows: intensityRows))
          <h2>Narrativa mensual</h2>
          <p>\(ReportHTML.escape(first?.moonFocusText ?? "La Luna del retorno define el foco emocional operativo del ciclo."))</p>
          <p>\(ReportHTML.escape(first?.ascToneText ?? "El ascendente del retorno aporta tono y estrategia de respuesta."))</p>
        </section>
        """
        return LunarReturnReportData(
            header: ReportHTML.header(chart: reading.natalChart, title: "Revolución lunar"),
            cover: ReportHTML.cover(chart: reading.natalChart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            periodLabel: period,
            returnCount: reading.events.count,
            body: body
        )
    }

    static func makeRequest(reading: LunarReturnReading, generatedAt: Date = Date(), theme: ReportTheme = .default) -> ReportRequest<LunarReturnReportData> {
        ReportRequest(templateName: "lunar_return", data: makeData(reading: reading, generatedAt: generatedAt, theme: theme))
    }
}

enum CalendarReportBuilder {
    static func makeData(month: EphemerisMonth, chartForCover chart: NatalChart? = nil, generatedAt: Date = Date(), theme: ReportTheme = .default) -> CalendarReportData {
        let coverChart = chart ?? ReportHTML.syntheticCoverChart(name: "Calendario astrológico")
        let generated = ReportHTML.longDateTime(generatedAt, timezone: coverChart.timezone)
        let monthLabel = ReportHTML.month(year: month.year, month: month.month)
        func events(_ kinds: Set<CelestialEventKind>) -> [CelestialEvent] { month.events.filter { kinds.contains($0.kind) }.sorted { $0.dateLocal < $1.dateLocal } }
        let body = """
        <section class="report-section">
          <h2>Mes objetivo</h2>
          <p class="callout">\(ReportHTML.escape(monthLabel)) · \(month.events.count) eventos celestes · \(month.dailyRows.count) filas de efemérides diarias.</p>
          <h2>Lunaciones</h2>\(eventTable(events([.newMoon, .fullMoon, .firstQuarter, .lastQuarter])))
          <h2>Eclipses</h2>\(eventTable(events([.solarEclipse, .lunarEclipse])))
          <h2>Estaciones</h2>\(eventTable(events([.stationRetrograde, .stationDirect])))
        </section>
        <section class="report-section page-break">
          <h2>Ingresos por signo</h2>\(eventTable(events([.signIngress])))
          <h2>Luna vacía de curso</h2>\(eventTable(events([.voidOfCourse, .voidOfCourseEnd])))
          <h2>Aspectos mundanos</h2>\(eventTable(events([.mundaneAspect])))
        </section>
        <section class="report-section page-break calendar-landscape">
          <h2>Tabla diaria de efemérides</h2>
          \(dailyEphemeris(month: month, theme: theme))
        </section>
        """
        return CalendarReportData(
            header: ReportHTML.header(chart: coverChart, title: "Calendario y efemérides — \(monthLabel)"),
            cover: ReportHTML.cover(chart: coverChart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            monthLabel: monthLabel,
            landscape: true,
            body: body
        )
    }

    static func makeRequest(month: EphemerisMonth, chartForCover chart: NatalChart? = nil, generatedAt: Date = Date(), theme: ReportTheme = .default) -> ReportRequest<CalendarReportData> {
        let data = makeData(month: month, chartForCover: chart, generatedAt: generatedAt, theme: theme)
        return ReportRequest(templateName: "calendar", data: data, pageSize: .a4Portrait, landscape: data.landscape)
    }

    private static func eventTable(_ events: [CelestialEvent]) -> String {
        guard !events.isEmpty else { return "<p>No hay eventos de esta categoría en el mes.</p>" }
        return ReportHTML.table(headers: ["Fecha", "Evento", "Posición", "Detalle", "Importancia"], rows: events.map { event in
            [event.dateLocal, event.title, event.formatted ?? event.signLabel ?? "—", event.subtitle ?? event.aspectLabel ?? event.eclipseType ?? "—", "\(event.importance.rawValue)"]
        })
    }
}

enum MonthlySummaryReportBuilder {
    static func makeData(summary: MonthlySummary, natalChart chart: NatalChart, generatedAt: Date = Date()) -> MonthlySummaryReportData {
        let generated = ReportHTML.longDateTime(generatedAt, timezone: chart.timezone)
        let monthLabel = ReportHTML.month(year: summary.year, month: summary.month)
        let body = """
        <section class="report-section">
          <h2>Resumen predictivo mensual</h2>
          <p class="callout">\(ReportHTML.escape(summary.climateSummary))</p>
          <h2>Lunaciones y eclipses en casas natales</h2>
          <h3>Lunaciones</h3>\(ReportHTML.table(headers: ["Fecha", "Evento", "Casa natal", "Planeta activado", "Narrativa"], rows: summary.lunationHits.map { [$0.event.dateLocal, $0.event.title, "Casa \($0.natalHouse)", $0.conjunctPlanet.map { "\($0.planetLabel) (\(ReportHTML.degree($0.orb)))" } ?? "—", $0.narrative] }))
          <h3>Eclipses</h3>\(ReportHTML.table(headers: ["Fecha", "Eclipse", "Casa", "Planetas", "Angular", "Narrativa"], rows: summary.eclipseHits.map { [$0.event.dateLocal, $0.event.title, "Casa \($0.natalHouse)", $0.conjunctPlanets.map { $0.planetLabel }.joined(separator: ", "), $0.isAngular ? "Sí" : "No", $0.narrative] }))
        </section>
        <section class="report-section page-break">
          <h2>Activaciones de planetas natales</h2>
          \(ReportHTML.table(headers: ["Fecha", "Estación", "Planeta natal", "Casa", "Orbe", "Narrativa"], rows: summary.stationHits.map { [$0.event.dateLocal, $0.event.title, $0.natalPlanetLabel, "Casa \($0.natalHouse)", ReportHTML.degree($0.orb), $0.narrative] }))
          <h2>Tránsitos principales</h2>
          \(ReportHTML.table(headers: ["Exacto", "Tránsito", "Prioridad", "Orbe", "Razón"], rows: summary.activeTransits.sorted(by: ReportHTML.transitPrioritySort).map { [$0.exactDate, "\($0.transitLabel) \($0.aspectLabel) \($0.natalLabel)", $0.priorityBand.label, ReportHTML.degree($0.minOrb), $0.compactReason] }))
          <h2>Ingresos por casa</h2>
          \(ReportHTML.table(headers: ["Fecha", "Planeta", "Casa", "Lectura"], rows: summary.houseIngresses.sorted { $0.date < $1.date }.map { [$0.date, $0.transitLabel, "Casa \($0.house)", $0.text ?? "Cambio de campo natal activado."] }))
        </section>
        """
        return MonthlySummaryReportData(
            header: ReportHTML.header(chart: chart, title: "Resumen mensual — \(monthLabel)"),
            cover: ReportHTML.cover(chart: chart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            monthLabel: monthLabel,
            body: body
        )
    }

    static func makeRequest(summary: MonthlySummary, natalChart chart: NatalChart, generatedAt: Date = Date()) -> ReportRequest<MonthlySummaryReportData> {
        ReportRequest(templateName: "monthly_summary", data: makeData(summary: summary, natalChart: chart, generatedAt: generatedAt))
    }
}

enum ProfectionsReportBuilder {
    static func makeData(result: ProfectionResult, natalChart chart: NatalChart, generatedAt: Date = Date()) -> ProfectionsReportData {
        let generated = ReportHTML.longDateTime(generatedAt, timezone: chart.timezone)
        let annual = result.annual
        let body = """
        <section class="report-section">
          <h2>Casa profeccionada del año</h2>
          \(ReportHTML.metricGrid([
            ReportMetricCard(label: "Casa", value: "\(annual.house)", detail: annual.signLabel),
            ReportMetricCard(label: "Lord of the Year", value: annual.lordLabel, detail: annual.cuspFormatted),
            ReportMetricCard(label: "Edad", value: "\(annual.age)", detail: "año profectado"),
            ReportMetricCard(label: "Período", value: ReportHTML.day(annual.startDate, timezone: chart.timezone), detail: "a \(ReportHTML.day(annual.endDate, timezone: chart.timezone))"),
          ]))
          <h2>Planetas natales en la casa</h2>
          \(ReportHTML.table(headers: ["Planeta", "Posición", "Casa", "℞"], rows: annual.natalPlanetsInHouse.map { [$0.label, $0.formatted, "Casa \($0.house)", $0.retrograde ? "Sí" : "No"] }))
          <h2>Aspectos natales del LotY</h2>
          \(ReportHTML.table(headers: ["LotY", "Aspecto", "Planeta", "Orbe"], rows: annual.natalAspectsByLord.map { [$0.lotyLabel, $0.aspectLabel, $0.planetLabel, ReportHTML.degree($0.orb)] }))
        </section>
        <section class="report-section page-break">
          <h2>Activaciones del año</h2>
          \(ReportHTML.table(headers: ["Fecha", "Activación", "Prioridad", "Orbe", "Razón"], rows: result.activations.sorted(by: ReportHTML.transitPrioritySort).map { [$0.exactDate, "\($0.transitLabel) \($0.aspectLabel) \($0.natalLabel)", $0.priorityBand.label, ReportHTML.degree($0.minOrb), $0.compactReason] }))
          <h2>Mensual</h2>
          \(ReportHTML.table(headers: ["Inicio", "Fin", "Casa", "Signo", "Señor"], rows: result.monthly.map { [ReportHTML.day($0.startDate, timezone: chart.timezone), ReportHTML.day($0.endDate, timezone: chart.timezone), "Casa \($0.house)", $0.signLabel, $0.lordLabel] }))
          <h2>Diaria</h2>
          \(ReportHTML.table(headers: ["Inicio", "Fin", "Casa", "Signo", "Señor"], rows: result.daily.map { [ReportHTML.day($0.startDate, timezone: chart.timezone), ReportHTML.day($0.endDate, timezone: chart.timezone), "Casa \($0.house)", $0.signLabel, $0.lordLabel] }))
        </section>
        """
        return ProfectionsReportData(
            header: ReportHTML.header(chart: chart, title: "Profecciones anuales"),
            cover: ReportHTML.cover(chart: chart, generated: generated),
            includeTOC: true,
            generatedDate: generated,
            yearLabel: "Edad \(annual.age)",
            house: annual.house,
            lordOfYear: annual.lordLabel,
            body: body
        )
    }

    static func makeRequest(result: ProfectionResult, natalChart chart: NatalChart, generatedAt: Date = Date()) -> ReportRequest<ProfectionsReportData> {
        ReportRequest(templateName: "profections", data: makeData(result: result, natalChart: chart, generatedAt: generatedAt))
    }
}

// MARK: - HTML helpers

enum ReportHTML {
    static func header(chart: NatalChart, title: String) -> ReportHeaderData {
        ReportHeaderData(chartName: chart.name.isEmpty ? chart.birthDate : chart.name, reportTitle: title, generatedDate: longDateTime(Date(), timezone: chart.timezone))
    }

    static func cover(chart: NatalChart, generated: String) -> ReportCoverData {
        let signIndex = SVGChartSupport.signIndex(for: chart.ascendant.longitude)
        let signLabel = SIGN_LABELS[max(0, min(11, signIndex))]
        return ReportCoverData(
            chartName: chart.name.isEmpty ? chart.birthDate : chart.name,
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            place: chart.placeName,
            generatedDate: generated,
            ascSign: signLabel.replacingOccurrences(of: String(signLabel.prefix(2)), with: "").trimmingCharacters(in: .whitespaces),
            ascGlyph: String(signLabel.prefix(2))
        )
    }

    static func metricGrid(_ cards: [ReportMetricCard]) -> String {
        let inner = cards.map { card in
            """
            <div class="metric-card"><div class="metric-label">\(escape(card.label))</div><div class="metric-value">\(escape(card.value))</div><div class="metric-detail">\(escape(card.detail))</div></div>
            """
        }.joined(separator: "\n")
        return "<div class=\"metric-grid\">\(inner)</div>"
    }

    static func table(headers: [String], rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "<p>Sin datos para esta tabla.</p>" }
        let head = headers.map { "<th scope=\"col\">\(escape($0))</th>" }.joined()
        let body = rows.map { row in
            "<tr>" + row.map { "<td>\(escape($0))</td>" }.joined() + "</tr>"
        }.joined(separator: "\n")
        return "<table><thead><tr>\(head)</tr></thead><tbody>\(body)</tbody></table>"
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func degree(_ value: Double) -> String { String(format: "%.2f°", value) }

    static func longDateTime(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func day(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func month(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = 1
        let date = components.date ?? Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized(with: Locale(identifier: "es_ES"))
    }

    static func transitPrioritySort(_ lhs: TransitEvent, _ rhs: TransitEvent) -> Bool {
        if lhs.priorityBand.rank != rhs.priorityBand.rank { return lhs.priorityBand.rank > rhs.priorityBand.rank }
        if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
        if lhs.exactDate != rhs.exactDate { return lhs.exactDate < rhs.exactDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func syntheticCoverChart(name: String) -> NatalChart {
        NatalChart(
            name: name,
            birthDate: "2000-01-01",
            birthTime: "00:00",
            timezone: "Europe/Madrid",
            latitude: 40.4168,
            longitude: -3.7038,
            placeName: "Madrid",
            ascendant: AngularPoint(longitude: 0, formatted: "♈ Aries 00°00'"),
            mc: AngularPoint(longitude: 270, formatted: "♑ Capricornio 00°00'"),
            cusps: stride(from: 0.0, to: 360.0, by: 30.0).map { $0 },
            bodies: []
        )
    }
}
