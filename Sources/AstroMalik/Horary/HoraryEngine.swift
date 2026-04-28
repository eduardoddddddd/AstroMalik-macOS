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

struct HoraryDiagnostics: Equatable {
    var pythonPath: String?
    var pythonVersion: String?
    var moduleSource: String?
    var modulePath: String?
    var checkedSources: [String]
    var lastError: String?

    var isReady: Bool {
        pythonPath != nil && modulePath != nil
    }
}

enum HoraryEngine {
    private static let envPythonPath = "ASTROMALIK_PYTHON_PATH"
    private static let envHorariaPath = "ASTROMALIK_HORARIA_PATH"
    private static let userDefaultsHorariaPath = "horariaModulePath"

    private static let pythonCandidates = [
        "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3",
    ]

    private static let timeoutNanoseconds: UInt64 = 10_000_000_000

    static func calculate(_ req: HoraryRequest) async throws -> HoraryResponse {
        if ProcessInfo.processInfo.environment["ASTROMALIK_HORARIA_ENGINE"] != "python" {
            do {
                return try HoraryNativeEngine.calculate(req)
            } catch {
                if ProcessInfo.processInfo.environment["ASTROMALIK_HORARIA_ENGINE"] == "swift" {
                    throw error
                }
            }
        }
        return try await calculateWithPython(req)
    }

    static func calculateWithPython(_ req: HoraryRequest) async throws -> HoraryResponse {
        let executable = try resolvePythonExecutable()
        let payload = try JSONEncoder().encode(req)
        var attemptedSources: [String] = []

        for moduleSource in moduleSources() + [nil] {
            attemptedSources.append(moduleSource?.label ?? "Python instalado")
            do {
                return try await runHorariaProcess(
                    executableURL: executable,
                    input: payload,
                    moduleSource: moduleSource
                )
            } catch let error as HoraryEngineError where error.isModuleUnavailable {
                continue
            }
        }

        throw HoraryEngineError.horariaUnavailable(attemptedSources)
    }

    static func diagnostics() async -> HoraryDiagnostics {
        let checked = moduleSources().map(\.label) + ["Python instalado"]
        guard let executable = try? resolvePythonExecutable() else {
            return HoraryDiagnostics(
                pythonPath: nil,
                pythonVersion: nil,
                moduleSource: nil,
                modulePath: nil,
                checkedSources: checked,
                lastError: HoraryEngineError.pythonNotFound.localizedDescription
            )
        }

        let versionResult = try? await runProcess(
            executableURL: executable,
            arguments: ["--version"],
            input: nil,
            moduleSource: nil
        )
        let version = [versionResult?.stdout, versionResult?.stderr]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        var lastError: String?
        let probe = """
        import horaria, inspect
        print(getattr(horaria, '__version__', 'version unknown'))
        print(inspect.getfile(horaria))
        """

        for source in moduleSources() + [nil] {
            do {
                let result = try await runProcess(
                    executableURL: executable,
                    arguments: ["-c", probe],
                    input: nil,
                    moduleSource: source
                )
                guard result.exitCode == 0 else {
                    lastError = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                let lines = result.stdout
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
                return HoraryDiagnostics(
                    pythonPath: executable.path,
                    pythonVersion: version,
                    moduleSource: source?.label ?? "Python instalado",
                    modulePath: lines.dropFirst().first ?? lines.first,
                    checkedSources: checked,
                    lastError: nil
                )
            } catch {
                lastError = error.localizedDescription
            }
        }

        return HoraryDiagnostics(
            pythonPath: executable.path,
            pythonVersion: version,
            moduleSource: nil,
            modulePath: nil,
            checkedSources: checked,
            lastError: lastError ?? HoraryEngineError.horariaUnavailable(checked).localizedDescription
        )
    }

    private static func resolvePythonExecutable() throws -> URL {
        let fileManager = FileManager.default
        let envPath = ProcessInfo.processInfo.environment[envPythonPath]
        let candidates = [envPath].compactMap { $0 } + pythonCandidates
        guard let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
            throw HoraryEngineError.pythonNotFound
        }
        return URL(fileURLWithPath: path)
    }

    private static func moduleSources() -> [HoraryModuleSource] {
        let fileManager = FileManager.default
        var sources: [HoraryModuleSource] = []

        if let bundled = AppResources.bundle.url(forResource: "horaria", withExtension: nil),
           fileManager.fileExists(atPath: bundled.path) {
            sources.append(HoraryModuleSource(label: "Bundle embebido", url: bundled))
        }

        if let env = ProcessInfo.processInfo.environment[envHorariaPath] {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            if fileManager.fileExists(atPath: url.path) {
                sources.append(HoraryModuleSource(label: "\(envHorariaPath)", url: url))
            }
        }

        if let stored = UserDefaults.standard.string(forKey: userDefaultsHorariaPath), !stored.isEmpty {
            let url = URL(fileURLWithPath: stored, isDirectory: true)
            if fileManager.fileExists(atPath: url.path) {
                sources.append(HoraryModuleSource(label: "Config local", url: url))
            }
        }

        var seen: Set<String> = []
        return sources.filter { source in
            let key = source.url.standardizedFileURL.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func runHorariaProcess(
        executableURL: URL,
        input: Data,
        moduleSource: HoraryModuleSource?
    ) async throws -> HoraryResponse {
        let result = try await runProcess(
            executableURL: executableURL,
            arguments: ["-m", "horaria.cli", "--json"],
            input: input,
            moduleSource: moduleSource
        )
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0 else {
            if stderr.contains("No module named 'horaria'") || stderr.contains("No module named horaria") {
                throw HoraryEngineError.horariaModuleUnavailable(moduleSource?.label ?? "Python instalado")
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

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        input: Data?,
        moduleSource: HoraryModuleSource?
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        if let moduleSource {
            var env = ProcessInfo.processInfo.environment
            let path = moduleSource.url.path
            env["PYTHONPATH"] = env["PYTHONPATH"].map { "\(path):\($0)" } ?? path
            process.environment = env
            process.currentDirectoryURL = moduleSource.url
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
            if let input {
                try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            }
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw HoraryEngineError.pythonLaunchFailed("No se pudo enviar datos a Horaria: \(error.localizedDescription)")
        }

        return try await waitForProcess(process, stdout: stdoutPipe, stderr: stderrPipe)
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

private struct HoraryModuleSource: Equatable {
    let label: String
    let url: URL
}

private struct ProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

enum HoraryEngineError: LocalizedError {
    case pythonNotFound
    case pythonLaunchFailed(String)
    case horariaModuleUnavailable(String)
    case horariaUnavailable([String])
    case processFailed(String)
    case emptyOutput
    case invalidOutput(String)
    case timeout

    var isModuleUnavailable: Bool {
        if case .horariaModuleUnavailable = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "No se encontró Python 3 en este Mac. Instala Python 3 o revisa las rutas configuradas para Horaria."
        case .pythonLaunchFailed(let detail):
            return "No se pudo arrancar el proceso de Horaria desde Python: \(detail)"
        case .horariaModuleUnavailable(let source):
            return "Horaria no se pudo importar desde \(source)."
        case .horariaUnavailable(let sources):
            return "Python 3 está disponible, pero el paquete Horaria no se pudo importar. Fuentes revisadas: \(sources.joined(separator: ", ")). Configura ASTROMALIK_HORARIA_PATH o instala el paquete horaria."
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
