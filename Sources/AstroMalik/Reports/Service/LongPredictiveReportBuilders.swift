import Foundation

// MARK: - Primary Directions Long PDF

enum PrimaryDirectionsLongReportBuilder {
    static let templateName = "primary_directions"

    static func build(
        chart: NatalChart,
        settings: PrimaryDirectionsLongReportSettings,
        directions: [EnrichedPrimaryDirection],
        speculum: [SpeculumRow] = [],
        asOf: Date = Date(),
        generatedAt: Date = Date()
    ) -> PrimaryDirectionsLongReportData {
        let generatedDate = LongPredictiveHTML.dateTime(generatedAt)
        let sorted = directions.sorted { lhs, rhs in
            if lhs.direction.weight != rhs.direction.weight { return lhs.direction.weight > rhs.direction.weight }
            return lhs.direction.estimatedDate < rhs.direction.estimatedDate
        }
        let highlighted = Array((sorted.filter { $0.direction.weight >= .major }.isEmpty ? sorted : sorted.filter { $0.direction.weight >= .major }).prefix(10))
        let currentYear = sorted.filter { Calendar(identifier: .gregorian).component(.year, from: $0.direction.estimatedDate) == Calendar(identifier: .gregorian).component(.year, from: asOf) }
        let body = LongPredictiveHTML.styles()
            + presetsSection(settings: settings, count: sorted.count)
            + weightTable(directions: sorted)
            + currentYearSection(currentYear, asOf: asOf)
            + semanticTimeline(directions: sorted)
            + highlightedDetails(highlighted, speculum: speculum)

        return PrimaryDirectionsLongReportData(
            header: ReportHeaderData(chartName: LongPredictiveHTML.chartName(chart), reportTitle: "Direcciones primarias", generatedDate: generatedDate),
            cover: LongPredictiveHTML.cover(chart: chart, generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            body: body
        )
    }

    static func request(data: PrimaryDirectionsLongReportData) -> ReportRequest<PrimaryDirectionsLongReportData> {
        ReportRequest(templateName: templateName, data: data, pageSize: .a4Portrait)
    }

    static func makeRequest(data: PrimaryDirectionsLongReportData) -> ReportRequest<PrimaryDirectionsLongReportData> {
        request(data: data)
    }

    private static func presetsSection(settings: PrimaryDirectionsLongReportSettings, count: Int) -> String {
        """
        <section class="report-section no-break">
          <h2>Presets aplicados</h2>
          <div class="long-report-grid">
            \(LongPredictiveHTML.metric("Preset", settings.presetName))
            \(LongPredictiveHTML.metric("Método", settings.method))
            \(LongPredictiveHTML.metric("Clave", settings.timeKey))
            \(LongPredictiveHTML.metric("Plano", settings.aspectPlane))
            \(LongPredictiveHTML.metric("Peso mínimo", settings.minimumWeight))
            \(LongPredictiveHTML.metric("Direcciones", "\(count)"))
          </div>
          <p class="caption">Conversas: \(settings.includeConverse ? "incluidas" : "excluidas"). La tabla siguiente se ordena por peso clásico: crítica, mayor, moderada y menor.</p>
        </section>
        """
    }

    private static func weightTable(directions: [EnrichedPrimaryDirection]) -> String {
        let rows = directions.map { enriched in
            let d = enriched.direction
            return """
            <tr>
              <td><span class="badge \(LongPredictiveHTML.weightClass(d.weight))">\(d.weight.label)</span></td>
              <td>\(LongPredictiveHTML.escape(enriched.displaySummary))</td>
              <td>\(LongPredictiveHTML.escape(enriched.ageFormatted))</td>
              <td>\(LongPredictiveHTML.date(d.estimatedDate))</td>
              <td>\(LongPredictiveHTML.escape(d.aspect.polarity))</td>
            </tr>
            """
        }.joined()
        return """
        <section class="report-section page-break">
          <h2>Tabla de direcciones por peso</h2>
          <table>
            <thead><tr><th>Peso</th><th>Dirección</th><th>Edad exacta</th><th>Fecha estimada</th><th>Polaridad</th></tr></thead>
            <tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 5, text: "Sin direcciones con los filtros aplicados.") : rows)</tbody>
          </table>
        </section>
        """
    }

    private static func currentYearSection(_ directions: [EnrichedPrimaryDirection], asOf: Date) -> String {
        let rows = directions.map { enriched in
            let d = enriched.direction
            return "<tr><td>\(LongPredictiveHTML.date(d.estimatedDate))</td><td>\(LongPredictiveHTML.escape(enriched.displaySummary))</td><td>\(d.weight.label)</td><td>\(LongPredictiveHTML.escape(enriched.arcFormatted))</td></tr>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Vista del año en curso</h2>
          <p>Ventana anual de referencia: \(Calendar(identifier: .gregorian).component(.year, from: asOf)).</p>
          <table>
            <thead><tr><th>Fecha</th><th>Dirección</th><th>Peso</th><th>Arco</th></tr></thead>
            <tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 4, text: "No hay direcciones exactas en el año de referencia.") : rows)</tbody>
          </table>
        </section>
        """
    }

    private static func semanticTimeline(directions: [EnrichedPrimaryDirection]) -> String {
        let entries = PrimaryDirectionsService.buildTimelineEntries(from: directions)
        let items = entries.map { entry in
            let key = entry.keyDirection?.displaySummary ?? "Sin dirección dominante"
            return "<li><strong>\(entry.label)</strong> — \(entry.overallTone.emoji) \(entry.overallTone.rawValue): \(LongPredictiveHTML.escape(key)) (\(entry.directions.count) direcciones).</li>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Timeline semántico</h2>
          <ul class="long-report-list">\(items.isEmpty ? "<li>Sin hitos suficientes para construir timeline.</li>" : items)</ul>
        </section>
        """
    }

    private static func highlightedDetails(_ directions: [EnrichedPrimaryDirection], speculum: [SpeculumRow]) -> String {
        let blocks = directions.map { enriched in
            let d = enriched.direction
            let interpretation = enriched.interpretation?.structuralText.nilIfBlank ?? "Texto clásico pendiente de curación verificable para esta combinación; se conserva el lenguaje técnico de prómissor, significador, aspecto y plano."
            let source = enriched.interpretation.map { "<p class=\"caption\">Fuente: \(LongPredictiveHTML.escape($0.source.nilIfBlank ?? "Corpus clásico")) \(LongPredictiveHTML.escape($0.sourceReference))</p>" } ?? ""
            return """
            <article class="detail-card no-break">
              <h3>\(LongPredictiveHTML.escape(enriched.displaySummary))</h3>
              <div class="long-report-grid">
                \(LongPredictiveHTML.metric("Hero", d.promissorLabel + " → " + d.significatorLabel))
                \(LongPredictiveHTML.metric("Edad exacta", enriched.ageFormatted))
                \(LongPredictiveHTML.metric("Fecha estimada", LongPredictiveHTML.date(d.estimatedDate)))
                \(LongPredictiveHTML.metric("Polaridad", d.aspect.polarity))
                \(LongPredictiveHTML.metric("Plano", d.aspectPlane.displayName))
                \(LongPredictiveHTML.metric("Tipo", d.directionType == .direct ? "Directa" : "Conversa"))
              </div>
              <h4>Texto principal del corpus clásico</h4>
              <p>\(LongPredictiveHTML.escape(interpretation))</p>
              \(source)
              <h4>Alternativos de lectura</h4>
              <ul><li>Lectura estructural: observar la casa/signo natal del significador activado.</li><li>Lectura temporal: usar la fecha exacta como pico, con orbe operativo antes y después.</li><li>Lectura de polaridad: \(LongPredictiveHTML.escape(d.aspect.polarity)) no sustituye la dignidad ni la condición natal.</li></ul>
              \(speculumFor(direction: d, speculum: speculum))
            </article>
            """
        }.joined()
        return """
        <section class="report-section page-break">
          <h2>Direcciones destacadas: detalle profesional</h2>
          \(blocks.isEmpty ? "<p>No hay direcciones destacadas para detallar.</p>" : blocks)
        </section>
        """
    }

    private static func speculumFor(direction: PrimaryDirection, speculum: [SpeculumRow]) -> String {
        let t = direction.technicalData
        var rows = """
        <tr><td>Prómissor RA</td><td>\(LongPredictiveHTML.degree(t.promissorRA))</td></tr>
        <tr><td>Prómissor declinación</td><td>\(LongPredictiveHTML.degree(t.promissorDeclination))</td></tr>
        <tr><td>Significador RA</td><td>\(LongPredictiveHTML.degree(t.significatorRA))</td></tr>
        <tr><td>Significador declinación</td><td>\(LongPredictiveHTML.degree(t.significatorDeclination))</td></tr>
        <tr><td>Polo Regiomontano significador</td><td>\(LongPredictiveHTML.degree(t.significatorPole))</td></tr>
        <tr><td>RAMC / latitud</td><td>\(LongPredictiveHTML.degree(t.ramc)) · \(LongPredictiveHTML.degree(t.geoLatitude))</td></tr>
        """
        if let row = speculum.first(where: { $0.key == direction.significator || $0.key == direction.promissor }) {
            rows += "<tr><td>Espéculo carta: \(LongPredictiveHTML.escape(row.label))</td><td>MD \(LongPredictiveHTML.degree(row.meridianDistance)) · ZD \(LongPredictiveHTML.degree(row.zenithDistance)) · Q \(LongPredictiveHTML.degree(row.q)) · W \(LongPredictiveHTML.degree(row.w))</td></tr>"
        }
        return "<h4>Espéculo Regiomontano</h4><table><tbody>\(rows)</tbody></table>"
    }
}

// MARK: - Solar Arc Long PDF

enum SolarArcLongReportBuilder {
    static let templateName = "solar_arc"

    static func build(
        chart: NatalChart,
        mode: SolarArcMode,
        targetDate: Date,
        currentSolarArc: Double,
        directions: [SolarArcDirection],
        generatedAt: Date = Date()
    ) -> SolarArcLongReportData {
        let generatedDate = LongPredictiveHTML.dateTime(generatedAt)
        let sorted = directions.sorted { lhs, rhs in
            if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
            return lhs.exactDate < rhs.exactDate
        }
        let exact = sorted.filter { abs($0.exactDate.timeIntervalSince(targetDate)) <= 365.25 * 86_400 }
        let body = LongPredictiveHTML.styles()
            + """
            <section class="report-section no-break">
              <h2>Modo y arco solar a la fecha</h2>
              <div class="long-report-grid">
                \(LongPredictiveHTML.metric("Modo", mode.label))
                \(LongPredictiveHTML.metric("Fecha objetivo", LongPredictiveHTML.date(targetDate)))
                \(LongPredictiveHTML.metric("Arco solar", LongPredictiveHTML.degree(currentSolarArc)))
                \(LongPredictiveHTML.metric("Direcciones ±5 años", "\(sorted.count)"))
              </div>
            </section>
            """
            + table(directions: sorted)
            + detail(directions: exact, targetDate: targetDate)
        return SolarArcLongReportData(
            header: ReportHeaderData(chartName: LongPredictiveHTML.chartName(chart), reportTitle: "Arco solar", generatedDate: generatedDate),
            cover: LongPredictiveHTML.cover(chart: chart, generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            body: body
        )
    }

    static func build(
        chart: NatalChart,
        mode: SolarArcMode,
        targetAge: Double,
        targetDate: Date,
        generatedAt: Date = Date()
    ) -> SolarArcLongReportData {
        let engine = SolarArcEngine()
        let directions = engine.solarArc(chart: chart, from: max(0, targetAge - 5), to: targetAge + 5, mode: mode, orb: 1.0)
        let arc = engine.solarArcAmount(chart: chart, age: targetAge, mode: mode) ?? 0
        return build(chart: chart, mode: mode, targetDate: targetDate, currentSolarArc: arc, directions: directions, generatedAt: generatedAt)
    }

    static func request(data: SolarArcLongReportData) -> ReportRequest<SolarArcLongReportData> {
        ReportRequest(templateName: templateName, data: data, pageSize: .a4Portrait)
    }

    static func makeRequest(data: SolarArcLongReportData) -> ReportRequest<SolarArcLongReportData> {
        request(data: data)
    }

    private static func table(directions: [SolarArcDirection]) -> String {
        let rows = directions.map { d in
            "<tr><td><span class=\"badge \(LongPredictiveHTML.weightClass(d.weight))\">\(d.weight.label)</span></td><td>\(LongPredictiveHTML.escape(d.displaySummary))</td><td>\(LongPredictiveHTML.escape(d.ageFormatted))</td><td>\(LongPredictiveHTML.date(d.exactDate))</td><td>\(LongPredictiveHTML.degree(d.orb))</td></tr>"
        }.joined()
        return """
        <section class="report-section page-break">
          <h2>Tabla de direcciones ±5 años por peso</h2>
          <table><thead><tr><th>Peso</th><th>Dirección</th><th>Edad</th><th>Fecha exacta</th><th>Orbe</th></tr></thead><tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 5, text: "Sin direcciones en la ventana ±5 años.") : rows)</tbody></table>
        </section>
        """
    }

    private static func detail(directions: [SolarArcDirection], targetDate: Date) -> String {
        let blocks = directions.map { d in
            """
            <article class="detail-card no-break">
              <h3>\(LongPredictiveHTML.escape(d.displaySummary))</h3>
              <p><strong>Exacta:</strong> \(LongPredictiveHTML.date(d.exactDate)) · <strong>Edad:</strong> \(LongPredictiveHTML.escape(d.ageFormatted)) · <strong>Arco:</strong> \(LongPredictiveHTML.escape(d.arcFormatted)).</p>
              <p>El punto dirigido parte de \(LongPredictiveHTML.escape(AstroEngine.degToSign(d.directedNatalLongitude))) y culmina en \(LongPredictiveHTML.escape(AstroEngine.degToSign(d.directedLongitude))). El receptor natal se mantiene en \(LongPredictiveHTML.escape(AstroEngine.degToSign(d.natalLongitude))).</p>
              <p class="caption">Polaridad técnica: \(d.polarity.label). Peso clásico: \(d.weight.label).</p>
            </article>
            """
        }.joined()
        return """
        <section class="report-section">
          <h2>Detalle de exactas en ±1 año</h2>
          <p>Centro de ventana: \(LongPredictiveHTML.date(targetDate)).</p>
          \(blocks.isEmpty ? "<p>No hay exactas en la ventana de ±1 año.</p>" : blocks)
        </section>
        """
    }
}

// MARK: - Progressions Long PDF

enum ProgressionsLongReportBuilder {
    static let templateName = "progressions"

    static func build(
        chart: NatalChart,
        snapshot: ProgressionSnapshot,
        yearlyAspects: [ProgressedAspect],
        highlightedChanges: [ProgressedIngress]? = nil,
        generatedAt: Date = Date()
    ) -> ProgressionsLongReportData {
        let generatedDate = LongPredictiveHTML.dateTime(generatedAt)
        let changes = highlightedChanges ?? snapshot.highlightedChanges
        let body = LongPredictiveHTML.styles()
            + snapshotSection(snapshot)
            + moonSection(snapshot)
            + aspectsSection(yearlyAspects)
            + changesSection(changes)
            + narrative(snapshot: snapshot, aspects: yearlyAspects, changes: changes)
        return ProgressionsLongReportData(
            header: ReportHeaderData(chartName: LongPredictiveHTML.chartName(chart), reportTitle: "Progresiones secundarias", generatedDate: generatedDate),
            cover: LongPredictiveHTML.cover(chart: chart, generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            body: body
        )
    }

    static func request(data: ProgressionsLongReportData) -> ReportRequest<ProgressionsLongReportData> {
        ReportRequest(templateName: templateName, data: data, pageSize: .a4Portrait)
    }

    static func makeRequest(data: ProgressionsLongReportData) -> ReportRequest<ProgressionsLongReportData> {
        request(data: data)
    }

    private static func snapshotSection(_ snapshot: ProgressionSnapshot) -> String {
        let bodyRows = snapshot.bodies.map { body in
            "<tr><td>\(LongPredictiveHTML.escape(body.label))</td><td>\(LongPredictiveHTML.escape(body.formatted))</td><td>Casa \(body.house)</td><td>\(body.retrograde ? "R" : "D")</td><td>\(String(format: "%.4f", body.speed))</td></tr>"
        }.joined()
        return """
        <section class="report-section no-break">
          <h2>Snapshot progresado</h2>
          <div class="long-report-grid">
            \(LongPredictiveHTML.metric("Fecha objetivo", LongPredictiveHTML.date(snapshot.targetDate)))
            \(LongPredictiveHTML.metric("Edad", String(format: "%.2f años", snapshot.ageYears)))
            \(LongPredictiveHTML.metric("ASC progresado", snapshot.ascendant.formatted))
            \(LongPredictiveHTML.metric("MC progresado", snapshot.mc.formatted))
            \(LongPredictiveHTML.metric("Modo ASC", snapshot.ascendantMode.label))
            \(LongPredictiveHTML.metric("Fase lunar", snapshot.lunarPhase.label))
          </div>
          <table><thead><tr><th>Planeta</th><th>Posición</th><th>Casa</th><th>Mov.</th><th>Vel.</th></tr></thead><tbody>\(bodyRows)</tbody></table>
        </section>
        """
    }

    private static func moonSection(_ snapshot: ProgressionSnapshot) -> String {
        guard let moon = snapshot.progressedMoon else {
            return "<section class=\"report-section\"><h2>Luna progresada por casa y signo</h2><p>Sin Luna progresada calculada.</p></section>"
        }
        return """
        <section class="report-section page-break">
          <h2>Luna progresada por casa y signo</h2>
          <p>La Luna progresada se encuentra en <strong>\(LongPredictiveHTML.escape(moon.formatted))</strong>, casa <strong>\(moon.house)</strong>. Esta posición actúa como minutero emocional del período y modula la fase lunar progresada: <strong>\(snapshot.lunarPhase.label)</strong> (ángulo \(LongPredictiveHTML.degree(snapshot.lunarPhase.angle))).</p>
          <p class="caption">Próximo umbral de fase: \(LongPredictiveHTML.degree(snapshot.lunarPhase.nextBoundary)).</p>
        </section>
        """
    }

    private static func aspectsSection(_ aspects: [ProgressedAspect]) -> String {
        let rows = aspects.sorted { $0.date < $1.date }.map { aspect in
            "<tr><td>\(aspect.exactDate)</td><td>\(aspect.kind.label)</td><td>\(LongPredictiveHTML.escape(aspect.title))</td><td>\(LongPredictiveHTML.degree(aspect.orb))</td><td>\(aspect.applying ? "Aplicativo" : "Separativo")</td></tr>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Aspectos prog→natal y prog→prog del año</h2>
          <table><thead><tr><th>Fecha</th><th>Tipo</th><th>Aspecto</th><th>Orbe</th><th>Fase</th></tr></thead><tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 5, text: "Sin aspectos progresados exactos en el año.") : rows)</tbody></table>
        </section>
        """
    }

    private static func changesSection(_ changes: [ProgressedIngress]) -> String {
        let rows = changes.sorted { $0.date < $1.date }.map { ingress in
            "<tr><td>\(ingress.dateLabel)</td><td>\(ingress.kind.label)</td><td>\(LongPredictiveHTML.escape(ingress.bodyLabel))</td><td>\(LongPredictiveHTML.escape(ingress.fromValue)) → \(LongPredictiveHTML.escape(ingress.toValue))</td><td>\(LongPredictiveHTML.escape(ingress.description))</td></tr>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Cambios destacados ±5 años</h2>
          <table><thead><tr><th>Fecha</th><th>Tipo</th><th>Cuerpo</th><th>Cambio</th><th>Lectura</th></tr></thead><tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 5, text: "Sin cambios destacados en ±5 años.") : rows)</tbody></table>
        </section>
        """
    }

    private static func narrative(snapshot: ProgressionSnapshot, aspects: [ProgressedAspect], changes: [ProgressedIngress]) -> String {
        """
        <section class="report-section">
          <h2>Narrativa técnica</h2>
          <p>El informe progresado sintetiza el estado simbólico día-por-año: ASC/MC progresados, fase lunar y agenda de aspectos exactos. La fase <strong>\(snapshot.lunarPhase.label)</strong> describe el tono de maduración del ciclo Sol-Luna.</p>
          <p>La prioridad interpretativa se asigna a la Luna progresada, a los aspectos con prioridad más alta y a los ingresos/estaciones lentas. En esta extracción se listan \(aspects.count) aspectos y \(changes.count) cambios para evitar ruido operativo.</p>
        </section>
        """
    }
}

// MARK: - Firdaria Long PDF

enum FirdariaLongReportBuilder {
    static let templateName = "firdaria"

    static func build(
        chart: NatalChart,
        timeline: FirdariaTimeline,
        currentMajor: FirdariaPeriod,
        currentMinor: FirdariaPeriod?,
        upcomingChanges: [FirdariaMinorChange],
        generatedAt: Date = Date()
    ) -> FirdariaLongReportData {
        let generatedDate = LongPredictiveHTML.dateTime(generatedAt)
        let body = LongPredictiveHTML.styles()
            + sectSection(timeline)
            + orderSection(timeline)
            + timelineSection(timeline)
            + currentSection(currentMajor: currentMajor, currentMinor: currentMinor)
            + upcomingSection(upcomingChanges)
            + cycleNarrative(timeline: timeline, currentMajor: currentMajor, currentMinor: currentMinor)
        return FirdariaLongReportData(
            header: ReportHeaderData(chartName: LongPredictiveHTML.chartName(chart), reportTitle: "Firdaria", generatedDate: generatedDate),
            cover: LongPredictiveHTML.cover(chart: chart, generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            body: body
        )
    }

    static func build(chart: NatalChart, asOf: Date, generatedAt: Date = Date()) -> FirdariaLongReportData {
        let engine = FirdariaEngine()
        let timeline = engine.firdariaPeriods(chart: chart)
        let current = engine.currentFirdaria(chart: chart, at: asOf)
        let upcoming = engine.upcomingMinorChanges(chart: chart, at: asOf, limit: 8)
        return build(chart: chart, timeline: timeline, currentMajor: current.major, currentMinor: current.minor, upcomingChanges: upcoming, generatedAt: generatedAt)
    }

    static func request(data: FirdariaLongReportData) -> ReportRequest<FirdariaLongReportData> {
        ReportRequest(templateName: templateName, data: data, pageSize: .a4Portrait)
    }

    static func makeRequest(data: FirdariaLongReportData) -> ReportRequest<FirdariaLongReportData> {
        request(data: data)
    }

    private static func sectSection(_ timeline: FirdariaTimeline) -> String {
        """
        <section class="report-section no-break">
          <h2>Secta</h2>
          <div class="long-report-grid">
            \(LongPredictiveHTML.metric("Secta", timeline.sect.label))
            \(LongPredictiveHTML.metric("Luminaria", timeline.sect.luminary.shortLabel))
            \(LongPredictiveHTML.metric("Benéfico de secta", timeline.sect.benefic.shortLabel))
            \(LongPredictiveHTML.metric("Maléfico de secta", timeline.sect.malefic.shortLabel))
          </div>
        </section>
        """
    }

    private static func orderSection(_ timeline: FirdariaTimeline) -> String {
        let rows = timeline.majorPeriods.map { p in
            "<tr><td>\(p.sequenceIndex + 1)</td><td>\(p.ruler.label)</td><td>\(LongPredictiveHTML.date(p.startDate))</td><td>\(LongPredictiveHTML.date(p.endDate))</td><td>\(String(format: "%.1f", p.nominalYears)) años</td></tr>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Orden firdariano del usuario</h2>
          <table><thead><tr><th>#</th><th>Regente</th><th>Inicio</th><th>Fin</th><th>Duración</th></tr></thead><tbody>\(rows)</tbody></table>
        </section>
        """
    }

    private static func timelineSection(_ timeline: FirdariaTimeline) -> String {
        """
        <section class="report-section page-break">
          <h2>Timeline 75 años</h2>
          <figure>\(firdariaTimeline(timeline: timeline, theme: .default))<figcaption>Períodos mayores del ciclo firdariano.</figcaption></figure>
        </section>
        """
    }

    private static func currentSection(currentMajor: FirdariaPeriod, currentMinor: FirdariaPeriod?) -> String {
        """
        <section class="report-section">
          <h2>Período mayor actual destacado</h2>
          <div class="long-report-grid">
            \(LongPredictiveHTML.metric("Mayor", currentMajor.ruler.label))
            \(LongPredictiveHTML.metric("Inicio", LongPredictiveHTML.date(currentMajor.startDate)))
            \(LongPredictiveHTML.metric("Fin", LongPredictiveHTML.date(currentMajor.endDate)))
            \(LongPredictiveHTML.metric("Menor", currentMinor?.ruler.label ?? "—"))
          </div>
          <p>El período mayor define la autoridad simbólica del capítulo. El subperíodo menor, cuando existe, concreta la administración cotidiana del mismo planeta o de su colaborador temporal.</p>
        </section>
        """
    }

    private static func upcomingSection(_ changes: [FirdariaMinorChange]) -> String {
        let rows = changes.map { change in
            "<tr><td>\(LongPredictiveHTML.date(change.date))</td><td>\(change.period.ruler.label)</td><td>\(LongPredictiveHTML.date(change.period.endDate))</td><td>\(String(format: "%.2f", change.period.nominalYears)) años</td></tr>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Próximos cambios</h2>
          <table><thead><tr><th>Entrada</th><th>Regente menor</th><th>Fin</th><th>Duración</th></tr></thead><tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 4, text: "Sin cambios próximos disponibles.") : rows)</tbody></table>
        </section>
        """
    }

    private static func cycleNarrative(timeline: FirdariaTimeline, currentMajor: FirdariaPeriod, currentMinor: FirdariaPeriod?) -> String {
        let items = timeline.majorPeriods.map { period in
            "<li><strong>\(period.ruler.shortLabel)</strong>: \(LongPredictiveHTML.planetNarrative(period.ruler))</li>"
        }.joined()
        return """
        <section class="report-section">
          <h2>Narrativa por planeta del ciclo en curso</h2>
          <p>Capítulo activo: <strong>\(currentMajor.ruler.shortLabel)</strong>\(currentMinor.map { " con subregente <strong>\($0.ruler.shortLabel)</strong>" } ?? "").</p>
          <ul class="long-report-list">\(items)</ul>
        </section>
        """
    }
}

// MARK: - Zodiacal Releasing Long PDF

enum ZodiacalReleasingLongReportBuilder {
    static let templateName = "zodiacal_releasing"

    static func build(
        chart: NatalChart,
        timelines: [ZRTimeline],
        asOf: Date,
        generatedAt: Date = Date()
    ) -> ZodiacalReleasingLongReportData {
        let generatedDate = LongPredictiveHTML.dateTime(generatedAt)
        let body = LongPredictiveHTML.styles()
            + lotsSummary(timelines)
            + timelines.map { lotSection($0, asOf: asOf) }.joined()
        return ZodiacalReleasingLongReportData(
            header: ReportHeaderData(chartName: LongPredictiveHTML.chartName(chart), reportTitle: "Zodiacal Releasing", generatedDate: generatedDate),
            cover: LongPredictiveHTML.cover(chart: chart, generatedDate: generatedDate),
            includeTOC: true,
            generatedDate: generatedDate,
            body: body
        )
    }

    static func build(chart: NatalChart, asOf: Date, generatedAt: Date = Date()) -> ZodiacalReleasingLongReportData {
        let engine = ZodiacalReleasingEngine()
        let timelines = [engine.zr(chart: chart, lot: .spirit, depth: 2), engine.zr(chart: chart, lot: .fortune, depth: 2)]
        return build(chart: chart, timelines: timelines, asOf: asOf, generatedAt: generatedAt)
    }

    static func request(data: ZodiacalReleasingLongReportData) -> ReportRequest<ZodiacalReleasingLongReportData> {
        ReportRequest(templateName: templateName, data: data, pageSize: .a4Portrait)
    }

    static func makeRequest(data: ZodiacalReleasingLongReportData) -> ReportRequest<ZodiacalReleasingLongReportData> {
        request(data: data)
    }

    private static func lotsSummary(_ timelines: [ZRTimeline]) -> String {
        let cards = timelines.map { timeline in
            LongPredictiveHTML.metric("Lote de \(timeline.lot.label)", "\(timeline.lotPoint.formatted) · \(timeline.lotPoint.signLabel)")
        }.joined()
        return """
        <section class="report-section no-break">
          <h2>Espíritu y Fortuna calculados</h2>
          <div class="long-report-grid">\(cards)</div>
          <p class="caption">El informe imprime ambos lotes cuando están disponibles. Espíritu se usa como eje de praxis, vocación y acción elegida; Fortuna como eje corporal, circunstancias y soporte material.</p>
        </section>
        """
    }

    private static func lotSection(_ timeline: ZRTimeline, asOf: Date) -> String {
        let currentL1 = timeline.currentL1(at: asOf)
        let currentL2 = timeline.currentL2(at: asOf)
        let upcoming = timeline.upcomingHighlightedEvents(after: asOf, limit: 8)
        return """
        <section class="report-section page-break">
          <h2>\(timeline.lot.noteLabel): capítulo actual</h2>
          <div class="long-report-grid">
            \(LongPredictiveHTML.metric("L1 actual", currentL1.map { $0.signLabel + " (" + LongPredictiveHTML.date($0.startDate) + " → " + LongPredictiveHTML.date($0.endDate) + ")" } ?? "—"))
            \(LongPredictiveHTML.metric("L2 actual", currentL2.map { $0.signLabel + " (" + LongPredictiveHTML.date($0.startDate) + " → " + LongPredictiveHTML.date($0.endDate) + ")" } ?? "—"))
            \(LongPredictiveHTML.metric("Lote", timeline.lotPoint.formatted))
            \(LongPredictiveHTML.metric("Secta", timeline.sect.label))
          </div>
          \(eventsTable(upcoming))
          <h3>Timeline SVG ZR (L1+L2)</h3>
          <figure>\(zrTimeline(timeline: timeline, depth: 2, theme: .default, height: 260))</figure>
          <h3>Todos los L1 históricos y futuros</h3>
          \(periodTable(timeline.periods))
          <h3>Narrativa del capítulo en curso</h3>
          <p>\(LongPredictiveHTML.zrNarrative(lot: timeline.lot, l1: currentL1, l2: currentL2))</p>
        </section>
        """
    }

    private static func eventsTable(_ events: [ZREvent]) -> String {
        let rows = events.map { event in
            "<tr><td>\(LongPredictiveHTML.date(event.date))</td><td>\(event.kind.label)</td><td>\(LongPredictiveHTML.escape(event.title))</td><td>\(LongPredictiveHTML.escape(event.detail))</td></tr>"
        }.joined()
        return "<h3>Próximos eventos (LB, peaks)</h3><table><thead><tr><th>Fecha</th><th>Tipo</th><th>Título</th><th>Detalle</th></tr></thead><tbody>\(rows.isEmpty ? LongPredictiveHTML.emptyRow(columns: 4, text: "Sin eventos destacados próximos en la ventana calculada.") : rows)</tbody></table>"
    }

    private static func periodTable(_ periods: [ZRPeriod]) -> String {
        let rows = periods.map { period in
            let l2 = period.children.prefix(6).map { "\($0.signLabel) \(LongPredictiveHTML.date($0.startDate))" }.joined(separator: "; ")
            return "<tr><td>\(period.signLabel)</td><td>\(LongPredictiveHTML.date(period.startDate))</td><td>\(LongPredictiveHTML.date(period.endDate))</td><td>\(String(format: "%.1f", period.nominalUnits)) \(period.unitLabel)</td><td>\(LongPredictiveHTML.escape(l2))</td></tr>"
        }.joined()
        return "<table><thead><tr><th>L1</th><th>Inicio</th><th>Fin</th><th>Duración</th><th>L2 colapsados</th></tr></thead><tbody>\(rows)</tbody></table>"
    }
}

// MARK: - Shared HTML Utilities

private enum LongPredictiveHTML {
    static func styles() -> String {
        """
        <style>
          .long-report-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8pt; margin: 12pt 0 16pt; }
          .metric-card { border: .5pt solid var(--neutral-rule); border-left: 3pt solid var(--gold); padding: 8pt; background: rgba(255,255,255,.32); break-inside: avoid; }
          .metric-label { display: block; font-family: var(--font-ui); font-size: 8.5pt; color: var(--ink-soft); text-transform: uppercase; letter-spacing: .06em; }
          .metric-value { display: block; margin-top: 2pt; color: var(--primary); font-weight: 700; }
          .detail-card { margin: 12pt 0 18pt; padding: 10pt 12pt; border: .5pt solid var(--gold-soft); background: rgba(255,255,255,.28); }
          .detail-card h4 { margin: 12pt 0 4pt; color: var(--primary); font-family: var(--font-ui); font-size: 10pt; text-transform: uppercase; letter-spacing: .04em; }
          .long-report-list li { margin-bottom: 5pt; }
          figure svg { width: 100%; height: auto; }
        </style>
        """
    }

    static func metric(_ label: String, _ value: String) -> String {
        "<div class=\"metric-card\"><span class=\"metric-label\">\(escape(label))</span><span class=\"metric-value\">\(escape(value))</span></div>"
    }

    static func chartName(_ chart: NatalChart) -> String {
        chart.name.nilIfBlank ?? chart.birthDate
    }

    static func cover(chart: NatalChart, generatedDate: String) -> ReportCoverData {
        let sign = signLabel(for: chart.ascendant.longitude)
        return ReportCoverData(
            chartName: chartName(chart),
            birthDate: chart.birthDate,
            birthTime: chart.birthTime,
            place: chart.placeName.nilIfBlank ?? "—",
            generatedDate: generatedDate,
            ascSign: sign.name,
            ascGlyph: sign.glyph
        )
    }

    static func emptyRow(columns: Int, text: String) -> String {
        "<tr><td colspan=\"\(columns)\">\(escape(text))</td></tr>"
    }

    static func weightClass(_ weight: PDWeight) -> String {
        switch weight {
        case .critical: return "critical"
        case .major: return "high"
        case .moderate: return "medium"
        case .minor: return "low"
        }
    }

    static func degree(_ value: Double) -> String {
        String(format: "%.2f°", value)
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    static func planetNarrative(_ planet: AstroPlanetKey) -> String {
        switch planet {
        case .sol: return "visibilidad, autoridad, dirección vital y relación con figuras solares."
        case .luna: return "cuerpo, hábitos, nutrición, familia y variabilidad emocional."
        case .mercurio: return "estudio, documentos, comercio, lenguaje y adaptación mental."
        case .venus: return "alianzas, deseo, estética, placer y conciliación."
        case .marte: return "acción, conflicto, cirugía simbólica, corte y defensa."
        case .jupiter: return "expansión, maestros, ley, protección y síntesis de sentido."
        case .saturno: return "estructura, límites, madurez, tiempo, responsabilidad y carga."
        case .nodoNorte: return "incremento, encuentros no ordinarios y amplificación del vector colectivo."
        case .nodoSur: return "disminución, cierre, drenaje y separación de patrones agotados."
        }
    }

    static func zrNarrative(lot: ZRLot, l1: ZRPeriod?, l2: ZRPeriod?) -> String {
        let axis = lot == .spirit ? "praxis, vocación y decisiones voluntarias" : "cuerpo, fortuna material y circunstancias que sostienen o limitan"
        let l1Text = l1.map { "El L1 en \($0.signLabel) marca el escenario principal desde \(date($0.startDate)) hasta \(date($0.endDate))." } ?? "No hay L1 activo para la fecha elegida."
        let l2Text = l2.map { "El L2 en \($0.signLabel) concreta el subcapítulo; su angularidad \($0.angularity?.label ?? "—") modula intensidad y visibilidad." } ?? "No hay L2 activo calculado."
        return "Para el lote de \(lot.label), el eje interpretativo es \(axis). \(l1Text) \(l2Text) Peaks y Loosing of the Bond se leen como cambios cualitativos, no como eventos aislados."
    }

    static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private static func signLabel(for longitude: Double) -> (glyph: String, name: String) {
        let normalized = ((longitude.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let index = max(0, min(11, Int(normalized / 30)))
        let label = SIGN_LABELS[index]
        let glyph = String(label.prefix(1))
        let name = label.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        return (glyph, name)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
