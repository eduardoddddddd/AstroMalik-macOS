import Foundation
import CSwissEph

// MARK: - Regiomontanus Speculum

/// Espéculo Regiomontano: calcula ZD, polo, Q, y W para un cuerpo.
/// Port directo del algoritmo de Morinus (regiospec.py), verificado línea a línea.
/// Todas las coordenadas en grados decimales.
struct RegiomontanusSpeculum {

    // MARK: - Speculum fields

    /// Longitud eclíptica (°)
    let longitude: Double

    /// Latitud eclíptica (°)
    let latitude: Double

    /// Ascensión recta (°eq)
    let ra: Double

    /// Declinación (°)
    let declination: Double

    /// Distancia meridiana (°eq), negativa si inferior
    let meridianDistance: Double

    /// Distancia cenital (°)
    let zenithDistance: Double

    /// Polo de Regiomontanus (°)
    let pole: Double

    /// Diferencia ascensional bajo el polo (°)
    let q: Double

    /// W = posición en el ecuador bajo el polo (°eq)
    let w: Double

    /// true si está en hemisferio este (cuadrantes I o IV)
    let eastern: Bool

    /// true si está por encima del horizonte
    let aboveHorizon: Bool

    /// true si la distancia meridiana es upper (MC side)
    let isUpperMD: Bool

    // MARK: - Initializer

    /// Calcula el espéculo Regiomontano para un cuerpo celeste.
    /// - Parameters:
    ///   - placelat: Latitud geográfica (°, +N/-S)
    ///   - ramc: Ascensión recta del Medium Coeli (°eq)
    ///   - lon: Longitud eclíptica del cuerpo (°)
    ///   - lat: Latitud eclíptica del cuerpo (°)
    ///   - ra: Ascensión recta del cuerpo (°eq)
    ///   - decl: Declinación del cuerpo (°)
    init(placelat: Double, ramc: Double, lon: Double, lat: Double, ra: Double, decl: Double) {
        self.longitude = lon
        self.latitude = lat
        self.ra = ra
        self.declination = decl

        let raic = Self.normalize(ramc + 180.0)

        // --- Eastern/Western ---
        // Eastern = ascending = quadrants I,IV (east of meridian)
        var isEastern = true
        if ramc > raic {
            if ra > raic && ra < ramc { isEastern = false }
        } else {
            if (ra > raic && ra < 360.0) || (ra < ramc && ra > 0.0) { isEastern = false }
        }
        self.eastern = isEastern

        // --- Meridian Distance ---
        var med = abs(ramc - ra)
        if med > 180 { med = 360 - med }

        var icd = abs(raic - ra)
        if icd > 180 { icd = 360 - icd }

        var md: Double
        var umd: Bool
        if icd < med {
            md = icd
            umd = false
        } else {
            md = med
            umd = true
        }
        self.isUpperMD = umd

        // --- Ascensional Difference for above/below horizon check ---
        let adlatVal = tan(decl * .pi / 180) * tan(placelat * .pi / 180)
        let adlat: Double
        if abs(adlatVal) <= 1.0 {
            adlat = asin(adlatVal) * 180 / .pi
        } else {
            adlat = 0
        }

        let dsa = 90.0 + adlat
        let isAbove = (med <= dsa)
        self.aboveHorizon = isAbove

        // Meridian distance with sign for table
        let tableMD: Double
        if umd {
            tableMD = md
        } else {
            tableMD = -md
        }
        self.meridianDistance = tableMD

        // --- Zenith Distance (Regiomontan formula) ---
        var zd = Self.calcZD(md: md, placelat: placelat, decl: decl, umd: umd)
        if zd > 90 { zd = 180 - zd }
        let tmpZD = zd

        // Sign correction per Morinus (Roberto fix v7.0.1)
        if isAbove && md < 0 {
            zd = -zd
        }
        if !isAbove && md > 0 {
            zd = -zd
        }
        self.zenithDistance = zd

        // --- Pole ---
        let poleVal = sin(placelat * .pi / 180) * sin(tmpZD * .pi / 180)
        if abs(poleVal) <= 1.0 {
            self.pole = asin(poleVal) * 180 / .pi
        } else {
            self.pole = 0
        }

        // --- Q (ascensional difference under the pole) ---
        let qVal = tan(decl * .pi / 180) * tan(self.pole * .pi / 180)
        if abs(qVal) <= 1.0 {
            self.q = asin(qVal) * 180 / .pi
        } else {
            self.q = 0
        }

        // --- W (oblique ascension under the pole) ---
        var ww: Double
        if isEastern {
            ww = ra - self.q
        } else {
            ww = ra + self.q
        }
        self.w = Self.normalize(ww)
    }

    // MARK: - Static ZD Calculation

    /// Calcula la distancia cenital de Regiomontanus.
    /// Transcripción exacta de regiospec.py → getZD().
    /// - Parameters:
    ///   - md: Distancia meridiana (°, siempre positiva)
    ///   - placelat: Latitud geográfica (°)
    ///   - decl: Declinación (°)
    ///   - umd: true si es upper meridian distance (MC side)
    static func calcZD(md: Double, placelat: Double, decl: Double, umd: Bool) -> Double {
        if md == 90.0 {
            let zd = 90.0 - atan(sin(abs(placelat * .pi / 180))) * tan(decl * .pi / 180) * 180 / .pi
            return zd
        } else if md < 90.0 {
            let A = atan(cos(placelat * .pi / 180) * tan(md * .pi / 180)) * 180 / .pi
            let B = atan(tan(abs(placelat * .pi / 180)) * cos(md * .pi / 180)) * 180 / .pi

            let C: Double
            if (decl < 0 && placelat < 0) || (decl >= 0 && placelat >= 0) {
                C = umd ? (B - abs(decl)) : (B + abs(decl))
            } else {
                C = umd ? (B + abs(decl)) : (B - abs(decl))
            }

            let F = atan(sin(abs(placelat * .pi / 180)) * sin(md * .pi / 180) * tan(C * .pi / 180)) * 180 / .pi
            return A + F
        }
        return 0.0
    }

    // MARK: - Normalize

    static func normalize(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }
}
