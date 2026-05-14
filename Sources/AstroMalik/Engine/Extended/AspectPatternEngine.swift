import Foundation

final class AspectPatternEngine {
    func patterns(chart: Chart, orb: Double = NatalExtendedAnalysisConfiguration.default.aspectPatternOrb) -> [AspectPattern] {
        let bodies = ExtendedAstro.bodies(in: chart, keys: ExtendedAstro.tenPlanetKeys)
        var found: [String: AspectPattern] = [:]

        detectTSquares(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }
        detectGrandTrines(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }
        detectYods(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }
        detectGrandCrosses(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }
        detectKites(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }
        detectMysticRectangles(bodies: bodies, orb: orb).forEach { found[$0.id] = $0 }

        return found.values.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            if lhs.averageOrb != rhs.averageOrb { return lhs.averageOrb < rhs.averageOrb }
            return lhs.id < rhs.id
        }
    }

    private func detectTSquares(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        combinations(bodies, choose: 3).compactMap { trio in
            for opposition in pairings(trio) {
                let a = opposition.0
                let b = opposition.1
                let c = trio.first { $0.key != a.key && $0.key != b.key }!
                guard let opp = aspect(a, b, angle: 180, key: "OPOSICION", label: "☍ Oposición", orb: orb),
                      let sq1 = aspect(c, a, angle: 90, key: "CUADRADO", label: "□ Cuadratura", orb: orb),
                      let sq2 = aspect(c, b, angle: 90, key: "CUADRADO", label: "□ Cuadratura", orb: orb) else { continue }
                return makePattern(.tSquare, bodies: trio, aspects: [opp, sq1, sq2])
            }
            return nil
        }
    }

    private func detectGrandTrines(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        combinations(bodies, choose: 3).compactMap { trio in
            let elements = Set(trio.map { ExtendedAstro.element(forSignIndex: ExtendedAstro.signIndex($0.longitude)) })
            guard elements.count == 1 else { return nil }
            guard let a1 = aspect(trio[0], trio[1], angle: 120, key: "TRIGONO", label: "△ Trígono", orb: orb),
                  let a2 = aspect(trio[0], trio[2], angle: 120, key: "TRIGONO", label: "△ Trígono", orb: orb),
                  let a3 = aspect(trio[1], trio[2], angle: 120, key: "TRIGONO", label: "△ Trígono", orb: orb) else { return nil }
            return makePattern(.grandTrine, bodies: trio, aspects: [a1, a2, a3])
        }
    }

    private func detectYods(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        combinations(bodies, choose: 3).compactMap { trio in
            for sextilePair in pairings(trio) {
                let a = sextilePair.0
                let b = sextilePair.1
                let apex = trio.first { $0.key != a.key && $0.key != b.key }!
                guard let sx = aspect(a, b, angle: 60, key: "SEXTIL", label: "⚹ Sextil", orb: orb),
                      let q1 = aspect(apex, a, angle: 150, key: "QUINCUNCIO", label: "⚻ Quincuncio", orb: orb),
                      let q2 = aspect(apex, b, angle: 150, key: "QUINCUNCIO", label: "⚻ Quincuncio", orb: orb) else { continue }
                return makePattern(.yod, bodies: trio, aspects: [sx, q1, q2])
            }
            return nil
        }
    }

    private func detectGrandCrosses(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        var result: [AspectPattern] = []
        for quartet in combinations(bodies, choose: 4) {
            for pairing in oppositionPairings(quartet) {
                guard let opp1 = aspect(pairing.0.0, pairing.0.1, angle: 180, key: "OPOSICION", label: "☍ Oposición", orb: orb),
                      let opp2 = aspect(pairing.1.0, pairing.1.1, angle: 180, key: "OPOSICION", label: "☍ Oposición", orb: orb) else { continue }
                let remainingPairs = allPairs(quartet).filter { pair in
                    !sameUnordered(pair, pairing.0) && !sameUnordered(pair, pairing.1)
                }
                let squares = remainingPairs.compactMap { aspect($0.0, $0.1, angle: 90, key: "CUADRADO", label: "□ Cuadratura", orb: orb) }
                if squares.count == 4 {
                    result.append(makePattern(.grandCross, bodies: quartet, aspects: [opp1, opp2] + squares))
                }
            }
        }
        return unique(result)
    }

    private func detectKites(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        var result: [AspectPattern] = []
        let grandTrines = detectGrandTrines(bodies: bodies, orb: orb)
        let bodyMap = Dictionary(uniqueKeysWithValues: bodies.map { ($0.key, $0) })
        for trine in grandTrines {
            let trineBodies = trine.planetKeys.compactMap { bodyMap[$0] }
            for fourth in bodies where !trine.planetKeys.contains(fourth.key) {
                for opposed in trineBodies {
                    let sextileTargets = trineBodies.filter { $0.key != opposed.key }
                    guard let opp = aspect(fourth, opposed, angle: 180, key: "OPOSICION", label: "☍ Oposición", orb: orb),
                          let sx1 = aspect(fourth, sextileTargets[0], angle: 60, key: "SEXTIL", label: "⚹ Sextil", orb: orb),
                          let sx2 = aspect(fourth, sextileTargets[1], angle: 60, key: "SEXTIL", label: "⚹ Sextil", orb: orb) else { continue }
                    let allBodies = trineBodies + [fourth]
                    result.append(makePattern(.kite, bodies: allBodies, aspects: trine.aspects + [opp, sx1, sx2]))
                }
            }
        }
        return unique(result)
    }

    private func detectMysticRectangles(bodies: [PlanetBody], orb: Double) -> [AspectPattern] {
        combinations(bodies, choose: 4).compactMap { quartet in
            var aspects: [PatternAspect] = []
            for pair in allPairs(quartet) {
                if let opposition = aspect(pair.0, pair.1, angle: 180, key: "OPOSICION", label: "☍ Oposición", orb: orb) {
                    aspects.append(opposition)
                } else if let trine = aspect(pair.0, pair.1, angle: 120, key: "TRIGONO", label: "△ Trígono", orb: orb) {
                    aspects.append(trine)
                } else if let sextile = aspect(pair.0, pair.1, angle: 60, key: "SEXTIL", label: "⚹ Sextil", orb: orb) {
                    aspects.append(sextile)
                }
            }
            let oppositions = aspects.filter { $0.aspectKey == "OPOSICION" }
            let trines = aspects.filter { $0.aspectKey == "TRIGONO" }
            let sextiles = aspects.filter { $0.aspectKey == "SEXTIL" }
            // En cuatro planetas hay seis pares únicos; el rectángulo místico operativo
            // se reconoce como 2 oposiciones + 2 trígonos + 2 sextiles.
            guard oppositions.count == 2, trines.count == 2, sextiles.count == 2 else { return nil }
            return makePattern(.mysticRectangle, bodies: quartet, aspects: aspects)
        }
    }

    private func aspect(
        _ a: PlanetBody,
        _ b: PlanetBody,
        angle: Double,
        key: String,
        label: String,
        orb: Double
    ) -> PatternAspect? {
        let aspectOrb = ExtendedAstro.aspectOrb(a.longitude, b.longitude, angle: angle)
        guard aspectOrb <= orb else { return nil }
        return PatternAspect(
            planetAKey: a.key,
            planetALabel: a.label,
            planetBKey: b.key,
            planetBLabel: b.label,
            aspectKey: key,
            aspectLabel: label,
            exactAngle: angle,
            orb: ExtendedAstro.rounded(aspectOrb, places: 3)
        )
    }

    private func makePattern(_ kind: AspectPatternKind, bodies: [PlanetBody], aspects: [PatternAspect]) -> AspectPattern {
        let ordered = bodies.sorted { $0.key < $1.key }
        let id = "\(kind.rawValue)-\(ordered.map(\.key).joined(separator: "-"))"
        let average = aspects.isEmpty ? 0 : aspects.reduce(0) { $0 + $1.orb } / Double(aspects.count)
        return AspectPattern(
            id: id,
            kind: kind,
            title: kind.label,
            planetKeys: ordered.map(\.key),
            planetLabels: ordered.map(\.label),
            averageOrb: ExtendedAstro.rounded(average, places: 3),
            aspects: aspects.sorted { $0.id < $1.id }
        )
    }

    private func combinations(_ bodies: [PlanetBody], choose k: Int) -> [[PlanetBody]] {
        guard k > 0 else { return [[]] }
        guard bodies.count >= k else { return [] }
        if k == 1 { return bodies.map { [$0] } }
        var result: [[PlanetBody]] = []
        for index in 0...(bodies.count - k) {
            let head = bodies[index]
            let tail = Array(bodies[(index + 1)...])
            for combo in combinations(tail, choose: k - 1) {
                result.append([head] + combo)
            }
        }
        return result
    }

    private func pairings(_ trio: [PlanetBody]) -> [(PlanetBody, PlanetBody)] {
        [(trio[0], trio[1]), (trio[0], trio[2]), (trio[1], trio[2])]
    }

    private func allPairs(_ bodies: [PlanetBody]) -> [(PlanetBody, PlanetBody)] {
        var pairs: [(PlanetBody, PlanetBody)] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count { pairs.append((bodies[i], bodies[j])) }
        }
        return pairs
    }

    private func oppositionPairings(_ quartet: [PlanetBody]) -> [((PlanetBody, PlanetBody), (PlanetBody, PlanetBody))] {
        [
            ((quartet[0], quartet[1]), (quartet[2], quartet[3])),
            ((quartet[0], quartet[2]), (quartet[1], quartet[3])),
            ((quartet[0], quartet[3]), (quartet[1], quartet[2])),
        ]
    }

    private func sameUnordered(_ lhs: (PlanetBody, PlanetBody), _ rhs: (PlanetBody, PlanetBody)) -> Bool {
        Set([lhs.0.key, lhs.1.key]) == Set([rhs.0.key, rhs.1.key])
    }

    private func unique(_ patterns: [AspectPattern]) -> [AspectPattern] {
        var map: [String: AspectPattern] = [:]
        for pattern in patterns { map[pattern.id] = pattern }
        return Array(map.values)
    }
}
