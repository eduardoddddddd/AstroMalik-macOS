#!/usr/bin/env python3
"""One-shot Foundry Local horary interpretation bridge.

Reads the already-calculated AstroMalik horary payload from stdin and writes a
single JSON interpretation to stdout. It does not open ports or keep a server
running; Swift invokes it as a local SDK-backed tool.
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

SYSTEM_PROMPT = """Eres un interprete experto de astrologia horaria clasica para AstroMalik.
Recibes calculos ya hechos por la app Swift. No calcules posiciones, casas, dignidades ni aspectos.
No contradigas el veredicto tecnico recibido. Si el juicio dice dudoso, no lo conviertas en si.
Explica con claridad: significadores, Luna, perfeccion, dignidades, recepciones/mediacion y advertencias.
Usa espanol natural, culto y sobrio. Evita psicologia moderna, fatalismo grandilocuente y relleno.
Devuelve SOLO JSON valido con estas claves:
schemaVersion, model, answer, confidence, title, summary, interpretation, technicalReading, cautions, generatedAt.
answer debe ser un string, no un objeto. technicalReading y cautions deben ser arrays de strings."""


def main() -> int:
    payload = json.load(sys.stdin)
    if not isinstance(payload, dict):
        raise ValueError("El payload debe ser un objeto JSON.")

    model_alias = str(payload.get("model") or DEFAULT_MODEL)
    prompt = build_prompt(payload, model_alias)
    raw = complete(model_alias, prompt)
    parsed = parse_model_json(raw)
    response = normalize_response(parsed, raw, payload, model_alias)
    json.dump(response, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


def complete(model_alias: str, prompt: str) -> str:
    with redirect_stdout(sys.stderr):
        from foundry_local_sdk import Configuration, FoundryLocalManager

        FoundryLocalManager.initialize(
            Configuration(
                app_name="astromalik-horary-local-ai",
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
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ]
        )
    return str(response.choices[0].message.content)


def build_prompt(payload: dict[str, Any], model_alias: str) -> str:
    request = payload.get("request") or {}
    chart = payload.get("chart") or {}
    judgement = payload.get("judgement") or {}
    user_data = {
        "schemaVersion": payload.get("schemaVersion", "horary-foundry-v1"),
        "model": model_alias,
        "question": request.get("question") or judgement.get("question"),
        "topic": {
            "house": judgement.get("questionHouse") or request.get("questionHouse"),
            "label": judgement.get("questionTopic"),
        },
        "technicalJudgement": {
            "verdict": judgement.get("verdict"),
            "confidence": judgement.get("confidence"),
            "mainReason": judgement.get("mainReason"),
            "perfectionKind": judgement.get("perfectionKind"),
            "timingRange": judgement.get("timingRange") or judgement.get("timeEstimate"),
            "supportingFactors": judgement.get("supportingFactors") or [],
            "blockingFactors": judgement.get("blockingFactors") or [],
            "technicalWarnings": judgement.get("technicalWarnings") or [],
            "notes": judgement.get("notes") or [],
            "perfectionRoute": judgement.get("perfectionRoute") or {},
        },
        "chartSummary": compact_chart(chart, judgement),
        "deterministicText": payload.get("judgementText", ""),
    }
    return (
        "Interpreta esta consulta horaria usando solo los datos recibidos. "
        "Mantente fiel al juicio tecnico y mejora la explicacion para un usuario avanzado.\n\n"
        "Responde SOLO con JSON valido y exactamente esta forma:\n"
        "{\n"
        '  "schemaVersion": "horary-foundry-v1",\n'
        f'  "model": "{model_alias}",\n'
        '  "answer": "si|no|no_todavia|requiere_mediacion|dudoso",\n'
        '  "confidence": "alta|media|baja",\n'
        '  "title": "titulo breve",\n'
        '  "summary": "una o dos frases",\n'
        '  "interpretation": "lectura completa",\n'
        '  "technicalReading": ["punto tecnico"],\n'
        '  "cautions": ["cautela"],\n'
        '  "generatedAt": "ISO8601"\n'
        "}\n\n"
        + json.dumps(user_data, ensure_ascii=False, indent=2)
    )


def compact_chart(chart: dict[str, Any], judgement: dict[str, Any]) -> dict[str, Any]:
    bodies = {body.get("name"): body for body in chart.get("bodies", []) if isinstance(body, dict)}
    dignities = {d.get("name"): d for d in chart.get("dignities", []) if isinstance(d, dict)}
    significators = judgement.get("significators") or {}
    route = judgement.get("perfectionRoute") or {}
    relevant_names = [
        significators.get("querent"),
        significators.get("quesited"),
        significators.get("moon"),
        route.get("intermediary"),
    ]
    relevant_names += significators.get("querentCosignifiers") or []
    relevant_names += significators.get("quesitedCosignifiers") or []

    def render_body(name: str | None) -> dict[str, Any] | None:
        if not name or name not in bodies:
            return None
        body = bodies[name]
        dignity = dignities.get(name, {})
        return {
            "name": name,
            "sign": body.get("sign"),
            "degreeInSign": body.get("degreeInSign"),
            "house": body.get("house"),
            "speed": body.get("speed"),
            "retrograde": body.get("retrograde"),
            "essentialScore": dignity.get("essentialScore"),
            "accidentalScore": dignity.get("accidentalScore"),
            "totalScore": dignity.get("totalScore"),
            "essentialTags": dignity.get("essentialTags") or [],
            "accidentalTags": dignity.get("accidentalTags") or [],
        }

    return {
        "header": chart.get("header") or {},
        "angles": chart.get("angles") or {},
        "sect": chart.get("sect"),
        "planetaryHourRuler": chart.get("planetaryHourRuler"),
        "relevantBodies": [
            item for item in (render_body(name) for name in unique(relevant_names)) if item is not None
        ],
        "activeConsiderations": [
            c for c in chart.get("considerations", []) if isinstance(c, dict) and c.get("active")
        ],
        "aspects": chart.get("aspects") or [],
    }


def unique(values: list[Any]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if isinstance(value, str) and value and value not in seen:
            seen.add(value)
            result.append(value)
    return result


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
    judgement = payload.get("judgement") or {}
    answer_object = parsed.get("answer") if isinstance(parsed.get("answer"), dict) else {}
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    interpretation = parsed.get("interpretation") or answer_object.get("interpretation")
    if not isinstance(interpretation, str) or not interpretation.strip():
        interpretation = raw.strip() or "El modelo no devolvio una interpretacion util."
    technical_answer = judgement.get("verdict")
    answer = technical_answer if isinstance(technical_answer, str) and technical_answer else parsed.get("answer")
    if not isinstance(answer, str):
        answer = "dudoso"
    technical_confidence = judgement.get("confidence")
    confidence = (
        technical_confidence
        if isinstance(technical_confidence, str) and technical_confidence
        else parsed.get("confidence")
    )
    if not isinstance(confidence, str):
        confidence = "media"
    return {
        "schemaVersion": "horary-foundry-v1",
        "model": str(parsed.get("model") or model_alias),
        "answer": str(answer),
        "confidence": str(confidence),
        "title": str(parsed.get("title") or answer_object.get("title") or "Lectura horaria local"),
        "summary": str(parsed.get("summary") or answer_object.get("summary") or judgement.get("mainReason") or ""),
        "interpretation": interpretation,
        "technicalReading": string_list(parsed.get("technicalReading") or answer_object.get("technicalReading")),
        "cautions": string_list(parsed.get("cautions") or answer_object.get("cautions")),
        "generatedAt": str(parsed.get("generatedAt") or answer_object.get("generatedAt") or generated_at),
        "rawModelOutput": raw,
    }


def string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)
