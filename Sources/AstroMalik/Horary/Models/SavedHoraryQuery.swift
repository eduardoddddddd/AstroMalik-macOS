import Foundation

struct SavedHoraryQuery: Identifiable, Codable, Equatable {
    let id: UUID
    let request: HoraryRequest
    let response: HoraryResponse
    let chart: HoraryChart
    let judgement: HoraryJudgement
    let createdAt: Date

    init(
        id: UUID = UUID(),
        request: HoraryRequest,
        response: HoraryResponse,
        createdAt: Date = Date()
    ) throws {
        self.id = id
        self.request = request
        self.response = response
        self.chart = try SavedHoraryQuery.decode(HoraryChart.self, from: response.chartJSON, label: "chartJSON")
        self.judgement = try SavedHoraryQuery.decode(HoraryJudgement.self, from: response.judgementJSON, label: "judgementJSON")
        self.createdAt = createdAt
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String, label: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw HoraryDecodingError.invalidUTF8(label)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HoraryDecodingError.invalidJSON(label, error.localizedDescription)
        }
    }
}

enum HoraryDecodingError: LocalizedError {
    case invalidUTF8(String)
    case invalidJSON(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8(let label):
            return "La respuesta de Horaria en \(label) no estaba en UTF-8."
        case .invalidJSON(let label, let detail):
            return "La respuesta de Horaria en \(label) no tenía un JSON válido: \(detail)"
        }
    }
}
