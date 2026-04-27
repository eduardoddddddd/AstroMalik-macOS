import Foundation

/// Lectura local y determinista para que el módulo nunca quede mudo.
/// No pretende sustituir al corpus curado: es una síntesis operativa basada en
/// la naturaleza del prómissor, el significador y el aspecto calculado.
struct PrimaryDirectionLocalReading: Equatable {
    let title: String
    let summary: String
    let practicalFocus: String
    let caution: String
    let sourceLabel: String

    static func build(for direction: PrimaryDirection) -> PrimaryDirectionLocalReading {
        let promissor = planetMeaning(direction.promissor)
        let significator = significatorMeaning(direction.significator)
        let aspect = aspectMeaning(direction.aspect)
        let motion = direction.directionType == .direct
            ? "La dirección directa tiende a sentirse como un acontecimiento que avanza hacia la vida visible."
            : "La dirección conversa suele funcionar como una activación más interna, retrospectiva o de reordenación."

        let title = "\(direction.promissorLabel) \(direction.aspect.label) \(direction.significatorLabel)"
        let summary = "\(promissor.core) \(aspect.dynamic) El foco cae sobre \(significator.area). \(motion)"
        let practicalFocus = "Observa \(significator.watch) durante el periodo de activación: ahí es donde la promesa simbólica de \(promissor.keyword) suele tomar cuerpo."
        let caution = aspect.caution

        return PrimaryDirectionLocalReading(
            title: title,
            summary: summary,
            practicalFocus: practicalFocus,
            caution: caution,
            sourceLabel: "Lectura operativa local; no es Capa 1 curada ni cita doctrinal."
        )
    }

    private static func planetMeaning(_ key: String) -> (keyword: String, core: String) {
        switch key {
        case "SOL":
            return ("Sol", "El Sol activa identidad, autoridad, vitalidad, propósito y figuras de mando.")
        case "LUNA":
            return ("Luna", "La Luna moviliza cuerpo, hábitos, familia, mundo emocional y cambios de circunstancia.")
        case "MERCURIO":
            return ("Mercurio", "Mercurio trae decisiones, papeles, estudio, comercio, desplazamientos y negociación.")
        case "VENUS":
            return ("Venus", "Venus abre temas de vínculos, placer, acuerdos, estética, deseo y conciliación.")
        case "MARTE":
            return ("Marte", "Marte señala acción, corte, conflicto, esfuerzo físico, urgencia o competencia.")
        case "JUPITER":
            return ("Júpiter", "Júpiter amplía oportunidades, protección, maestros, ley, viajes, fe y crecimiento.")
        case "SATURNO":
            return ("Saturno", "Saturno concentra pruebas, límites, responsabilidad, demoras, estructura y maduración.")
        case "URANO":
            return ("Urano", "Urano introduce ruptura, cambio súbito, independencia y necesidad de salir del patrón.")
        case "NEPTUNO":
            return ("Neptuno", "Neptuno difumina certezas y activa inspiración, idealización, confusión o entrega.")
        case "PLUTON":
            return ("Plutón", "Plutón intensifica procesos de poder, pérdida, regeneración y cambio irreversible.")
        default:
            return (key, "El prómissor activa el tema simbólico principal de esta dirección.")
        }
    }

    private static func significatorMeaning(_ key: String) -> (area: String, watch: String) {
        switch key {
        case "ASC":
            return ("el cuerpo, la identidad, el rumbo personal y la forma de iniciar", "salud, imagen, decisiones propias e inicios")
        case "MC":
            return ("vocación, reputación, autoridad, profesión y exposición pública", "trabajo, visibilidad, responsabilidades y objetivos")
        case "SOL":
            return ("vitalidad, voluntad, padre/autoridad y propósito", "energía vital, liderazgo, reconocimiento y dirección")
        case "LUNA":
            return ("cuerpo emocional, familia, hábitos, hogar y fluctuaciones", "ánimo, descanso, familia, vivienda y ritmos")
        case "PARTFORTUNA":
            return ("recursos naturales, cuerpo, fortuna material y facilidad práctica", "dinero disponible, apoyos concretos y estado físico")
        default:
            return ("el área significada por \(key)", "los asuntos asociados a \(key)")
        }
    }

    private static func aspectMeaning(_ aspect: PDaspect) -> (dynamic: String, caution: String) {
        switch aspect {
        case .conjunction:
            return (
                "La conjunción une fuerzas y hace que el tema sea difícil de ignorar.",
                "No conviene leerla como buena o mala por sí sola: la naturaleza del planeta y el contexto deciden el tono."
            )
        case .sextile:
            return (
                "El sextil abre una vía práctica: ayuda, ocasión, conversación o margen de maniobra.",
                "La oportunidad existe, pero suele pedir iniciativa; si no se usa, puede pasar desapercibida."
            )
        case .square:
            return (
                "La cuadratura fuerza movimiento mediante presión, fricción o necesidad de resolver.",
                "Evita actuar solo por reacción: la tensión puede ser productiva si se le da estructura."
            )
        case .trine:
            return (
                "El trígono facilita integración, apoyo y desarrollo con menos resistencia visible.",
                "La facilidad también puede volver el proceso pasivo; conviene darle dirección consciente."
            )
        case .opposition:
            return (
                "La oposición exterioriza el tema a través de otros, decisiones polarizadas o acontecimientos frente a ti.",
                "No conviertas la tensión en una guerra de extremos: la clave es negociar el eje completo."
            )
        }
    }
}
