# Astrocartografía — informe de la fase 7

Fecha: **03/10/2026**, Europe/Madrid. Máquina: **Mac15,13**, macOS **27.0.1 (26A434)**. Configuración de las pruebas: build **debug** de Swift, no release. No es un certificado para otros Macs.

Este informe no repite la autoría de las fases 0–6. Comprueba, con pruebas propias, que el motor, la natal y los cambios de carta no se mezclan, y deja medido el tiempo del cálculo.

## Regresión

```bash
python3 scripts/check_swiss_access.py
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

- Guard Swiss: OK (Sources + Tests, solo la fachada).
- `git diff --check`: sin errores de espacios.
- Suite completa: **522 ejecutados, 1 omitido, 0 fallos**, **41,169 s**. Antes de estas cinco pruebas eran 513. El omitido ya existía; no es un fallo nuevo. La suite incluye la carta natal de referencia y el resto de motores, no solo astrocartografía.

## Concurrencia y cartas que se sustituyen

`AstrocartographyPhase7HardeningTests`:

- Una ráfaga de cartas distintas sobre el servicio con cancelación. Cada resultado aceptado coincide con el cálculo en serie de **su** petición. Al terminar, una carta en reposo coincide con el motor.
- Una carta en vuelo, bloqueada a propósito, se sustituye por otra. La primera termina en cancelación. La publicada es la segunda y coincide con el motor.
- Veinte pares simultáneos de carta natal (`AstroEngine.computeNatalChart`) y astrocartografía, en cinco instantes y lugares sintéticos. Ángulos, longitudes, casas y retrogradación natales coinciden con la pasada en serie. La astrocartografía coincide con la suya. No se usaron cartas personales.

## Invariantes en seis instantes

JD 2378496.5 (1800-01-01), 2415020.0, 2451545.0, 2488069.5, 2600000.0 y 2816787.0. En todos: 10 cuerpos, 40 líneas, procedencia Swiss, tiempo sidéreo en `[0, 360)` y coordenadas dentro de rango. MC e IC de cada cuerpo quedan a 180° (tolerancia 1e-6), medido en las longitudes de la línea, no llamando otra vez a la fórmula del meridiano. En 1800-01-01 el Sol sigue declarando el fallback sin fichero Swiss.

## Rendimiento

Objetivo del plan: menos de 1 s para motor y geometría de diez cuerpos, en caliente, sin red ni mapa. Medición dentro de la suite completa, un calentamiento y 31 muestras, JD 2451545.0, tolerancia 1 km:

| | |
|---|---|
| p50 | 1,285 ms |
| p95 | 1,364 ms |
| Vértices | 5936 |
| ¿p95 < 1 s? | sí, en este Mac y en debug |

El percentil usa los índices 15 y 29 de la serie ordenada. La geometría pesada sigue en una tarea separada, después de soltar el candado Swiss. No se midió la app en pantalla ni se ejecutó Thread Sanitizer.

## Empaquetado

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/package_app.sh
codesign --verify --deep --strict AstroMalik.app
stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %z' AstroMalik.app/Contents/MacOS/AstroMalik
```

- Build release del paquete: **94,65 s**, exit 0.
- Firma ad-hoc: `codesign --verify --deep --strict` correcto.
- Binario: **2026-10-03 15:46:44 +0200**.
- En el bundle están `readings_v1.json` y la plantilla `astrocartography.html`.
- `astromalik-cli --help` del release menciona el comando `astrocartography`.
- Arranque: no había otra instancia. `open` dejó el proceso 5101 vivo (estado `S`, 3 s). Se cerró después con AppleScript. No se dejó la ventana abierta.

## Qué no cierra esta fase

- El cambio de pestaña del panel (Guía, Mapa, Lugar…) sigue lento según el reporte del 03/10/2026. No está diagnosticado ni resuelto. El presupuesto de 1 s es del motor, no de esa interacción.
- No hay smoke visual nuevo de MapKit en la app abierta por el usuario.
- No hay prueba en un Mac con macOS 14 físico, ni TSan, ni Joplin real, ni PDF en un lector externo.
- El 03/10/2026 el usuario pidió la release en GitHub. Se publica como **v1.2.0**. El ZIP universal lo adjunta el workflow al tag, no un paquete local.
