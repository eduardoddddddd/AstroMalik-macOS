# Prompt: Scraping y generación de corpus de tránsitos para AstroMalik

## Tarea

Necesito ampliar mi corpus de interpretaciones de tránsitos astrológicos. Actualmente tengo 745 textos de la fuente "Grupo Venus" en mi base SQLite `corpus.db`. Quiero llegar a cobertura completa: 10 planetas en tránsito × 12 puntos natales (10 planetas + ASC + MC) × 5 aspectos = 600 combinaciones.

Tu trabajo:
1. Buscar en la web interpretaciones de tránsitos de fuentes abiertas de calidad.
2. Para cada combinación planeta-aspecto-punto natal, **redactar un texto original en castellano** basándote en múltiples fuentes consultadas (NO copiar textualmente de ninguna fuente).
3. Generar un archivo SQL con todos los INSERTs.

---

## Fuentes a consultar (por orden de calidad)

Busca interpretaciones en estas webs para cada combinación:
- cafeastrology.com/transitaspects/
- astrologyking.com/transits/
- astrolibrary.org
- astro.com/astrology (textos de Liz Greene/Robert Hand si son accesibles)
- skyscript.co.uk

Para cada aspecto, consulta al menos 2-3 fuentes, sintetiza las ideas principales y redacta un texto ORIGINAL en castellano que capture la esencia del tránsito.

---

## Estructura de la base de datos

```sql
CREATE TABLE interpretaciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    clave TEXT NOT NULL,
    tipo TEXT NOT NULL,
    texto_largo TEXT,
    texto_corto TEXT,
    fuente_nombre TEXT,
    calidad INTEGER DEFAULT 5
);
```

## Convención de claves

Patrón: `<PLANETA_TRANSITO>_tr_<PLANETA_NATAL>_<ASPECTO>`

### Identificadores EXACTOS de planetas:
SOL, LUNA, MERCURIO, VENUS, MARTE, JUPITER, SATURNO, URANO, NEPTUNO, PLUTON

### Identificadores EXACTOS de aspectos:
CONJUNCION, SEXTIL, CUADRADO, TRIGONO, OPOSICION

### Puntos angulares:
ASC, MC

### Ejemplos:
```
SATURNO_tr_SOL_CONJUNCION
JUPITER_tr_LUNA_TRIGONO
URANO_tr_ASC_CUADRADO
NEPTUNO_tr_MC_OPOSICION
```

---

## Criterios de redacción

- Castellano de España, tuteo (tú, no usted).
- Tono profesional pero accesible. Directo sobre aspectos difíciles (no suavizar cuadraturas u oposiciones).
- Cada texto debe tener entre 150 y 500 palabras.
- Estructura interna sugerida para cada texto:
  1. Naturaleza general del tránsito (qué energías se cruzan)
  2. Manifestaciones concretas en la vida (trabajo, relaciones, salud, psicología según aplique)
  3. Duración y ritmo (los tránsitos lentos duran meses/años, los rápidos días)
  4. Consejo práctico o actitud recomendada
- NO usar lenguaje temporal como "ahora", "en este momento", "este periodo" — estos textos se muestran como referencia permanente del aspecto.
- SÍ usar frases como "cuando este tránsito está activo", "durante la vigencia de este aspecto", "mientras dura esta influencia".


## Diferenciación por planeta en tránsito

Ajusta el tono y contenido según el planeta:

- **Sol/Luna/Mercurio/Venus**: tránsitos rápidos (días). Textos más breves (150-250 palabras). Énfasis en efectos inmediatos y cotidianos.
- **Marte**: tránsito medio (semanas). Textos de 200-300 palabras. Énfasis en acción, conflicto, energía.
- **Júpiter**: tránsito medio-largo (meses). 250-400 palabras. Expansión, oportunidades, excesos.
- **Saturno**: tránsito largo (meses). 300-500 palabras. Estructura, pruebas, maduración, responsabilidad.
- **Urano**: tránsito largo (1-2 años). 300-500 palabras. Ruptura, liberación, cambio repentino, innovación.
- **Neptuno**: tránsito largo (2-3 años). 300-500 palabras. Disolución, espiritualidad, confusión, creatividad, engaño.
- **Plutón**: tránsito muy largo (2-5 años). 300-500 palabras. Transformación profunda, poder, crisis, regeneración.

---

## Formato de salida SQL

Genera un archivo SQL ejecutable. Ejemplo:

```sql
-- Corpus de tránsitos para AstroMalik
-- Fuentes consultadas: Café Astrology, Astrology King, AstroLibrary
-- Textos originales redactados en castellano
-- Generado: [fecha]

BEGIN TRANSACTION;

INSERT INTO interpretaciones (clave, tipo, texto_largo, texto_corto, fuente_nombre, calidad)
VALUES (
    'SATURNO_tr_SOL_CONJUNCION',
    'transito',
    'Cuando Saturno transita en conjunción con tu Sol natal, se inicia un periodo de consolidación y prueba que afecta al núcleo de tu identidad. Este tránsito, que dura varias semanas con orbe estrecho y meses con orbe amplio, marca el comienzo de un nuevo ciclo saturnino respecto a tu vitalidad y propósito de vida.

Durante esta fase, es habitual sentir una mayor carga de responsabilidades, limitaciones o exigencias externas que ponen a prueba tu resistencia y claridad de propósito. Pueden surgir problemas de salud menor relacionados con el agotamiento o la falta de vitalidad. Las figuras de autoridad — jefes, padres, instituciones — cobran un protagonismo especial, a veces en forma de confrontación, a veces como mentores exigentes.

No es un tránsito de castigo sino de definición: Saturno te obliga a separar lo esencial de lo superfluo en tu vida. Los proyectos que tienen base sólida se consolidan; los que no, se desmoronan. Es un momento excelente para establecer estructuras duraderas, asumir compromisos serios y trabajar con disciplina hacia objetivos a largo plazo.

La actitud más productiva es aceptar las limitaciones como maestras, no como enemigas. Lo que construyas con esfuerzo durante este tránsito tiene potencial de durar décadas.',
    'Saturno sobre el Sol marca un periodo de prueba, consolidación y definición del propósito vital. Exige disciplina y separar lo esencial de lo superfluo.',
    'AstroMalik - Síntesis editorial',
    7
);

-- [...continuar con TODAS las combinaciones...]

COMMIT;
```

### Reglas del SQL:
- `calidad = 7` (por debajo de Robert Hand que sería 8, por encima de Grupo Venus que es 5)
- `fuente_nombre = 'AstroMalik - Síntesis editorial'`
- `tipo = 'transito'`
- Escapar comillas simples con doble comilla simple: `''`
- `texto_corto`: 1-2 frases de resumen, máximo 200 caracteres

---

## Orden de trabajo

Procesa por planeta en tránsito, de más lento a más rápido:
1. PLUTON (sobre los 12 puntos × 5 aspectos = 60 textos)
2. NEPTUNO (60 textos)
3. URANO (60 textos)
4. SATURNO (60 textos)
5. JUPITER (60 textos)
6. MARTE (60 textos)
7. VENUS (60 textos)
8. MERCURIO (60 textos)
9. SOL (60 textos)
10. LUNA (60 textos)

---

## Al final del archivo

```sql
-- RESUMEN DE COBERTURA
-- Total insertado: [N] interpretaciones
-- Planetas de tránsito cubiertos: [lista]
-- Puntos natales cubiertos: SOL, LUNA, MERCURIO, VENUS, MARTE, JUPITER, SATURNO, URANO, NEPTUNO, PLUTON, ASC, MC
-- Aspectos cubiertos: CONJUNCION, SEXTIL, CUADRADO, TRIGONO, OPOSICION

-- INSTRUCCIONES
-- 1. Backup: cp corpus.db corpus.db.bak
-- 2. Ejecutar: sqlite3 corpus.db < transitos_sintesis.sql
-- 3. Verificar: sqlite3 corpus.db "SELECT COUNT(*) FROM interpretaciones WHERE fuente_nombre='AstroMalik - Síntesis editorial'"
-- 4. La app usa ORDER BY calidad DESC, así que estos textos (calidad 7) tienen prioridad sobre Grupo Venus (5)
```

---

## Notas importantes

- NO copies textualmente de ninguna web. Lee varias fuentes por aspecto y redacta tu propio texto en castellano.
- Prioriza profundidad astrológica: incluye la lógica detrás del aspecto (qué energía planetaria choca/armoniza con qué función natal).
- Sé concreto en las manifestaciones: no "cambios en tu vida" genérico sino "tensiones con figuras de autoridad" o "impulso creativo inusual" según corresponda.
- Para tránsitos a ASC: enfocarse en la imagen personal, el cuerpo, cómo te presentas al mundo.
- Para tránsitos a MC: enfocarse en la carrera, la vocación, la reputación pública, la dirección vital.
- Si un aspecto no tiene sentido lógico (ej. Luna tránsito Luna conjunción — es el retorno lunar), adaptar el texto a esa naturaleza cíclica específica.
