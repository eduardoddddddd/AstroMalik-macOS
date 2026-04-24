import SwiftUI

struct TransitTimelineView: View {
    let events: [TransitEvent]
    let fromDate: Date
    let toDate: Date
    let onSelect: (TransitEvent) -> Void

    private let labelWidth: CGFloat = 190
    private let rowHeight: CGFloat = 38
    private let plotHeight: CGFloat = 26

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal
    }

    private var startDate: Date {
        calendar.startOfDay(for: fromDate)
    }

    private var endDate: Date {
        calendar.startOfDay(for: toDate)
    }

    private var totalDays: Int {
        max(1, daysBetween(startDate, endDate) + 1)
    }

    private var minimumDayWidth: CGFloat {
        switch totalDays {
        case ...21: return 24
        case ...60: return 16
        case ...180: return 9
        case ...540: return 5
        default: return 3
        }
    }

    private func dayWidth(for availableWidth: CGFloat) -> CGFloat {
        let availablePlotWidth = max(0, availableWidth - labelWidth - 24)
        let fillWidth = availablePlotWidth / CGFloat(totalDays)
        return max(minimumDayWidth, fillWidth)
    }

    private func timelineWidth(for availableWidth: CGFloat, dayWidth: CGFloat) -> CGFloat {
        let availablePlotWidth = max(0, availableWidth - labelWidth - 24)
        return max(CGFloat(totalDays) * dayWidth, availablePlotWidth, 520)
    }

    var body: some View {
        GeometryReader { proxy in
            let effectiveDayWidth = dayWidth(for: proxy.size.width)
            let effectiveTimelineWidth = timelineWidth(
                for: proxy.size.width,
                dayWidth: effectiveDayWidth
            )

            VStack(alignment: .leading, spacing: 0) {
                header
                if events.isEmpty {
                    emptyFilteredState
                } else {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            axisRow(dayWidth: effectiveDayWidth, timelineWidth: effectiveTimelineWidth)
                            ScrollView(.vertical) {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                        timelineRow(
                                            event: event,
                                            index: index,
                                            dayWidth: effectiveDayWidth,
                                            timelineWidth: effectiveTimelineWidth
                                        )
                                    }
                                }
                            }
                            .frame(minHeight: 120)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
            .background(Color.appSurface)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Línea temporal", systemImage: "waveform.path.ecg")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.appPrimaryText)
            Text("\(events.count) tránsitos")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyFilteredState: some View {
        VStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
            Text("No hay tránsitos con el filtro de intensidad actual")
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func axisRow(dayWidth: CGFloat, timelineWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: labelWidth, height: 34)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.appBorder.opacity(0.55))
                    .frame(width: timelineWidth, height: 1)
                    .offset(y: 24)
                ForEach(axisMarks, id: \.offset) { mark in
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.appPrimaryText.opacity(mark.major ? 0.7 : 0.35))
                            .frame(width: 1, height: mark.major ? 22 : 12)
                        Text(mark.label)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .offset(x: CGFloat(mark.offset) * dayWidth, y: 0)
                }
            }
            .frame(width: timelineWidth, height: 34, alignment: .leading)
        }
    }

    private func timelineRow(
        event: TransitEvent,
        index: Int,
        dayWidth: CGFloat,
        timelineWidth: CGFloat
    ) -> some View {
        Button {
            onSelect(event)
        } label: {
            HStack(spacing: 0) {
                eventLabel(event)
                    .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.appBorder.opacity(0.35))
                        .frame(width: timelineWidth, height: 1)
                        .offset(y: -6)
                    ForEach(visibleSamples(for: event), id: \.sample) { item in
                        let barHeight = max(2, CGFloat(item.sample.intensity) * plotHeight)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color(hex: event.color).opacity(0.78))
                            .frame(width: max(2, dayWidth - 1), height: barHeight)
                            .offset(x: CGFloat(item.offset) * dayWidth, y: -7)
                    }
                    if let exactOffset = offset(forISODate: event.exactDate) {
                        Rectangle()
                            .fill(Color.appPrimaryText.opacity(0.75))
                            .frame(width: 1, height: plotHeight + 6)
                            .offset(x: CGFloat(exactOffset) * dayWidth + max(1, dayWidth / 2), y: -7)
                    }
                }
                .frame(width: timelineWidth, height: rowHeight, alignment: .bottomLeading)
            }
            .padding(.vertical, 1)
            .background(index.isMultiple(of: 2) ? Color.appSurface : Color.appPanel.opacity(0.45))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func eventLabel(_ event: TransitEvent) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: event.color))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(event.transitLabel) \(event.aspectLabel) \(event.natalLabel)")
                    .font(.caption)
                    .foregroundColor(.appPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(event.starsDisplay)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(starColor(event.stars))
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 12)
    }

    private var axisMarks: [TimelineAxisMark] {
        if totalDays <= 21 {
            return marksByStride(1, majorEvery: 7)
        }
        if totalDays <= 90 {
            return marksByStride(7, majorEvery: 28)
        }
        if totalDays <= 540 {
            return monthMarks(step: 1)
        }
        return monthMarks(step: 3)
    }

    private func marksByStride(_ strideDays: Int, majorEvery: Int) -> [TimelineAxisMark] {
        stride(from: 0, through: totalDays - 1, by: strideDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return TimelineAxisMark(
                offset: offset,
                label: compactLabel(for: date),
                major: offset % majorEvery == 0
            )
        }
    }

    private func monthMarks(step: Int) -> [TimelineAxisMark] {
        var marks: [TimelineAxisMark] = []
        var comps = calendar.dateComponents([.year, .month], from: startDate)
        comps.day = 1
        var cursor = calendar.date(from: comps) ?? startDate
        if cursor < startDate {
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? startDate
        }
        if marks.isEmpty {
            marks.append(TimelineAxisMark(offset: 0, label: compactLabel(for: startDate), major: true))
        }
        while cursor <= endDate {
            let offset = daysBetween(startDate, cursor)
            if offset >= 0 && offset < totalDays && !marks.contains(where: { $0.offset == offset }) {
                marks.append(TimelineAxisMark(offset: offset, label: compactLabel(for: cursor), major: true))
            }
            guard let next = calendar.date(byAdding: .month, value: step, to: cursor) else { break }
            cursor = next
        }
        return marks
    }

    private func visibleSamples(for event: TransitEvent) -> [TimelineSamplePosition] {
        event.samples.compactMap { sample in
            guard let offset = offset(forISODate: sample.date), offset >= 0, offset < totalDays else {
                return nil
            }
            return TimelineSamplePosition(offset: offset, sample: sample)
        }
    }

    private func offset(forISODate isoDate: String) -> Int? {
        guard let date = dateFromISO(isoDate) else { return nil }
        return daysBetween(startDate, date)
    }

    private func dateFromISO(_ isoDate: String) -> Date? {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return comps.date
    }

    private func compactLabel(for date: Date) -> String {
        let comps = calendar.dateComponents([.day, .month, .year], from: date)
        guard let day = comps.day, let month = comps.month else { return "" }
        if totalDays > 540, let year = comps.year {
            return "\(month)/\(String(format: "%02d", year % 100))"
        }
        return "\(day)/\(month)"
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func starColor(_ stars: Int) -> Color {
        switch stars {
        case 5: return Color(hex: "#d97706")
        case 4: return Color(hex: "#2563eb")
        case 3: return Color(hex: "#15803d")
        default: return .secondary
        }
    }
}

private struct TimelineAxisMark {
    var offset: Int
    var label: String
    var major: Bool
}

private struct TimelineSamplePosition: Hashable {
    var offset: Int
    var sample: TransitIntensitySample
}
