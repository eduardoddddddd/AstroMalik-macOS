import SwiftUI

struct EphemerisTableView: View {
    let rows: [DailyEphemerisRow]

    private let columns = [
        "Día", "☉", "☽", "☿", "♀", "♂", "♃", "♄", "⛢", "♆", "♇", "☊", "Fase"
    ]

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { column in
                        Text(column)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            .frame(width: column == "Fase" ? 135 : 74, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                    }
                }
                .background(Color.appChipBackground)

                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        Text(String(row.date.suffix(2)))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(width: 74, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 7)

                        ForEach(row.positions, id: \.planetKey) { position in
                            Text(position.formatted)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(position.retrograde ? .appWarning : .appPrimaryText)
                                .frame(width: 74, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 7)
                        }

                        Text("\(phaseIcon(row.lunarPhaseAngle)) \(row.lunarPhaseLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 135, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 7)
                    }
                    .background(Int(row.date.suffix(2)) ?? 0 % 2 == 0 ? Color.appSurface.opacity(0.65) : Color.appPanel)
                    Divider()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.appBorder.opacity(0.75), lineWidth: 1)
            )
            .padding(16)
        }
        .background(Color.appBackground)
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
