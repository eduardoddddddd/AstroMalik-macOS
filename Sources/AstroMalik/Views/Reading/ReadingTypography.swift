import SwiftUI

// MARK: - ReadingTypography
// Tipografía de documento para la Lectura Natal: separa por ritmo y jerarquía,
// no por tarjetas anidadas. Los bloques del corpus deben permanecer siempre
// visibles y sin truncado.

struct ReadingChapterTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3.weight(.semibold))
            .foregroundColor(.appPrimaryText)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.top, 28)
    }
}

struct ReadingBodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .lineSpacing(5)
            .foregroundColor(.appPrimaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReadingSourceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReadingTechnicalHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.monospacedDigit())
            .foregroundColor(.appPrimaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func readingChapterTitle() -> some View { modifier(ReadingChapterTitleStyle()) }
    func readingBody() -> some View { modifier(ReadingBodyStyle()) }
    func readingSource() -> some View { modifier(ReadingSourceStyle()) }
    func readingTechnicalHeader() -> some View { modifier(ReadingTechnicalHeaderStyle()) }
}
