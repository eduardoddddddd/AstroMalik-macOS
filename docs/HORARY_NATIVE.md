# Horaria Nativa En Swift

## Estado

Horaria se calcula por defecto dentro de AstroMalik-macOS con `HoraryNativeEngine`. El antiguo paquete Python `horaria` queda como modo legado/fallback, no como dependencia normal de la app.

## Contrato

La app conserva el contrato que ya consumía la UI:

- `HoraryRequest`
- `HoraryResponse`
- `HoraryChart`
- `HoraryJudgement`

Los JSON antiguos siguen abriendo porque los campos nuevos del juicio son opcionales.

Campos estructurados nuevos:

- `verdict`: `si`, `no`, `no_todavia`, `dudoso`, `requiere_mediacion`
- `confidence`: `alta`, `media`, `baja`
- `mainReason`
- `supportingFactors`
- `blockingFactors`
- `technicalWarnings`
- `timingRange`

La ruta de perfección añade:

- grados hasta perfección
- grados hasta cambio de signo
- cuerpo más rápido
- si perfecciona antes del cambio de signo
- confianza técnica de la ruta

## Doctrina V1

Alcance tradicional estricto:

- siete planetas tradicionales
- Nodo Norte verdadero
- Parte de Fortuna y Parte del Espíritu
- casas Regiomontanus
- aspectos mayores: conjunción, sextil, cuadratura, trígono y oposición
- dignidades esenciales: domicilio, exaltación, triplicidad, término, decanato, detrimento, caída y peregrino
- dignidad accidental básica: angularidad, retrogradación, combustión/rayos/cazimi y velocidad
- hora planetaria y acuerdo horario
- radicalidad por advertencias activas
- recepción simple y mutua
- perfección directa, translación y colección básica

## Regla Crítica De Luna Fuera De Curso

La Luna está fuera de curso si no perfecciona aspecto mayor antes de salir del signo.

El motor nativo aplica la misma condición a la perfección: si la Luna aplica a un planeta pero el aspecto exacto ocurre después del cambio de signo, esa ruta no cuenta como perfección lunar válida.

Esta regla corrige el fallo detectado en el experimento Python: una carta podía mostrar simultáneamente `luna_vacia` y “perfección directa” por esa misma Luna aunque el aspecto exacto ocurriera ya en el signo siguiente.

## Motor Legado Python

`HoraryEngine.calculate` usa Swift por defecto y solo cae a Python si el motor nativo falla inesperadamente.

Variables:

```bash
ASTROMALIK_HORARIA_ENGINE=swift   # fuerza Swift, sin fallback
ASTROMALIK_HORARIA_ENGINE=python  # fuerza Python legacy
ASTROMALIK_PYTHON_PATH=/ruta/a/python3
ASTROMALIK_HORARIA_PATH=/ruta/al/repo/horaria
```

La vista de diagnóstico de Horaria sigue mostrando disponibilidad del modo Python legacy. No es necesaria para calcular consultas en el flujo normal.

## UI

`HoraryResultView` usa los campos estructurados cuando existen:

- veredicto y confianza arriba
- motivo principal
- ruta de perfección y tiempo simbólico
- significadores
- Luna y curso
- factores a favor
- factores en contra
- notas técnicas

Si una consulta guardada solo tiene `judgementText` antiguo, se renderiza el texto legacy por secciones.

## Tests De Regresión

`HoraryParityTests` ya no exige paridad literal con Python. Ahora valida:

- el motor nativo genera juicio estructurado
- las consultas guardadas actuales calculan sin mutar la base local
- JSON legacy decodifica sin campos estructurados
- Luna vacía en último grado no puede perfeccionar después de cambiar de signo
- sin perfección + Luna vacía no devuelve un “sí” limpio

