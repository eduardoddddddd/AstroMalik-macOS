import Foundation

// MARK: - ReadingTemplates
// Frases-puente en español para la lectura natal. Deterministas, doctrinales,
// estilo RevolutionTemplates: concisas y sin adornos. Sin LLM.
// Fuentes de temperamento: doctrina humoral clásica (Ptolomeo, Tetrabiblos I;
// Lilly, CA Libro I) adaptada a lectura moderna.

enum ReadingTemplates {

    // MARK: - Temperamento (elemento dominante × modalidad dominante)

    static func temperament(element: ChartElement, modality: ChartModality) -> String {
        let base: String
        switch element {
        case .fire:
            base = "Carta de dominante fuego: temperamento colérico, energía que busca expresarse en acción, entusiasmo y afirmación de sí."
        case .earth:
            base = "Carta de dominante tierra: temperamento melancólico en el sentido clásico — realismo, paciencia y necesidad de resultados tangibles."
        case .air:
            base = "Carta de dominante aire: temperamento sanguíneo, vida orientada a la idea, el vínculo y el intercambio; comprende antes de sentir."
        case .water:
            base = "Carta de dominante agua: temperamento flemático, percepción emocional del mundo; la experiencia se filtra por el sentimiento y la memoria."
        }
        let modal: String
        switch modality {
        case .cardinal:
            modal = "El predominio cardinal imprime iniciativa: la energía arranca con fuerza, aunque sostenerla cuesta más que iniciarla."
        case .fixed:
            modal = "El predominio fijo imprime persistencia: lo que se emprende se sostiene, con el riesgo correlativo de rigidez."
        case .mutable:
            modal = "El predominio mutable imprime adaptabilidad: la energía fluye y se ajusta, con el riesgo correlativo de dispersión."
        }
        return base + " " + modal
    }

    static func missingElement(_ element: ChartElement) -> String {
        switch element {
        case .fire:
            return "Ausencia de fuego: el impulso y la confianza espontánea no vienen de serie; se conquistan o se buscan en otros."
        case .earth:
            return "Ausencia de tierra: lo práctico y lo material no son terreno natural; conviene construir estructura externa deliberadamente."
        case .air:
            return "Ausencia de aire: la distancia mental y la objetividad cuestan; el juicio tiende a implicarse en lo vivido."
        case .water:
            return "Ausencia de agua: la vida emocional no se muestra con facilidad; la sensibilidad existe pero opera por canales indirectos."
        }
    }

    // MARK: - Secta

    static func sect(isDiurnal: Bool) -> String {
        isDiurnal
            ? "Carta diurna: el Sol sobre el horizonte gobierna la secta; la expresión consciente y pública tiene prioridad sobre la instintiva."
            : "Carta nocturna: la Luna gobierna la secta; lo instintivo, lo privado y lo receptivo marcan el tono de fondo."
    }

    // MARK: - Hemisferios

    static func hemispheres(aboveHorizon: Int, eastern: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        var parts: [String] = []
        let aboveRatio = Double(aboveHorizon) / Double(total)
        if aboveRatio >= 0.7 {
            parts.append("La mayoría planetaria sobre el horizonte orienta la vida hacia lo público y lo objetivo.")
        } else if aboveRatio <= 0.3 {
            parts.append("La mayoría planetaria bajo el horizonte orienta la vida hacia lo subjetivo y lo privado.")
        }
        let easternRatio = Double(eastern) / Double(total)
        if easternRatio >= 0.7 {
            parts.append("El énfasis oriental favorece la iniciativa propia sobre la circunstancia.")
        } else if easternRatio <= 0.3 {
            parts.append("El énfasis occidental hace que la vida se module en relación con los demás.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Stellium

    static func stellium(_ stellium: ChartStellium) -> String {
        let names = stellium.planetLabels.joined(separator: ", ")
        switch stellium.scope {
        case .sign(let signKey):
            let idx = SIGN_KEYS.firstIndex(of: signKey) ?? 0
            return "Stellium en \(SIGN_LABELS[idx]): \(names) concentran la energía de la carta en un solo tono zodiacal."
        case .house(let house):
            return "Stellium en la casa \(house): \(names) hacen de sus asuntos un eje vital dominante."
        }
    }

    // MARK: - Regente del Ascendente

    /// Frase doctrinal por casa donde cae el regente del ASC.
    static func ascRulerInHouse(_ house: Int) -> String {
        switch house {
        case 1:  return "El regente del Ascendente en la casa 1 devuelve la vida a su dueño: identidad fuerte, destino autodirigido."
        case 2:  return "El regente del Ascendente en la casa 2 orienta la vida hacia la consolidación: recursos, valía y sustento propios."
        case 3:  return "El regente del Ascendente en la casa 3 gobierna la vida desde el intercambio: palabra, entorno cercano, movimiento."
        case 4:  return "El regente del Ascendente en la casa 4 ancla la vida en el origen: familia, tierra y vida interior como centro de gravedad."
        case 5:  return "El regente del Ascendente en la casa 5 dirige la vida hacia la expresión: creación, placer, hijos, lo que se engendra."
        case 6:  return "El regente del Ascendente en la casa 6 sitúa la vida en el trabajo y el servicio: oficio, salud y disciplina cotidiana."
        case 7:  return "El regente del Ascendente en la casa 7 entrega la vida al encuentro: el otro — pareja, socio o adversario — define el camino."
        case 8:  return "El regente del Ascendente en la casa 8 lleva la vida por la transformación: crisis, recursos ajenos y regeneración."
        case 9:  return "El regente del Ascendente en la casa 9 impulsa la vida hacia el sentido: estudios superiores, viajes, fe y doctrina."
        case 10: return "El regente del Ascendente en la casa 10 vuelca la vida en la obra pública: vocación, cargo y reconocimiento."
        case 11: return "El regente del Ascendente en la casa 11 teje la vida en lo colectivo: amistades, alianzas y proyectos compartidos."
        case 12: return "El regente del Ascendente en la casa 12 retira la vida hacia lo oculto: soledad fértil, sacrificio y trabajo invisible."
        default: return "El regente del Ascendente gobierna la vida desde la casa \(house)."
        }
    }

    /// Cuando el regente del ASC es una luminaria ya leída en la tríada.
    static func ascRulerIsLuminary(rulerLabel: String) -> String {
        "El regente del Ascendente es \(rulerLabel), ya leído en la tríada: identidad y vitalidad comparten un mismo gobernante, y todo lo dicho allí pesa doble."
    }

    // MARK: - Casas

    static func emptyHousesLead() -> String {
        "Las casas sin planetas no son áreas vacías de vida: sus asuntos se leen por el estado de su regente."
    }

    // MARK: - Síntesis

    static func synthesisLead() -> String {
        "Borrador automático con los hechos duros de la carta. Edítalo: la síntesis final es del astrólogo, no del motor."
    }
}
