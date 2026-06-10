import SwiftUI

struct ReadingTOCView: View {
    let chapters: [ReadingChapter]
    @Binding var selectedChapter: ReadingChapterKind?
    var onSelect: (ReadingChapterKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ÍNDICE")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .tracking(1.2)
                .padding(.bottom, 2)

            ForEach(chapters) { chapter in
                Button {
                    selectedChapter = chapter.id
                    onSelect(chapter.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedChapter == chapter.id ? "largecircle.fill.circle" : "circle")
                            .font(.caption)
                            .foregroundColor(selectedChapter == chapter.id ? .appSecondaryAccent : .secondary)
                        Text(chapter.title)
                            .font(.callout)
                            .foregroundColor(selectedChapter == chapter.id ? .appPrimaryText : .secondary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 16)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(width: 180)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
    }
}
