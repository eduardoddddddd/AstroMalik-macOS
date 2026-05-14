import Foundation

/// Tema visual inmutable para informes PDF HTML+CSS.
struct ReportTheme: Equatable, Sendable {
    struct Palette: Equatable, Sendable {
        let background: String
        let ink: String
        let inkSoft: String
        let primary: String
        let gold: String
        let goldSoft: String
        let benefic: String
        let malefic: String
        let neutralRule: String
        let tableStripe: String
    }

    struct Typography: Equatable, Sendable {
        let bodyFamily: String
        let uiFamily: String
        let glyphFamily: String
        let serifFallback: String
        let sansFallback: String
    }

    struct PageMargins: Equatable, Sendable {
        let topMM: Double
        let rightMM: Double
        let bottomMM: Double
        let leftMM: Double
    }

    struct FontScale: Equatable, Sendable {
        let h1PT: Double
        let h2PT: Double
        let h3PT: Double
        let bodyPT: Double
        let captionPT: Double
    }

    let palette: Palette
    let typography: Typography
    let margins: PageMargins
    let fontScale: FontScale

    static let `default` = ReportTheme(
        palette: Palette(
            background: "#F4EEE0",
            ink: "#1B1B1F",
            inkSoft: "#4A4A52",
            primary: "#1B2A4E",
            gold: "#A07C2C",
            goldSoft: "#C7A95A",
            benefic: "#3F6E48",
            malefic: "#8C3A2A",
            neutralRule: "#D8CDB4",
            tableStripe: "#ECE2CC"
        ),
        typography: Typography(
            bodyFamily: "\"EB Garamond\", \"Garamond\", \"Adobe Garamond Pro\", serif",
            uiFamily: "\"Inter\", -apple-system, BlinkMacSystemFont, \"Helvetica Neue\", Arial, sans-serif",
            glyphFamily: "\"astro-glyphs\", \"Apple Symbols\", \"Segoe UI Symbol\", serif",
            serifFallback: "\"EB Garamond\", \"Garamond\", \"Adobe Garamond Pro\", serif",
            sansFallback: "\"Inter\", -apple-system, BlinkMacSystemFont, \"Helvetica Neue\", Arial, sans-serif"
        ),
        margins: PageMargins(topMM: 25, rightMM: 25, bottomMM: 20, leftMM: 25),
        fontScale: FontScale(h1PT: 32, h2PT: 22, h3PT: 16, bodyPT: 11, captionPT: 9)
    )

    /// Devuelve un bloque CSS `:root` con todos los tokens del tema.
    func cssVariables() -> String {
        """
        :root {
          --bg: \(palette.background);
          --ink: \(palette.ink);
          --ink-soft: \(palette.inkSoft);
          --primary: \(palette.primary);
          --gold: \(palette.gold);
          --gold-soft: \(palette.goldSoft);
          --benefic: \(palette.benefic);
          --malefic: \(palette.malefic);
          --neutral-rule: \(palette.neutralRule);
          --table-stripe: \(palette.tableStripe);
          --font-body: \(typography.bodyFamily);
          --font-ui: \(typography.uiFamily);
          --font-glyphs: \(typography.glyphFamily);
          --font-serif-fallback: \(typography.serifFallback);
          --font-sans-fallback: \(typography.sansFallback);
          --page-margin-top: \(cssMillimeters(margins.topMM));
          --page-margin-right: \(cssMillimeters(margins.rightMM));
          --page-margin-bottom: \(cssMillimeters(margins.bottomMM));
          --page-margin-left: \(cssMillimeters(margins.leftMM));
          --font-size-h1: \(cssPoints(fontScale.h1PT));
          --font-size-h2: \(cssPoints(fontScale.h2PT));
          --font-size-h3: \(cssPoints(fontScale.h3PT));
          --font-size-body: \(cssPoints(fontScale.bodyPT));
          --font-size-caption: \(cssPoints(fontScale.captionPT));
        }
        """
    }

    private func cssMillimeters(_ value: Double) -> String {
        format(value) + "mm"
    }

    private func cssPoints(_ value: Double) -> String {
        format(value) + "pt"
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
