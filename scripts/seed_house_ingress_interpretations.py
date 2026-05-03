#!/usr/bin/env python3
"""Seed original AstroMalik interpretations for transit house ingresses.

The texts are original Spanish syntheses, informed by standard modern transit
astrology references for planets moving through natal houses. They are not copied
from the reference sites.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "Sources" / "AstroMalik" / "Resources" / "corpus.db"

PLANETS = {
    "MARTE": {
        "name": "Marte",
        "source_url": "https://astrolibrary.org/transits/mars-houses/",
        "tone": "activa, calienta y acelera",
        "gift": "valor para actuar, cortar inercias y defender una posición",
        "shadow": "prisa, irritabilidad, conflicto o desgaste por forzar demasiado",
        "advice": "conviene dar salida física y práctica a la energía antes de convertirla en pelea",
    },
    "JUPITER": {
        "name": "Júpiter",
        "source_url": "https://astrolibrary.org/transits/jupiter-houses/",
        "tone": "ensancha, promete crecimiento y abre perspectiva",
        "gift": "oportunidades, confianza, aprendizaje y sensación de permiso para ir más lejos",
        "shadow": "exceso, promesas grandes, dispersión o esperar que la suerte sustituya al criterio",
        "advice": "conviene aceptar la expansión, pero ponerle medida, método y prioridades",
    },
    "SATURNO": {
        "name": "Saturno",
        "source_url": "https://astrolibrary.org/transits/saturn-houses/",
        "tone": "densifica, ordena y somete a prueba",
        "gift": "madurez, estructura, límites sanos y resultados construidos con paciencia",
        "shadow": "miedo, retrasos, sensación de carga o empobrecimiento de lo espontáneo",
        "advice": "conviene simplificar, asumir responsabilidad y distinguir obligación real de culpa heredada",
    },
    "URANO": {
        "name": "Urano",
        "source_url": "https://astrolibrary.org/transits/uranus-houses/",
        "tone": "despierta, electrifica y rompe automatismos",
        "gift": "libertad, innovación, independencia y soluciones inesperadas",
        "shadow": "inestabilidad, decisiones bruscas o rebeldía que corta antes de comprender",
        "advice": "conviene experimentar con margen de seguridad y no confundir libertad con destrucción de todo vínculo",
    },
    "NEPTUNO": {
        "name": "Neptuno",
        "source_url": "https://astrolibrary.org/transits/neptune-houses/",
        "tone": "sensibiliza, disuelve bordes y vuelve simbólica la experiencia",
        "gift": "inspiración, compasión, imaginación, entrega y apertura espiritual",
        "shadow": "niebla, idealización, evasión, cansancio o pérdida de referencias concretas",
        "advice": "conviene sostener prácticas de claridad: descanso, límites, comprobaciones y lenguaje sencillo",
    },
    "PLUTON": {
        "name": "Plutón",
        "source_url": "https://astrolibrary.org/transits/pluto-houses/",
        "tone": "intensifica, purga y transforma desde la raíz",
        "gift": "regeneración, poder interior, honestidad psicológica y capacidad de atravesar crisis",
        "shadow": "obsesión, control, compulsiones o luchas de poder difíciles de reconocer",
        "advice": "conviene no maquillar lo que emerge: mirar el patrón, depurarlo y elegir una forma más consciente de poder",
    },
}

HOUSES = {
    1: {
        "area": "identidad, cuerpo, presencia y modo de iniciar",
        "entry": "se nota como cambio de tono personal: el cuerpo, la imagen y la manera de presentarte piden actualización",
        "use": "redefinir hábitos físicos, estilo de iniciativa y relación con el propio deseo",
        "watch": "reaccionar desde la máscara o sobreactuar para demostrar quién eres",
    },
    2: {
        "area": "dinero, recursos, seguridad material y autoestima",
        "entry": "desplaza la atención hacia lo que sostienes, gastas, produces y valoras",
        "use": "ordenar ingresos, gastos, talentos y criterios de merecimiento",
        "watch": "confundir valor personal con posesión, deuda o rendimiento inmediato",
    },
    3: {
        "area": "mente cotidiana, comunicación, hermanos, entorno cercano y aprendizaje básico",
        "entry": "mueve la agenda diaria: conversaciones, desplazamientos, papeles y decisiones pequeñas ganan importancia",
        "use": "aprender, escribir, negociar, preguntar mejor y revisar rutinas mentales",
        "watch": "ruido mental, discusiones menores o dispersión por exceso de estímulos",
    },
    4: {
        "area": "hogar, familia, raíces, memoria emocional y base privada",
        "entry": "lleva el tránsito hacia dentro: casa, intimidad, pertenencia y asuntos familiares empiezan a pesar más",
        "use": "reordenar la base vital, limpiar herencias emocionales y cuidar el espacio de descanso",
        "watch": "quedar atrapado en defensas antiguas o en lealtades familiares inconscientes",
    },
    5: {
        "area": "creatividad, placer, amor romántico, hijos y expresión personal",
        "entry": "enciende la zona donde quieres jugar, crear, amar y dejar una marca propia",
        "use": "dar forma a una obra, recuperar deseo, educar con presencia y permitir alegría consciente",
        "watch": "drama, narcisismo, riesgo innecesario o buscar validación constante",
    },
    6: {
        "area": "trabajo diario, salud, servicio, técnica y hábitos",
        "entry": "aterriza el tránsito en la vida práctica: horarios, cuerpo, tareas y eficiencia empiezan a pedir ajustes",
        "use": "mejorar método, higiene vital, alimentación, descanso y relación con obligaciones concretas",
        "watch": "somatizar tensión, obsesionarse con fallos o vivir solo para resolver pendientes",
    },
    7: {
        "area": "pareja, socios, contratos, clientes y confrontaciones abiertas",
        "entry": "pone el foco en el espejo del otro: acuerdos, desacuerdos y vínculos significativos se vuelven escenario principal",
        "use": "negociar de forma adulta, redefinir pactos y escuchar qué revela la relación",
        "watch": "proyectar todo fuera o ceder poder para evitar una conversación clara",
    },
    8: {
        "area": "intimidad, recursos compartidos, deuda, duelo, sexualidad y procesos psicológicos",
        "entry": "abre una zona más profunda: dependencia, confianza, miedo y entrega empiezan a pedir verdad",
        "use": "sanar pactos invisibles, ordenar finanzas compartidas y atravesar cambios internos",
        "watch": "control, secretos, manipulación o miedo a perder algo que ya está cambiando",
    },
    9: {
        "area": "creencias, estudios superiores, viajes, maestros, ley y sentido vital",
        "entry": "amplía el horizonte: ideas, mapas, formación, extranjería o búsqueda de sentido pasan al primer plano",
        "use": "estudiar, enseñar, viajar, publicar o revisar la filosofía que guía tus decisiones",
        "watch": "dogmatismo, prometer desde una fe no verificada o huir hacia teorías grandilocuentes",
    },
    10: {
        "area": "vocación, carrera, reputación, autoridad y dirección pública",
        "entry": "sube el tránsito al escenario visible: metas, jefes, profesión y reconocimiento exigen definición",
        "use": "tomar dirección, asumir autoridad y alinear ambición con responsabilidad real",
        "watch": "vivir para la mirada externa o pelear con figuras de autoridad sin estrategia",
    },
    11: {
        "area": "amistades, redes, comunidad, proyectos colectivos y futuro deseado",
        "entry": "mueve el campo social: alianzas, grupos y planes a medio plazo empiezan a reorganizarse",
        "use": "elegir tribu, colaborar, activar proyectos y revisar qué futuro merece energía",
        "watch": "diluirte en expectativas del grupo o confundir popularidad con pertenencia real",
    },
    12: {
        "area": "retiro, inconsciente, cierre de ciclo, espiritualidad, sueño y asuntos ocultos",
        "entry": "lleva el tránsito a una zona de fondo: lo invisible, lo pendiente y lo no dicho trabajan desde atrás",
        "use": "descansar, cerrar, perdonar, investigar patrones inconscientes y preparar un nuevo ciclo",
        "watch": "aislamiento, autosabotaje, escapismo o actuar movido por miedos no nombrados",
    },
}

SOURCE_NAME = "Síntesis AstroMalik basada en AstroLibrary"
AUTHOR = "AstroMalik/Codex"


def build_text(planet_key: str, house: int) -> tuple[str, str]:
    planet = PLANETS[planet_key]
    house_data = HOUSES[house]
    title = f"{planet['name']} ingresa en Casa {house}"
    short = f"{planet['name']} activa {house_data['area']}."
    long = (
        f"{title}.\n\n"
        f"Cuando {planet['name']} cruza la cúspide de la Casa {house}, su cualidad —{planet['tone']}— "
        f"se concentra en {house_data['area']}. El ingreso suele sentirse como un cambio de escenario: "
        f"{house_data['entry']}.\n\n"
        f"Potencial: {planet['gift']}. En esta casa puede servir para {house_data['use']}. "
        f"La clave no es interpretar el día exacto como destino cerrado, sino como apertura de un tramo: "
        f"desde aquí los aspectos posteriores de {planet['name']} desarrollarán con más fuerza estos temas.\n\n"
        f"Sombra a vigilar: {planet['shadow']}; en Casa {house}, especialmente {house_data['watch']}. "
        f"Orientación práctica: {planet['advice']}."
    )
    return short, long


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"No existe corpus.db en {DB_PATH}")

    con = sqlite3.connect(DB_PATH)
    try:
        rows = []
        for planet_key, planet in PLANETS.items():
            for house in range(1, 13):
                short, long = build_text(planet_key, house)
                rows.append((
                    "transito",
                    f"{planet_key}_tr_CASA_{house}_INGRESO",
                    AUTHOR,
                    planet["source_url"],
                    SOURCE_NAME,
                    "es",
                    short,
                    long,
                    4,
                ))

        con.executemany(
            """
            INSERT INTO interpretaciones (
                tipo, clave, autor, fuente_url, fuente_nombre, idioma_origen,
                texto_corto, texto_largo, calidad
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(clave, fuente_url) DO UPDATE SET
                autor = excluded.autor,
                fuente_nombre = excluded.fuente_nombre,
                idioma_origen = excluded.idioma_origen,
                texto_corto = excluded.texto_corto,
                texto_largo = excluded.texto_largo,
                calidad = excluded.calidad,
                fecha_scrape = date('now')
            """,
            rows,
        )
        con.commit()
        print(f"Seeded {len(rows)} house ingress interpretations into {DB_PATH}")
    finally:
        con.close()


if __name__ == "__main__":
    main()
