import Foundation

struct RectificationSymbolismRule: Equatable {
    let houses: Set<Int>
    let bodyKeys: Set<String>
}

enum RectificationSymbolismRules {
    static func rule(for type: RectificationEventType) -> RectificationSymbolismRule {
        switch type {
        case .relationshipStart, .marriage:
            return .init(houses: [7], bodyKeys: ["VENUS", "JUPITER", "LUNA", "DSC"])
        case .divorce:
            return .init(houses: [7, 8, 12], bodyKeys: ["MARTE", "SATURNO", "URANO", "VENUS", "DSC"])
        case .childBirth:
            return .init(houses: [5], bodyKeys: ["LUNA", "VENUS", "JUPITER"])
        case .siblingBirth:
            return .init(houses: [3], bodyKeys: ["MERCURIO"])
        case .parentDeath:
            return .init(houses: [4, 8, 10], bodyKeys: ["SATURNO", "MARTE", "SOL", "LUNA", "IC", "MC"])
        case .familyDeath:
            return .init(houses: [4, 8], bodyKeys: ["SATURNO", "MARTE", "PLUTON", "IC"])
        case .relocation, .homePurchase:
            return .init(houses: [4], bodyKeys: ["LUNA", "URANO", "IC"])
        case .educationStart, .graduation:
            return .init(houses: [3, 9], bodyKeys: ["MERCURIO", "JUPITER"])
        case .careerStart, .promotion, .publicRecognition:
            return .init(houses: [10], bodyKeys: ["SOL", "SATURNO", "JUPITER", "MC"])
        case .jobLoss:
            return .init(houses: [6, 10, 12], bodyKeys: ["SATURNO", "MARTE", "URANO", "MC"])
        case .accident:
            return .init(houses: [1, 6, 8], bodyKeys: ["MARTE", "URANO", "SATURNO", "ASC"])
        case .surgery:
            return .init(houses: [1, 6, 8, 12], bodyKeys: ["MARTE", "PLUTON", "SATURNO", "ASC"])
        case .illness:
            return .init(houses: [1, 6, 12], bodyKeys: ["SATURNO", "NEPTUNO", "LUNA", "ASC"])
        case .legalIssue:
            return .init(houses: [7, 9], bodyKeys: ["JUPITER", "SATURNO"])
        case .travelAbroad:
            return .init(houses: [9], bodyKeys: ["JUPITER", "MERCURIO"])
        case .spiritualShift:
            return .init(houses: [9, 12], bodyKeys: ["JUPITER", "NEPTUNO"])
        case .financialGain:
            return .init(houses: [2, 8], bodyKeys: ["JUPITER", "VENUS"])
        case .financialLoss:
            return .init(houses: [2, 8, 12], bodyKeys: ["SATURNO", "NEPTUNO", "PLUTON"])
        case .identityShift:
            return .init(houses: [1], bodyKeys: ["SOL", "ASC"])
        case .other:
            return .init(houses: [], bodyKeys: [])
        }
    }

    static func symbolicFit(
        event: RectificationEvent,
        sourceKey: String,
        targetKey: String
    ) -> RectificationSymbolicFit {
        let rule = rule(for: event.type)
        let sourceMatches = rule.bodyKeys.contains(sourceKey)
        let targetMatches = rule.bodyKeys.contains(targetKey)
        let angleMatches = (targetKey == "ASC" && rule.houses.contains(1))
            || (targetKey == "MC" && rule.houses.contains(10))
            || (targetKey == "DSC" && rule.houses.contains(7))
            || (targetKey == "IC" && rule.houses.contains(4))
        if (sourceMatches || targetMatches) && angleMatches { return .strong }
        if sourceMatches || targetMatches || angleMatches { return .moderate }
        return rule.bodyKeys.isEmpty ? .neutral : .weak
    }

    static func multiplier(for fit: RectificationSymbolicFit) -> Double {
        switch fit {
        case .contradiction: return 0
        case .neutral: return 0.55
        case .weak: return 0.40
        case .moderate: return 0.75
        case .strong: return 1.00
        }
    }
}

