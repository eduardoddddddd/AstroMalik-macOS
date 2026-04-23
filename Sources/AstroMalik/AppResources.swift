import Foundation

enum AppResources {
    static let bundle: Bundle = {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AstroMalik_AstroMalik.bundle"),
            Bundle.main.bundleURL.appendingPathComponent("AstroMalik_AstroMalik.bundle"),
            Bundle.main.resourceURL?.appendingPathComponent("AstroMalik_AstroMalik.bundle"),
            Bundle.module.bundleURL,
        ].compactMap { $0 }

        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return Bundle.module
    }()
}
