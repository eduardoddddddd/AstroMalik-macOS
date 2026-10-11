import Foundation
#if os(Windows)
import WinSDK
#endif

/// Zona IANA del equipo. En macOS es `TimeZone.current`. En Windows,
/// Foundation devuelve `GMT`, así que se pregunta al ICU del sistema
/// (`icu.dll`, Windows 10 1903+): `ucal_getHostTimeZone` aplica la región del
/// usuario («Romance Standard Time» + ES → `Europe/Madrid`).
enum HostTimeZone {
    static let current: TimeZone = {
        #if os(Windows)
        if let identifier = windowsHostIdentifier(), let zone = TimeZone(identifier: identifier) {
            return zone
        }
        #endif
        return TimeZone.current
    }()

    #if os(Windows)
    private typealias HostZoneFunction = @convention(c) (UnsafeMutablePointer<UInt16>, Int32, UnsafeMutablePointer<Int32>) -> Int32

    private static func windowsHostIdentifier() -> String? {
        guard let icu = "icu.dll".withCString(encodedAs: UTF16.self, { LoadLibraryW($0) }),
              let symbol = GetProcAddress(icu, "ucal_getHostTimeZone") else { return nil }
        let function = unsafeBitCast(symbol, to: HostZoneFunction.self)
        var buffer = [UInt16](repeating: 0, count: 128)
        var status: Int32 = 0
        let length = function(&buffer, Int32(buffer.count), &status)
        guard status <= 0, length > 0, Int(length) < buffer.count else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
    }
    #endif
}
