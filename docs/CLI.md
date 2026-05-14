# CLI `astromalik-cli`

Desde 1.0 el proyecto incluye un binario headless `astromalik-cli` que ejecuta la cadena cross-personal completa desde línea de comandos. Es el reemplazo natural de scripts Python externos que generaban tránsitos semanales en Joplin: ahora el cálculo lo hace la app real con Swiss Ephemeris y el motor cross-personal.

## Para qué sirve

Tres casos de uso principales:

1. **Tarea programada vía LaunchAgent o cron** — informe semanal/mensual automático.
2. **Integración con otros sistemas** — pipear el Markdown a otra herramienta o servicio.
3. **Reproducibilidad** — generar el mismo informe desde un script con argumentos fijos.

## Build

El binario es un target SPM independiente:

```bash
cd /Users/eduardoariasbravo/Developer/AstroMalik-macOS
swift build --product astromalik-cli --configuration release
ls .build/release/astromalik-cli
```

El ejecutable empaquetado se distribuye en `AstroMalik.app/Contents/MacOS/astromalik-cli` cuando se usa `./scripts/package_app.sh` (si el script lo incluye), o se referencia directamente desde `.build/release/` para LaunchAgent.

## Argumentos

```text
astromalik-cli \
  --chart <nombre|UUID>      (obligatorio)
  --date <YYYY-MM-DD>        (opcional, default: hoy local)
  --scope <complete|annual|monthly|weekly>   (default: complete)
  --model <sonnet|opus>      (default: sonnet)
  --output <destino>         (default: stdout)
  --notebook <nombre>        (opcional, alias de joplin:Nombre)
  --user-db <ruta>           (opcional, default: user.db estándar)
  --corpus-db <ruta>         (opcional, default: corpus del bundle)
  --verbose                  (opcional, logs detallados a stderr)
  --help                     (muestra ayuda y sale 0)
```

### `--chart`

Resolución por nombre exacto primero (case-sensitive), luego por UUID. Si la carta no existe en `user.db` el CLI sale con código **2** y mensaje a stderr.

### `--date`

Fecha de referencia para el cálculo cross-personal. Formato ISO `YYYY-MM-DD`. Default: hoy en la zona horaria local del Mac.

### `--scope`

Determina el alcance narrativo solicitado a Anthropic (no cambia los cálculos del state):

- `complete` — informe completo.
- `annual` — foco anual.
- `monthly` — foco mensual.
- `weekly` — foco semanal.

### `--model`

Mapea a las dos configuraciones por defecto de `AnthropicClient`:

- `sonnet` → `AnthropicClient.Config.default` (Sonnet 4.6, 4096 max tokens).
- `opus` → `AnthropicClient.Config.opusLong` (Opus 4.7, 8000 max tokens).

### `--output`

Tres formatos:

- `stdout` — escribe el Markdown del informe a stdout (sin apéndice de trazabilidad). Útil para pipear a otra herramienta.
- `file:/ruta/al/fichero.md` — escribe Markdown + apéndice de trazabilidad al path. Crea directorios padre si no existen.
- `joplin:NombreDeCuaderno` — crea una nota Joplin en el cuaderno indicado vía `JoplinClipperService`. Si el cuaderno no existe, se crea antes.

`--notebook NombreDeCuaderno` es alias conveniente de `--output joplin:NombreDeCuaderno`.

## Códigos de salida

| Código | Significado |
|---:|---|
| 0 | Éxito |
| 1 | Error genérico |
| 2 | Carta no encontrada |
| 3 | Error de Anthropic (auth, ratelimit, network) |
| 4 | Error de Joplin |
| 5 | Error de I/O (paths, permisos) |
| 64 | EX_USAGE (argumentos inválidos) |

Convenientes para encadenar en scripts con `if`/`||`/`&&`.

## Credenciales

El CLI reutiliza la resolución de credenciales del módulo `AstroMalik`:

- **Anthropic API key**: Keychain (`com.astromalik.anthropic`) → `ANTHROPIC_API_KEY`. Si falta → exit 3.
- **Joplin token**: Keychain → `ASTROMALIK_JOPLIN_TOKEN` → settings locales de Joplin Desktop. Si falta y `--output` es joplin → exit 4.

Para preparar el entorno en una sesión nueva del shell:

```bash
export ANTHROPIC_API_KEY="$(security find-generic-password -s com.astromalik.anthropic -w 2>/dev/null)"
```

Si la línea está en `~/.zshrc`, las sesiones la heredan automáticamente. Los LaunchAgents heredan el entorno del lanzamiento del agente, no del shell, así que es preferible **dejar la API key en Keychain** y que el CLI la lea desde ahí.

## Logs

Por defecto, dos líneas a stderr:

```text
astromalik-cli: starting chart=Eduardo scope=weekly model=sonnet
astromalik-cli: done duration=3.2s tokens=15234/4892 cost=$0.0612
```

Con `--verbose`, traza completa de cada paso:

```text
astromalik-cli: resolve chart "Eduardo" -> 9F3E... (Edu rectificada)
astromalik-cli: assemble cross-personal inputs
astromalik-cli: profections age=49 house=2 LotY=MERCURIO
astromalik-cli: firdaria major=SATURNO minor=JUPITER
astromalik-cli: zr spirit L1=Libra L2=Acuario peak=true
astromalik-cli: build engine state -> 47 signals, 12 topics
astromalik-cli: anthropic send model=claude-sonnet-4-6 tokens-in=15234
astromalik-cli: anthropic response tokens-out=4892 cache-read=8000 cost=$0.0612
astromalik-cli: write joplin notebook=AstroMalik
astromalik-cli: done duration=3.2s
```

Ningún log incluye la API key, ni siquiera enmascarada.

## LaunchAgent recipes

`scripts/launchagents/` contiene dos plists listos:

### Semanal — Sábado 18:00

`com.astromalik.cli.weekly.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.astromalik.cli.weekly</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/AstroMalik.app/Contents/MacOS/astromalik-cli</string>
        <string>--chart</string><string>Eduardo</string>
        <string>--scope</string><string>weekly</string>
        <string>--model</string><string>sonnet</string>
        <string>--output</string><string>joplin:AstroMalik</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>6</integer>
        <key>Hour</key><integer>18</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>/Users/USERNAME/Library/Logs/AstroMalik/cli.out</string>
    <key>StandardErrorPath</key><string>/Users/USERNAME/Library/Logs/AstroMalik/cli.err</string>
</dict>
</plist>
```

### Mensual — Día 1 a las 09:00

`com.astromalik.cli.monthly.plist`: igual estructura con `--scope monthly` y `Day=1, Hour=9`.

### Cargar

```bash
mkdir -p ~/Library/Logs/AstroMalik
cp scripts/launchagents/com.astromalik.cli.weekly.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.astromalik.cli.weekly.plist
```

Para descargar:

```bash
launchctl unload ~/Library/LaunchAgents/com.astromalik.cli.weekly.plist
```

Para ejecutar manualmente (run-now):

```bash
launchctl start com.astromalik.cli.weekly
```

## Ejemplos de uso

Informe semanal por defecto a Joplin:

```bash
astromalik-cli --chart "Eduardo" --scope weekly --output joplin:AstroMalik
```

Informe mensual a archivo Markdown:

```bash
astromalik-cli --chart "Eduardo" --scope monthly \
  --output file:~/Documents/AstroMalik/informes/2026-05.md
```

Informe anual con Opus al cumpleaños:

```bash
astromalik-cli --chart "Eduardo" --scope annual --model opus \
  --date 2026-10-11 --output joplin:AstroMalik
```

Pipear a otra herramienta:

```bash
astromalik-cli --chart "Eduardo" --scope weekly --output stdout \
  | pandoc -f markdown -o informe.pdf
```

Verbose para diagnóstico:

```bash
astromalik-cli --chart "Eduardo" --verbose --output stdout > /dev/null
```

## Tests

`Tests/AstroMalikCLITests/AstroMalikCLITests.swift` cubre el parser:

- todos los flags se rellenan correctamente.
- sin `--chart` → EX_USAGE.
- `--scope foo` → EX_USAGE.
- `--output stdout` / `file:...` / `joplin:...` mapean al enum interno.

Tests end-to-end del flujo completo no se incluyen porque requieren API real; se validan manualmente.

## Roadmap

- **1.0**: parser, resolución de cartas por nombre/UUID, scopes, modelos, tres destinos, LaunchAgent recipes, tests del parser.
- **1.1+ posible**:
  - flag `--pdf` para generar también el informe PDF junto al Markdown.
  - flag `--batch` para múltiples cartas en una sola invocación con cache compartido del prompt.
  - flag `--dry-run` que evalúa el state sin llamar a Anthropic (estimación de coste).
  - integración con `notify` para alertar de errores recurrentes en la tarea programada.
