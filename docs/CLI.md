# AstroMalik CLI

`astromalik-cli` es la interfaz local, determinista y automatizable de AstroMalik. Está pensada para terminal, scripts, cron/LaunchAgent y agentes LLM externos como Codex, Claude o GPT.

## Filosofía

Por defecto el CLI **no llama a ningún LLM ni a ninguna API externa**:

- `--format json`
- `--output stdout`
- `--narrative none`
- `--no-network`
- `source: "local"`
- `networkUsed: false`

Esto permite pedir datos astrológicos reales calculados con los motores locales de AstroMalik sin coste, sin Anthropic y sin OpenRouter. Las APIs LLM son opcionales y deben activarse explícitamente.

## Comandos principales

```bash
astromalik-cli charts list
astromalik-cli chart show --chart "Edu" --format json
astromalik-cli natal --chart "Edu" --format markdown
astromalik-cli transits --chart "Edu" --from 2026-06-15 --to 2026-06-21 --format json
astromalik-cli monthly --chart "Edu" --month 2026-06 --format markdown
astromalik-cli weekly --chart "Edu" --from 2026-06-15 --format json
astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --format markdown --narrative none
```

El modo antiguo sin subcomando se mantiene como alias de `cross-personal`:

```bash
astromalik-cli --chart "Edu" --date 2026-06-13 --scope weekly
```

## Técnicas adicionales

También existen subcomandos locales para técnicas predictivas ya presentes en el motor:

```bash
astromalik-cli profections --chart "Edu" --date 2026-06-13
astromalik-cli firdaria --chart "Edu" --date 2026-06-13
astromalik-cli zodiacal-releasing --chart "Edu" --date 2026-06-13
astromalik-cli progressions --chart "Edu" --date 2026-06-13
astromalik-cli solar-return --chart "Edu" --date 2026-06-13
astromalik-cli lunar-return --chart "Edu" --date 2026-06-13
astromalik-cli primary-directions --chart "Edu" --date 2026-06-13
astromalik-cli solar-arc --chart "Edu" --date 2026-06-13
```

## Flags globales

| Flag | Default | Descripción |
|---|---:|---|
| `--format json\|markdown` | `json` | JSON estable para agentes o Markdown legible. |
| `--output stdout\|file:/ruta\|joplin:Cuaderno` | `stdout` | Destino de salida. Joplin requiere red local explícita. |
| `--user-db /ruta/user.db` | App Support | Base de datos de cartas guardadas. |
| `--corpus-db /ruta/corpus.db` | App Support/bundle | Corpus local de interpretaciones. |
| `--verbose` | off | Logs a stderr. |
| `--no-network` | on | Impide Anthropic/OpenRouter/Joplin. |
| `--allow-network` | off | Permite red solo para opciones explícitas. |
| `--narrative none\|local\|anthropic\|openrouter` | `none` | Narrativa LLM desactivada por defecto. Alias: `--llm`. |
| `--scope complete\|annual\|monthly\|weekly` | `complete` | Alcance de `cross-personal`. |
| `--model sonnet\|opus` | `sonnet` | Modelo Anthropic cuando se pide explícitamente. |

## Seguridad de red

`--no-network` es el comportamiento por defecto. Si se intenta pedir Anthropic sin permiso explícito, el CLI falla antes de crear el cliente:

```bash
astromalik-cli cross-personal --chart "Edu" --narrative anthropic
```

Mensaje esperado:

```text
La narrativa Anthropic requiere --allow-network y --narrative anthropic explícitos.
```

Para usar IA con coste debe indicarse de forma explícita:

```bash
astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --narrative anthropic --allow-network
```

OpenRouter queda igualmente protegido por `--allow-network`; si se solicita sin permiso, falla antes de cualquier red.

## Salida JSON

La salida JSON está diseñada para ser estable y útil para agentes. Incluye:

- `metadata`: carta, id, fecha de generación, zona horaria, comando, scope y rango de fechas.
- `chart`: resumen de la carta consultada.
- `technicalData`: datos calculados por los motores locales.
- `events`: eventos ordenados por fecha/prioridad.
- `interpretations`: textos locales del corpus o plantillas deterministas cuando existen.
- `warnings`: avisos de cobertura o narrativa desactivada.
- `source`: normalmente `"local"`.
- `networkUsed`: `false` por defecto.

Ejemplo para agentes:

```bash
astromalik-cli transits --chart "Edu" --from 2026-06-15 --to 2026-06-21 --format json
```

El agente puede consumir `events`, `technicalData.transits`, `technicalData.houseIngresses` e `interpretations` sin llamar a ningún LLM externo.

## Salida Markdown

La salida Markdown es legible directamente y no depende de un LLM externo:

```bash
astromalik-cli natal --chart "Edu" --format markdown
astromalik-cli monthly --chart "Edu" --month 2026-06 --format markdown
astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --format markdown --narrative none
```

Usa textos del corpus local y plantillas deterministas. No busca ser literaria: prioriza información astrológica estructurada, auditable y consultable.

## Ejemplos seguros recomendados

```bash
astromalik-cli charts list
astromalik-cli natal --chart "Edu" --format markdown
astromalik-cli transits --chart "Edu" --from 2026-06-15 --to 2026-06-21 --format json
astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --format markdown --narrative none
```

## Ejemplo explícito con IA y coste

```bash
astromalik-cli cross-personal --chart "Edu" --date 2026-06-13 --scope weekly --narrative anthropic --allow-network
```

Usa esta forma solo cuando quieras pagar una narrativa externa. Sin `--allow-network`, el comando falla de forma segura.
