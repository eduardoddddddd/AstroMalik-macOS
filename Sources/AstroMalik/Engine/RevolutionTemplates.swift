import Foundation

// MARK: - Revolution Templates
// Plantillas de texto temáticas para Revolución Solar y Lunar.
// Se componen algorítmicamente a partir de la posición del ASC de revolución,
// su regente, y las casas/signos implicados. Sustituyen la reutilización de
// textos natales que antes se hacía en buildSolarReturnInterpretations.

enum RevolutionTemplates {

    // MARK: - Solar Return: Year Theme by Natal House of RS ASC

    /// Texto del "tema del año" según la casa natal donde cae el ASC de revolución.
    static func yearTheme(natalHouse: Int) -> String {
        switch natalHouse {
        case 1:
            return "Este año el foco está en ti: tu identidad, tu imagen y cómo te presentas al mundo. Es un periodo de reinvención personal, donde lo que quieres ser y cómo quieres que te perciban cobra protagonismo. Buen momento para iniciar proyectos propios y tomar la iniciativa."
        case 2:
            return "El año gira en torno a tus recursos, tu economía y lo que valoras. Los temas de dinero, posesiones y autoestima pasan a primer plano. Es un periodo para consolidar tu seguridad material y replantearte qué es lo verdaderamente importante para ti."
        case 3:
            return "La comunicación, el aprendizaje y el entorno inmediato marcan el año. Relaciones con hermanos, vecinos o compañeros de estudios se activan. Es un periodo favorable para cursos, escritura, viajes cortos y todo lo que implique intercambio de ideas."
        case 4:
            return "El hogar, la familia y las raíces son el escenario central del año. Posibles mudanzas, reformas, reconciliaciones familiares o la necesidad de encontrar tu base emocional. Es un año para construir los cimientos de lo que viene."
        case 5:
            return "Creatividad, romance, hijos y placer marcan el tono del año. Es un periodo vital para expresarte, disfrutar y conectar con lo que te apasiona. Proyectos creativos, relaciones amorosas o la llegada de hijos pueden ser protagonistas."
        case 6:
            return "El trabajo diario, la salud y las rutinas son el tema central. Es un año para organizar tu vida, mejorar hábitos, atender el cuerpo y perfeccionar tu método de trabajo. Relaciones con compañeros y colaboradores también se activan."
        case 7:
            return "Las relaciones personales, los socios y los compromisos con el otro dominan el año. Puede haber una asociación importante, un matrimonio, un contrato clave o una confrontación que te obliga a negociar. El año te pide mirar al otro para entenderte a ti."
        case 8:
            return "Transformación profunda, crisis y renacimiento marcan el año. Temas de recursos compartidos, herencias, deudas, sexualidad o procesos psicológicos intensos. Es un periodo de soltar lo que ya no sirve para regenerarte."
        case 9:
            return "Expansión, viajes largos, estudios superiores y búsqueda de sentido. El año te invita a ampliar horizontes, ya sea viajando, estudiando, publicando o cuestionando tus creencias. Buen periodo para conectar con culturas o filosofías diferentes."
        case 10:
            return "La carrera, la vocación y la imagen pública son el eje del año. Ascensos, cambios profesionales, reconocimiento o mayor exposición pública. Es un año donde lo que construyes profesionalmente tiene especial relevancia."
        case 11:
            return "Amistades, proyectos colectivos, ideales y comunidad. El año te conecta con grupos, asociaciones o movimientos que comparten tus valores. Los sueños a largo plazo y la dimensión social de tu vida cobran importancia."
        case 12:
            return "Interioridad, retiro, cierre de ciclos y espiritualidad. Es un año para hacer balance, soltar, descansar y preparar internamente lo que vendrá. Puede haber momentos de aislamiento elegido o forzado. La vida interior se enriquece si le das espacio."
        default:
            return "Año de transición con múltiples temas activos."
        }
    }

    /// Título corto del tema por casa.
    static func yearThemeTitle(natalHouse: Int) -> String {
        switch natalHouse {
        case 1:  return "Identidad y reinvención personal"
        case 2:  return "Recursos, dinero y valores"
        case 3:  return "Comunicación, aprendizaje y entorno"
        case 4:  return "Hogar, familia y raíces"
        case 5:  return "Creatividad, romance y expresión"
        case 6:  return "Trabajo, salud y rutinas"
        case 7:  return "Relaciones y compromisos"
        case 8:  return "Transformación y crisis"
        case 9:  return "Expansión, viajes y filosofía"
        case 10: return "Carrera y vocación"
        case 11: return "Amistades e ideales colectivos"
        case 12: return "Interioridad y cierre de ciclos"
        default: return "Temas variados"
        }
    }

    // MARK: - Solar Return: ASC Sign Tone

    /// Tono del año según el signo del ASC de revolución.
    static func yearTone(signKey: String) -> String {
        switch signKey {
        case "ARIES":
            return "El tono del año es de iniciativa, empuje y acción directa. Aries en el Ascendente de revolución trae energía para comenzar, competir y afirmarte. Puede haber impaciencia, pero también valentía para romper inercias."
        case "TAURO":
            return "El tono del año es de estabilidad, disfrute y consolidación. Tauro en el Ascendente invita a construir con paciencia, valorar lo tangible y buscar seguridad. Año para plantar semillas que crecerán despacio."
        case "GEMINIS":
            return "El tono del año es de curiosidad, versatilidad y comunicación. Géminis en el Ascendente multiplica los contactos, los estímulos y las opciones. Año de mucho movimiento mental y social."
        case "CANCER":
            return "El tono del año es de sensibilidad, protección y conexión emocional. Cáncer en el Ascendente subraya la vida familiar, la necesidad de raíces y la importancia de sentirte seguro emocionalmente."
        case "LEO":
            return "El tono del año es de expresión, generosidad y visibilidad. Leo en el Ascendente trae un impulso a brillar, liderar y mostrar quién eres. Año de confianza y creatividad, con riesgo de orgullo excesivo."
        case "VIRGO":
            return "El tono del año es de análisis, mejora y servicio. Virgo en el Ascendente favorece la organización, el perfeccionismo constructivo y la atención al detalle. Año para depurar, corregir y ser útil."
        case "LIBRA":
            return "El tono del año es de equilibrio, armonía y relación con el otro. Libra en el Ascendente pide diplomacia, estética y justicia. Las asociaciones y la búsqueda de belleza marcan la energía disponible."
        case "ESCORPIO":
            return "El tono del año es de profundidad, intensidad y transformación. Escorpio en el Ascendente no admite superficialidad. Año para investigar, regenerarse y enfrentar verdades incómodas con poder."
        case "SAGITARIO":
            return "El tono del año es de expansión, optimismo y búsqueda de sentido. Sagitario en el Ascendente abre horizontes, inspira aventura y favorece la fe en el futuro. Riesgo de exceso o dispersión."
        case "CAPRICORNIO":
            return "El tono del año es de responsabilidad, ambición y estructura. Capricornio en el Ascendente pide madurez, planificación y esfuerzo sostenido. Año de resultados si se trabaja con disciplina."
        case "ACUARIO":
            return "El tono del año es de innovación, independencia y originalidad. Acuario en el Ascendente trae deseo de libertad, de romper moldes y de conectar con ideas progresistas. Año para experimentar y diferenciarte."
        case "PISCIS":
            return "El tono del año es de intuición, sensibilidad y trascendencia. Piscis en el Ascendente difumina los límites, favorece la creatividad artística y la espiritualidad. Cuidado con la confusión o la evasión."
        default:
            return "Tono general del año."
        }
    }

    // MARK: - Solar Return: Ruler of RS ASC in Natal House

    /// Dónde se canaliza la energía del año según la casa natal del regente del ASC RS.
    static func rulerInNatalHouse(_ house: Int) -> String {
        switch house {
        case 1:
            return "El regente del año recae sobre ti mismo: la energía se canaliza hacia proyectos personales, tu imagen y tu iniciativa propia."
        case 2:
            return "El regente del año apunta hacia tus recursos: la energía se canaliza hacia el dinero, las posesiones y la consolidación de tu seguridad material."
        case 3:
            return "El regente del año apunta hacia la comunicación: la energía se canaliza hacia el aprendizaje, los viajes cortos y el entorno cercano."
        case 4:
            return "El regente del año apunta hacia el hogar: la energía se canaliza hacia la familia, las raíces y la vida doméstica."
        case 5:
            return "El regente del año apunta hacia la creatividad: la energía se canaliza hacia el romance, los hijos, el ocio y la expresión artística."
        case 6:
            return "El regente del año apunta hacia el trabajo y la salud: la energía se canaliza hacia las rutinas, los compañeros y la mejora de hábitos."
        case 7:
            return "El regente del año apunta hacia las relaciones: la energía se canaliza hacia la pareja, los socios o los compromisos con otros."
        case 8:
            return "El regente del año apunta hacia la transformación: la energía se canaliza hacia procesos profundos, recursos compartidos o renovación interna."
        case 9:
            return "El regente del año apunta hacia la expansión: la energía se canaliza hacia viajes largos, estudios superiores o la búsqueda de sentido."
        case 10:
            return "El regente del año apunta hacia la carrera: la energía se canaliza hacia la profesión, la vocación y la proyección pública."
        case 11:
            return "El regente del año apunta hacia lo colectivo: la energía se canaliza hacia amistades, grupos, proyectos sociales y sueños a largo plazo."
        case 12:
            return "El regente del año apunta hacia lo interior: la energía se canaliza hacia la espiritualidad, el retiro, la introspección o el cierre de ciclos."
        default:
            return "La energía del año se distribuye de forma variada."
        }
    }

    // MARK: - Solar Return: Moon in RS House

    /// Estado emocional del año según la casa de la Luna de revolución.
    static func solarMoonInHouse(_ house: Int) -> String {
        switch house {
        case 1:
            return "Las emociones están a flor de piel este año. Tu estado de ánimo es muy visible para los demás. Necesitas sentir que eres tú quien marca el rumbo."
        case 2:
            return "La seguridad material te da tranquilidad emocional este año. Las fluctuaciones económicas afectan directamente a tu estado de ánimo."
        case 3:
            return "Necesitas comunicar, hablar, escribir y moverte para sentirte bien. Las conversaciones y el aprendizaje alimentan tu bienestar emocional."
        case 4:
            return "El hogar y la familia son tu refugio emocional este año. Mucha vida interior, nostalgia o necesidad de raíces estables. Posible mudanza o cambio doméstico."
        case 5:
            return "El placer, la creatividad y el romance alimentan tus emociones este año. Necesitas disfrutar, jugar y expresarte para sentirte vivo."
        case 6:
            return "Las rutinas diarias y la salud condicionan tu estado emocional. Buen año para organizar tu bienestar pero con riesgo de preocupación excesiva."
        case 7:
            return "Las relaciones de pareja o de asociación marcan tu vida emocional. Necesitas al otro para sentirte completo o cuestionas lo que tienes."
        case 8:
            return "Emociones intensas, profundas y transformadoras. Posibles crisis que te obligan a soltar apegos. La vida emocional pide autenticidad radical."
        case 9:
            return "Las emociones se expanden viajando, estudiando o buscando sentido. Necesitas horizontes amplios para sentirte libre emocionalmente."
        case 10:
            return "Tu vida profesional y tu reputación afectan directamente a tu estado emocional. Te importa cómo te ve el mundo y necesitas reconocimiento."
        case 11:
            return "Los amigos y los proyectos colectivos son tu red emocional este año. Te sientes bien cuando contribuyes a algo más grande que tú."
        case 12:
            return "Emociones ocultas, vida interior rica y necesidad de soledad. Puede haber sacrificios emocionales o una conexión profunda con lo espiritual."
        default:
            return "Las emociones se manifiestan de forma variada este año."
        }
    }

    // MARK: - Lunar Return: Moon House (Monthly Focus)

    /// Foco emocional del mes según la casa de la Luna del retorno.
    static func lunarMoonInHouse(_ house: Int) -> String {
        switch house {
        case 1:
            return "Mes de atención a ti mismo, a tu cuerpo y a cómo te presentas. Las emociones son visibles y la iniciativa personal se activa."
        case 2:
            return "Mes donde el dinero, los recursos y la seguridad material absorben la energía emocional. Buen momento para organizar la economía."
        case 3:
            return "Mes de comunicación, conversaciones importantes y movimiento en el entorno cercano. Aprender, hablar y escribir te calma."
        case 4:
            return "Mes centrado en el hogar y la familia. Necesitas intimidad, raíces y un espacio seguro. Posibles eventos domésticos."
        case 5:
            return "Mes de placer, creatividad y romance. Las emociones se expresan a través del juego, el arte o la conexión amorosa."
        case 6:
            return "Mes de trabajo, rutinas y atención a la salud. Las tareas cotidianas absorben la energía emocional. Cuida tu cuerpo."
        case 7:
            return "Mes donde las relaciones con los demás son el foco emocional. Negociaciones, compromisos o confrontaciones con la pareja o socios."
        case 8:
            return "Mes de intensidad emocional, transformación y temas profundos. Posibles finales, cierres o renovaciones internas."
        case 9:
            return "Mes de apertura, viajes o expansión mental. Las emociones buscan sentido, aventura y conexión con algo más grande."
        case 10:
            return "Mes donde la carrera y la imagen pública absorben la energía emocional. Necesitas sentir que avanzas profesionalmente."
        case 11:
            return "Mes de conexión social, amistades y proyectos colectivos. Las emociones se alimentan de pertenecer a un grupo y compartir ideales."
        case 12:
            return "Mes de retiro, introspección y cierre. Las emociones piden soledad, descanso y conexión con el mundo interior."
        default:
            return "Mes con temas emocionales variados."
        }
    }

    // MARK: - Lunar Return: ASC Sign Tone (Monthly)

    /// Tono del mes según el signo del ASC del retorno lunar.
    static func lunarAscTone(signKey: String) -> String {
        switch signKey {
        case "ARIES":
            return "Mes de iniciativa, acción rápida y afirmación personal. Aries marca un tono directo y enérgico."
        case "TAURO":
            return "Mes de calma, estabilidad y disfrute sensorial. Tauro marca un ritmo lento pero sólido."
        case "GEMINIS":
            return "Mes de mucha comunicación, versatilidad y movimiento social. Géminis activa la curiosidad."
        case "CANCER":
            return "Mes de sensibilidad, protección emocional y conexión familiar. Cáncer intensifica la vida interior."
        case "LEO":
            return "Mes de expresión, creatividad y visibilidad. Leo trae confianza y deseo de brillar."
        case "VIRGO":
            return "Mes de organización, análisis y atención al detalle. Virgo favorece la mejora práctica."
        case "LIBRA":
            return "Mes de equilibrio, diplomacia y relaciones armónicas. Libra pide belleza y justicia."
        case "ESCORPIO":
            return "Mes de intensidad, profundidad y transformación. Escorpio no permite superficialidades."
        case "SAGITARIO":
            return "Mes de optimismo, expansión y búsqueda de sentido. Sagitario abre horizontes."
        case "CAPRICORNIO":
            return "Mes de responsabilidad, disciplina y ambición. Capricornio pide estructura y resultados."
        case "ACUARIO":
            return "Mes de innovación, independencia y originalidad. Acuario rompe moldes y busca libertad."
        case "PISCIS":
            return "Mes de intuición, sensibilidad y conexión espiritual. Piscis difumina los límites."
        default:
            return "Mes con un tono general activo."
        }
    }

    // MARK: - Ruler Lookup

    /// Devuelve la clave del planeta regente clásico de un signo.
    static func classicalRuler(signKey: String) -> String {
        switch signKey {
        case "ARIES":       return "MARTE"
        case "TAURO":       return "VENUS"
        case "GEMINIS":     return "MERCURIO"
        case "CANCER":      return "LUNA"
        case "LEO":         return "SOL"
        case "VIRGO":       return "MERCURIO"
        case "LIBRA":       return "VENUS"
        case "ESCORPIO":    return "MARTE"
        case "SAGITARIO":   return "JUPITER"
        case "CAPRICORNIO": return "SATURNO"
        case "ACUARIO":     return "SATURNO"
        case "PISCIS":      return "JUPITER"
        default:            return "SOL"
        }
    }

    // MARK: - Intensity Score (Lunar Return)

    /// Calcula un score de intensidad 1-5 para un retorno lunar.
    /// Factores: aspectos tensos a la Luna, planetas angulares,
    /// dignidad lunar (domicilio/exaltación/caída/exilio).
    static func lunarIntensityScore(
        moonHouse: Int,
        moonSignKey: String,
        dominantAspects: [NatalAspect],
        angularPlanetCount: Int
    ) -> Int {
        var score: Double = 2.0 // base

        // Aspectos tensos a la Luna
        let tensionKeys: Set<String> = ["CUADRADO", "OPOSICION"]
        let harmonyKeys: Set<String> = ["TRIGONO", "SEXTIL"]
        let moonAspects = dominantAspects.filter { $0.keyA == "LUNA" || $0.keyB == "LUNA" }
        let tenseCount = moonAspects.filter { tensionKeys.contains($0.aspKey) }.count
        let harmonyCount = moonAspects.filter { harmonyKeys.contains($0.aspKey) }.count
        score += Double(tenseCount) * 0.6
        score -= Double(harmonyCount) * 0.15

        // Planetas angulares = más acción
        score += Double(min(angularPlanetCount, 4)) * 0.3

        // Dignidad lunar
        switch moonSignKey {
        case "CANCER":      score -= 0.4  // domicilio = cómoda
        case "TAURO":       score -= 0.3  // exaltación = cómoda
        case "CAPRICORNIO": score += 0.5  // caída = incómoda
        case "ESCORPIO":    score += 0.4  // exilio = incómoda
        default: break
        }

        // Casas angulares de la Luna = más intenso
        if [1, 4, 7, 10].contains(moonHouse) { score += 0.3 }

        return max(1, min(5, Int(score.rounded())))
    }

    // MARK: - Intensity Label

    static func intensityLabel(_ score: Int) -> String {
        switch score {
        case 1: return "Tranquilo"
        case 2: return "Suave"
        case 3: return "Moderado"
        case 4: return "Intenso"
        case 5: return "Muy intenso"
        default: return "—"
        }
    }

    static func intensityStars(_ score: Int) -> String {
        String(repeating: "★", count: score) + String(repeating: "☆", count: max(0, 5 - score))
    }
}
