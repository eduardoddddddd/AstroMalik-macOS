import Foundation

protocol PrimaryDirectionLLMClient: Sendable {
    func complete(
        direction: PrimaryDirection,
        context: PDInterpretationContext,
        systemPrompt: String,
        userPrompt: String,
        promptVersion: String
    ) async throws -> String
}

actor PrimaryDirectionFoundryClient: PrimaryDirectionLLMClient {
    private static let envPythonPath = "ASTROMALIK_FOUNDRY_PYTHON"
    private static let envScriptPath = "ASTROMALIK_FOUNDRY_PD_SCRIPT"
    private static let envModel = "ASTROMALIK_FOUNDRY_MODEL"
    private static let defaultPythonPath = "/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python"
    private static let defaultScriptPath = "/Users/eduardoariasbravo/Developer/AstroMalik-macOS/scripts/foundry_primary_direction_once.py"
    private static let defaultTimeoutNanoseconds: UInt64 = 180_000_000_000

    nonisolated static var configuredModel: String {
        ProcessInfo.processInfo.environment[envModel] ?? "qwen2.5-7b"
    }

    private let pythonURL: URL
    private let scriptURL: URL
    private let model: String
    private let timeoutNanoseconds: UInt64
    private let encoder: JSONEncoder

    init(
        pythonPath: String = PrimaryDirectionFoundryClient.defaultPythonPath,
        scriptPath: String = PrimaryDirectionFoundryClient.defaultScriptPath,
        model: String = PrimaryDirectionFoundryClient.configuredModel,
        timeoutNanoseconds: UInt64 = PrimaryDirectionFoundryClient.defaultTimeoutNanoseconds
    ) {
        let env = ProcessInfo.processInfo.environment
        self.pythonURL = URL(fileURLWithPath: env[Self.envPythonPath] ?? pythonPath)
        self.scriptURL = URL(fileURLWithPath: env[Self.envScriptPath] ?? scriptPath)
        self.model = model
        self.timeoutNanoseconds = timeoutNanoseconds
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    func complete(
        direction: PrimaryDirection,
        context: PDInterpretationContext,
        systemPrompt: String,
        userPrompt: String,
        promptVersion: String
    ) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            throw PrimaryDirectionFoundryError.pythonNotFound(pythonURL.path)
        }
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw PrimaryDirectionFoundryError.scriptNotFound(scriptURL.path)
        }

        let payload = PrimaryDirectionFoundryPayload(
            schemaVersion: "primary-direction-foundry-v1",
            model: model,
            promptVersion: promptVersion,
            direction: direction,
            context: context,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
        let result = try await runProcess(
            executableURL: pythonURL,
            arguments: [scriptURL.path],
            input: try encoder.encode(payload)
        )
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard result.exitCode == 0 else {
            throw PrimaryDirectionFoundryError.processFailed(
                stderr.isEmpty ? "Foundry termino con codigo \(result.exitCode)." : stderr
            )
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stdout.isEmpty else {
            throw PrimaryDirectionFoundryError.emptyOutput(stderr)
        }
        return try Self.decodeCompletionOutput(stdout)
    }

    static func decodeCompletionOutput(_ stdout: String) throws -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PrimaryDirectionFoundryError.emptyOutput("")
        }

        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let json = extractJSONObject(from: trimmed) {
            return json
        }

        throw PrimaryDirectionFoundryError.invalidOutput("No se encontro un objeto JSON valido en la salida de Foundry.")
    }

    private static func extractJSONObject(from text: String) -> String? {
        var startIndex: String.Index?
        var depth = 0
        var inString = false
        var isEscaped = false

        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
                index = text.index(after: index)
                continue
            }

            if char == "\"" {
                inString = true
            } else if char == "{" {
                if depth == 0 { startIndex = index }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0, let startIndex {
                    return String(text[startIndex...index])
                }
            }

            index = text.index(after: index)
        }
        return nil
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        input: Data
    ) async throws -> PrimaryDirectionFoundryProcessResult {
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
            throw PrimaryDirectionFoundryError.pythonLaunchFailed(error.localizedDescription)
        }

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: input)
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw PrimaryDirectionFoundryError.pythonLaunchFailed("No se pudo enviar JSON a Foundry: \(error.localizedDescription)")
        }

        return try await waitForProcess(process, stdout: stdoutPipe, stderr: stderrPipe)
    }

    private func waitForProcess(
        _ process: Process,
        stdout: Pipe,
        stderr: Pipe
    ) async throws -> PrimaryDirectionFoundryProcessResult {
        let timeoutNanoseconds = self.timeoutNanoseconds
        return try await withThrowingTaskGroup(of: PrimaryDirectionFoundryProcessResult.self) { group in
            group.addTask {
                process.waitUntilExit()
                let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                return PrimaryDirectionFoundryProcessResult(
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
                throw PrimaryDirectionFoundryError.timeout
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw PrimaryDirectionFoundryError.invalidOutput("Foundry no devolvio resultado.")
            }
            return result
        }
    }
}

private struct PrimaryDirectionFoundryPayload: Encodable {
    let schemaVersion: String
    let model: String
    let promptVersion: String
    let direction: PrimaryDirection
    let context: PDInterpretationContext
    let systemPrompt: String
    let userPrompt: String
}

private struct PrimaryDirectionFoundryProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

enum PrimaryDirectionFoundryError: LocalizedError, Equatable {
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
            return "No se encontro el puente Foundry de Direcciones en \(path). Configura ASTROMALIK_FOUNDRY_PD_SCRIPT."
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
