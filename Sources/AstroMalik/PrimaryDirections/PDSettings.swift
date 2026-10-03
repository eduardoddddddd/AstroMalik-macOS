import Foundation

// MARK: - PDSettings

/// Configuración de cálculo persistida en UserDefaults.
struct PDSettings: Equatable, Sendable {
    var method: PrimaryDirectionMethod = .regiomontanus
    var key: PrimaryDirectionKey = .naibod
    var maxYears: Double = 90
    var aspectPlane: PDAspectPlane = .zodiacal
    var filterPreset: PDFilterPreset? = .classical

    private static let keyUD = "PrimaryDirections.Key"
    private static let methodUD = "PrimaryDirections.Method"
    private static let maxYearsUD = "PrimaryDirections.MaxYears"
    private static let planeUD = "PrimaryDirections.AspectPlane"
    private static let planeVersionUD = "PrimaryDirections.AspectPlane.Version"
    private static let filterPresetUD = "PrimaryDirections.FilterPreset"
    private static let customPresetValue = "Personalizado"

    static func load() -> PDSettings {
        var s = PDSettings()
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: keyUD), let k = PrimaryDirectionKey(rawValue: raw) {
            s.key = k
        }
        if let raw = ud.string(forKey: methodUD), let m = PrimaryDirectionMethod(rawValue: raw) {
            s.method = m
        }
        if ud.integer(forKey: planeVersionUD) < 2 {
            s.aspectPlane = .zodiacal
            ud.set(PDAspectPlane.zodiacal.rawValue, forKey: planeUD)
            ud.set(2, forKey: planeVersionUD)
        } else if let raw = ud.string(forKey: planeUD), let p = PDAspectPlane(rawValue: raw) {
            s.aspectPlane = p
        }
        let years = ud.double(forKey: maxYearsUD)
        if years > 0 { s.maxYears = years }
        if ud.object(forKey: filterPresetUD) == nil {
            s.filterPreset = .classical
        } else if let raw = ud.string(forKey: filterPresetUD) {
            s.filterPreset = raw == customPresetValue ? nil : PDFilterPreset(rawValue: raw)
        }
        return s
    }

    func persist() {
        let ud = UserDefaults.standard
        ud.set(key.rawValue, forKey: Self.keyUD)
        ud.set(method.rawValue, forKey: Self.methodUD)
        ud.set(aspectPlane.rawValue, forKey: Self.planeUD)
        ud.set(2, forKey: Self.planeVersionUD)
        ud.set(maxYears, forKey: Self.maxYearsUD)
        ud.set(filterPreset?.rawValue ?? Self.customPresetValue, forKey: Self.filterPresetUD)
    }

    var calculatorConfig: PrimaryDirectionCalculator.Config {
        let preset = filterPreset
        return PrimaryDirectionCalculator.Config(
            method: method,
            key: key,
            maxYears: maxYears,
            aspects: preset?.orderedAspects ?? PDaspect.allCases,
            promissors: preset?.orderedPromissors ?? [],
            significators: preset?.orderedSignificators ?? [],
            aspectPlane: aspectPlane
        )
    }
}
