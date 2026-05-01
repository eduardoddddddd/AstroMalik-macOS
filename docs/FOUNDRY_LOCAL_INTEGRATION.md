# Foundry Local En AstroMalik

Documento de investigacion e integracion practica de Microsoft Foundry Local en AstroMalik-macOS.

Fecha de trabajo inicial: 2026-04-30.

## Resumen Ejecutivo

Foundry Local es prometedor, pero no hay que tratarlo como magia. La prueba confirma que puede ejecutar modelos locales desde SDK Python en un Mac Apple Silicon, descargar modelos optimizados y responder sin enviar datos a un backend externo. Tambien confirma que la calidad de un modelo pequeno no basta, por si sola, para producir una interpretacion editorial buena en un dominio tecnico.

La conclusion arquitectonica importante es esta:

- AstroMalik debe seguir calculando y juzgando con codigo determinista.
- Foundry Local debe usarse como runtime local de modelos.
- El modelo no debe decidir el resultado tecnico.
- El modelo puede ayudar a redactar, resumir, reordenar, explicar o dialogar.
- El puente no debe ser un servidor local persistente si no hace falta.

La integracion actual usa un proceso Python one-shot:

```text
SwiftUI Horaria / Direcciones Primarias
  -> cliente Swift Foundry
  -> Process(stdin JSON / stdout JSON)
  -> script Python one-shot
  -> foundry-local-sdk
  -> modelo local qwen2.5-7b
```

No se abre ningun puerto propio de AstroMalik. No queda ningun daemon de AstroMalik corriendo. La llamada es una herramienta local invocada bajo demanda.

## Fuentes Oficiales Revisadas

Documentacion oficial usada para contrastar decisiones:

- Foundry Local overview: https://learn.microsoft.com/en-us/azure/foundry-local/what-is-foundry-local
- Foundry Local SDK reference: https://learn.microsoft.com/en-us/azure/foundry-local/reference/reference-sdk-current
- Integrate with inference SDKs: https://learn.microsoft.com/en-us/azure/foundry-local/how-to/how-to-integrate-with-inference-sdks
- Foundry Local CLI reference: https://learn.microsoft.com/en-us/azure/foundry-local/reference/reference-cli
- Get started with Foundry Local: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-local/get-started

Puntos clave verificados en la documentacion:

- El SDK no requiere obligatoriamente que la CLI este instalada en la maquina final.
- El servidor REST local es opcional.
- El servidor REST existe sobre todo para integracion con clientes HTTP/OpenAI-compatible.
- El SDK Python permite usar API nativa con `model.get_chat_client()` y `client.complete_chat(...)`.
- El SDK permite configurar `model_cache_dir`.
- Foundry Local esta orientado a inferencia local de usuario unico, no a servir modelos para muchos usuarios concurrentes.
- La primera ejecucion puede descargar modelos y componentes de ejecucion.
- Una vez descargado, el modelo puede ejecutarse desde cache local.

## Estado Local Encontrado

Contexto de instalacion local documentado previamente en:

```text
/Users/eduardoariasbravo/Developer/Foundry Local/FOUNDRY_LOCAL_EXPERT.md
```

Datos relevantes:

```text
CLI Foundry Local: ~/.local/bin/foundry
Version CLI comprobada: 0.8.119
SDK Python venv: /Users/eduardoariasbravo/Developer/Foundry Local/.venv
Python del venv: /Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python
Paquete SDK usado: foundry-local-sdk
```

Script de smoke test existente:

```text
/Users/eduardoariasbravo/Developer/Foundry Local/foundry_quickstart.py
```

Comando de catalogo por SDK:

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  "/Users/eduardoariasbravo/Developer/Foundry Local/foundry_quickstart.py"
```

Modelos relevantes vistos en catalogo:

- `qwen2.5-0.5b`
- `qwen2.5-1.5b`
- `qwen2.5-coder-0.5b`
- `qwen2.5-coder-1.5b`
- `qwen3-0.6b`
- `phi-4-mini`
- `phi-4-mini-reasoning`
- `qwen2.5-7b`
- `qwen2.5-coder-7b`
- modelos Whisper

## Que Se Probo

### 1. Smoke Test Con `qwen2.5-0.5b`

Se descargo y cargo `qwen2.5-0.5b` mediante SDK Python.

Resultado:

- El modelo se descarga.
- El modelo carga.
- `model.get_chat_client()` funciona.
- `client.complete_chat(...)` responde.
- La calidad conversacional fue pobre para este caso.

Respuesta observada en una prueba simple:

```text
Espero que estés contento. ¿Puedes contarme algo más?
```

Esto fue una senal temprana: el modelo pequeno puede servir como smoke test tecnico, pero no como base seria de redaccion astrologica o editorial.

### 2. Smoke Test Con `qwen2.5-1.5b`

Se descargo y cargo `qwen2.5-1.5b`.

Resultado:

- Descarga mayor.
- Cache final aproximada: 1.3 GB.
- Responde mas coherentemente que el 0.5B, pero sigue siendo fragil.
- Tiende a obedecer parcialmente el formato JSON.
- A veces devuelve JSON envuelto en markdown.
- A veces inventa matices tecnicos si se le deja espacio.
- A veces contradice el juicio determinista si el prompt no lo ata con fuerza.

Conclusion:

`qwen2.5-1.5b` es valido para probar el pipeline local, pero no debe tener autoridad interpretativa final. Para calidad real haran falta prompts mas estrechos, postprocesado y quizas modelos mayores.

## Lo Que Salio Mal

### 1. El Servidor Local Era Una Mala Direccion Para Este Objetivo

La primera propuesta tecnica fue montar un microservidor HTTP local. Eso habria funcionado, pero chocaba con el objetivo real:

- no depender de servidores locales;
- no abrir puertos;
- no dejar procesos residentes;
- usar Foundry como SDK/runtime embebible;
- mantener AstroMalik como app de escritorio limpia.

La documentacion oficial confirma que el servidor REST es opcional. Por tanto, se elimino esa direccion.

Decision final:

```text
No FastAPI.
No Uvicorn.
No endpoint local propio de AstroMalik.
No daemon de AstroMalik.
```

Se usa un proceso one-shot Python invocado por Swift.

### 2. Logs De Foundry Contaminaban stdout

El script Python parecia devolver JSON, pero en la app aparecio:

```text
Foundry Local respondio, pero el JSON no era valido:
The data couldn't be read because it isn't in the correct format.
```

Causa real:

Foundry Local imprimia logs en `stdout` durante import/inicializacion:

```text
[foundry-local] | ... | INFO | Native libraries found ...
[foundry-local] | ... | INFO | Foundry.Local.Core initialized successfully ...
{ JSON real de AstroMalik }
```

Swift intentaba decodificar toda la salida como JSON, y fallaba.

Correccion:

- Mover el import de `foundry_local_sdk` dentro de un bloque `redirect_stdout(sys.stderr)`.
- Ejecutar inicializacion, descarga, carga e inferencia dentro de ese mismo bloque.
- Reservar `stdout` exclusivamente para el JSON final de AstroMalik.
- Endurecer Swift para que, si alguna vez hay ruido, busque una linea JSON valida.

Archivo corregido:

```text
scripts/foundry_horary_once.py
```

### 3. La Cache No Estaba Donde Parecia

Se comprobo:

```bash
foundry cache location
foundry cache list
```

La CLI indicaba:

```text
/Users/eduardoariasbravo/.foundry/cache/models
No models cached on device
```

Pero el SDK habia creado una cache distinta por `app_name`:

```text
/Users/eduardoariasbravo/.astromalik-horary-local-ai/cache/models
```

El modelo cacheado realmente estaba en:

```text
/Users/eduardoariasbravo/.astromalik-horary-local-ai/cache/models/Microsoft/qwen2.5-1.5b-instruct-generic-gpu-4/v4
```

Tamano:

```text
1.3G
```

Esto encaja con la documentacion: `model_cache_dir` es configurable y el SDK puede manejar su propia cache.

Implicacion:

Para producto real conviene fijar explicitamente `model_cache_dir` para evitar ambiguedad entre cache CLI y cache de app.

### 4. El Modelo Intento Hacerse Astrologo

Problema funcional observado:

El modelo no se limito a redactar; intento reinterpretar la carta. En vez de tomar el juicio tecnico como autoridad, empezo a jugar a emitir sentencia propia:

- puso demasiado peso en advertencias;
- cambio matices;
- simplifico mal;
- convirtio una lectura compleja en un "no";
- trato la tecnica como si el fuera el motor astrologico.

Esto confirma una regla de arquitectura:

```text
El LLM no debe interpretar desde cero.
El LLM debe operar sobre un contrato cerrado.
```

Para AstroMalik, Foundry debe trabajar como editor, explicador o conversador controlado, no como juez tecnico.

## Arquitectura Implementada

Estado actualizado: 2026-05-01.

Horaria y Direcciones Primarias usan Foundry Local como runtime contextual local. OpenRouter ya no participa en el flujo de Direcciones Primarias: no hay fallback, no hay badge de OpenRouter y no se requiere API key para generar la lectura contextual de Direcciones.

Modelo por defecto:

```text
qwen2.5-7b
```

El cambio a 7B fue deliberado: `qwen2.5-1.5b` sirvio para validar el pipeline, pero la calidad editorial observada era demasiado fragil. `qwen2.5-7b` dio una lectura horaria mucho mas usable y coherente, siempre manteniendo la regla de que Swift conserva la autoridad tecnica.

### Archivos Nuevos

Clientes Swift:

```text
Sources/AstroMalik/Horary/Interpretation/HoraryFoundryClient.swift
Sources/AstroMalik/PrimaryDirections/Interpretation/PrimaryDirectionFoundryClient.swift
```

Scripts Python one-shot:

```text
scripts/foundry_horary_once.py
scripts/foundry_primary_direction_once.py
```

Tests agregados:

```text
Tests/AstroMalikTests/HoraryFoundryClientTests.swift
Tests/AstroMalikTests/PrimaryDirectionFoundryClientTests.swift
```

UI modificada:

```text
Sources/AstroMalik/Horary/Views/HoraryResultView.swift
Sources/AstroMalik/PrimaryDirections/Views/PrimaryDirectionsView.swift
Sources/AstroMalik/PrimaryDirections/Views/PrimaryDirectionDetailView.swift
```

### Flujo Actual

```text
1. Usuario calcula una consulta horaria en AstroMalik.
2. HoraryNativeEngine produce HoraryChart y HoraryJudgement.
3. HoraryResultView muestra el juicio tecnico.
4. Usuario pulsa "Generar interpretacion local".
5. HoraryFoundryClient serializa:
   - HoraryRequest
   - HoraryChart
   - HoraryJudgement
   - judgementText determinista
6. Swift lanza:
   /Users/.../Foundry Local/.venv/bin/python scripts/foundry_horary_once.py
7. Swift escribe JSON por stdin.
8. Python llama al SDK de Foundry Local.
9. Python escribe JSON final por stdout.
10. Swift decodifica HoraryAIInterpretation.
11. La UI muestra la tarjeta "Interpretacion IA local".
```

### Por Que One-Shot

Ventajas:

- No abre puertos.
- No deja procesos residentes de AstroMalik.
- Es facil de depurar.
- Mantiene la app principal en Swift.
- Respeta mejor la idea de SDK/runtime local.
- Encaja con una demo de laboratorio.

Inconvenientes:

- Cada llamada tiene coste de arranque.
- Si el modelo no esta cargado, puede tardar.
- No es la arquitectura final mas eficiente.

Arquitectura posterior posible:

- Swift llama a un binario Rust embebido.
- Rust usa SDK si el ecosistema esta suficientemente maduro.
- O Swift integra Foundry via C#/Rust helper estable.
- O Python se mantiene como herramienta empaquetada, pero con cache y modelo precalentados.

## Contrato De Datos

El script de Horaria recibe un JSON de entrada parecido a:

```json
{
  "schemaVersion": "horary-foundry-v1",
  "model": "qwen2.5-7b",
  "queryId": "UUID",
  "request": {},
  "chart": {},
  "judgement": {},
  "judgementText": "texto determinista"
}
```

El modelo no recibe libertad plena. El prompt le dice:

- no calcular posiciones;
- no calcular casas;
- no calcular dignidades;
- no recalcular aspectos;
- no contradecir el juicio tecnico;
- responder en JSON;
- producir texto sobrio en espanol.

Salida esperada:

```json
{
  "schemaVersion": "horary-foundry-v1",
  "model": "qwen2.5-7b",
  "answer": "si",
  "confidence": "alta",
  "title": "Titulo breve",
  "summary": "Resumen breve",
  "interpretation": "Texto interpretativo",
  "technicalReading": [
    "Punto tecnico"
  ],
  "cautions": [
    "Cautela"
  ],
  "generatedAt": "2026-04-30T00:00:00Z",
  "rawModelOutput": "salida original del modelo"
}
```

El script de Direcciones Primarias recibe:

```json
{
  "schemaVersion": "primary-direction-foundry-v1",
  "model": "qwen2.5-7b",
  "promptVersion": "2.0.1-foundry-qwen7b",
  "direction": {},
  "context": {},
  "systemPrompt": "...",
  "userPrompt": "..."
}
```

En Direcciones, el puente endurece los campos estructurados mas sensibles:

- `clave` se recompone desde la direccion calculada.
- `factoresConsiderados` se derivan del contexto determinista.
- `periodoActivacion.edadExacta` se alinea con la edad calculada.
- `polaridad` se decide por aspecto/estado recibido.
- `promptVersion` se impone desde Swift.

Esto deja al modelo con la parte que mejor hace: redactar `tituloPrincipal` y `textoEstructural` con el material ya calculado.

### Regla Critica De Seguridad Interpretativa

Si Swift envia:

```json
{
  "verdict": "si",
  "confidence": "alta"
}
```

el puente devuelve:

```json
{
  "answer": "si",
  "confidence": "alta"
}
```

aunque el modelo haya intentado decir otra cosa.

Esto ya fue probado con un payload real.

## Comandos Utiles

### Listar catalogo por SDK

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  "/Users/eduardoariasbravo/Developer/Foundry Local/foundry_quickstart.py"
```

### Probar script one-shot con payload guardado

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  scripts/foundry_horary_once.py \
  < /tmp/astromalik_foundry_payload.json \
  > /tmp/foundry_out.json \
  2> /tmp/foundry_err.log
```

Validar stdout:

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  -m json.tool /tmp/foundry_out.json
```

Ver logs:

```bash
tail -40 /tmp/foundry_err.log
```

### Comprobar cache CLI

```bash
export PATH="$HOME/.local/bin:$PATH"
foundry cache location
foundry cache list
```

### Comprobar cache SDK de AstroMalik

```bash
du -sh ~/.astromalik-primary-directions-local-ai/cache/models
find ~/.astromalik-primary-directions-local-ai/cache/models -maxdepth 4 -type d
```

### Comprobar desde SDK

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" - <<'PY'
from foundry_local_sdk import Configuration, FoundryLocalManager

FoundryLocalManager.initialize(
    Configuration(
        app_name="astromalik-primary-directions-local-ai",
        model_cache_dir="~/.astromalik-primary-directions-local-ai/cache/models",
        log_level="error"
    )
)
manager = FoundryLocalManager.instance
print([(m.alias, getattr(m, "id", None)) for m in manager.catalog.get_cached_models()])
for alias in ["qwen2.5-1.5b", "qwen2.5-7b"]:
    model = manager.catalog.get_model(alias)
    print(alias, model.is_cached)
PY
```

## Variables De Entorno

El cliente Swift permite ajustar rutas sin recompilar:

```text
ASTROMALIK_FOUNDRY_PYTHON
ASTROMALIK_FOUNDRY_HORARY_SCRIPT
ASTROMALIK_FOUNDRY_PD_SCRIPT
ASTROMALIK_FOUNDRY_MODEL
ASTROMALIK_FOUNDRY_MODEL_CACHE_DIR
```

Defaults actuales:

```text
ASTROMALIK_FOUNDRY_PYTHON =
/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python

ASTROMALIK_FOUNDRY_HORARY_SCRIPT =
/Users/eduardoariasbravo/Developer/AstroMalik-macOS/scripts/foundry_horary_once.py

ASTROMALIK_FOUNDRY_PD_SCRIPT =
/Users/eduardoariasbravo/Developer/AstroMalik-macOS/scripts/foundry_primary_direction_once.py

ASTROMALIK_FOUNDRY_MODEL =
qwen2.5-7b

ASTROMALIK_FOUNDRY_MODEL_CACHE_DIR =
~/.astromalik-primary-directions-local-ai/cache/models
```

La cache compartida evita duplicar descargas entre Horaria y Direcciones. Tras cachear `qwen2.5-7b`, el directorio observado ocupa aproximadamente 6 GB.

## Verificaciones Realizadas

### Build Swift

```bash
swift build
```

Resultado:

```text
Build complete
```

### Script Python

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  -m py_compile scripts/foundry_horary_once.py

"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  -m py_compile scripts/foundry_primary_direction_once.py
```

Resultado:

```text
OK
```

### Prueba Real Foundry

Se ejecuto:

```bash
"/Users/eduardoariasbravo/Developer/Foundry Local/.venv/bin/python" \
  scripts/foundry_horary_once.py \
  < /tmp/astromalik_foundry_payload.json \
  > /tmp/foundry_out.json \
  2> /tmp/foundry_err.log
```

Se valido:

```bash
python -m json.tool /tmp/foundry_out.json
```

Resultado:

- `stdout` es JSON puro.
- logs de Foundry van a `stderr`.
- claves esperadas presentes:
  - `answer`
  - `confidence`
  - `title`
  - `summary`
  - `interpretation`
  - `technicalReading`
  - `cautions`
  - `generatedAt`
  - `rawModelOutput`

### Test Determinista De Veredicto

Se modifico un payload para incluir:

```json
{
  "verdict": "si",
  "confidence": "alta"
}
```

Resultado del puente:

```text
answer= si
confidence= alta
```

Esto confirma que el puente respeta la autoridad de Swift.

### Swift Test

Se agrego:

```text
Tests/AstroMalikTests/HoraryFoundryClientTests.swift
Tests/AstroMalikTests/PrimaryDirectionFoundryClientTests.swift
```

Objetivo:

- probar JSON limpio;
- probar JSON rodeado de ruido de Foundry.
- probar Python/script faltante;
- probar timeout del proceso.

No se pudo ejecutar `swift test` en esta maquina porque el toolchain fallo antes de correr tests:

```text
no such module 'XCTest'
```

El error ocurre en todos los tests, no solo en los nuevos.

## Estado De La App

Despues de cambios se ejecuto:

```bash
scripts/package_app.sh
```

Resultado:

```text
App empaquetada en: /Users/eduardoariasbravo/Developer/AstroMalik-macOS/AstroMalik.app
```

Timestamp verificado:

```text
AstroMalik.app/Contents/MacOS/AstroMalik
Apr 30 21:35:11 2026
```

## Evaluacion Del Modelo

### `qwen2.5-0.5b`

Uso recomendado:

- smoke test;
- prueba de instalacion;
- comprobar pipeline;
- tareas muy simples.

No recomendado para:

- prosa interpretativa fina;
- dominio astrologico;
- JSON robusto;
- estilo editorial.

### `qwen2.5-1.5b`

Uso recomendado:

- demo local real;
- prueba de latencia;
- validar integracion;
- probar prompts y controles.

Limitaciones:

- estilo pobre;
- tiende a simplificar;
- puede inventar;
- puede contradecir si no se blinda;
- puede devolver JSON imperfecto;
- no entiende bien que debe actuar como editor, no como astrologo.
- no recomendado como modelo final de lectura contextual.

### `qwen2.5-7b`

Uso recomendado actual:

- lectura contextual local de Horaria;
- lectura contextual local de Direcciones Primarias;
- redaccion mas natural y coherente;
- mejor seguimiento del contrato JSON que los modelos pequenos.

Limitaciones:

- primer arranque o primera descarga puede tardar varios minutos;
- sigue pudiendo introducir tension logica si el prompt deja ambiguedad;
- no debe tener autoridad sobre calculos, sentencia o factores tecnicos;
- requiere mas disco y memoria que 1.5B.

### Candidatos Futuros

Para mejor calidad:

- `phi-4-mini`
- `phi-4-mini-reasoning`

Hipotesis:

- `phi-4-mini` podria redactar mejor y seguir instrucciones mejor.
- `qwen2.5-coder-*` podria ser util para JSON/tool-calling, pero no para prosa astrologica.

## Lecciones Arquitectonicas

### 1. Foundry Local Es Runtime, No Producto Magico

Lo importante no es que "haya IA local". Lo importante es que permite construir una capa local controlada:

- privada;
- portable;
- sin costes por token;
- sin backend;
- potencialmente empaquetable.

Pero el modelo sigue siendo un modelo. Si es pequeno, falla como modelo pequeno.

### 2. El Contrato Importa Mas Que El Prompt

El prompt ayuda, pero no basta.

Hay que cerrar el contrato:

- que campos puede tocar;
- que campos no puede tocar;
- que campos se imponen desde codigo;
- que salida es valida;
- que se hace cuando la salida no cumple.

En esta prueba, el puente impone `answer` y `confidence` desde Swift cuando existen.

### 3. Separar Calculo, Juicio Y Redaccion

Capas recomendadas:

```text
Calculo astronomico -> determinista
Juicio tecnico -> determinista / reglas
Texto doctrinal base -> plantillas / corpus
Redaccion local -> Foundry
Dialogo posterior -> Foundry con herramientas
```

El LLM puede ayudar mucho en las dos ultimas, pero no debe invadir las primeras.

### 4. No Usar Servidor Si No Hace Falta

El REST server de Foundry tiene sentido cuando:

- quieres usar OpenAI SDK directamente;
- quieres streaming por HTTP;
- varias partes de la app necesitan hablar con el mismo runtime;
- quieres herramientas externas apuntando a un endpoint local.

No tiene sentido como primera opcion si:

- quieres una app desktop limpia;
- no quieres puertos;
- no quieres procesos residentes;
- la llamada puede ser puntual;
- quieres probar SDK nativo.

### 5. Hay Que Controlar stdout/stderr

Cuando una app Swift invoca procesos locales, stdout debe ser contrato de datos.

Regla:

```text
stdout = JSON maquina
stderr = logs humanos
```

Foundry puede imprimir logs durante import/inicializacion. Hay que encapsularlo.

## Direcciones Primarias

Direcciones Primarias usa el mismo patron one-shot que Horaria:

```text
SwiftUI Direcciones
  -> PrimaryDirectionContextualInterpreter
  -> PrimaryDirectionFoundryClient.swift
  -> Process(stdin JSON / stdout JSON)
  -> scripts/foundry_primary_direction_once.py
  -> foundry-local-sdk
  -> modelo local qwen2.5-7b
```

La sustitucion es quirurgica: la llamada que antes usaba `OpenRouterClient.complete(...)` ahora llama a Foundry Local. La cache `primary_directions_interpretations` se conserva, pero el `promptVersion` pasa a `2.0.1-foundry-qwen7b` para no reutilizar lecturas antiguas.

Variables propias del flujo:

```text
ASTROMALIK_FOUNDRY_PD_SCRIPT
ASTROMALIK_FOUNDRY_PYTHON
ASTROMALIK_FOUNDRY_MODEL
```

Regla interpretativa:

```text
Foundry no calcula direcciones.
Foundry no recalcula dignidades ni aspectos.
Foundry solo redacta la lectura contextual con los datos que recibe.
```

## Proximos Pasos Recomendados

### Corto Plazo

1. Probar `phi-4-mini` como modelo de redaccion comparativa frente a `qwen2.5-7b`.
2. Cambiar progresivamente prompts de "interpretar" a "reescribir editorialmente".
3. Reducir el JSON enviado al modelo.
4. Enviar solo:
   - sentencia tecnica;
   - factores a favor;
   - factores en contra;
   - texto determinista;
   - objetivo editorial.
5. Prohibir explicitamente terminos tecnicos nuevos que no esten en input.
6. Eliminar o esconder `rawModelOutput` de UI final, mantenerlo solo para debug.

### Prompt Mejor Enfoque

El enfoque actual dice "interpreta". Eso invita al modelo a hacerse astrologo.

Mejor:

```text
Actua como editor astrologico.
No emitas juicio nuevo.
No anadas tecnica nueva.
No nombres factores que no aparezcan en el input.
Convierte el texto tecnico en una lectura clara, humana y sobria.
Mantiene el veredicto, confianza y factores dados.
```

### Medio Plazo

1. Crear un modo "editorial local" generico para varias pantallas.
2. Usar Foundry para:
   - resumir;
   - explicar;
   - convertir tabla tecnica en texto;
   - responder preguntas sobre datos ya calculados.
3. Usar herramientas deterministas:
   - el modelo pregunta;
   - Swift/Python calcula;
   - el modelo explica.
4. Evaluar streaming.
5. Evaluar empaquetado del runtime.

### Largo Plazo

1. Sustituir Python por Rust si aporta:
   - binario unico;
   - empaquetado limpio;
   - menor friccion de distribucion;
   - control de permisos;
   - estabilidad.
2. Investigar SDK nativo mas cercano a Swift:
   - C# no es ideal para macOS Swift;
   - Rust podria ser mejor puente;
   - Python es excelente laboratorio.
3. Crear un "AI Runtime Adapter" comun para toda la app:
   - Foundry local;
   - modo sin IA;
   - seleccion de modelo.

## Decision Actual

Mantener la integracion como experimental.

No venderla como interpretacion astrologica final.

Usarla como banco de pruebas para:

- privacidad local;
- SDK Foundry;
- cache de modelos;
- latencia local;
- control de salida;
- arquitectura de IA local en AstroMalik.

La parte astrologica ha demostrado algo muy util: el modelo pequeno no debe tener autoridad tecnica. Pero Foundry Local, como infraestructura, si merece seguir explorandose.
