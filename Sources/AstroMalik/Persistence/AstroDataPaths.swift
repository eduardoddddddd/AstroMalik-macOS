import Foundation

#if os(Windows)
enum AstroDataPaths {
    static func directory(create: Bool = true) throws -> URL {
        guard let root = ProcessInfo.processInfo.environment["LOCALAPPDATA"],
              !root.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Falta LOCALAPPDATA para localizar los datos de AstroMalik."])
        }
        let directory = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent("AstroMalik for Windows", isDirectory: true)
        if create { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        return directory
    }
    static func userDatabaseURL(createDirectory: Bool = true) throws -> URL {
        try directory(create: createDirectory).appendingPathComponent("user.db")
    }
}
#endif
