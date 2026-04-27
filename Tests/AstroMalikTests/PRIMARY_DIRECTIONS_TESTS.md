# Primary Directions Golden Tests

Estos tests son una red de seguridad de regresion para el motor actual de
Direcciones Primarias. No intentan decidir si los valores astrologicos son
"mejores"; congelan exactamente lo que calcula hoy el codigo para detectar
cambios involuntarios durante refactors.

## Que cubren

- Total exacto de direcciones por carta.
- Las 10 primeras direcciones ordenadas por `abs(arc)`: promissor,
  significator, aspecto, arco, edad estimada y tipo.
- Espéculo Regiomontano de planetas, ASC y MC: RA, declinacion, polo, Q y W.
- RAMC y oblicuidad usados por el calculo.

Tolerancias:

- Angulos: `1e-4` grados.
- Edades: `1e-3` años.
- Counts: igualdad exacta.

## Regenerar el baseline

Si un cambio intencional modifica el algoritmo, regenera el JSON con:

```sh
swift scripts/generate_pd_golden.swift
```

Despues ejecuta:

```sh
swift test
```

Nunca regeneres `PrimaryDirectionsGolden.json` sin entender primero que
cambio. El baseline se acepta como verdad solo cuando el cambio del motor es
deliberado y revisado; si se actualiza a ciegas, los tests dejan de proteger
contra regresiones.

## Cartas de control

- Eduardo: caso real conocido, Madrid, 11 octubre 1976 20:33 local
  (`Europe/Madrid`). Sirve como carta de referencia principal con ASC en
  Geminis, Sol en Libra, Luna en Tauro y Saturno en Leo.
- Buenos Aires: hemisferio sur y latitud media-baja, 15 marzo 1985 14:00 local
  (`America/Argentina/Buenos_Aires`). Cubre signos y polos con latitud
  geografica negativa.
- Reykjavik: latitud alta, 1 enero 1990 06:30 local (`Atlantic/Reykjavik`).
  Cubre formulas cerca de zonas de dominio numericamente delicadas.

Baseline actual:

- Eduardo: 155 direcciones.
- Buenos Aires: 124 direcciones.
- Reykjavik: 163 direcciones.

Ninguna de las tres cartas produce 0 direcciones con el motor actual.
