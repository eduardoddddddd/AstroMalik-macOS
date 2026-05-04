import SwiftUI

struct EphemerisDayDetailView: View {
    let day: Int?
    let events: [CelestialEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(day.map { "Eventos del día \($0)" } ?? "Selecciona un día")
                    .appSectionHeader()
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count) evento\(events.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    Text(day == nil ? "Pulsa un día del calendario para ver su detalle." : "No hay eventos principales registrados para este día.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                }
            }
        }
        .appCard(padding: 14)
    }

    private func eventRow(_ event: CelestialEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(Self.icon(for: event.kind))
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(localTime(event.dateLocal))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text(event.title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                }
                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(importanceLabel(event.importance))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(importanceColor(event.importance).opacity(0.16))
                .foregroundColor(importanceColor(event.importance))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(importanceColor(event.importance).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func localTime(_ dateLocal: String) -> String {
        guard dateLocal.count >= 16 else { return "--:--" }
        return String(dateLocal.suffix(5))
    }

    private func importanceLabel(_ importance: EventImportance) -> String {
        switch importance {
        case .minor: return "menor"
        case .moderate: return "media"
        case .major: return "mayor"
        case .critical: return "crítica"
        }
    }

    private func importanceColor(_ importance: EventImportance) -> Color {
        switch importance {
        case .minor: return .secondary
        case .moderate: return .appSecondaryAccent
        case .major: return .appAccentFill
        case .critical: return .appWarning
        }
    }

    static func icon(for kind: CelestialEventKind) -> String {
        switch kind {
        case .newMoon: return "🌑"
        case .fullMoon: return "🌕"
        case .firstQuarter: return "🌓"
        case .lastQuarter: return "🌗"
        case .solarEclipse: return "🌘"
        case .lunarEclipse: return "🌖"
        case .stationRetrograde: return "℞"
        case .stationDirect: return "↻"
        case .signIngress: return "♈︎"
        case .voidOfCourse: return "☽"
        case .voidOfCourseEnd: return "↦"
        case .mundaneAspect: return "◇"
        }
    }
}
