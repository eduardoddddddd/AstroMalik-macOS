import Foundation

extension SolarArcDirection {
    var primaryDirectionAdapter: PrimaryDirection {
        PrimaryDirection(
            id: id,
            promissor: directedPoint,
            promissorLabel: directedPointLabel,
            significator: natalPoint,
            significatorLabel: natalPointLabel,
            aspect: aspect,
            aspectAngle: aspectAngle,
            directionType: .direct,
            aspectPlane: .ecliptic,
            arc: solarArc,
            estimatedAge: exactAge,
            estimatedDate: exactDate,
            method: .regiomontanus,
            key: mode == .naibod ? .naibod : .ptolemy,
            technicalData: PDTechnicalData(
                promissorRA: directedLongitude,
                promissorDeclination: 0,
                significatorRA: natalLongitude,
                significatorDeclination: 0,
                significatorPole: 0,
                obliquity: 0,
                ramc: 0,
                geoLatitude: 0
            ),
            weight: weight
        )
    }

    var displaySummary: String {
        "\(directedPointLabel) dirigido \(aspect.label) \(natalPointLabel) natal"
    }

    var ageFormatted: String {
        let years = Int(exactAge)
        let months = Int((exactAge - Double(years)) * 12)
        if months == 0 { return "\(years) años" }
        return "\(years) años, \(months) meses"
    }

    var arcFormatted: String {
        let absoluteArc = abs(solarArc)
        let degrees = Int(absoluteArc)
        let totalMinutes = (absoluteArc - Double(degrees)) * 60
        let minutes = Int(totalMinutes)
        let seconds = Int((totalMinutes - Double(minutes)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))'\(String(format: "%02d", seconds))\""
    }
}
