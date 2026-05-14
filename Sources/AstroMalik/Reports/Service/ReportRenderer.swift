import Foundation
import CoreGraphics
@preconcurrency import WebKit

enum PDFPageSize: Equatable, Sendable {
    case a4Portrait
    case a4Landscape
    case letter

    var sizeInPoints: CGSize {
        switch self {
        case .a4Portrait:
            return CGSize(width: Self.mmToPoints(210), height: Self.mmToPoints(297))
        case .a4Landscape:
            return CGSize(width: Self.mmToPoints(297), height: Self.mmToPoints(210))
        case .letter:
            return CGSize(width: 612, height: 792)
        }
    }

    var cssPageSize: String {
        switch self {
        case .a4Portrait: return "A4 portrait"
        case .a4Landscape: return "A4 landscape"
        case .letter: return "letter"
        }
    }

    private static func mmToPoints(_ millimeters: Double) -> CGFloat {
        CGFloat(millimeters / 25.4 * 72.0)
    }
}

struct PDFMargins: Equatable, Sendable {
    let top: Double
    let right: Double
    let bottom: Double
    let left: Double

    static let standard = PDFMargins(top: 25, right: 25, bottom: 20, left: 25)

    init(top: Double, right: Double, bottom: Double, left: Double) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    var cssDeclaration: String {
        "\(Self.format(top))mm \(Self.format(right))mm \(Self.format(bottom))mm \(Self.format(left))mm"
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.2f", value)
    }
}

struct PDFRenderError: Error, Equatable, Sendable, LocalizedError {
    enum Code: Equatable, Sendable {
        case timeout
        case webkitFailure
    }

    let code: Code
    let reason: String?

    static let timeout = PDFRenderError(code: .timeout, reason: nil)

    static func webkitFailure(reason: String) -> PDFRenderError {
        PDFRenderError(code: .webkitFailure, reason: reason)
    }

    var errorDescription: String? {
        switch code {
        case .timeout:
            return "Timeout esperando a WebKit durante la generación del PDF."
        case .webkitFailure:
            return reason ?? "WebKit no pudo generar el PDF."
        }
    }
}

actor ReportRenderer {
    private let baseURL: URL?
    private let timeout: TimeInterval

    init(baseURL: URL? = nil, timeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func render(
        html: String,
        pageSize: PDFPageSize = .a4Portrait,
        margins: PDFMargins = .standard
    ) async throws -> Data {
        try await Self.renderOnMain(
            html: html,
            pageSize: pageSize,
            margins: margins,
            baseURL: baseURL,
            timeout: timeout
        )
    }

    @MainActor
    private static func renderOnMain(
        html: String,
        pageSize: PDFPageSize,
        margins: PDFMargins,
        baseURL: URL?,
        timeout: TimeInterval
    ) async throws -> Data {
        let pagePoints = pageSize.sizeInPoints
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: pagePoints),
            configuration: configuration
        )

        let htmlWithOverrides = injectPrintOverrides(html, pageSize: pageSize, margins: margins)
        let navigationWaiter = WebViewNavigationWaiter(timeout: timeout)
        try await navigationWaiter.load(html: htmlWithOverrides, in: webView, baseURL: baseURL)
        webView.navigationDelegate = nil

        // Permite que scripts sincrónicos de la plantilla (TOC) y layout/fonts terminen antes de imprimir.
        try? await waitForDocumentReadiness(in: webView)

        let contentHeight = try await measuredContentHeight(in: webView, minimum: pagePoints.height)
        let pdfConfiguration = WKPDFConfiguration()
        pdfConfiguration.rect = CGRect(
            x: 0,
            y: 0,
            width: pagePoints.width,
            height: max(pagePoints.height, contentHeight)
        )

        return try await createPDF(from: webView, configuration: pdfConfiguration)
    }

    @MainActor
    private static func injectPrintOverrides(
        _ html: String,
        pageSize: PDFPageSize,
        margins: PDFMargins
    ) -> String {
        let override = """
        <style id="astromalik-render-overrides">
        :root {
          --page-margin-top: \(cssMillimeters(margins.top));
          --page-margin-right: \(cssMillimeters(margins.right));
          --page-margin-bottom: \(cssMillimeters(margins.bottom));
          --page-margin-left: \(cssMillimeters(margins.left));
        }
        @page { size: \(pageSize.cssPageSize); margin: \(margins.cssDeclaration); }
        </style>
        """

        if let range = html.range(of: "</head>", options: [.caseInsensitive, .backwards]) {
            var result = html
            result.insert(contentsOf: "\n\(override)\n", at: range.lowerBound)
            return result
        }
        return override + html
    }

    @MainActor
    private static func waitForDocumentReadiness(in webView: WKWebView) async throws {
        _ = try? await evaluateJavaScript(
            """
            new Promise((resolve) => {
              const finish = () => {
                if (document.fonts && document.fonts.ready) {
                  document.fonts.ready.then(() => resolve(true)).catch(() => resolve(true));
                } else {
                  resolve(true);
                }
              };
              if (document.readyState === 'complete') {
                window.requestAnimationFrame(() => window.requestAnimationFrame(finish));
              } else {
                window.addEventListener('load', () => window.requestAnimationFrame(finish), { once: true });
              }
            });
            """,
            in: webView
        )
    }

    @MainActor
    private static func measuredContentHeight(in webView: WKWebView, minimum: CGFloat) async throws -> CGFloat {
        let result = try await evaluateJavaScript(
            """
            Math.max(
              document.body ? document.body.scrollHeight : 0,
              document.body ? document.body.offsetHeight : 0,
              document.documentElement ? document.documentElement.clientHeight : 0,
              document.documentElement ? document.documentElement.scrollHeight : 0,
              document.documentElement ? document.documentElement.offsetHeight : 0
            );
            """,
            in: webView
        )

        if let number = result as? NSNumber {
            return max(minimum, CGFloat(truncating: number))
        }
        if let double = result as? Double {
            return max(minimum, CGFloat(double))
        }
        if let int = result as? Int {
            return max(minimum, CGFloat(int))
        }
        return minimum
    }

    @MainActor
    private static func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    continuation.resume(throwing: PDFRenderError.webkitFailure(reason: error.localizedDescription))
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }

    @MainActor
    private static func createPDF(from webView: WKWebView, configuration: WKPDFConfiguration) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: PDFRenderError.webkitFailure(reason: error.localizedDescription))
                }
            }
        }
    }

    private static func cssMillimeters(_ value: Double) -> String {
        if value.rounded() == value { return "\(Int(value))mm" }
        return String(format: "%.2fmm", value)
    }
}

private final class WebViewNavigationWaiter: NSObject, WKNavigationDelegate {
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Void, Error>?

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    @MainActor
    func load(html: String, in webView: WKWebView, baseURL: URL?) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(.failure(PDFRenderError.timeout))
            }
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(PDFRenderError.webkitFailure(reason: error.localizedDescription)))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(PDFRenderError.webkitFailure(reason: error.localizedDescription)))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        switch result {
        case .success:
            continuation.resume(returning: ())
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
