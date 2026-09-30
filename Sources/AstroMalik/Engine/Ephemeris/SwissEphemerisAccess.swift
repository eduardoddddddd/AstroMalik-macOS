import Foundation
import CSwissEph

/// One process-wide boundary for the vendored library (TLS is disabled on Apple).
/// Pointer lifetimes and return codes are unchanged. No suspension/network/UI work
/// may occur inside a transaction. Reentrant so an atomic multi-call snapshot can
/// use the same facade as individual legacy calls without deadlocking.
enum SwissEphemerisAccess {
    private static let lock = NSRecursiveLock()

    static func transaction<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    static func swe_set_ephe_path(_ path: UnsafePointer<CChar>?) {
        transaction { CSwissEph.swe_set_ephe_path(path) }
    }

    static func swe_version(_ version: UnsafeMutablePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
        transaction { CSwissEph.swe_version(version) }
    }

    @discardableResult
    static func swe_calc_ut(_ jd: Double, _ body: Int32, _ flags: Int32,
                            _ values: UnsafeMutablePointer<Double>?, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_calc_ut(jd, body, flags, values, error) }
    }

    static func swe_julday(_ year: Int32, _ month: Int32, _ day: Int32, _ hour: Double, _ calendar: Int32) -> Double {
        transaction { CSwissEph.swe_julday(year, month, day, hour, calendar) }
    }

    static func swe_sidtime(_ jd: Double) -> Double {
        transaction { CSwissEph.swe_sidtime(jd) }
    }

    static func swe_sidtime0(_ jd: Double, _ obliquity: Double, _ nutation: Double) -> Double {
        transaction { CSwissEph.swe_sidtime0(jd, obliquity, nutation) }
    }

    static func swe_cotrans(_ input: UnsafeMutablePointer<Double>?, _ output: UnsafeMutablePointer<Double>?, _ obliquity: Double) {
        transaction { CSwissEph.swe_cotrans(input, output, obliquity) }
    }

    static func swe_houses_ex2(_ jd: Double, _ flags: Int32, _ latitude: Double, _ longitude: Double, _ system: Int32,
                               _ cusps: UnsafeMutablePointer<Double>?, _ angles: UnsafeMutablePointer<Double>?,
                               _ cuspSpeeds: UnsafeMutablePointer<Double>?, _ angleSpeeds: UnsafeMutablePointer<Double>?,
                               _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_houses_ex2(jd, flags, latitude, longitude, system, cusps, angles, cuspSpeeds, angleSpeeds, error) }
    }

    static func swe_houses_armc_ex2(_ armc: Double, _ latitude: Double, _ obliquity: Double, _ system: Int32,
                                    _ cusps: UnsafeMutablePointer<Double>?, _ angles: UnsafeMutablePointer<Double>?,
                                    _ cuspSpeeds: UnsafeMutablePointer<Double>?, _ angleSpeeds: UnsafeMutablePointer<Double>?,
                                    _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_houses_armc_ex2(armc, latitude, obliquity, system, cusps, angles, cuspSpeeds, angleSpeeds, error) }
    }

    static func swe_solcross_ut(_ longitude: Double, _ jd: Double, _ flags: Int32, _ error: UnsafeMutablePointer<CChar>?) -> Double {
        transaction { CSwissEph.swe_solcross_ut(longitude, jd, flags, error) }
    }

    static func swe_mooncross_ut(_ longitude: Double, _ jd: Double, _ flags: Int32, _ error: UnsafeMutablePointer<CChar>?) -> Double {
        transaction { CSwissEph.swe_mooncross_ut(longitude, jd, flags, error) }
    }

    static func swe_sol_eclipse_when_glob(_ jd: Double, _ flags: Int32, _ types: Int32,
                                         _ times: UnsafeMutablePointer<Double>?, _ backward: Int32, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_sol_eclipse_when_glob(jd, flags, types, times, backward, error) }
    }

    static func swe_lun_eclipse_when(_ jd: Double, _ flags: Int32, _ types: Int32,
                                    _ times: UnsafeMutablePointer<Double>?, _ backward: Int32, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_lun_eclipse_when(jd, flags, types, times, backward, error) }
    }

    static func swe_sol_eclipse_how(_ jd: Double, _ flags: Int32, _ place: UnsafeMutablePointer<Double>?,
                                   _ attributes: UnsafeMutablePointer<Double>?, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_sol_eclipse_how(jd, flags, place, attributes, error) }
    }

    static func swe_lun_eclipse_how(_ jd: Double, _ flags: Int32, _ place: UnsafeMutablePointer<Double>?,
                                   _ attributes: UnsafeMutablePointer<Double>?, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_lun_eclipse_how(jd, flags, place, attributes, error) }
    }

    static func swe_rise_trans(_ jd: Double, _ body: Int32, _ star: UnsafeMutablePointer<CChar>?, _ flags: Int32, _ mode: Int32,
                               _ place: UnsafeMutablePointer<Double>?, _ pressure: Double, _ temperature: Double,
                               _ times: UnsafeMutablePointer<Double>?, _ error: UnsafeMutablePointer<CChar>?) -> Int32 {
        transaction { CSwissEph.swe_rise_trans(jd, body, star, flags, mode, place, pressure, temperature, times, error) }
    }
}
