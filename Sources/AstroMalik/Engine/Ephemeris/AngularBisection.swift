import Foundation

/// Busca por bisección el JD donde `angularFunction(jd)` cruza `target`.
///
/// La función angular debe devolver un valor en grados. El algoritmo compara
/// la distancia angular firmada respecto al objetivo, por lo que soporta bien
/// cruces alrededor de 0°/360° como las Lunas Nuevas.
func bisectAngularCrossing(
    startJD: Double,
    endJD: Double,
    target: Double,
    toleranceJD: Double = 1.0 / 1_440.0,
    angularFunction: (Double) throws -> Double
) throws -> Double {
    var low = startJD
    var high = endJD
    let normalizedTarget = EphemerisUtilities.normalizedDegree(target)
    var lowValue = EphemerisUtilities.signedAngularDistance(try angularFunction(low), target: normalizedTarget)
    let highValue = EphemerisUtilities.signedAngularDistance(try angularFunction(high), target: normalizedTarget)

    if abs(lowValue) < 1e-9 { return low }
    if abs(highValue) < 1e-9 { return high }
    guard lowValue * highValue <= 0 else {
        throw EphemerisError.invalidBracket
    }

    while abs(high - low) > toleranceJD {
        let mid = (low + high) / 2
        let midValue = EphemerisUtilities.signedAngularDistance(try angularFunction(mid), target: normalizedTarget)
        if abs(midValue) < 1e-9 { return mid }
        if lowValue * midValue <= 0 {
            high = mid
        } else {
            low = mid
            lowValue = midValue
        }
    }
    return (low + high) / 2
}

/// Busca por bisección el JD donde una función escalar cruza `target`.
/// Útil para estaciones planetarias: velocidad eclíptica = 0.
func bisectScalarCrossing(
    startJD: Double,
    endJD: Double,
    target: Double = 0,
    toleranceJD: Double = 1.0 / 1_440.0,
    scalarFunction: (Double) throws -> Double
) throws -> Double {
    var low = startJD
    var high = endJD
    var lowValue = try scalarFunction(low) - target
    let highValue = try scalarFunction(high) - target

    if abs(lowValue) < 1e-12 { return low }
    if abs(highValue) < 1e-12 { return high }
    guard lowValue * highValue <= 0 else {
        throw EphemerisError.invalidBracket
    }

    while abs(high - low) > toleranceJD {
        let mid = (low + high) / 2
        let midValue = try scalarFunction(mid) - target
        if abs(midValue) < 1e-12 { return mid }
        if lowValue * midValue <= 0 {
            high = mid
        } else {
            low = mid
            lowValue = midValue
        }
    }
    return (low + high) / 2
}
