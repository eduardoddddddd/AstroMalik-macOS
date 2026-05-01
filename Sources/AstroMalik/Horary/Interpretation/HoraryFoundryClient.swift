import Foundation

struct HoraryAIInterpretation: Codable, Equatable, Sendable {
    let schemaVersion: String
    let model: String
    let answer: String
    let confidence: String
    let title: String
    let summary: String
    let interpretation: String
    let technicalReading: [String]
    let cautions: [String]
    let generatedAt: String
    let rawModelOutput: String?
}

actor HoraryFoundryClient {
    private static let envPythonPath = "ASTROMALIK_FOUNDRY_PYTHON"
    private static let envScriptPath = "ASTROMALIK_FOUNDRY_HORARY_SCRIPT"
    private static let envModel = "ASTROMALIK_FOUNDRY_MODEL"
    private static let defaultPythonPath = "/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python"
    private static let defaultScriptPath = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/scripts/foundry_horary_once.py"
    private static let timeoutNanoseconds: UInt64 = 180_000_000_000

    private let pythonURL: URL
    private let scriptURL: URL
    private let model: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        pythonPath: String = HoraryFoundryClient.defaultPythonPath,
        scriptPath: String = HoraryFoundryClient.defaultScriptPath,
        model: String = ProcessInfo.processInfo.environment[HoraryFoundryClient.envModel] ?? "qwen2.5-7b"
    ) {
        let env = ProcessInfo.processInfo.environment
        self.pythonURL = URL(fileURLWithPath: env[Self.envPythonPath] ?? pythonPath)
        self.scriptURL = URL(fileURLWithPath: env[Self.envScriptPath] ?? scriptPath)
        self.model = model
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
    }

    func interpret(query: SavedHoraryQuery) async throws -> HoraryAIInterpretation {
        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            throw HoraryFoundryError.pythonNotFound(pythonURL.path)
        }
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw HoraryFoundryError.scriptNotFound(scriptURL.path)
        }

        let payload = HoraryFoundryPayload(
            schemaVersion: "horary-foundry-v1",
            model: model,
            queryId: query.id,
            request: query.request,
            chart: query.chart,
            judgement: query.judgement,
            judgementText: query.response.judgementText
        )
        let input = try encoder.encode(payload)
        let result = try await runProcess(
            executableURL: pythonURL,
            arguments: [scriptURL.path],
            input: input
        )
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0 else {
            throw HoraryFoundryError.processFailed(stderr.isEmpty ? "Foundry termino con codigo \(result.exitCode)." : stderr)
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stdout.isEmpty else {
            throw HoraryFoundryError.emptyOutput(stderr)
        }
        return try Self.decodeInterpretationOutput(stdout, decoder: decoder)
    }

    static func decodeInterpretationOutput(
        _ stdout: String,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> HoraryAIInterpretation {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HoraryFoundryError.emptyOutput("")
        }

        if let data = trimmed.data(using: .utf8),
           let interpretation = try? decoder.decode(HoraryAIInterpretation.self, from: data) {
            return interpretation
        }

        for line in trimmed.components(separatedBy: .newlines).reversed() {
            let candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.hasPrefix("{"), candidate.hasSuffix("}"),
                  let data = candidate.data(using: .utf8)
            else { continue }
            if let interpretation = try? decoder.decode(HoraryAIInterpretation.self, from: data) {
                return interpretation
            }
        }

        throw HoraryFoundryError.invalidOutput("No se encontro un objeto JSON valido en la salida de Foundry.")
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        input: Data
    ) async throws -> FoundryProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

        var env = ProcessInfo.processInfo.environment
        env[Self.envModel] = model
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw HoraryFoundryError.pythonLaunchFailed(error.localizedDescription)
        }

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw HoraryFoundryError.pythonLaunchFailed("No se pudo enviar JSON a Foundry: \(error.localizedDescription)")
        }

        return try await waitForProcess(process, stdout: stdoutPipe, stderr: stderrPipe)
    }

    private func waitForProcess(
        _ process: Process,
        stdout: Pipe,
        stderr: Pipe
    ) async throws -> FoundryProcessResult {
        try await withThrowingTaskGroup(of: FoundryProcessResult.self) { group in
            group.addTask {
                process.waitUntilExit()
                let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                return FoundryProcessResult(
                    exitCode: Int(process.terminationStatus),
                    stdout: String(decoding: stdoutData, as: UTF8.self),
                    stderr: String(decoding: stderrData, as: UTF8.self)
                )
            }

            group.addTask {
                try await Task.sleep(nanoseconds: Self.timeoutNanoseconds)
                if process.isRunning {
                    process.terminate()
                }
                throw HoraryFoundryError.timeout
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw HoraryFoundryError.invalidOutput("Foundry no devolvio resultado.")
            }
            return result
        }
    }
}

private struct HoraryFoundryPayload: Encodable {
    let schemaVersion: String
    let model: String
    let queryId: UUID
    let request: HoraryRequest
    let chart: HoraryChart
    let judgement: HoraryJudgement
    let judgementText: String
}

private struct FoundryProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

enum HoraryFoundryError: LocalizedError, Equatable {
    case pythonNotFound(String)
    case scriptNotFound(String)
    case pythonLaunchFailed(String)
    case processFailed(String)
    case emptyOutput(String)
    case invalidOutput(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "No se encontro el Python de Foundry Local en \(path). Configura ASTROMALIK_FOUNDRY_PYTHON."
        case .scriptNotFound(let path):
            return "No se encontro el puente Foundry de Horaria en \(path). Configura ASTROMALIK_FOUNDRY_HORARY_SCRIPT."
        case .pythonLaunchFailed(let detail):
            return "No se pudo arrancar Foundry Local desde Python: \(detail)"
        case .processFailed(let detail):
            return "Foundry Local devolvio un error: \(detail)"
        case .emptyOutput(let stderr):
            return stderr.isEmpty ? "Foundry Local no devolvio ningun resultado." : "Foundry Local no devolvio resultado: \(stderr)"
        case .invalidOutput(let detail):
            return "Foundry Local respondio, pero el JSON no era valido: \(detail)"
        case .timeout:
            return "Foundry Local tardo demasiado en responder. El primer arranque del modelo puede ser lento; reintentarlo suele bastar."
        }
    }
}
