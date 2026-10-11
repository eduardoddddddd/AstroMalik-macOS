# Recursos de datos del motor (fuera de los parches)

## `timezone_boundaries.bin` — límites de zonas horarias (F3c)

- **Fuente:** [timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder),
  versión **2026d** (16-09-2026), asset `timezones-with-oceans.geojson.zip`
  (55 874 703 bytes, SHA-256 `e391c92c7b90339c3afe8558082b4532b8d9afc9daad68da31f4569a1ca61034`,
  comprobado contra el `digest` publicado en GitHub). Conjunto completo (no el
  que funde zonas iguales desde 1970) e incluye océanos.
- **Licencia:** ODbL 1.0 (datos derivados de OpenStreetMap; © colaboradores de
  OpenStreetMap). Este fichero es una base de datos derivada y se ofrece bajo
  la misma licencia ODbL.
- **Simplificación:** mapshaper 0.7.68, conservando la topología entre zonas:

  ```bash
  mapshaper combined-with-oceans.json -simplify 3% keep-shapes planar -o simp-3.json precision=0.0001 format=geojson
  python scripts/build-timezone-boundaries.py simp-3.json engine/resources/timezone_boundaries.bin "timezone-boundary-builder 2026d timezones-with-oceans, mapshaper -simplify 3% keep-shapes planar, precision 0.0001"
  ```

- **Resultado:** 444 zonas, 1 095 polígonos, 253 886 puntos, 2 067 239 bytes.
- **Validación (2026-10-11):** 20 078 puntos (20 000 al azar entre −60° y 75°
  de latitud, las 48 ciudades del catálogo y 30 casos de frontera) cruzados con
  los datos completos sin simplificar: 1 discrepancia en los puntos al azar,
  ninguno sin zona y todas las ciudades y fronteras correctas (Buenos Aires,
  Reykjavik, Ceuta/Melilla, Canarias, Irún/Hendaya, Badajoz/Elvas, El
  Paso/Ciudad Juárez, Indianápolis…). Con 1 % de vértices fallaban Melilla y El
  Paso. El único solape del conjunto es Asia/Shanghai–Asia/Urumqi (Xinjiang),
  intencionado en los datos: se devuelve sin verificar con ambas candidatas.
- La zona IANA aporta el historial de cambios de hora; los límites son los
  actuales.
