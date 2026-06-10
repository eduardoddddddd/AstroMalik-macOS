import SwiftUI

struct ReadingChapterView: View {
    let chapter: ReadingChapter
    var searchQuery: String = ""
    var onFocus: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.title)
                .readingChapterTitle()
            if let subtitle = chapter.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chapter.blocks) { block in
                    ReadingBlockView(block: block, searchQuery: searchQuery, onFocus: onFocus)
                }
            }
        }
        .id(chapter.id)
    }
}
