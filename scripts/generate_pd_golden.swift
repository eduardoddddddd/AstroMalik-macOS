import Darwin
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = [
    "GENERATE_PD_GOLDEN=1",
    "swift",
    "test",
    "--filter",
    "PrimaryDirectionsGoldenBootstrapTests/testGeneratePrimaryDirectionsGoldenBaseline",
]
process.currentDirectoryURL = repoRoot
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
