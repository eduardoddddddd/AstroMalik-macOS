# Entradas F2a, no resultados de referencia

`manifest-template.json` define peticiones y argv; sus expected solo nombran
archivos que se producirán **en el Mac**. No contiene respuestas Windows
reclasificadas como golden. Las políticas de comparación se revisan por ruta.

- Eduardo, Buenos Aires y Reykjavik son las cartas auténticas de F1. Sus
  longitudes originales Moshier se conservan como entrada completa para ambos
  CLI; un CLI `natal` lee esa carta y compone su lectura/corpus, no recalcula el
  nacimiento. `natal.compute` sí recalcula por la fachada F3.
- `madrid-war1940-control` usa el control temporal F1 `madrid-1940-7`,
  1940-07-15 12:00 Europe/Madrid, con las coordenadas de Madrid de Eduardo.
  Es un control de hora de guerra de 1940, no una biografía ni un caso de la
  Guerra Civil 1936–1939. No hay referencia 1936–1939 en los inputs F1/upstream.
- La sinastría usa Eduardo y Buenos Aires, dos cartas F1 existentes. No se
  atribuye a personas una relación ficticia.
- Horaria reproduce la petición de prueba F3; rectificación reproduce el caso
  sintético de `RectificationEngineTests` y sus parámetros observados en F3.
  Los eventos no pertenecen a Eduardo.
- Referencia fija: 2026-10-04T00:00:00Z; mes 2026-10; tránsitos seis meses
  hasta 2027-04-04T00:00:00Z. `TZ=UTC` en Mac y Windows es obligatorio:
  el CLI original interpreta `YYYY-MM-DD` mediante `Calendar.current`.

## Exportación real

`scripts/mac/gen-fixtures.sh` requiere CLI original baseline y RPC F3
compilados por separado. Los repos y ejecutables se indican con rutas absolutas:

```sh
bash scripts/mac/gen-fixtures.sh \
  --template fixtures/inputs/f2/manifest-template.json \
  --output fixtures/mac/f2 \
  --cli /ruta/baseline/.build/release/astromalik-cli \
  --rpc /ruta/f3/astromalik-engine \
  --cli-repo /ruta/baseline --rpc-repo /ruta/f3 \
  --backend-probe /ruta/backend-observado.json
```

La carpeta de salida debe ser nueva. Se abre exclusivamente una base temporal;
F3 importa las cartas y CLI recibe `--user-db` explícito. `--no-network`, JSON,
stdout y narrativa local se exigen en cada CLI. Se conservan stdout/stderr,
progreso, hello, hashes de binarios/recursos, commits y la plantilla original.
`manifest.json` y `SHA256SUMS` aparecen después del lote completo. Un fallo deja
`failure.json` y no valida la referencia. Los hashes de recursos son del repo
fuente; hello registra el backend configurado del host. `--backend-probe`
adjunta flags realmente observados en el original; no se presenta hello como
una medición de los flags efectivos del CLI.

El exportador rechaza Windows. Las capturas se registran aparte mediante
`scripts/mac/capture-screen.py`, después de navegar y comprobar la app real.
