import Foundation

struct RectificationTransitBody: Sendable {
    let label: String
    let longitude: Double
}

/// Candidate-independent ephemerides prepared once for a complete analysis.
struct RectificationEphemerisCache: Sendable {
    let transitsByEvent: [UUID: [String: RectificationTransitBody]]

    static func prepare(for session: RectificationSession) throws -> Self {
        var result: [UUID: [String: RectificationTransitBody]] = [:]
        result.reserveCapacity(session.events.count)
        for event in session.events {
            try Task.checkCancellation()
            let jd = event.dateStart.timeIntervalSince1970
                / RectificationScoringSupport.secondsPerDay + 2_440_587.5
            do {
                let planets = try AstroEngine.calcPlanets(jd: jd)
                result[event.id] = planets.mapValues {
                    RectificationTransitBody(label: $0.label, longitude: $0.deg)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Leave this event uncached so the scorer preserves its normal
                // per-technique warning path instead of aborting all analysis.
                continue
            }
        }
        return Self(transitsByEvent: result)
    }
}
