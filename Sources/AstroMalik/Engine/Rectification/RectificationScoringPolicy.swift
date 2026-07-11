import Foundation

/// Named scoring policy for the rectification heuristic.
///
/// These values are conservative expert-system defaults, not empirically
/// calibrated probabilities. Keeping them centralized makes future corpus
/// calibration auditable without presenting them as user-tunable truth.
enum RectificationScoringPolicy {
    static let firstConfirmationWeight = 0.20
    static let additionalConfirmationWeight = 0.10

    static let highCandidateScore = 55.0
    static let mediumCandidateScore = 30.0
    static let highMinimumGap = 8.0
    static let mediumMinimumGap = 3.0
    static let highMinimumEventCount = 6
    static let minimumConfidenceEventCount = 3

    static func confirmationWeight(at offset: Int) -> Double {
        offset == 0 ? firstConfirmationWeight : additionalConfirmationWeight
    }
}
