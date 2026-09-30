import Foundation
import Combine
import CryptoKit

struct AstroChartInput: Equatable, Sendable {
    let id: UUID
    let date: String
    let time: String
    let timezone: String

    init(_ chart: NatalChart) {
        id = chart.id; date = chart.birthDate; time = chart.birthTime; timezone = chart.timezone
    }
    func request() throws -> AstrocartographyRequest {
        let jd = try julianDayFromLocal(birthDate: date, birthTime: time, timezoneName: timezone).jd
        return try AstrocartographyRequest(instant: AstroNatalInstant(julianDay: jd),
                                           geometryToleranceKm: AstroMercatorGeometry.coreBudgetKm)
    }
}

struct AstroMapPresentation: Equatable, Sendable {
    let result: AstrocartographyResult
    let lines: [AstroVisualLine]
    let revision: String
}

@MainActor
final class AstrocartographyViewModel: ObservableObject {
    enum State: Equatable {
        case empty, working, ready, cancelled, failed(String)
    }
    typealias ServiceFactory = @Sendable () async throws -> AstrocartographyCalculationService
    @Published private(set) var state: State = .empty
    @Published private(set) var presentation: AstroMapPresentation?
    @Published var selectedLine: AstroLineID?
    @Published var selectedPlace: GeoCoordinate?
    @Published var bodies = Set(AstroBody.allCases)
    @Published var angles = Set(AstroAngle.allCases)
    private let factory: ServiceFactory
    private var service: AstrocartographyCalculationService?
    private var generation = UUID()
    private var activeWork: Task<AstroMapPresentation, Error>?

    init(factory: @escaping ServiceFactory = { try await AstrocartographyViewModel.makeService() }) {
        self.factory = factory
    }

    var visibleLines: [AstroVisualLine] {
        presentation?.lines.filter { bodies.contains($0.id.body) && angles.contains($0.id.angle) } ?? []
    }

    func reconcileSelection() {
        if let selectedLine, !visibleLines.contains(where: { $0.id == selectedLine }) { self.selectedLine = nil }
    }

    /// SwiftUI's task lifetime cancels the caller; token checks also prevent
    /// an obsolete factory/preparation completion from publishing over a new chart.
    func load(_ input: AstroChartInput?) async {
        activeWork?.cancel(); activeWork = nil
        let token = UUID(); generation = token
        presentation = nil; selectedLine = nil; selectedPlace = nil
        guard let input else {
            state = .empty
            return
        }
        state = .working
        do {
            let request = try input.request()
            let calculator: AstrocartographyCalculationService
            if let service { calculator = service } else {
                calculator = try await factory()
                try Task.checkCancellation()
                guard generation == token else { return }
                service = calculator
            }
            try Task.checkCancellation()
            guard generation == token else { return }
            let work = Task {
                let result = try await calculator.calculate(request: request)
                let task = Task.detached {
                    let lines = try result.lines.map { try AstroMercatorGeometry.prepare($0) }
                    return AstroMapPresentation(result: result, lines: lines, revision: token.uuidString)
                }
                return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            }
            activeWork = work
            let prepared = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
            try Task.checkCancellation()
            guard generation == token else { return }
            activeWork = nil; presentation = prepared; state = .ready
        } catch {
            guard generation == token else { return }
            activeWork = nil
            state = error is CancellationError ? .cancelled : .failed(error.localizedDescription)
        }
    }

    func cancel() {
        activeWork?.cancel(); activeWork = nil
        generation = UUID(); presentation = nil; selectedLine = nil; selectedPlace = nil
        state = .cancelled
        // Cancellation of the view task is the generation-safe service cancellation;
        // do not enqueue an unscoped service.cancel that could cancel a newer load.
    }

    nonisolated static func makeService() async throws -> AstrocartographyCalculationService {
        try await Task.detached {
            guard let url = AppResources.bundle.url(forResource: "sepl_18", withExtension: "se1", subdirectory: "ephe") else {
                throw AstrocartographyError.ephemerisFailure("No se encuentran las efemérides locales empaquetadas.")
            }
            let directory = url.deletingLastPathComponent()
            let revision = try resourceRevision(directory: directory)
            return try AstrocartographyCalculationService(
                calculator: AstrocartographyEngine(ephemeris: SwissAstrocartographyEphemeris(ephemerisDirectory: directory.path)),
                ephemerisRevision: revision)
        }.value
    }

    /// Content digest, not just path/mtime. Bundled resources are immutable during
    /// a workspace lifetime; recreate the model after an external resource update.
    nonisolated static func resourceRevision(directory: URL) throws -> String {
        var hash = SHA256()
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "se1" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            try Task.checkCancellation()
            hash.update(data: Data(file.lastPathComponent.utf8))
            hash.update(data: try Data(contentsOf: file))
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return "Swiss/\(try SwissAstrocartographyEphemeris.libraryVersion())/\(directory.path)/\(digest)/flags=\(SwissAstrocartographyEphemeris.requestedFlags)/\(SwissAstrocartographyEphemeris.algorithmVersion)"
    }
}
