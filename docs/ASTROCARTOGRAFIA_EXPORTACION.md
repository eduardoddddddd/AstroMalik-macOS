# Astrocartografía — exportaciones (F6)

Tres salidas, un solo modelo. PDF, nota de Joplin y CLI se generan desde `AstroExportDocument`
(`Sources/AstroMalik/Astrocartography/Export/AstroExportDocument.swift`), así que no pueden
contradecirse. Seguimiento de la fase: [ASTROCARTOGRAFIA_SEGUIMIENTO.md](ASTROCARTOGRAFIA_SEGUIMIENTO.md).

## Principios

- **Solo por acción explícita.** Nada se genera, envía ni guarda hasta que el usuario pulsa un botón o ejecuta la CLI. Los lugares guardados no autorizan exportar.
- **Sin recalcular.** El documento recoge los valores reales del cálculo (flags devueltos, procedencia, diagnósticos, distancias con su cota, relocación). Ninguno se redondea al guardarlo; el redondeo es solo de presentación.
- **Sin LLM ni red obligatoria.** La única llamada de red posible es el mapa base de Apple del PDF, opcional.
- **Sin interpretar de más.** Los textos son las lecturas de F5; si falta una, queda un aviso, nunca texto inventado.

## Documento versionado (`schemaVersion: 1`)

JSON con claves ordenadas, **sin marca de tiempo**. Misma carta, lugar y recursos ⇒ mismos bytes.

| Campo | Contenido |
|---|---|
| `schemaVersion`, `kind` | `1`, `astromalik.astrocartography` |
| `chart` | id, nombre, fecha/hora/zona/lugar de nacimiento, sistema de casas, ASC/MC/cúspides natales |
| `instant` | JD y escala temporal (`utcApproximatedAsUT1`) |
| `method` | contrato, convención, algoritmos de líneas/distancia/relocación, efemérides (fuente y versión), radio de la esfera, tolerancia, diagnósticos Swiss |
| `editorial` | versión de los textos y estado de revisión (ausente si no cargaron) |
| `policy` | umbrales cerca/regional del programa |
| `chartLines` | las 40 líneas: AR, declinación, flags Swiss devueltos, si tienen trazo, diagnósticos |
| `place` | (opcional) nombre, coordenadas, origen, zona, titular, temas, las 40 distancias con cota y punto más próximo, relocación o su error, lecturas de las líneas cercanas, lecturas ausentes |
| `warnings` | zona no verificada, fallback de efemérides, relocación no disponible, textos ausentes, líneas sin distancia |
| `disclaimer` | lectura simbólica; bandas no son intensidad |

Cambios de campos compatibles añaden claves; uno incompatible sube `schemaVersion`.

## PDF (F6.1, F6.2)

`AstrocartographyReportBuilder` + plantilla `Resources/Reports/templates/astrocartography.html`, con el tema visual común. Secciones: portada, resumen y temas, mapa de líneas, lecturas, carta relocada (frente a la natal), distancias a las 40 líneas, método y límites (con advertencias y tabla de líneas). Como el resto de informes de la app, es una página continua larga.

### Mapa

La figura es un SVG determinista (`AstroMapSVGRenderer`) con la misma proyección Web Mercator (±85.0511°) que el mapa en pantalla. Con un lugar analizado, las líneas a ≤ umbral regional van en trazo grueso y el resto atenuado; si no hay ninguna cerca, todas pesan igual. El ángulo se distingue por el trazo y el planeta por el color.

**Mapa base de Apple (opcional, casilla en la UI).** Necesita conexión. Hallazgo medido: una sola petición de `MKMapSnapshotter` para `MKMapRect.world` **no devuelve el mundo entero** (solo ±90° de longitud y al doble de escala), por lo que las líneas habrían quedado desalineadas. Se captura el mundo en cuatro cuadrantes, cada uno se coloca con el propio `Snapshot.point(for:)` de MapKit y se **verifica la escala** de cada uno; si algo no cuadra, se descarta el mapa base. Alineación comprobada visualmente con ciudades de referencia y sin costura entre cuadrantes. El snapshotter no dibuja atribución, así que el informe imprime «Mapa base: Apple Maps…» junto a la figura siempre que se usa.

**Fallback.** Sin conexión, tras 20 s, con escala inesperada o si el usuario desmarca la casilla, el PDF se genera igual con las líneas sobre una cuadrícula de 30° y la figura dice «Sin mapa base: <motivo>». Nunca se bloquea ni se falla por el mapa.

## Joplin (F6.3)

Botón «Exportar a Joplin» en la pestaña Lugar. Crea una nota Markdown con el mismo contenido (`AstroExportMarkdown`) en el cuaderno configurado (por defecto `codex`) del Web Clipper **local** (127.0.0.1), con etiquetas `astrocartografía`, `astromalik` y `lugar` (las crea si no existen, sin duplicar). Mostrado el cuaderno destino antes de pulsar. Si falla, el error se muestra y no se reintenta solo. El PDF sigue usando la preferencia general «subir PDF a Joplin» de Ajustes, que ya existía y es del usuario.

## CLI (F6.4)

```bash
astromalik-cli astrocartography --chart "Edu" [--place "Madrid" | --lat 40.4168 --lon -3.7038]
                                [--near-km N] [--regional-km N] [--no-readings] [--format json|markdown]
                                [--output stdout|file:/ruta|joplin:Cuaderno --allow-network]
```

Local, sin red y determinista; no abre `corpus.db`. Errores: lugar no encontrado, coordenadas o umbrales inválidos y combinaciones incompatibles salen con código 1 (parámetros incorrectos en el parser, 64); `joplin:` sin `--allow-network` sale con 6, como el resto de la CLI. Con varios lugares del catálogo para `--place` se usa el primero y se avisa en `warnings`.

## Límites

- El PDF no se ha visto en una impresora ni en lector externo; se revisó renderizado a imagen y con PDFKit.
- Cuatro cuadrantes cuestan cuatro peticiones a Apple; el resultado se comprime en JPEG (calidad 0.82) para no inflar el PDF.
- El documento exporta un lugar por vez. Una exportación comparativa de varios lugares no está hecha.
- Los textos y su revisión son los de F5; el informe no añade interpretación nueva.
