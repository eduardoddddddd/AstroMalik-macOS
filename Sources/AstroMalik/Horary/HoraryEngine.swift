import Foundation

struct HoraryRequest: Codable, Equatable {
    let question: String
    let datetimeLocal: String
    let timezone: String
    let latitude: Double
    let longitude: Double
    let placeName: String
    let questionHouse: Int
    let includeFortune: Bool
}

struct HoraryResponse: Codable, Equatable {
    let chartJSON: String
    let judgementJSON: String
    let judgementText: String
    let calculatedAt: String
}

enum HoraryEngine {
    private static let pythonCandidates = [
        "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3",
    ]

    static let fallbackRepoPath = "/Users/eduardoariasbravo/Developer/horaria"
    private static let timeoutNanoseconds: UInt64 = 10_000_000_000

    static func calculate(_ req: HoraryRequest) async throws -> HoraryResponse {
        let executable = try resolvePythonExecutable()
        let payload = try JSONEncoder().encode(req)

        do {
            return try await runHorariaProcess(
                executableURL: executable,
                input: payload,
                useFallbackRepo: false
            )
        } catch let error as HoraryEngineError where error.shouldRetryWithFallback {
            return try await runHorariaProcess(
                executableURL: executable,
                input: payload,
                useFallbackRepo: true
            )
        }
    }

    private static func resolvePythonExecutable() throws -> URL {
        let fileManager = FileManager.default
        guard let path = pythonCandidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
            throw HoraryEngineError.pythonNotFound
        }
        return URL(fileURLWithPath: path)
    }

    private static func runHorariaProcess(
        executableURL: URL,
        input: Data,
        useFallbackRepo: Bool
    ) async throws -> HoraryResponse {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["-m", "horaria.cli", "--json"]

        if useFallbackRepo {
            var env = ProcessInfo.processInfo.environment
            let existingPythonPath = env["PYTHONPATH"].map { "\($0):\(fallbackRepoPath)" } ?? fallbackRepoPath
            env["PYTHONPATH"] = existingPythonPath
            process.environment = env
            process.currentDirectoryURL = URL(fileURLWithPath: fallbackRepoPath, isDirectory: true)
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw HoraryEngineError.pythonLaunchFailed(error.localizedDescription)
        }

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw HoraryEngineError.pythonLaunchFailed("No se pudo enviar el request a Horaria: \(error.localizedDescription)")
        }

        let result = try await waitForProcess(process, stdout: stdoutPipe, stderr: stderrPipe)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0 else {
            if stderr.contains("No module named 'horaria'") || stderr.contains("No module named horaria") {
                if useFallbackRepo {
                    throw HoraryEngineError.horariaUnavailableAfterFallback
                }
                throw HoraryEngineError.horariaUnavailable
            }
            throw HoraryEngineError.processFailed(stderr.isEmpty ? "Horaria terminó con código \(result.exitCode)." : stderr)
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stdout.isEmpty else {
            throw HoraryEngineError.emptyOutput
        }

        guard let data = stdout.data(using: .utf8) else {
            throw HoraryEngineError.invalidOutput("La salida de Horaria no estaba en UTF-8.")
        }

        do {
            return try JSONDecoder().decode(HoraryResponse.self, from: data)
        } catch {
            throw HoraryEngineError.invalidOutput(error.localizedDescription)
        }
    }

    private static func waitForProcess(
        _ process: Process,
        stdout: Pipe,
        stderr: Pipe
    ) async throws -> ProcessResult {
        try await withThrowingTaskGroup(of: ProcessResult.self) { group in
            group.addTask {
                process.waitUntilExit()
                let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                return ProcessResult(
                    exitCode: Int(process.terminationStatus),
                    stdout: String(decoding: stdoutData, as: UTF8.self),
                    stderr: String(decoding: stderrData, as: UTF8.self)
                )
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                if process.isRunning {
                    process.terminate()
                }
                throw HoraryEngineError.timeout
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw HoraryEngineError.invalidOutput("Horaria no devolvió resultado.")
            }
            return result
        }
    }
}

private struct ProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

enum HoraryEngineError: LocalizedError {
    case pythonNotFound
    case pythonLaunchFailed(String)
    case horariaUnavailable
    case horariaUnavailableAfterFallback
    case processFailed(String)
    case emptyOutput
    case invalidOutput(String)
    case timeout

    var shouldRetryWithFallback: Bool {
        if case .horariaUnavailable = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "No se encontró Python 3 en este Mac. Instala Python 3 o revisa las rutas configuradas para Horaria."
        case .pythonLaunchFailed(let detail):
            return "No se pudo arrancar el proceso de Horaria desde Python: \(detail)"
        case .horariaUnavailable:
            return "Python 3 está disponible, pero el paquete Horaria no se pudo importar. Se intentará el fallback al repo local."
        case .horariaUnavailableAfterFallback:
            return "Python 3 está disponible, pero Horaria no se pudo cargar ni desde la instalación local ni desde /Users/eduardoariasbravo/Developer/horaria."
        case .processFailed(let detail):
            return "Horaria devolvió un error al calcular la consulta: \(detail)"
        case .emptyOutput:
            return "Horaria no devolvió ningún resultado."
        case .invalidOutput(let detail):
            return "Horaria respondió, pero el JSON de salida no era válido: \(detail)"
        case .timeout:
            return "Horaria tardó demasiado en responder. Reinténtalo; si persiste, revisa la instalación de Python y del paquete horaria."
        }
    }
}
