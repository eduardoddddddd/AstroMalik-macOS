import Foundation

/// Hard-isolated data routing for the temporary, non-distributed F2a screenshot build.
/// The bundle identifier check prevents this from affecting any ordinary app build.
enum F2CaptureSandbox {
    static let bundleIdentifier = "com.astromalik.f2capture.edd8912"
    static let root = URL(fileURLWithPath: "/Users/eduardoariasbravo/.codex/worktrees/windows-f2a-real-screens/AstroMalik-macOS/docs/windows-f2a-reference/sandbox", isDirectory: true)
    static var isEnabled: Bool { Bundle.main.bundleIdentifier == bundleIdentifier }

    static var appSupportDirectory: URL {
        root.appendingPathComponent("Library/Application Support/AstroMalik", isDirectory: true)
    }

    static func userDatabaseURL() throws -> URL {
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        return appSupportDirectory.appendingPathComponent("user.db")
    }
}
