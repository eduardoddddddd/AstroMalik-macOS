import Foundation

final class DistributionEngine {
    func distribution(chart: Chart) -> NatalDistribution {
        let planets = ExtendedAstro.bodies(in: chart, keys: ExtendedAstro.tenPlanetKeys)
        let elements = buckets(
            category: .element,
            names: ["Fuego", "Tierra", "Aire", "Agua"],
            planets: planets
        ) { body in
            ExtendedAstro.element(forSignIndex: ExtendedAstro.signIndex(body.longitude))
        }
        let modalities = buckets(
            category: .modality,
            names: ["Cardinal", "Fijo", "Mutable"],
            planets: planets
        ) { body in
            ExtendedAstro.modality(forSignIndex: ExtendedAstro.signIndex(body.longitude))
        }
        let hemispheres = buckets(
            category: .hemisphere,
            names: ["Norte", "Sur", "Este", "Oeste"],
            planets: planets
        ) { body in
            hemisphereNames(forHouse: body.house)
        }
        .sorted { lhs, rhs in ["Norte", "Sur", "Este", "Oeste"].firstIndex(of: lhs.name)! < ["Norte", "Sur", "Este", "Oeste"].firstIndex(of: rhs.name)! }

        let quadrants = buckets(
            category: .quadrant,
            names: ["Cuadrante 1", "Cuadrante 2", "Cuadrante 3", "Cuadrante 4"],
            planets: planets
        ) { body in
            [quadrantName(forHouse: body.house)]
        }

        let singletonBuckets = [elements, modalities, hemispheres].flatMap { $0 }.filter { $0.count == 1 }
        let singletons = singletonBuckets.compactMap { bucket -> SingletonPlanet? in
            guard let key = bucket.planetKeys.first, let label = bucket.planetLabels.first else { return nil }
            return SingletonPlanet(
                category: bucket.category,
                bucketName: bucket.name,
                planetKey: key,
                planetLabel: label
            )
        }

        return NatalDistribution(
            elements: elements,
            modalities: modalities,
            hemispheres: hemispheres,
            quadrants: quadrants,
            singletons: singletons.sorted { $0.id < $1.id }
        )
    }

    private func buckets(
        category: DistributionCategory,
        names: [String],
        planets: [PlanetBody],
        classifier: (PlanetBody) -> String
    ) -> [DistributionBucket] {
        buckets(category: category, names: names, planets: planets) { body in [classifier(body)] }
    }

    private func buckets(
        category: DistributionCategory,
        names: [String],
        planets: [PlanetBody],
        classifier: (PlanetBody) -> [String]
    ) -> [DistributionBucket] {
        names.map { name in
            let matching = planets.filter { classifier($0).contains(name) }
            return DistributionBucket(
                category: category,
                name: name,
                count: matching.count,
                planetKeys: matching.map(\.key),
                planetLabels: matching.map(\.label)
            )
        }
    }

    private func hemisphereNames(forHouse house: Int) -> [String] {
        var names: [String] = []
        if (7...12).contains(house) { names.append("Norte") }
        if (1...6).contains(house) { names.append("Sur") }
        if [10, 11, 12, 1, 2, 3].contains(house) { names.append("Este") }
        if (4...9).contains(house) { names.append("Oeste") }
        return names
    }

    private func quadrantName(forHouse house: Int) -> String {
        switch house {
        case 1...3: return "Cuadrante 1"
        case 4...6: return "Cuadrante 2"
        case 7...9: return "Cuadrante 3"
        default: return "Cuadrante 4"
        }
    }
}
