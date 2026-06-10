import SwiftUI

struct ReadingBlockView: View {
    let block: ReadingBlock
    var searchQuery: String = ""
    var onFocus: (String) -> Void = { _ in }

    var body: some View {
        switch block.kind {
        case .lead(let text):
            Text(text)
                .readingBody()
                .padding(.vertical, block.emphasis == .primary ? 8 : 4)

        case .pointHeader(let data):
            pointHeader(data)
                .padding(.top, block.emphasis == .primary ? 10 : 6)

        case .corpus(let title, let paragraphs, let source):
            corpusBlock(title: title, paragraphs: paragraphs, source: source)

        case .chips(let chips):
            chipsBlock(chips)

        case .aspectLine(let data):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(data.text)
                    .font(.callout.monospacedDigit())
                    .foregroundColor(.appPrimaryText)
                Spacer(minLength: 8)
                Text(String(format: "%.1f", data.score))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 3)

        case .groupedList(let title, let items):
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
                Text(items.joined(separator: " · "))
                    .readingBody()
                    .font(.callout)
            }
            .padding(.vertical, 4)
        }
    }

    private func pointHeader(_ data: PointHeaderData) -> some View {
        Button {
            onFocus(data.key)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.appPrimaryText)
                    Text(data.detail)
                        .readingTechnicalHeader()
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 8)
                if !data.badges.isEmpty {
                    ReadingFlowLayout(spacing: 6) {
                        ForEach(data.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.appChipBackground)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: 220, alignment: .trailing)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Enfocar en la rueda: \(data.title)")
    }

    private func corpusBlock(title: String?, paragraphs: [String], source: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title, !title.isEmpty {
                Text(highlighted(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appPrimaryText)
            }
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(highlighted(paragraph))
                    .readingBody()
                    .padding(.vertical, searchQuery.isEmpty ? 0 : (paragraph.localizedCaseInsensitiveContains(searchQuery) ? 3 : 0))
                    .background(searchQuery.isEmpty ? Color.clear : (paragraph.localizedCaseInsensitiveContains(searchQuery) ? Color.appAccentFill.opacity(0.10) : Color.clear))
            }
            if !source.isEmpty {
                Text("— \(source)")
                    .readingSource()
            }
        }
        .padding(.vertical, block.emphasis == .primary ? 8 : 5)
    }

    private func chipsBlock(_ chips: [ReadingChip]) -> some View {
        ReadingFlowLayout(spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                HStack(spacing: 5) {
                    Text(chip.label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(chip.value)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.appPrimaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chipColor(chip.tint).opacity(0.18))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(chipColor(chip.tint).opacity(0.28), lineWidth: 1))
            }
        }
        .padding(12)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.appBorder.opacity(0.65), lineWidth: 1))
        .padding(.vertical, 6)
    }

    private func chipColor(_ tint: ReadingChip.ChipTint) -> Color {
        switch tint {
        case .fire: return .orange
        case .earth: return .brown
        case .air: return .cyan
        case .water: return .blue
        case .neutral: return .secondary
        case .accent: return .appSecondaryAccent
        }
    }

    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attributed }
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerText.startIndex
        while searchStart < lowerText.endIndex,
              let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor = .appAccentFill.opacity(0.28)
                attributed[attributedRange].foregroundColor = .appPrimaryText
            }
            searchStart = range.upperBound
        }
        return attributed
    }
}

/// Layout mínimo para chips que fluyen horizontalmente y saltan de línea.
struct ReadingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        let rows = rows(in: width, subviews: subviews)
        return CGSize(width: width, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [(width: CGFloat, height: CGFloat)] {
        var rows: [(width: CGFloat, height: CGFloat)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentWidth == 0 ? size.width : currentWidth + spacing + size.width
            if currentWidth > 0, nextWidth > width {
                rows.append((currentWidth, currentHeight))
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }
        if currentWidth > 0 { rows.append((currentWidth, currentHeight)) }
        return rows
    }
}

private extension String {
    func localizedCaseInsensitiveContains(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
