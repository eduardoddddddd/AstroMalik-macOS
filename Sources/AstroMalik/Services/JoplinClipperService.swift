import Foundation

struct JoplinClipperSettings: Codable, Equatable {
    var host: String
    var port: Int
    var token: String
    var notebook: String

    static let `default` = JoplinClipperSettings(
        host: "127.0.0.1",
        port: 41184,
        token: "",
        notebook: "AstroMalik"
    )
}

protocol JoplinHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: JoplinHTTPClient {}

final class JoplinClipperService {
    private let settings: JoplinClipperSettings
    private let client: JoplinHTTPClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(settings: JoplinClipperSettings, client: JoplinHTTPClient = URLSession.shared) {
        self.settings = settings.resolvingDetectedToken()
        self.client = client
    }

    func createNote(title: String, body: String) async throws {
        let notebookID = try await findOrCreateNotebook()
        let payload = NotePayload(title: title, body: body, parentID: notebookID)
        _ = try await request(
            path: "/notes",
            method: "POST",
            body: payload,
            responseType: JoplinNote.self
        )
    }

    private func findOrCreateNotebook() async throws -> String {
        let desired = settings.notebook.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desired.isEmpty else { throw JoplinClipperError.invalidNotebook }

        var page = 1
        while true {
            let response = try await request(
                path: "/folders",
                method: "GET",
                page: page,
                body: EmptyPayload?.none,
                responseType: JoplinList<JoplinFolder>.self
            )
            if let folder = response.items.first(where: {
                $0.title.caseInsensitiveCompare(desired) == .orderedSame
            }) {
                return folder.id
            }
            guard response.hasMore else { break }
            page += 1
        }

        let created = try await request(
            path: "/folders",
            method: "POST",
            body: FolderPayload(title: desired),
            responseType: JoplinFolder.self
        )
        return created.id
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        page: Int? = nil,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        guard let url = makeURL(path: path, page: page) else {
            throw JoplinClipperError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AstroMalik/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        if Body.self != Optional<EmptyPayload>.self {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await client.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JoplinClipperError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw JoplinClipperError.httpStatus(http.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func makeURL(path: String, page: Int?) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = settings.host.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = settings.port
        components.path = path
        var query: [URLQueryItem] = []
        let token = settings.token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            query.append(URLQueryItem(name: "token", value: token))
        }
        if let page {
            query.append(URLQueryItem(name: "page", value: String(page)))
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url
    }
}

enum JoplinClipperError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case invalidNotebook
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de Joplin no es válida."
        case .invalidResponse:
            return "Joplin devolvió una respuesta no reconocida."
        case .invalidNotebook:
            return "Configura un cuaderno de Joplin válido."
        case .httpStatus(let status):
            if status == 403 {
                return "Joplin rechazó la petición (403). Revisa el token del Web Clipper en Ajustes."
            }
            return "Joplin respondió con estado HTTP \(status). Revisa puerto y token."
        }
    }
}

extension JoplinClipperSettings {
    func resolvingDetectedToken() -> JoplinClipperSettings {
        var copy = self
        if copy.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let detected = Self.detectedClipperToken() {
            copy.token = detected
        }
        return copy
    }

    static func detectedClipperToken() -> String? {
        if let token = ProcessInfo.processInfo.environment["ASTROMALIK_JOPLIN_TOKEN"],
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return token
        }

        let candidates = [
            "/opt/joplin-server-profile/settings.json",
            NSString(string: "~/.config/joplin-desktop/settings.json").expandingTildeInPath,
            NSString(string: "~/Library/Application Support/Joplin/settings.json").expandingTildeInPath,
        ]

        for path in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["api.token"] as? String,
                  !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }
            return token
        }
        return nil
    }
}

private struct EmptyPayload: Encodable {}

private struct JoplinList<Item: Decodable>: Decodable {
    let items: [Item]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
    }
}

private struct JoplinFolder: Decodable {
    let id: String
    let title: String
}

private struct JoplinNote: Decodable {
    let id: String
}

private struct FolderPayload: Encodable {
    let title: String
}

private struct NotePayload: Encodable {
    let title: String
    let body: String
    let parentID: String

    enum CodingKeys: String, CodingKey {
        case title
        case body
        case parentID = "parent_id"
    }
}
