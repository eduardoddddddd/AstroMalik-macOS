# Guía de Curación del Corpus de Direcciones Primarias

## Política

La Capa 1 del módulo de Direcciones Primarias es doctrinal y determinista. No se genera texto con LLM para poblar `primary_direction_meanings`.

Una fila solo puede pasar a `populated = 1` cuando el texto haya sido verificado contra una edición real y localizable de la fuente.

## Campos obligatorios al poblar

- `clave`: formato `PROMISSOR_SIGNIFICADOR_ASPECTO`
- `texto_corto`: resumen breve y fiel
- `texto_largo`: desarrollo más completo, también fiel y verificable
- `fuente_nombre`: obra o autor normalizado
- `fuente_referencia`: referencia bibliográfica precisa
- `populated = 1`
- `calidad`: puntuación editorial de 1 a 10

## Formato de referencia

Usar siempre una referencia suficientemente exacta para volver a la fuente:

- Autor u obra
- Libro o tractatus
- capítulo, consideración o sección concreta
- edición usada si es relevante
- página(s) si están disponibles

Ejemplos válidos:

- `Lilly, Christian Astrology, Book III, cap. XXIII, Regulus 1985, pp. 645-648`
- `Bonatti, Liber Astronomiae, Tractatus X, Consideratio 12, edición X`
- `Morin, Astrologia Gallica, Libro 21, sección sobre direcciones`

Ejemplos no válidos:

- `Lilly, cap. LXVI`
- `Bonatti, Tractatus X`
- `Morin`

## Criterio para `calidad`

- `10`: cita o traducción fiel revisada y totalmente trazable
- `8-9`: resumen editorial muy sólido, con referencia exacta y contraste suficiente
- `6-7`: material útil pero pendiente de una segunda revisión editorial
- `1-5`: no usar con `populated = 1`; conservar en trabajo interno fuera de la tabla final

## Invariantes que no se deben romper

- `populated = 0` implica `texto_corto IS NULL`
- `populated = 0` implica `texto_largo IS NULL`
- `populated = 0` implica `fuente_nombre IS NULL`
- no debe haber atribución parcial ni texto “provisional” dentro de filas no pobladas

## Alcance actual

La tranche seed inicial de 29 claves ya no es el límite operativo del corpus. La migración `006_populate_pd_classical_corpus.sql` incorporó 165 interpretaciones clásicas pobladas desde Lilly, `Christian Astrology`, Libro III, con informe de cobertura en `corpus_sources/reports/pd_corpus_population_report.md`.

Para nuevas tandas editoriales:

- no ampliar claves sin definir primero fuente primaria y alcance
- conservar el informe de población junto al SQL
- preferir textos breves, trazables y doctrinalmente sobrios frente a síntesis especulativas
- mantener separada la lectura contextual LLM de la Capa 1 clásica
