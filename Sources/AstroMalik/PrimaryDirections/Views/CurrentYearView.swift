import SwiftUI

struct CurrentYearView: View {
    @ObservedObject var vm: PrimaryDirectionsViewModel

    private var yearDate: Binding<Date> {
        Binding(
            get: { dateForYear(vm.selectedYear) },
            set: { vm.selectedYear = Calendar.current.component(.year, from: $0) }
        )
    }

    private var directions: [EnrichedPrimaryDirection] {
        vm.directionsForSelectedYear
    }

    private var nearestID: UUID? {
        let target = targetDate(in: vm.selectedYear)
        return directions.min {
            abs($0.direction.estimatedDate.timeIntervalSince(target)) <
            abs($1.direction.estimatedDate.timeIntervalSince(target))
        }?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if directions.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(directions) { enriched in
                    yearCard(enriched)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
            }
        }
        .background(Color.appBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            DatePicker("Año", selection: yearDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: 128)
                .accessibilityLabel("Año seleccionado")

            Stepper("\(vm.selectedYear)", value: $vm.selectedYear, in: 1800...2200)
                .font(.caption.monospaced())
                .frame(width: 126)

            Spacer()

            Text("\(directions.count)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(Color.appAccentFill.opacity(0.65))
            Text("Sin direcciones en la ventana anual")
                .font(.headline)
            Text("La vista incluye el año elegido con margen residual de ±18 meses.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func yearCard(_ enriched: EnrichedPrimaryDirection) -> some View {
        let isNearest = enriched.id == nearestID
        return Button {
            vm.selectedDirection = enriched
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(enriched.displaySummary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(enriched.direction.estimatedDate, format: .dateTime.year().month(.abbreviated))
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.appAccentFill)
                }

                HStack(spacing: 8) {
                    tag(enriched.ageCompact)
                    tag(enriched.direction.directionType == .direct ? "Directa" : "Conversa")
                    tag(enriched.direction.aspectPlane.displayName)
                    if isNearest {
                        tag("Más cercana")
                            .foregroundStyle(Color.appSecondaryAccent)
                    }
                }

                Text(primarySnippet(for: enriched))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                isNearest ? Color.appSecondaryAccent.opacity(0.10) : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isNearest ? Color.appSecondaryAccent.opacity(0.45) : Color.appBorder.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.appPanel, in: Capsule())
    }

    private func primarySnippet(for enriched: EnrichedPrimaryDirection) -> String {
        let raw = if let interpretation = enriched.interpretation, !interpretation.textoCortoPD.isEmpty {
            interpretation.textoCortoPD
        } else {
            PrimaryDirectionLocalReading.build(for: enriched.direction).summary
        }
        if raw.count <= 200 { return raw }
        return String(raw.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func dateForYear(_ year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }

    private func targetDate(in year: Int) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? dateForYear(year)
    }
}

private extension EnrichedPrimaryDirection {
    var ageCompact: String {
        let years = Int(direction.estimatedAge)
        let months = Int((direction.estimatedAge - Double(years)) * 12)
        return "\(years)a \(months)m"
    }
}
