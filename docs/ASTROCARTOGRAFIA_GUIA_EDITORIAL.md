# Astrocartografía — guía editorial de lecturas (F5)

Versión editorial: `astrocartography-readings-v1` · 2 de octubre de 2026.
Recurso: [`readings_v1.json`](../Sources/AstroMalik/Resources/Astrocartography/readings_v1.json).
Generador: [`scripts/build_astrocartography_readings.py`](../scripts/build_astrocartography_readings.py).
Seguimiento de la fase: [ASTROCARTOGRAFIA_SEGUIMIENTO.md](ASTROCARTOGRAFIA_SEGUIMIENTO.md).

## 1. Alcance y estado de revisión

- 40 lecturas: 10 cuerpos (`PLANET_LIST`) × 4 ángulos (ASC, DSC, MC, IC).
- Texto en castellano, redacción original de AstroMalik. No se copia ni se traduce prosa de terceros.
- **Estado de revisión: revisado por el usuario el 02/10/2026** («muy bien»). Redactadas por IA y
  aceptadas tras lectura humana; `reviewStatus = revisado-por-el-usuario-2026-10-02`, vigilado por test.
  La atribución a fuentes (sección 5) sigue sin verificarse con fuente primaria.
- El contenido vive en un recurso JSON versionable, **no en `corpus.db`**. Promoverlo al corpus es una
  decisión posterior del integrador, con migración propia.
- Cero llamadas a LLM o red en ejecución: las lecturas son datos locales.

## 2. Claves y nombres estables

Clave: `CUERPO:ÁNGULO` con los `rawValue` de `AstroBody` y `AstroAngle`, p. ej. `VENUS:DSC`, `SATURNO:IC`.
Orden canónico: cuerpos en orden de `PLANET_LIST`, ángulos ASC, DSC, MC, IC. La identidad completa de línea
(`AstroLineID.stableKey`) añade la convención astronómica, de modo que cambiar la convención no reutiliza
lecturas por accidente.

Los títulos usan los nombres reales («Venus en el Descendente: …»), nunca marcadores internos.

## 3. Estructura de cada lectura

Cuatro capas obligatorias, todas visibles siempre (sin controles de expandir):

| Capa | Pregunta que responde |
|---|---|
| `mechanism` — Qué suele activar | Qué función planetaria se pone en juego en ese ángulo |
| `potential` — Potencial | Qué puede favorecer cuando se vive con coherencia |
| `shadow` — Sombra | Qué dificultades o excesos son típicos |
| `practice` — Cómo trabajarlo | Qué actitud ayuda, y recordatorio de que el efecto depende de la carta natal |

Marco por ángulo (coherente en todas las lecturas):

- **ASC**: cuerpo, identidad, presencia y modo de llegar al lugar.
- **DSC**: los otros: pareja, socios, interlocutores, adversarios, acuerdos.
- **MC**: vida pública, vocación, reputación, metas visibles.
- **IC**: hogar, raíces, familia, intimidad, base interior.

MC/IC describen culminación, no visibilidad sobre el horizonte; los textos no lo afirman.

## 4. Estilo y límites del lenguaje

- Condicional y tendencia: «suele asociarse», «puede favorecer», «existe el riesgo». Nada de certezas.
- Ninguna lectura es «buena» o «mala» en bloque: toda capa de potencial tiene su sombra y viceversa.
- Cada `practice` recuerda que la lectura se matiza con la carta natal, el planeta natal o las decisiones.
- Sin lenguaje temporal de tránsito ni predictivo.
- Sin consejos médicos, legales o financieros; sin promesas de éxito, amor, dinero o salud.
- Las distancias (km) y las bandas «cerca / regional / lejos» son **parámetros de producto**; ningún texto
  los menciona ni se intensifica o atenúa por ellos.

### Validación automática (en Swift y en el generador)

Se rechaza una lectura si:

- falta cualquiera de las 40 claves, hay duplicados o la clave no coincide con su cuerpo y ángulo;
- tiene una capa vacía, ningún `sourceReferences`, o menos de **650 caracteres** en total
  (las lecturas actuales miden entre 715 y 963; el umbral se fijó sobre lo realmente redactado, no se rellenó texto);
- contiene lenguaje prohibido (raíces, sin distinguir mayúsculas): `ahora`, `hoy`, `este momento`,
  `actualmente`, `siempre`, `nunca`, `destino`, `garantiz…`, `inevitabl…`, `maldici…`, `condena`,
  `sufrirás`, `ocurrirá`, `seguro que`.

La lista está en `AstrocartographyReadingLibrary.forbiddenPatterns` y en el generador; un test comprueba que coinciden.
Estas reglas detectan fallos obvios; no sustituyen la lectura humana.

## 5. Fuentes y derechos

- Texto: redacción original. Las fuentes se consultan para principios, no para prosa.
- Naturaleza de los planetas: Ptolomeo, *Tetrabiblos* I (dominio público), como fuente de principios.
- Ángulos: tradición de casas angulares. El método de líneas angulares sobre el mapa se atribuye a Jim Lewis
  (década de 1970); solo se usa la idea de las líneas, no su texto. **Pendiente de verificar con una fuente
  primaria durante la revisión humana** (obra y año exactos).
- No se reutilizan los textos de sinastría ni de tránsitos como si describieran astrocartografía.
- No se incorpora prosa de páginas comerciales contemporáneas. Si el revisor humano añade una fuente nueva,
  debe registrarla en `sourceReferences` con su estado de derechos.

## 6. Checklist del revisor humano (G5)

- [x] (02/10/2026, usuario) Leer las 40 lecturas completas en la app (carta de prueba, lugar cercano a varias líneas).
- [ ] Comprobar que ninguna copia o parafrasea de cerca una obra comercial.
- [ ] Confirmar que ninguna capa es fatalista, determinista ni da consejo médico/legal/financiero.
- [ ] Verificar equilibrio: ninguna línea es solo «buena» o solo «mala».
- [ ] Revisar la atribución a Jim Lewis y los capítulos de Ptolomeo citados.
- [ ] Cambiar `reviewStatus` en el generador, regenerar, actualizar el test que lo vigila y anotarlo en el seguimiento.

## 7. Cómo modificar un texto

1. Editar el texto en `scripts/build_astrocartography_readings.py` (la fuente de verdad).
2. `python3 scripts/build_astrocartography_readings.py` (determinista; falla si algo incumple la guía).
3. `swift test --filter AstrocartographyReadingTests`.
4. Si cambia el contenido, subir `EDITORIAL_VERSION` para que exportaciones y guardados distingan versiones.
5. Regenerar la app con `scripts/package_app.sh`.

## 8. Cómo se conecta con los lugares (F5.3)

- `AstrocartographyReadingLibrary` carga y valida el recurso; `AstroReadingCatalog` lo envuelve y degrada a
  `.unavailable(motivo)` si falla, mostrando un fallback por línea.
- `AstroPlaceReadingBuilder` toma el `LocationAnalysis` ya calculado (nada se recalcula) y devuelve, ordenadas por
  distancia, las líneas dentro del umbral regional con su banda y, **por separado**, su lectura. Las más lejanas
  se cuentan, no se listan. La cobertura se calcula sobre **todas** las líneas definidas en el lugar, también
  ocultas por filtros o lejanas.
- Si falta una clave: aviso visible por línea y cobertura incompleta con la lista de claves sin texto. Nunca se
  inventa texto ni se oculta la línea.
- `AstrocartographyReading` (contrato v1) se mantiene intacto: `library.reading(for:)` proyecta sobre él para
  que F6 exporte sin tocar el contrato.
