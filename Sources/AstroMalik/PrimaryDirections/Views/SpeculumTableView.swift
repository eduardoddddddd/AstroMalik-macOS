import SwiftUI

struct SpeculumTableView: View {
    let rows: [SpeculumRow]
    let promissorKey: String
    let significatorKey: String

    var body: some View {
        Table(rows) {
            TableColumn("Cuerpo") { row in
                cell(row.label, row: row, monospaced: false)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Long") { row in
                cell(degrees(row.longitude), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("Lat") { row in
                cell(signedDegrees(row.latitude), row: row)
            }
            .width(min: 64, ideal: 76)

            TableColumn("AR") { row in
                cell(degrees(row.rightAscension), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("Decl") { row in
                cell(signedDegrees(row.declination), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("MD") { row in
                cell(signedDegrees(row.meridianDistance), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("ZD") { row in
                cell(signedDegrees(row.zenithDistance), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("Polo") { row in
                cell(signedDegrees(row.pole), row: row)
            }
            .width(min: 70, ideal: 82)

            TableColumn("Q") { row in
                cell(signedDegrees(row.q), row: row)
            }
            .width(min: 64, ideal: 76)

            TableColumn("W") { row in
                cell(degrees(row.w), row: row)
            }
            .width(min: 70, ideal: 82)
        }
        .frame(minHeight: 260)
        .accessibilityLabel("Espéculo Regiomontano completo")
    }

    private func cell(_ text: String, row: SpeculumRow, monospaced: Bool = true) -> some View {
        Text(text)
            .font(monospaced ? .caption.monospaced() : .caption)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .background(rowTint(row))
    }

    private func rowTint(_ row: SpeculumRow) -> Color {
        if row.key == promissorKey && row.key == significatorKey {
            return Color.appAccentFill.opacity(0.18)
        }
        if row.key == promissorKey {
            return Color.appAccentFill.opacity(0.11)
        }
        if row.key == significatorKey {
            return Color.appSecondaryAccent.opacity(0.11)
        }
        return .clear
    }

    private func degrees(_ value: Double) -> String {
        "\(String(format: "%.2f", value))°"
    }

    private func signedDegrees(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "")\(String(format: "%.2f", value))°"
    }
}
