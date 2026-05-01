#!/usr/bin/env python3
"""One-shot Foundry Local primary direction interpretation bridge.

Reads the already-calculated AstroMalik primary direction payload from stdin and
writes a single ContextualInterpretation JSON object to stdout. Swift invokes it
as a local SDK-backed tool; it does not open ports or keep a server running.
"""

from __future__ import annotations

import json
import os
import re
import sys
from contextlib import redirect_stdout
from datetime import datetime, timezone
from typing import Any

DEFAULT_MODEL = os.environ.get("ASTROMALIK_FOUNDRY_MODEL", "qwen2.5-7b")
DEFAULT_MODEL_CACHE_DIR = os.path.expanduser(
    os.environ.get(
        "ASTROMALIK_FOUNDRY_MODEL_CACHE_DIR",
        "~/.astromalik-primary-directions-local-ai/cache/models",
    )
)

SYSTEM_PROMPT = """Eres editor astrologico de AstroMalik para direcciones primarias.
Recibes calculos ya hechos por la app Swift. No calcules posiciones, casas,
dignidades, aspectos, arcos ni fechas. No inventes factores tecnicos.
Redacta una lectura morinista solo con los datos recibidos.
Si falta un factor, dilo como factor no disponible o no lo uses.
Devuelve SOLO JSON valido con el schema solicitado."""


def main() -> int:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        raise ValueError("El payload debe ser un objeto JSON.")

    model_alias = str(payload.get("model") or DEFAULT_MODEL)
    prompt = build_prompt(payload, model_alias)
    raw = complete(model_alias, prompt, str(payload.get("systemPrompt") or ""))
    parsed = parse_model_json(raw)
    response = normalize_response(parsed, raw, payload, model_alias)
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


def complete(model_alias: str, prompt: str, system_prompt: str) -> str:
    with redirect_stdout(sys.stderr):
        from foundry_local_sdk import Configuration, FoundryLocalManager

        FoundryLocalManager.initialize(
            Configuration(
                app_name="astromalik-primary-directions-local-ai",
                model_cache_dir=DEFAULT_MODEL_CACHE_DIR,
                log_level="error",
            )
        )
        manager = FoundryLocalManager.instance
        model = manager.catalog.get_model(model_alias)
        if not model.is_cached:
            model.download(lambda progress: print(f"download {model_alias}: {progress:5.1f}", file=sys.stderr, flush=True))
        model.load()
        client = model.get_chat_client()
        response = client.complete_chat(
            [
                {"role": "system", "content": SYSTEM_PROMPT + "\n\n" + system_prompt},
                {"role": "user", "content": prompt},
            ]
        )
    return str(response.choices[0].message.content)


def build_prompt(payload: dict[str, Any], model_alias: str) -> str:
    direction = payload.get("direction") or {}
    context = payload.get("context") or {}
    user_prompt = str(payload.get("userPrompt") or "")
    prompt_version = str(payload.get("promptVersion") or "2.0.1-foundry-qwen7b")
    schema = {
        "directionId": "<UUID>",
        "clave": "<PROMISSOR_SIGNIFICADOR_ASPECTO>",
        "tituloPrincipal": "<2-3 frases de sintesis tematica>",
        "textoEstructural": "<interpretacion morinista 200-400 palabras>",
        "factoresConsiderados": [
            {"factor": "<nombre_factor>", "valor": "<valor_observado>", "modulacion": "<amplifica|atenua|invierte|neutro>"}
        ],
        "periodoActivacion": {
            "edadExacta": direction.get("estimatedAge"),
            "orbeEnMeses": 6,
            "fechaInicio": None,
            "fechaFin": None,
        },
        "areasAfectadas": [{"area": "<nombre>", "peso": 1}],
        "intensidad": 5,
        "polaridad": "<benefico|malefico|neutro|mixto>",
        "generadoEn": "<ISO8601>",
        "promptVersion": prompt_version,
    }
    compact_payload = {
        "schemaVersion": payload.get("schemaVersion", "primary-direction-foundry-v1"),
        "model": model_alias,
        "promptVersion": prompt_version,
        "direction": direction,
        "context": context,
    }
    return (
        "Redacta la interpretacion contextual local de esta direccion primaria.\n"
        "Usa el prompt tecnico recibido como fuente de datos, no como permiso para inventar.\n"
        "No anadas ningun texto fuera del JSON.\n\n"
        "Schema obligatorio:\n"
        + json.dumps(schema, ensure_ascii=False, indent=2)
        + "\n\nDatos compactos:\n"
        + json.dumps(compact_payload, ensure_ascii=False, indent=2)
        + "\n\nPrompt tecnico de AstroMalik:\n"
        + user_prompt
    )


def parse_model_json(raw: str) -> dict[str, Any]:
    text = raw.strip()
    if text.startswith("```"):
        text = "\n".join(text.splitlines()[1:-1]).strip()

    def load_candidate(candidate: str) -> dict[str, Any]:
        for repaired in (candidate, repair_braces(candidate)):
            try:
                value = json.loads(repaired)
                return value if isinstance(value, dict) else {}
            except json.JSONDecodeError:
                continue
        return {}

    parsed = load_candidate(text)
    if parsed:
        return parsed

    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if match:
        return load_candidate(match.group(0))
    return {}


def repair_braces(text: str) -> str:
    opens = text.count("{")
    closes = text.count("}")
    if opens > closes:
        return text + ("}" * (opens - closes))
    return text


def normalize_response(
    parsed: dict[str, Any],
    raw: str,
    payload: dict[str, Any],
    model_alias: str,
) -> dict[str, Any]:
    direction = payload.get("direction") or {}
    context = payload.get("context") or {}
    prompt_version = str(payload.get("promptVersion") or "2.0.1-foundry-qwen7b")
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    clave = f"{direction.get('promissor', '')}_{direction.get('significator', '')}_{str(direction.get('aspect', '')).upper()}"
    interpretation = parsed.get("textoEstructural")
    if not isinstance(interpretation, str) or not interpretation.strip():
        interpretation = raw.strip() or "El modelo local no devolvio una interpretacion util."

    return {
        "directionId": str(parsed.get("directionId") or direction.get("id") or ""),
        "clave": clave,
        "tituloPrincipal": str(parsed.get("tituloPrincipal") or "Lectura local de direccion primaria"),
        "textoEstructural": interpretation,
        "factoresConsiderados": deterministic_factors(context),
        "periodoActivacion": normalize_period(parsed.get("periodoActivacion"), direction),
        "areasAfectadas": area_list(parsed.get("areasAfectadas"), direction),
        "intensidad": deterministic_intensity(parsed.get("intensidad"), direction, context),
        "polaridad": deterministic_polarity(direction, context),
        "generadoEn": generated_at,
        "promptVersion": prompt_version,
    }


def normalize_period(value: Any, direction: dict[str, Any]) -> dict[str, Any]:
    period = value if isinstance(value, dict) else {}
    return {
        "edadExacta": number(period.get("edadExacta"), number(direction.get("estimatedAge"), 0.0)),
        "orbeEnMeses": bounded_int(period.get("orbeEnMeses"), 1, 60, 6),
        "fechaInicio": nullable_string(period.get("fechaInicio")),
        "fechaFin": nullable_string(period.get("fechaFin")),
    }


def factor_list(value: Any) -> list[dict[str, str]]:
    if not isinstance(value, list):
        return []
    result: list[dict[str, str]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        factor = str(item.get("factor") or "").strip()
        valor = str(item.get("valor") or "").strip()
        modulacion = str(item.get("modulacion") or "neutro").strip()
        if factor and valor:
            result.append({"factor": factor, "valor": valor, "modulacion": normalize_modulation(modulacion)})
    return result


def deterministic_factors(context: dict[str, Any]) -> list[dict[str, str]]:
    factors: list[dict[str, str]] = []

    dignity = context.get("promissorDignity")
    factors.append({
        "factor": "dignidad_esencial_promissor",
        "valor": clean_factor_value(dignity),
        "modulacion": dignity_modulation(dignity),
    })

    house = context.get("promissorNatalHouse")
    factors.append({
        "factor": "casa_natal_promissor",
        "valor": f"Casa {house}" if house is not None else "factor no disponible",
        "modulacion": house_modulation(house),
    })

    natal_aspect = context.get("natalAspectBetweenPromissorAndSignificator")
    factors.append({
        "factor": "aspecto_natal_promissor_significador",
        "valor": clean_factor_value(natal_aspect, fallback="ninguno"),
        "modulacion": "amplifica" if natal_aspect else "neutro",
    })

    sect_value = "nocturna" if context.get("isNocturnal") else "diurna"
    sect_value += " | promissor en sect" if context.get("promissorInSect") else " | promissor fuera de sect"
    factors.append({
        "factor": "sect",
        "valor": sect_value,
        "modulacion": "amplifica" if context.get("promissorInSect") else "atenua",
    })

    condition = context.get("significatorCondition")
    factors.append({
        "factor": "condicion_significador",
        "valor": clean_factor_value(condition),
        "modulacion": "neutro",
    })

    age = context.get("nativeCurrentAge")
    birth_year = context.get("birthYear")
    if age is not None or birth_year is not None:
        value = " | ".join(
            part for part in [
                f"edad actual {age}" if age is not None else "",
                f"nacimiento {birth_year}" if birth_year is not None else "",
            ]
            if part
        )
        factors.append({"factor": "datos_temporales_nativo", "valor": value, "modulacion": "neutro"})

    return factors


def area_list(value: Any, direction: dict[str, Any]) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return fallback_areas(direction)
    result: list[dict[str, Any]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        area = str(item.get("area") or "").strip()
        if area:
            result.append({"area": area, "peso": bounded_int(item.get("peso"), 1, 3, 1)})
    return result or fallback_areas(direction)


def fallback_areas(direction: dict[str, Any]) -> list[dict[str, Any]]:
    significator = str(direction.get("significator") or "")
    if significator == "ASC":
        return [{"area": "cuerpo identidad y rumbo personal", "peso": 3}]
    if significator == "MC":
        return [{"area": "vocacion reputacion y oficio", "peso": 3}]
    if significator == "LUNA":
        return [{"area": "familia cuerpo emocional y habitos", "peso": 2}]
    if significator == "SOL":
        return [{"area": "vitalidad autoridad y proposito", "peso": 2}]
    if significator == "PARTFORTUNA":
        return [{"area": "recursos cuerpo y fortuna material", "peso": 2}]
    return [{"area": "area significada por el significador", "peso": 1}]


def normalize_modulation(value: str) -> str:
    return value if value in {"amplifica", "atenua", "invierte", "neutro"} else "neutro"


def normalize_polarity(value: Any) -> str:
    text = str(value or "").strip()
    return text if text in {"benefico", "malefico", "neutro", "mixto"} else "mixto"


def deterministic_polarity(direction: dict[str, Any], context: dict[str, Any]) -> str:
    aspect = str(direction.get("aspect") or "")
    dignity = str(context.get("promissorDignity") or "").lower()
    weakened = any(term in dignity for term in ("exilio", "detrimento", "caida", "caída"))
    if aspect in {"cuadratura", "oposicion"}:
        return "malefico"
    if aspect in {"sextil", "trigono"}:
        return "mixto" if weakened else "benefico"
    if aspect == "conjuncion":
        return "mixto"
    return "mixto"


def deterministic_intensity(value: Any, direction: dict[str, Any], context: dict[str, Any]) -> int:
    score = bounded_int(value, 1, 10, 5)
    aspect = str(direction.get("aspect") or "")
    if aspect in {"conjuncion", "cuadratura", "oposicion"}:
        score = max(score, 6)
    if context.get("natalAspectBetweenPromissorAndSignificator"):
        score = min(10, score + 1)
    return score


def clean_factor_value(value: Any, fallback: str = "factor no disponible") -> str:
    if value is None:
        return fallback
    text = str(value).strip()
    return text or fallback


def dignity_modulation(value: Any) -> str:
    text = str(value or "").lower()
    if any(term in text for term in ("domicilio", "exaltacion", "exaltación", "triplicidad")):
        return "amplifica"
    if any(term in text for term in ("exilio", "detrimento", "caida", "caída", "peregrino")):
        return "atenua"
    return "neutro"


def house_modulation(value: Any) -> str:
    try:
        house = int(value)
    except (TypeError, ValueError):
        return "neutro"
    if house in {1, 4, 7, 10}:
        return "amplifica"
    if house in {6, 8, 12}:
        return "atenua"
    return "neutro"


def bounded_int(value: Any, low: int, high: int, default: int) -> int:
    try:
        return max(low, min(high, int(value)))
    except (TypeError, ValueError):
        return default


def number(value: Any, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def nullable_string(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)
