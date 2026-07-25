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
        "ser reconocida sin tener que imitar ni someterse a la dirección de A",
        True,
    ),
    PlanetProfile(
        "LUNA",
        "Luna",
        "responder desde la sensibilidad, los hábitos, la memoria y la necesidad de cuidado",
        "receptividad, intimidad cotidiana y capacidad para registrar el clima emocional",
        "reaccionar antes de comprender, proteger en exceso o pedir seguridad de forma indirecta",
        "nombrar sus necesidades sin convertirlas en una obligación para B",
        "la seguridad emocional, los ritmos íntimos y las respuestas instintivas",
        "que sus estados internos son percibidos y que la relación toca una zona muy privada",
        "replegarse, volverse cambiante o interpretar cualquier diferencia como falta de cuidado",
        "disponer de tiempo para sentir y responder sin que A adivine o gestione todo",
        True,
    ),
    PlanetProfile(
        "MERCURIO",
        "Mercurio",
        "preguntar, nombrar, comparar ideas y abrir canales de intercambio",
        "curiosidad, articulación mental y capacidad para traducir experiencias en palabras",
        "intelectualizar lo sensible, discutir para imponerse o llenar de ruido la relación",
        "escuchar la respuesta completa y comprobar qué entendió B antes de concluir",
        "el pensamiento, la voz, el aprendizaje y la forma de interpretar los hechos",
        "que su mente se activa, encuentra interlocución y debe ordenar mejor sus argumentos",
        "defender cada idea, corregir compulsivamente o retirarse cuando no se siente comprendida",
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
        "que resulta apreciada y que sus preferencias entran en una negociación íntima",
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
        "exagerar, delegar el criterio en A o resistirse por sentir que recibe una lección",
        "conservar su propio marco ético y decidir qué oportunidades tienen un tamaño sostenible",
        True,
    ),
    PlanetProfile(
        "SATURNO",
        "Saturno",
        "introducir estructura, realidad, demora y responsabilidad en el vínculo",
        "constancia, sobriedad, capacidad de sostener compromisos y aprendizaje a largo plazo",
        "juzgar, enfriar, controlar o convertir el miedo en reglas para la otra persona",
        "explicar el límite y asumir su propia vulnerabilidad en vez de administrar a B",
        "los límites, la responsabilidad, la autoestima competente y el miedo al fracaso",
        "que debe tomarse en serio una parte de sí misma y medir qué puede sostener",
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
        "La conjunción puede dar presencia y capacidad de acción conjunta porque A activa de forma directa el principio de B. Su fuerza no es automáticamente armónica: amplifica tanto la afinidad como cualquier exceso.",
        "La proximidad puede borrar matices, hacer que B sienta la función de A como propia o que A suponga una coincidencia que todavía no ha sido hablada.",
        "Conviene diferenciar qué aporta cada persona, dejar pausas y comprobar el consentimiento antes de interpretar intensidad como compatibilidad.",
    ),
    AspectProfile(
        "SEXTIL",
        "sextil",
        "como una oportunidad de cooperación que suele estar disponible, aunque necesita ser utilizada",
        "El sextil facilita intercambio, aprendizaje y ayuda práctica. A ofrece una puerta que B puede abrir sin sentirse obligada, y la relación gana recursos cuando ambas personas toman iniciativa.",
        "Por ser cómodo, el potencial puede quedar en simpatía o buenas intenciones; también puede darse por supuesta una colaboración que nadie concreta.",
        "Funciona mejor con invitaciones específicas, proyectos pequeños y respuestas explícitas que conviertan la afinidad en experiencia compartida.",
    ),
    AspectProfile(
        "CUADRADO",
        "cuadratura",
        "mediante una fricción activa que obliga a modificar hábitos y respuestas",
        "La cuadratura produce movimiento: A desafía el modo habitual en que B gestiona esta función y B devuelve una resistencia que puede afinar la expresión de A. Bien trabajada, genera habilidad y honestidad.",
        "Sin elaboración, el contacto repite el mismo choque con distintas excusas; cada persona puede atribuir a la otra una tensión que también pertenece a su propio patrón.",
        "Ayuda separar hechos de interpretaciones, negociar una conducta cada vez y usar la discrepancia como información, no como veredicto sobre el vínculo.",
    ),
    AspectProfile(
        "TRIGONO",
        "trígono",
        "a través de una circulación fluida que suele sentirse familiar y poco forzada",
        "El trígono permite que el aporte de A llegue al campo de B con escasa resistencia. Favorece confianza, cooperación espontánea y la sensación de que ciertas capacidades se comprenden sin demasiada explicación.",
        "La facilidad puede volverse inconsciente: evitar conversaciones necesarias, reforzar costumbres poco sanas o asumir que comprenderse en un área equivale a coincidir en todo.",
        "Conviene hacer consciente el recurso, agradecerlo y aplicarlo a asuntos concretos; la comodidad gana profundidad cuando no reemplaza los límites ni la revisión.",
    ),
    AspectProfile(
        "OPOSICION",
        "oposición",
        "desde polos complementarios: cada persona encarna algo que la otra ve enfrente",
        "La oposición aporta perspectiva y una fuerte conciencia del otro. A y B pueden completar un eje, alternar funciones y descubrir capacidades que aisladas quedarían fuera de campo.",
        "También favorece proyección, atracción seguida de rechazo o discusiones en las que cada parte defiende un extremo y deposita el contrario en la otra.",
        "La tarea es sostener dos verdades a la vez, turnarse en los roles y formular acuerdos que no exijan que una persona abandone su polo para que exista relación.",
    ),
)


def relevance_note(source: PlanetProfile, target: PlanetProfile) -> str:
    if source.personal and target.personal:
        return (
            "Al intervenir dos funciones personales, suele notarse de forma directa en la "
            "convivencia, la comunicación o las decisiones compartidas."
        )
    if not source.personal and target.personal:
        return (
            f"Como {source.name} es lento y {target.name} personal, la persona A canaliza un "
            "tema generacional hacia una zona muy individual de B; el efecto gana peso con "
            "orbe estrecho y contactos a los ángulos."
        )
    if source.personal and not target.personal:
        return (
            f"El principio personal de A hace visible en B un tema lento o generacional de "
            f"{target.name}; no conviene atribuir a este único aspecto toda la historia del vínculo."
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
    short_text = (
        f"{planet_with_article(source, capitalized=True)} de A en {aspect.name} "
        f"{planet_with_preposition(target)} de B pone "
        f"{source.source_gift} en relación con {target.target_field}. "
        f"Puede ser un recurso si A logra {source.source_adjustment} y B puede "
        f"{target.target_request}."
    )
    paragraphs = [
        (
            f"{planet_with_article(source, capitalized=True)} de la persona A en "
            f"{aspect.name} {planet_with_preposition(target)} de la persona B entra en "
            f"{target.target_field} de la persona B {aspect.contact}. A tiende a "
            f"{source.source_action}; B puede sentir {target.target_reception}."
            f"{same_planet_note(source, target)}"
        ),
        (
            f"{aspect.potential} En su expresión fértil, se combinan {source.source_gift} "
            f"con la posibilidad de que B use este estímulo para desarrollar con mayor "
            f"conciencia {target.target_field}."
        ),
        (
            f"{aspect.tension} La sombra aparece si A empieza a {source.source_shadow}, "
            f"mientras B responde al {target.target_defense}. Ninguna de estas respuestas "
            "es inevitable: describen un circuito posible, no el carácter completo de las personas."
        ),
        (
            f"{aspect.practice} Para cuidar la dirección A→B, A necesita {source.source_adjustment}; "
            f"B necesita {target.target_request}. {relevance_note(source, target)} "
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
    long_texts: set[str] = set()
    for entry in entries:
        assert len(entry.short_text) >= 220, f"short text too small: {entry.key}"
        assert len(entry.long_text) >= 1350, f"long text too small: {entry.key}"
        assert "persona A" in entry.long_text, f"missing A role: {entry.key}"
        assert "persona B" in entry.long_text, f"missing B role: {entry.key}"
        assert not banned.search(entry.long_text), f"temporal language: {entry.key}"
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
