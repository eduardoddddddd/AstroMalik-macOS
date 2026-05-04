import SwiftUI

private enum EphemerisViewMode: String, CaseIterable, Identifiable {
    case calendar = "Calendario"
    case table = "Efemérides"
    case summary = "Resumen"
    var id: String { rawValue }
}

struct EphemerisCalendarView: View {
    @EnvironmentObject var appState: AppState

    @State private var currentYear: Int
    @State private var currentMonth: Int
    @State private var selectedDay: Int?
    @State private var viewMode: EphemerisViewMode = .calendar
    @State private var monthData: EphemerisMonth?
    @State private var isLoading = false
    @State private var isCreatingNote = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var noteTask: Task<Void, Never>?

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let comps = calendar.dateComponents([.year, .month, .day], from: Date())
        _currentYear = State(initialValue: comps.year ?? 2026)
        _currentMonth = State(initialValue: comps.month ?? 1)
        _selectedDay = State(initialValue: comps.day)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView("Calculando efemérides…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else if let monthData {
                content(monthData)
            } else {
                emptyView
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Efemérides")
        .task(id: "\(currentYear)-\(currentMonth)") { loadMonth() }
        .onDisappear {
            calculationTask?.cancel()
            noteTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered)
            Text(monthTitle)
                .font(.title2.weight(.semibold))
                .foregroundColor(.appPrimaryText)
                .frame(minWidth: 180)
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered)
            Button("Hoy") { goToToday() }
                .buttonStyle(.bordered)

            Picker("Vista", selection: $viewMode) {
                ForEach(EphemerisViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 330)

            Spacer()

            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundColor(.appSecondaryAccent)
            }

            Button {
                if let monthData { createJoplinNote(monthData) }
            } label: {
                Label(isCreatingNote ? "Creando…" : "Joplin", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .disabled(monthData == nil || isCreatingNote)
        }
        .padding(16)
    }

    @ViewBuilder
    private func content(_ month: EphemerisMonth) -> some View {
        switch viewMode {
        case .calendar:
            HStack(alignment: .top, spacing: 16) {
                calendarGrid(month)
                    .frame(minWidth: 520)
                EphemerisDayDetailView(day: selectedDay, events: eventsForSelectedDay(month))
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 460, maxHeight: .infinity)
            }
            .padding(16)
        case .table:
            EphemerisTableView(rows: month.dailyRows)
        case .summary:
            MonthlySummaryView(ephemeris: month, monthTitle: monthTitle)
        }
    }

    private func calendarGrid(_ month: EphemerisMonth) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calendario mensual")
                    .appSectionHeader()
                Spacer()
                Text("\(month.events.count) eventos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { label in
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarCells, id: \.self) { day in
                    if let day {
                        dayCell(day, month: month)
                    } else {
                        Color.clear.frame(height: 82)
                    }
                }
            }
        }
        .appCard(padding: 14)
    }

    private func dayCell(_ day: Int, month: EphemerisMonth) -> some View {
        let events = eventsFor(day: day, month: month)
        let phase = phaseFor(day: day, month: month)
        let selected = day == selectedDay
        let maxImportance = events.map(\.importance).max() ?? .minor

        return Button {
            selectedDay = day
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(day)")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text(phaseIcon(phase?.lunarPhaseAngle ?? 0))
                }
                if let phase {
                    Text(phase.lunarPhaseLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    ForEach(events.prefix(5)) { event in
                        Text(EphemerisDayDetailView.icon(for: event.kind))
                            .font(.caption)
                    }
                    if events.count > 5 {
                        Text("+\(events.count - 5)").font(.caption2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(dayBackground(selected: selected, importance: maxImportance, hasEvents: !events.isEmpty))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.appAccentFill : Color.appBorder.opacity(0.6), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dayBackground(selected: Bool, importance: EventImportance, hasEvents: Bool) -> Color {
        if selected { return Color.appAccentFill.opacity(0.18) }
        guard hasEvents else { return Color.appSurface.opacity(0.72) }
        switch importance {
        case .minor: return Color.appChipBackground.opacity(0.7)
        case .moderate: return Color.appSecondaryAccent.opacity(0.12)
        case .major: return Color.appAccentFill.opacity(0.12)
        case .critical: return Color.appWarning.opacity(0.16)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.day.timeline.leading")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
            Text("Calcula el calendario astrológico mensual.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.appWarning)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") { loadMonth() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func loadMonth() {
        calculationTask?.cancel()
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        let year = currentYear
        let month = currentMonth
        let timezone = TimeZone.current.identifier
        calculationTask = Task {
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try await EphemerisEngine.computeMonth(year: year, month: month, timezone: timezone)
                }
                let data = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                monthData = data
                if selectedDay == nil || !(1...daysInMonth(year: year, month: month)).contains(selectedDay ?? 0) {
                    selectedDay = 1
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled { isLoading = false }
        }
    }

    private func createJoplinNote(_ month: EphemerisMonth) {
        noteTask?.cancel()
        isCreatingNote = true
        statusMessage = nil
        errorMessage = nil
        let settings = appState.joplinSettings
        let title = "Efemérides — \(monthTitle)"
        let body = EphemerisNoteBuilder.markdown(month: month, monthTitle: monthTitle)
        noteTask = Task {
            do {
                let service = JoplinClipperService(settings: settings)
                try await service.createNote(title: title, body: body)
                guard !Task.isCancelled else { return }
                statusMessage = "Nota creada en Joplin."
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            if !Task.isCancelled { isCreatingNote = false }
        }
    }

    private func eventsForSelectedDay(_ month: EphemerisMonth) -> [CelestialEvent] {
        guard let selectedDay else { return [] }
        return eventsFor(day: selectedDay, month: month)
    }

    private func eventsFor(day: Int, month: EphemerisMonth) -> [CelestialEvent] {
        month.eventsByDay[dateKey(day: day)]?.sorted { $0.dateLocal < $1.dateLocal } ?? []
    }

    private func phaseFor(day: Int, month: EphemerisMonth) -> DailyEphemerisRow? {
        month.dailyRows.first { $0.date == dateKey(day: day) }
    }

    private var calendarCells: [Int?] {
        let firstWeekday = weekdayIndexMondayFirst(year: currentYear, month: currentMonth, day: 1)
        let blanks = Array<Int?>(repeating: nil, count: firstWeekday)
        let days = (1...daysInMonth(year: currentYear, month: currentMonth)).map { Optional($0) }
        return blanks + days
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        let date = dateFor(year: currentYear, month: currentMonth, day: 1) ?? Date()
        return formatter.string(from: date).capitalized
    }

    private func moveMonth(_ delta: Int) {
        var month = currentMonth + delta
        var year = currentYear
        if month < 1 { month = 12; year -= 1 }
        if month > 12 { month = 1; year += 1 }
        currentYear = year
        currentMonth = month
        selectedDay = min(selectedDay ?? 1, daysInMonth(year: year, month: month))
    }

    private func goToToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let comps = calendar.dateComponents([.year, .month, .day], from: Date())
        currentYear = comps.year ?? currentYear
        currentMonth = comps.month ?? currentMonth
        selectedDay = comps.day ?? 1
    }

    private func dateKey(day: Int) -> String {
        String(format: "%04d-%02d-%02d", currentYear, currentMonth, day)
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        guard let date = dateFor(year: year, month: month, day: 1) else { return 30 }
        let calendar = Calendar(identifier: .gregorian)
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func weekdayIndexMondayFirst(year: Int, month: Int, day: Int) -> Int {
        guard let date = dateFor(year: year, month: month, day: day) else { return 0 }
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date) // Sunday = 1
        return (weekday + 5) % 7
    }

    private func dateFor(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps)
    }

    private func phaseIcon(_ angle: Double) -> String {
        switch angle {
        case 0..<45, 315..<360: return "🌑"
        case 45..<90: return "🌒"
        case 90..<135: return "🌓"
        case 135..<180: return "🌔"
        case 180..<225: return "🌕"
        case 225..<270: return "🌖"
        case 270..<315: return "🌗"
        default: return "🌘"
        }
    }
}
