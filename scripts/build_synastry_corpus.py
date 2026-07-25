#!/usr/bin/env python3
"""Build and validate AstroMalik's Spanish synastry corpus.

The generated texts are an original editorial synthesis. Public-domain sources
provide doctrine (planetary natures, aspect modes, and chart-comparison rules);
the script does not translate or reproduce modern website interpretations.

Usage:
    python3 scripts/build_synastry_corpus.py --check
    python3 scripts/build_synastry_corpus.py --apply-db --write-migration
"""

from __future__ import annotations

import argparse
import dataclasses
import itertools
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "Sources" / "AstroMalik" / "Resources" / "corpus.db"
MIGRATION_PATH = ROOT / "Resources" / "migrations" / "008_synastry_corpus_v2.sql"
SOURCE_NAME = "AstroMalik — síntesis editorial de sinastría v2"
SOURCE_URL = (
    "https://github.com/eduardoddddddd/AstroMalik-macOS/"
    "blob/main/docs/synastry-corpus-v2.md"
)
ASPECT_KEYS = ("CONJUNCION", "SEXTIL", "CUADRADO", "TRIGONO", "OPOSICION")


@dataclasses.dataclass(frozen=True)
class PlanetProfile:
    key: str
    name: str
    source_action: str
    source_gift: str
    source_shadow: str
    source_adjustment: str
    target_field: str
    target_reception: str
    target_defense: str
    target_request: str
    personal: bool


@dataclasses.dataclass(frozen=True)
class AspectProfile:
    key: str
    name: str
    contact: str
    potential: str
    tension: str
    practice: str
    reception: str


# Velocidad media, de la más rápida a la más lenta. En sinastría el planeta más
# lento domina el contacto con independencia de en qué carta esté: en un
# Luna–Saturno es la persona Saturno quien estructura, no quien recibe.
SPEED_ORDER = (
    "LUNA", "MERCURIO", "VENUS", "SOL", "MARTE",
    "JUPITER", "SATURNO", "URANO", "NEPTUNO", "PLUTON",
)


@dataclasses.dataclass(frozen=True)
class CorpusEntry:
    key: str
    short_text: str
    long_text: str


PLANETS = (
    PlanetProfile(
        "SOL",
        "Sol",
        "afirmar su identidad, orientar la relación y hacer visible lo que considera esencial",
        "claridad de propósito, vitalidad y una presencia capaz de reunir",
        "ocupar demasiado espacio, buscar validación o confundir liderazgo con centralidad",
        "mostrar dirección sin eclipsar la subjetividad de la otra persona",
        "la identidad, la voluntad y la necesidad de reconocimiento",
        "que su manera de ser queda vista, estimulada y convocada a definirse",
        "competir por el protagonismo o vivir la iniciativa ajena como una desautorización",
        "lograr reconocimiento sin tener que imitar ni someterse a la dirección de {AGENT}",
        True,
    ),
    PlanetProfile(
        "LUNA",
        "Luna",
        "responder desde la sensibilidad, los hábitos, la memoria y la necesidad de cuidado",
        "receptividad, intimidad cotidiana y capacidad para registrar el clima emocional",
        "reaccionar antes de comprender, proteger en exceso o pedir seguridad de forma indirecta",
        "nombrar sus necesidades sin convertirlas en una obligación para {RECEIVER}",
        "la seguridad emocional, los ritmos íntimos y las respuestas instintivas",
        "que sus estados internos son percibidos y que la relación toca una zona muy privada",
        "replegarse, volverse cambiante o interpretar cualquier diferencia como falta de cuidado",
        "disponer de tiempo para sentir y responder sin que {AGENT} adivine o gestione todo",
        True,
    ),
    PlanetProfile(
        "MERCURIO",
        "Mercurio",
        "preguntar, nombrar, comparar ideas y abrir canales de intercambio",
        "curiosidad, articulación mental y capacidad para traducir experiencias en palabras",
        "intelectualizar lo sensible, discutir para imponerse o llenar de ruido la relación",
        "escuchar la respuesta completa y comprobar qué entendió {RECEIVER} antes de concluir",
        "el pensamiento, la voz, el aprendizaje y la forma de interpretar los hechos",
        "que su mente se activa, encuentra interlocución y debe ordenar mejor sus argumentos",
        "defender cada idea, corregir compulsivamente o retirarse cuando no percibe comprensión",
        "poder cambiar de opinión y precisar sus palabras sin que la conversación se convierta en examen",
        True,
    ),
    PlanetProfile(
        "VENUS",
        "Venus",
        "buscar afinidad, expresar aprecio y proponer una forma compartida de placer y acuerdo",
        "tacto, reciprocidad, sensibilidad estética y voluntad de acercamiento",
        "evitar el conflicto, agradar a cualquier precio o medir el vínculo solo por la armonía",
        "expresar preferencias y límites con la misma claridad con la que ofrece afecto",
        "la afectividad, los valores, el gusto y la manera de recibir o devolver cariño",
        "que recibe aprecio y que sus preferencias entran en una negociación íntima",
        "complacer sin autenticidad, comparar afectos o confundir desacuerdo con desamor",
        "recibir cercanía sin deber corresponder de la misma forma ni al mismo ritmo",
        True,
    ),
    PlanetProfile(
        "MARTE",
        "Marte",
        "actuar, desear, competir y poner en movimiento lo que estaba detenido",
        "coraje, franqueza, energía sexual y capacidad para defender una iniciativa",
        "presionar, provocar, acelerar el consentimiento o convertir toda diferencia en combate",
        "preguntar antes de empujar y usar su fuerza para una meta acordada",
        "el deseo, la iniciativa, la rabia y la capacidad de afirmar límites",
        "que su energía se enciende y que debe posicionarse con mayor rapidez y claridad",
        "contraatacar, inhibirse o vivir la activación del contacto como invasión",
        "poder decir sí, no o todavía no sin que ello sea leído como derrota o rechazo global",
        True,
    ),
    PlanetProfile(
        "JUPITER",
        "Júpiter",
        "ampliar perspectivas, transmitir confianza y vincular la experiencia con un sentido mayor",
        "generosidad, humor, esperanza y capacidad para abrir oportunidades",
        "prometer más de lo posible, moralizar o dar por hecho que crecer siempre significa ir más lejos",
        "ajustar su entusiasmo a la realidad y ofrecer visión sin ocupar el lugar de guía permanente",
        "las creencias, la confianza, el juicio y el horizonte de crecimiento",
        "que sus posibilidades parecen ensancharse y que sus convicciones entran en diálogo",
        "exagerar, delegar el criterio en {AGENT} o resistirse por sentir que recibe una lección",
        "conservar su propio marco ético y decidir qué oportunidades tienen un tamaño sostenible",
        True,
    ),
    PlanetProfile(
        "SATURNO",
        "Saturno",
        "introducir estructura, realidad, demora y responsabilidad en el vínculo",
        "constancia, sobriedad, capacidad de sostener compromisos y aprendizaje a largo plazo",
        "juzgar, enfriar, controlar o convertir el miedo en reglas para la otra persona",
        "explicar el límite y asumir su propia vulnerabilidad en vez de administrar a {RECEIVER}",
        "los límites, la responsabilidad, la autoestima competente y el miedo al fracaso",
        "que debe tomarse en serio una parte de sí y medir qué puede sostener",
        "sentirse insuficiente, obedecer por temor o endurecerse frente a cualquier observación",
        "distinguir un compromiso elegido de una carga y recibir crítica sin perder autoridad propia",
        True,
    ),
    PlanetProfile(
        "URANO",
        "Urano",
        "interrumpir automatismos, reclamar libertad e introducir una perspectiva inesperada",
        "originalidad, honestidad radical y capacidad para renovar estructuras agotadas",
        "desconectarse sin explicación, confundir libertad con imprevisibilidad o provocar por sistema",
        "avisar de sus cambios y negociar espacio sin romper el contacto emocional",
        "la autonomía, la diferencia, la capacidad de cambio y la relación con lo imprevisible",
        "que una zona de su vida se despierta, se acelera y ya no acepta funcionar por inercia",
        "aferrarse al control, responder con cambios bruscos o vivir toda cercanía como pérdida de libertad",
        "experimentar sin destruir la continuidad que necesita para integrar el cambio",
        False,
    ),
    PlanetProfile(
        "NEPTUNO",
        "Neptuno",
        "sensibilizar, imaginar, disolver fronteras rígidas y percibir lo que no se formula",
        "empatía, inspiración, simbolización y apertura a una intimidad no literal",
        "idealizar, proyectar, eludir datos incómodos o pedir una fusión que borre límites",
        "contrastar la intuición con hechos y no convertir la compasión en rescate",
        "la imaginación, la permeabilidad psíquica, los ideales y los límites sutiles",
        "que se abre una zona inspirada y vulnerable donde las señales pueden sentirse antes de comprenderse",
        "confundir deseo con realidad, asumir emociones ajenas o callar para preservar una imagen ideal",
        "pedir claridad, tiempo y acuerdos verificables sin despreciar la dimensión sensible",
        False,
    ),
    PlanetProfile(
        "PLUTON",
        "Plutón",
        "intensificar, revelar motivaciones ocultas y llevar el contacto hacia cuestiones de poder y cambio profundo",
        "penetración psicológica, capacidad regenerativa y valentía para afrontar lo evitado",
        "obsesionarse, controlar, poner a prueba la lealtad o presentar la intensidad como prueba de verdad",
        "renunciar a la coerción y compartir poder, información y capacidad de retirada",
        "la relación con el poder, la pérdida, la intimidad radical y la transformación",
        "que una capa profunda de su experiencia queda movilizada y difícilmente admite respuestas superficiales",
        "protegerse mediante secreto, compulsión o luchas de poder que sustituyen al diálogo",
        "mantener consentimiento, apoyos propios y derecho a procesar la intensidad a su ritmo",
        False,
    ),
)


ASPECTS = (
    AspectProfile(
        "CONJUNCION",
        "conjunción",
        "de manera concentrada: las dos funciones se superponen y resultan difíciles de ignorar",
        "La conjunción puede dar presencia y capacidad de acción conjunta porque {AGENT} activa de forma directa el principio de {RECEIVER}. Su fuerza no es automáticamente armónica: amplifica tanto la afinidad como cualquier exceso.",
        "La proximidad puede borrar matices, hacer que {RECEIVER} sienta la función de {AGENT} como propia o que {AGENT} suponga una coincidencia que todavía no ha sido hablada.",
        "Conviene diferenciar qué aporta cada persona, dejar pausas y comprobar el consentimiento antes de interpretar intensidad como compatibilidad.",
        "de forma directa e inmediata, sin apenas margen para graduarlo",
    ),
    AspectProfile(
        "SEXTIL",
        "sextil",
        "como una oportunidad de cooperación que suele estar disponible, aunque necesita ser utilizada",
        "El sextil facilita intercambio, aprendizaje y ayuda práctica. {AGENT} ofrece una puerta que {RECEIVER} puede abrir sin sentir obligación, y la relación gana recursos cuando ambas personas toman iniciativa.",
        "Por ser cómodo, el potencial puede quedar en simpatía o buenas intenciones; también puede darse por supuesta una colaboración que nadie concreta.",
        "Funciona mejor con invitaciones específicas, proyectos pequeños y respuestas explícitas que conviertan la afinidad en experiencia compartida.",
        "como una invitación que puede aceptar, aplazar o declinar",
    ),
    AspectProfile(
        "CUADRADO",
        "cuadratura",
        "mediante una fricción activa que obliga a modificar hábitos y respuestas",
        "La cuadratura produce movimiento: {AGENT} desafía el modo habitual en que {RECEIVER} gestiona esta función y {RECEIVER} devuelve una resistencia que puede afinar la expresión de {AGENT}. Bien trabajada, genera habilidad y honestidad.",
        "Sin elaboración, el contacto repite el mismo choque con distintas excusas; cada persona puede atribuir a la otra una tensión que también pertenece a su propio patrón.",
        "Ayuda separar hechos de interpretaciones, negociar una conducta cada vez y usar la discrepancia como información, no como veredicto sobre el vínculo.",
        "de forma incómoda, como una exigencia que no había pedido",
    ),
    AspectProfile(
        "TRIGONO",
        "trígono",
        "a través de una circulación fluida que suele sentirse familiar y poco forzada",
        "El trígono permite que el aporte de {AGENT} llegue al campo de {RECEIVER} con escasa resistencia. Favorece confianza, cooperación espontánea y la sensación de que ciertas capacidades se comprenden sin demasiada explicación.",
        "La facilidad puede volverse inconsciente: evitar conversaciones necesarias, reforzar costumbres poco sanas o asumir que comprenderse en un área equivale a coincidir en todo.",
        "Conviene hacer consciente el recurso, agradecerlo y aplicarlo a asuntos concretos; la comodidad gana profundidad cuando no reemplaza los límites ni la revisión.",
        "con naturalidad, hasta el punto de que puede pasar desapercibido",
    ),
    AspectProfile(
        "OPOSICION",
        "oposición",
        "desde polos complementarios: cada persona encarna algo que la otra ve enfrente",
        "La oposición aporta perspectiva y una fuerte conciencia del otro. {AGENT} y {RECEIVER} pueden completar un eje, alternar funciones y descubrir capacidades que aisladas quedarían fuera de campo.",
        "También favorece proyección, atracción seguida de rechazo o discusiones en las que cada parte defiende un extremo y deposita el contrario en la otra.",
        "La tarea es sostener dos verdades a la vez, turnarse en los roles y formular acuerdos que no exijan que una persona abandone su polo para que exista relación.",
        "desde enfrente, como algo que parece venir de fuera y no de sí",
    ),
)


def speed_rank(planet: PlanetProfile) -> int:
    return SPEED_ORDER.index(planet.key)


def dominant_is_target(source: PlanetProfile, target: PlanetProfile) -> bool:
    """¿Manda el planeta de B? Ocurre cuando el punto de destino es el más lento.

    La geometría del aspecto es recíproca, pero la experiencia no: el planeta
    más lento impone su naturaleza al más rápido. Redactar siempre «A actúa y B
    recibe» invertía la dinámica clásica en la mitad de las entradas: en un
    Luna de A con Saturno de B, quien estructura es la persona Saturno.
    """
    return speed_rank(target) > speed_rank(source)


def hierarchy_note(
    agent: PlanetProfile, agent_role: str, receiver: PlanetProfile, receiver_role: str
) -> str:
    if agent.key == receiver.key:
        return ""
    return (
        f" En este contacto el peso lo lleva {agent_role}: "
        f"{planet_with_article(agent)} es el punto más lento de los dos y tiende a "
        f"imponer su naturaleza sobre {planet_with_article(receiver)} de "
        f"{receiver_role}, con independencia de quién haya iniciado el vínculo."
    )


def relevance_note(
    agent: PlanetProfile, agent_role: str, receiver: PlanetProfile, receiver_role: str
) -> str:
    if agent.personal and receiver.personal:
        return (
            "Al intervenir dos funciones personales, suele notarse de forma directa en la "
            "convivencia, la comunicación o las decisiones compartidas."
        )
    if not agent.personal and receiver.personal:
        return (
            f"Como {agent.name} es lento y {receiver.name} personal, {agent_role} canaliza un "
            f"tema generacional hacia una zona muy individual de {receiver_role}; el efecto "
            "gana peso con orbe estrecho y contactos a los ángulos."
        )
    if agent.personal and not receiver.personal:
        return (
            f"El principio personal de {agent_role} hace visible en {receiver_role} un tema "
            f"lento o generacional de {receiver.name}; no conviene atribuir a este único "
            "aspecto toda la historia del vínculo."
        )
    return (
        "Al unir dos planetas lentos, este contacto es principalmente generacional y no debería "
        "ocupar el centro de la lectura salvo que sea muy exacto, angular o forme un patrón con "
        "planetas personales."
    )


def same_planet_note(source: PlanetProfile, target: PlanetProfile) -> str:
    if source.key != target.key:
        return ""
    return (
        f" Como ambos puntos son {source.name}, la relación funciona además como espejo: "
        "se reconocen estrategias semejantes, pero cada persona puede expresarlas con distinto "
        "signo, casa, dignidad y contexto natal."
    )


def planet_with_article(planet: PlanetProfile, *, capitalized: bool = False) -> str:
    article = "la" if planet.key == "LUNA" else "el"
    if capitalized:
        article = article.capitalize()
    return f"{article} {planet.name}"


def planet_with_preposition(planet: PlanetProfile) -> str:
    return f"a la {planet.name}" if planet.key == "LUNA" else f"al {planet.name}"


def build_entry(
    source: PlanetProfile, target: PlanetProfile, aspect: AspectProfile
) -> CorpusEntry:
    key = f"SYN_{source.key}_{target.key}_{aspect.key}"

    # La clave siempre es «planeta de A → planeta de B», pero quien impone su
    # naturaleza es el punto más lento. Se reparten los papeles en consecuencia.
    if dominant_is_target(source, target):
        agent, agent_role = target, "B"
        receiver, receiver_role = source, "A"
    else:
        agent, agent_role = source, "A"
        receiver, receiver_role = target, "B"

    def roles(text: str) -> str:
        return text.format(AGENT=agent_role, RECEIVER=receiver_role)

    short_text = (
        f"{planet_with_article(source, capitalized=True)} de A en {aspect.name} "
        f"{planet_with_preposition(target)} de B pone "
        f"{agent.source_gift} en relación con {receiver.target_field}. "
        f"Puede ser un recurso si {agent_role} logra {roles(agent.source_adjustment)} "
        f"y {receiver_role} puede {roles(receiver.target_request)}."
    )
    paragraphs = [
        (
            f"{planet_with_article(source, capitalized=True)} de la persona A en "
            f"{aspect.name} {planet_with_preposition(target)} de la persona B toca "
            f"{receiver.target_field} de la persona {receiver_role} {aspect.contact}. "
            f"{agent_role} tiende a {roles(agent.source_action)}; {receiver_role} puede "
            f"sentir {roles(receiver.target_reception)}, y el aspecto hace que ese "
            f"estímulo llegue {aspect.reception}."
            f"{same_planet_note(source, target)}"
            f"{hierarchy_note(agent, agent_role, receiver, receiver_role)}"
        ),
        (
            f"{roles(aspect.potential)} En su expresión fértil, se combinan {agent.source_gift} "
            f"con la posibilidad de que {receiver_role} use este estímulo para desarrollar "
            f"con mayor conciencia {receiver.target_field}."
        ),
        (
            f"{roles(aspect.tension)} La sombra aparece si {agent_role} empieza a "
            f"{roles(agent.source_shadow)}, mientras {receiver_role} responde al "
            f"{roles(receiver.target_defense)}. Ninguna de estas respuestas "
            "es inevitable: describen un circuito posible, no el carácter completo de las personas."
        ),
        (
            f"{aspect.practice} {agent_role} necesita {roles(agent.source_adjustment)}; "
            f"{receiver_role} necesita {roles(receiver.target_request)}. "
            f"{relevance_note(agent, agent_role, receiver, receiver_role)} "
            "El orbe, las casas activadas y el estado natal de ambos planetas pueden modificar "
            "de forma decisiva esta lectura."
        ),
    ]
    return CorpusEntry(key, short_text, "\n\n".join(paragraphs))


def build_entries() -> list[CorpusEntry]:
    return [
        build_entry(source, target, aspect)
        for source, target, aspect in itertools.product(PLANETS, PLANETS, ASPECTS)
    ]


def validate_entries(entries: list[CorpusEntry]) -> None:
    expected_keys = {
        f"SYN_{source.key}_{target.key}_{aspect.key}"
        for source, target, aspect in itertools.product(PLANETS, PLANETS, ASPECTS)
    }
    keys = {entry.key for entry in entries}
    assert len(entries) == 500, f"expected 500 entries, got {len(entries)}"
    assert len(keys) == 500, "duplicate corpus keys"
    assert keys == expected_keys, "coverage does not match 10 × 10 × 5"

    banned = re.compile(
        r"\b(ahora|hoy|este momento|en estos momentos|temporalmente)\b",
        flags=re.IGNORECASE,
    )
    # La aplicación sustituye «la persona A/B» por el nombre real de cada carta,
    # así que ningún adjetivo ni participio puede concordar en género con el rol:
    # «la persona B … resulta apreciada» pasaría a «Carlos … resulta apreciada».
    # Solo se admiten formas epicenas para todo lo que califique a A o a B.
    gendered_role = re.compile(
        r"\b(apreciad|reconocid|comprendid|valorad|escuchad|aceptad|respetad"
        r"|tratad|obligad|preparad|dispuest|content|satisfech)[oa]s?\b"
        r"|\bsí mism[oa]s?\b",
        flags=re.IGNORECASE,
    )
    long_texts: set[str] = set()
    for entry in entries:
        assert len(entry.short_text) >= 220, f"short text too small: {entry.key}"
        assert len(entry.long_text) >= 1350, f"long text too small: {entry.key}"
        assert "persona A" in entry.long_text, f"missing A role: {entry.key}"
        assert "persona B" in entry.long_text, f"missing B role: {entry.key}"
        assert not banned.search(entry.long_text), f"temporal language: {entry.key}"
        for field, text in (("short", entry.short_text), ("long", entry.long_text)):
            match = gendered_role.search(text)
            assert not match, (
                f"gendered agreement in {field} text of {entry.key}: "
                f"{match.group(0)!r} — use an epicene wording"
            )
            assert "{" not in text and "}" not in text, (
                f"unsubstituted role placeholder in {field} text of {entry.key}"
            )
        assert entry.long_text not in long_texts, f"duplicate long text: {entry.key}"
        long_texts.add(entry.long_text)


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def render_migration(entries: list[CorpusEntry]) -> str:
    lines = [
        "-- Migration 008: replacement synastry corpus v2",
        "-- Original Spanish editorial synthesis; no modern website text is reproduced.",
        "-- Doctrine and provenance: docs/synastry-corpus-v2.md",
        "",
        "DELETE FROM interpretaciones",
        "WHERE tipo = 'sinastria'",
        f"  AND fuente_nombre IN ('Grupo Venus', {sql_quote(SOURCE_NAME)});",
        "",
    ]
    for entry in entries:
        values = (
            "NULL",
            sql_quote("sinastria"),
            sql_quote(entry.key),
            sql_quote("AstroMalik"),
            sql_quote(SOURCE_URL),
            sql_quote(SOURCE_NAME),
            sql_quote("es"),
            sql_quote(entry.short_text),
            sql_quote(entry.long_text),
            "5",
            "date('now')",
        )
        lines.extend(
            [
                "INSERT INTO interpretaciones",
                "  (id, tipo, clave, autor, fuente_url, fuente_nombre, idioma_origen,",
                "   texto_corto, texto_largo, calidad, fecha_scrape)",
                f"VALUES ({', '.join(values)})",
                "ON CONFLICT(clave, fuente_url) DO UPDATE SET",
                "  autor = excluded.autor,",
                "  fuente_nombre = excluded.fuente_nombre,",
                "  idioma_origen = excluded.idioma_origen,",
                "  texto_corto = excluded.texto_corto,",
                "  texto_largo = excluded.texto_largo,",
                "  calidad = excluded.calidad,",
                "  fecha_scrape = excluded.fecha_scrape;",
                "",
            ]
        )
    return "\n".join(lines)


def apply_to_db(entries: list[CorpusEntry]) -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"corpus database not found: {DB_PATH}")
    connection = sqlite3.connect(DB_PATH)
    try:
        connection.execute("BEGIN IMMEDIATE")
        connection.execute(
            """
            DELETE FROM interpretaciones
            WHERE tipo = 'sinastria'
              AND fuente_nombre IN ('Grupo Venus', ?)
            """,
            (SOURCE_NAME,),
        )
        connection.executemany(
            """
            INSERT INTO interpretaciones (
                tipo, clave, autor, fuente_url, fuente_nombre, idioma_origen,
                texto_corto, texto_largo, calidad, fecha_scrape
            ) VALUES (?, ?, ?, ?, ?, 'es', ?, ?, 5, date('now'))
            ON CONFLICT(clave, fuente_url) DO UPDATE SET
                autor = excluded.autor,
                fuente_nombre = excluded.fuente_nombre,
                idioma_origen = excluded.idioma_origen,
                texto_corto = excluded.texto_corto,
                texto_largo = excluded.texto_largo,
                calidad = excluded.calidad,
                fecha_scrape = excluded.fecha_scrape
            """,
            [
                (
                    "sinastria",
                    entry.key,
                    "AstroMalik",
                    SOURCE_URL,
                    SOURCE_NAME,
                    entry.short_text,
                    entry.long_text,
                )
                for entry in entries
            ],
        )
        connection.commit()
        # The promotion replaces a large text block in-place. Compact the
        # production artifact so deleted or superseded corpus pages are not
        # shipped inside the application bundle.
        connection.execute("VACUUM")
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def validate_db(entries: list[CorpusEntry]) -> None:
    connection = sqlite3.connect(DB_PATH)
    try:
        rows = connection.execute(
            """
            SELECT clave, texto_corto, texto_largo, fuente_nombre, idioma_origen, calidad
            FROM interpretaciones
            WHERE tipo = 'sinastria'
            """
        ).fetchall()
    finally:
        connection.close()
    assert len(rows) == 500, f"database has {len(rows)} synastry rows, expected 500"
    assert {row[0] for row in rows} == {entry.key for entry in entries}
    assert all(row[3] == SOURCE_NAME for row in rows)
    assert all(row[4] == "es" and row[5] == 5 for row in rows)
    assert all(len(row[1]) >= 220 and len(row[2]) >= 1350 for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate generated entries and, if already promoted, the production DB.",
    )
    parser.add_argument(
        "--apply-db",
        action="store_true",
        help="Replace the obsolete Grupo Venus rows in the production corpus.",
    )
    parser.add_argument(
        "--write-migration",
        action="store_true",
        help=f"Write the idempotent SQL migration to {MIGRATION_PATH}.",
    )
    args = parser.parse_args()

    entries = build_entries()
    validate_entries(entries)
    if args.apply_db:
        apply_to_db(entries)
        validate_db(entries)
    elif args.check:
        connection = sqlite3.connect(DB_PATH)
        try:
            count = connection.execute(
                """
                SELECT COUNT(*) FROM interpretaciones
                WHERE tipo = 'sinastria' AND fuente_nombre = ?
                """,
                (SOURCE_NAME,),
            ).fetchone()[0]
        finally:
            connection.close()
        if count:
            validate_db(entries)
    if args.write_migration:
        MIGRATION_PATH.parent.mkdir(parents=True, exist_ok=True)
        MIGRATION_PATH.write_text(render_migration(entries), encoding="utf-8")

    print(f"synastry corpus ok: {len(entries)} entries")
    if args.apply_db:
        print(f"updated database: {DB_PATH}")
    if args.write_migration:
        print(f"wrote migration: {MIGRATION_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
