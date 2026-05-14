# Análisis Astrológico Funcional de AstroMalik-macOS

**Autor:** Claude Opus (Anthropic)
**Fecha:** 3 de mayo de 2026
**Alcance:** Análisis de funcionalidad astrológica, coherencia doctrinal, lagunas interpretativas y líneas de mejora. No es una revisión técnica de código.

---

## 1. Visión General

AstroMalik es una aplicación de astrología nativa para macOS que cubre un espectro notable de técnicas: carta natal con lectura guiada, sinastría, revoluciones solar y lunar, tránsitos con scoring multidimensional, direcciones primarias regiomontanas y horaria clásica nativa. Todo calculado localmente con Swiss Ephemeris embebido y corpus interpretativo en SQLite.

**Valoración global:** La aplicación alcanza un nivel de profundidad técnica y doctrinal poco frecuente en software astrológico independiente. Donde muchos programas se limitan a generar datos, AstroMalik intenta ofrecer *lectura*, que es un salto cualitativo importante. Sin embargo, hay áreas donde la funcionalidad astrológica puede madurar significativamente.

---

## 2. Módulo Natal: Fortalezas y Lagunas

### Lo que hace bien
- Cálculo preciso con Swiss Ephemeris (Placidus por defecto).
- Los 10 cuerpos principales están presentes.
- Aspectos mayores con orbes clásicos razonables (8° conjunción/oposición, 7° cuadratura/trígono, 5° sextil).
- Dignidades esenciales completas: domicilio, exaltación, triplicidad (Doroteo), términos egipcios, decanatos caldeos, exilio, caída y peregrino.
- Recepción mutua por domicilio implementada.
- Secta diurna/nocturna calculada.
- Dispositor básico implementado.
- Rueda natal interactiva con líneas de aspecto.
- Lectura guiada con tríada Sol/Luna/ASC, regente del ASC, casas angulares y aspectos dominantes.

### Lagunas astrológicas significativas

#### 2.1 Cuerpos celestes ausentes
- **Nodos lunares en la natal**: Se calculan para tránsitos pero no aparecen como cuerpos en la carta natal. El Nodo Norte y Nodo Sur son fundamentales para la lectura natal (destino kármico, punto de crecimiento) y deberían formar parte de `PLANET_LIST` o al menos mostrarse junto a los planetas.
- **Lilith (Luna Negra)**: Ausente. Es un punto muy utilizado en astrología moderna y psicológica.
- **Quirón**: Ausente. Su posición por signo y casa es relevante para la herida primordial y el don del sanador.
- **Vértex**: Punto de encuentros fatídicos, útil en sinastría y cartas de eventos.
- **Parte de Fortuna**: Calculada en horaria pero no en la natal, donde tiene uso legítimo en la tradición.

#### 2.2 Aspectos limitados a los cinco mayores
Solo se calculan conjunción, sextil, cuadratura, trígono y oposición. Faltan:
- **Quincuncio (150°)**: Aspecto de ajuste, tensión latente y crisis de salud. No es menor en la práctica.
- **Semicuadratura (45°) y sesquicuadratura (135°)**: Relevantes para tránsitos de planetas lentos.
- **Quintil (72°) y biquintil (144°)**: Para talento creativo.

El README menciona "quincuncio y aspectos menores configurables" en el roadmap, lo que confirma la intención.

#### 2.3 Orbes sin diferenciación por luminarias
Los orbes son fijos por aspecto (8°, 7°, 5°), sin considerar que las luminarias (Sol y Luna) merecen orbes más amplios que los planetas exteriores. La tradición de Lilly y la práctica moderna convergen en que el Sol admite hasta 10-12° en conjunción y la Luna 8-10°, mientras que Plutón raramente supera 3-4°.

#### 2.4 Dignidades esenciales: precisiones pendientes
- La función `detrimentSign` devuelve `nil` para planetas de dos domicilios (Mercurio, Venus, Marte, Júpiter, Saturno), pero existe `isInDetriment` que sí los cubre. El resultado es que la función pública `dignities()` solo detecta exilio para Sol y Luna, dejando falsos negativos para los demás planetas. **Esto es un bug doctrinal** que hace que un Mercurio en Sagitario no aparezca como en exilio.
- No se distingue entre triplicidad diurna y nocturna en el cálculo: `triplicityRuler` acepta cualquier regente de la triplicidad independientemente de la secta. La carta ya sabe si es diurna o nocturna (`isDiurnal`), pero no se usa para filtrar la triplicidad. Doroteo y Lilly son claros en que solo el regente correspondiente a la secta tiene dignidad de triplicidad.

#### 2.5 Ausencia de síntesis interpretativa automatizada
La "Lectura Guiada" es un esqueleto de navegación excelente, pero los textos del corpus se presentan como fichas aisladas. Falta:
- **Patrón elemental**: ¿Cuántos planetas en fuego/tierra/aire/agua? El balance elemental es la primera lectura rápida que hace cualquier astrólogo.
- **Patrón modal**: ¿Predominio cardinal/fijo/mutable? Indica estilo de acción.
- **Hemisferios**: ¿Planetas concentrados arriba/abajo, este/oeste? Indica orientación vital.
- **Stellium**: Detección de 3+ planetas en un signo o casa.
- **Almuten figuris**: Planeta con mayor dignidad acumulada en la carta, un concepto clásico potente.
- **Disposición final**: Cadena de disposiciones hasta el dispositor final (planeta en su propio domicilio o bucle mutuo).

---

## 3. Sinastría: Sólida pero incompleta

### Fortalezas
- Aspectos bidireccionales (A sobre B y B sobre A).
- 420 textos de corpus específico.
- Rueda doble visual.
- Exportación a Joplin.

### Lagunas

#### 3.1 Superposición de casas ausente
La sinastría moderna no se limita a aspectos. **¿En qué casa de B cae el Sol de A?** Esto es fundamental: si tu Venus cae en la casa 7 de tu pareja, la atracción es obvia; si cae en la casa 12, es secreta o sacrificial. Esta superposición es tan importante como los aspectos y actualmente no se calcula ni se muestra.

#### 3.2 Sin carta compuesta ni Davison
La carta compuesta (punto medio de cada planeta) y la carta Davison (momento y lugar medio entre los nacimientos) son herramientas estándar de sinastría relacional que permitirían una lectura de la relación como entidad.

#### 3.3 Aspectos solo entre planetas
No se calculan aspectos de planetas de A con ASC o MC de B, que son los más reveladores ("tu Saturno en conjunción con mi Ascendente" es una de las configuraciones sinástrias más significativas).

#### 3.4 Sin scoring de compatibilidad
A diferencia de los tránsitos (que tienen un sistema de scoring sofisticado), la sinastría no pondera la importancia de cada aspecto. Un Venus-Júpiter trígono no tiene el mismo peso que un Sol-Saturno cuadratura, pero ambos aparecen con la misma jerarquía visual.

---

## 4. Revolución Solar: Buen nivel, mejoras posibles

### Fortalezas
- Cálculo del retorno exacto con `swe_solcross_ut`.
- Lectura guiada con tema del año (por casa natal del ASC RS), tono (por signo del ASC RS), regente del año, Luna RS, planetas angulares y repeticiones natales.
- Los textos de RevolutionTemplates son doctrinalmente sólidos y bien redactados.
- Superposición de planetas RS en casas natales.

### Lagunas

#### 4.1 Aspectos RS con natal ausentes
No se calculan los aspectos entre planetas de la revolución y planetas natales. Esto es crucial: "Saturno RS en cuadratura a mi Luna natal" es una de las señales más claras de un año emocionalmente exigente. Actualmente solo se muestran los aspectos internos de la carta RS entre sus propios planetas.

#### 4.2 Sin comparación interanual
No se puede comparar la RS del año actual con la del siguiente o el anterior. Los astrólogos profesionales trabajan con secuencias de revoluciones para ver evolución temática.

#### 4.3 Regentes clásicos únicamente
Se usa solo la regencia clásica (Escorpio = Marte). Para muchos astrólogos la corregencia moderna (Escorpio = Plutón) es relevante en la RS. Podría ofrecerse como opción.

#### 4.4 Sin consideración de lugar
El lugar de la RS es uno de los temas más debatidos en astrología predictiva. La app permite elegir el lugar, pero no muestra cómo cambian las casas si se calcula para el lugar de residencia vs. el de nacimiento. Una vista comparativa sería valiosa.

---

## 5. Revolución Lunar: Bien orientada, expansible

### Fortalezas
- Serie de retornos con scoring de intensidad.
- Mini-narrativas por retorno.
- Estadísticas (intervalos, casa lunar más frecuente, velocidades).
- Tono por ASC del retorno.

### Lagunas

#### 5.1 Sin cruce con la revolución solar
El retorno lunar más potente es el que activa la RS del año. ¿El ASC del retorno lunar cae sobre un punto sensible de la RS? ¿Hay conjunciones lunares mensuales a planetas angulares de la RS? Esta integración RS-RL es donde la predictiva clásica brilla.

#### 5.2 Sin aspectos Luna RL con natal
Similar al caso solar: ¿qué aspectos forma la Luna del retorno con los planetas natales? Es la pregunta central del mes.

#### 5.3 Fases lunares no consideradas
¿El retorno cae en Luna nueva, llena, creciente o menguante? La fase de la Luna en el momento del retorno matiza la energía del ciclo.

---

## 6. Tránsitos: El módulo más maduro

### Fortalezas
- Sistema de scoring multidimensional (técnico, relevancia personal, impacto temporal).
- Bandas de prioridad (baja/media/alta/crítica).
- Orbes propios de tránsito, separados de los natales.
- Eje nodal fusionado para evitar duplicados.
- Muestras diarias de intensidad.
- Filtros por foco.
- Timeline visual.
- Motivos compactos para explicar por qué un tránsito es importante.
- Detección de retrogradación en la fecha exacta.
- Cluster de tránsitos al mismo punto.

### Lagunas

#### 6.1 Sin ingresos por casa
Cuando Saturno entra en tu casa 7, no necesariamente forma aspectos inmediatos, pero su presencia allí durante 2-3 años es uno de los tránsitos más significativos. Los ingresos por casa (tránsito de un planeta por una nueva casa natal) son imprescindibles en cualquier programa de tránsitos profesional. El roadmap lo menciona.

#### 6.2 Tránsitos de planetas rápidos infrautilizados
La Luna se puede excluir (bien), pero Mercurio, Venus y Sol se calculan con pesos bajos (2, 2, 2) y orbes estrechos. En la práctica, un tránsito de Venus conjunción a tu Venus natal es un evento claro. Los pesos podrían refinarse contextualmente.

#### 6.3 Sin tránsitos recíprocos
Solo se calcula "planeta transitante sobre punto natal". No se consideran tránsitos sobre la carta compuesta ni tránsitos mutuos en sinastría (¿qué está transitando sobre su carta al mismo tiempo?).

#### 6.4 Eclipses ausentes
Las lunaciones (Luna nueva y llena) y los eclipses en relación con la natal son técnicas predictivas fundamentales que no están implementadas.

#### 6.5 Retrogradación no narrativa
Se detecta si el tránsito es retrógrado en la fecha exacta, pero no se narra la dinámica de las tres pasadas (directa-retrógrada-directa) como una historia con inicio, repetición y cierre.

---

## 7. Direcciones Primarias: Impresionante para un proyecto independiente

### Fortalezas
- Motor Regiomontano con polo del significador.
- Directas y conversas calculadas correctamente (roles astronómicos invertidos).
- Tres claves: Naibod, Ptolomeo, Brahe (con Brahe basada en arco real).
- Plano zodiacal y eclíptico.
- Parte de Fortuna opt-in.
- Presets y pesos.
- Corpus clásico de Lilly (Christian Astrology, Libro III).
- Espéculo completo con RA, declinación, polo.
- Interpretación contextual local (determinista) + Foundry Local + OpenRouter.
- Timeline por significador.
- Detalle profesional con datos técnicos completos.

### Lagunas

#### 7.1 Sin direcciones con latitud
Las direcciones en latitud (planetas con latitud eclíptica significativa) se omiten. Para la Luna, cuya latitud puede alcanzar ±5°, esto introduce un error en arcos mundanos. El efecto es menor para direcciones zodiacales.

#### 7.2 Sin profecciones
Las profecciones (1 signo por año, 2.5° por mes) son la técnica predictiva hermana de las direcciones primarias. Son triviales de calcular y su integración daría contexto inmediato: "este año profectas a la casa 7, y la dirección primaria Sol conjunción DSC activa en el mismo periodo" es una confirmación potente.

#### 7.3 Sin firdaria ni períodos planetarios
Los periodos cronológicos (firdaria, decenios, etc.) que indican qué planeta "gobierna" cada fase de la vida contextualizarían las direcciones de forma muy natural.

#### 7.4 Plano mundano incompleto
Solo se implementa zodiacal y eclíptico. El plano mundano verdadero (por arco semidiurno/seminocturno) requiere cálculo más complejo con latitud del planeta. El nombre "mundano" aparece en `PDAspectPlane` pero no queda claro si el cálculo lo implementa plenamente.

---

## 8. Horaria Clásica: La joya doctrinal

### Fortalezas
- Motor nativo Swift sin dependencia Python.
- Solo planetas tradicionales (correcto doctrinalmente).
- Casas Regiomontanus (estándar en horaria).
- Dignidades esenciales y accidentales completas.
- Hora planetaria con cálculo real de salida/puesta del Sol.
- Consideraciones: ASC temprano/tardío, vía combusta, Luna vacía de curso, Saturno en 1/7, acuerdo hora-ASC.
- Recepción mutua y simple.
- Perfección directa, traslación y colección.
- Veredicto estructurado con confianza y factores.
- Corrección doctrinal clave: la Luna no perfecciona si el aspecto se completa después del cambio de signo.
- Moieties por planeta (no orbes fijos).
- Timing simbólico por tipo de casa y modalidad.

### Lagunas

#### 8.1 Sin antiscios
Los antiscios (puntos de igual declinación: signo reflejado sobre el eje Cáncer-Capricornio) y contra-antiscios son aspectos "ocultos" que Lilly usa extensamente. Un planeta a 10° Leo tiene su antiscio a 20° Tauro. Si el significador está ahí, hay conexión.

#### 8.2 Sin disposición del Sol/Luna
¿Dónde está el dispositor de la Luna? ¿Y el del Sol? ¿Está ese dispositor dignificado? Estas preguntas son centrales en el juicio horario de Lilly.

#### 8.3 Frustración y prohibición ausentes
Cuando dos significadores se aplican pero un tercer planeta más rápido se interpone antes de la perfección (frustración) o un planeta lento bloquea por aspecto al significador antes de que llegue (prohibición), el juicio cambia radicalmente. Lilly dedica capítulos enteros a esto.

#### 8.4 Besieging (asedio) no evaluado
Cuando un planeta está entre Marte y Saturno (los maléficos), la situación es grave. Es una condición clásica que el motor no evalúa.

#### 8.5 Combustión como impedimento de perfección
Si el significador está combusto (a menos de 8.5° del Sol), se calcula la dignidad accidental pero no se usa como factor de imperfección.

#### 8.6 Temas horarios no cubiertos
El motor asigna significadores por casa y busca perfección genérica. Pero la horaria clásica tiene reglas específicas por tema:
- **Casa 7 (pareja)**: ¿Hay recepción entre regentes de 1 y 7? ¿La Luna aplica al regente de 7?
- **Casa 10 (trabajo)**: ¿El regente de 10 recibe al regente de 1?
- **Objetos perdidos (Casa 2)**: Reglas de dirección basadas en la Luna y el regente de 2.

Un sistema de reglas por tema de pregunta mejoraría enormemente la calidad del juicio.

---

## 9. Corpus Interpretativo: Evaluación

### Inventario actual
| Tipo | Registros |
|---|---:|
| Planeta en signo | 125 |
| Planeta en casa | 121 |
| Aspectos natales | 368 |
| Tránsitos | 745 |
| Sinastría | 420 |
| **Total** | **1.779** |

### Análisis de cobertura

#### Natal
- 125 entradas de planeta-signo para 10 planetas × 12 signos = 120 combinaciones + ASC = 133 posibles. Cobertura casi completa.
- 121 entradas de planeta-casa para 10 × 12 = 120 + ASC = 133. Cobertura alta.
- 368 aspectos natales para 10 planetas en pares con 5 aspectos = C(10,2)×5 = 225 posibles. Hay más de 225, lo que sugiere variantes o aspectos con ASC/MC. Cobertura buena.

#### Tránsitos
- 745 textos. Planetas transitantes × puntos natales × aspectos = un espacio combinatorio enorme. La cobertura parcial es esperable; lo importante es que los tránsitos lentos (Plutón, Neptuno, Urano, Saturno, Júpiter) sobre puntos sensibles estén bien cubiertos.

#### Sinastría
- 420 textos para SYN_PLANETA_PLANETA_ASPECTO. Con 10×10×5 = 500 combinaciones máximas (excluyendo duplicados), la cobertura es alta (~84%).

### Calidad
Los textos del corpus no se han auditado individualmente en esta revisión, pero los templates de RevolutionTemplates son doctrinalmente correctos y están bien redactados. La política de fuente trazable (Lilly, Bonatti, Ptolomeo) es un punto fuerte.

---

## 10. Sistema de Casas

Actualmente solo se ofrece Placidus (natal) y Regiomontanus (horaria y direcciones). El roadmap menciona "configurar sistemas de casas desde UI". Los más demandados serían:

- **Koch**: Popular en países de habla alemana.
- **Whole Sign (signo entero)**: Revivido por la astrología helenística, cada vez más usado.
- **Campanus**: Preferido por algunos astrólogos clásicos.
- **Equal Houses (casas iguales)**: Simple y útil para latitudes extremas donde Placidus falla.
- **Porphyry**: Histórico, sencillo.

La elección del sistema de casas debería ser configurable a nivel de carta, no solo global. Swiss Ephemeris soporta todos estos con el parámetro `hsys`.

---

## 11. Tabla de Mejoras Priorizadas

| Prioridad | Mejora | Módulo | Impacto |
|---|---|---|---|
| **Crítica** | Corregir bug de exilio para planetas de dos domicilios | Motor natal | Los exilios de Mercurio, Venus, Marte, Júpiter y Saturno no se detectan |
| **Crítica** | Filtrar triplicidad por secta (diurna/nocturna) | Dignidades | Actualmente cualquier regente de triplicidad cuenta |
| **Alta** | Nodos lunares en carta natal | Motor natal | Fundamental para lectura natal |
| **Alta** | Ingresos por casa en tránsitos | Tránsitos | Uno de los tránsitos más importantes |
| **Alta** | Aspectos RS/RL con carta natal | Revoluciones | Lectura predictiva esencial |
| **Alta** | Superposición de casas en sinastría | Sinastría | Técnica sinástrica básica |
| **Alta** | Balance elemental y modal en natal | Lectura guiada | Primera síntesis que todo astrólogo hace |
| **Alta** | Frustración y prohibición en horaria | Horaria | Reglas de Lilly fundamentales |
| **Media** | Quincuncio (150°) | Aspectos | Aspecto significativo no cubierto |
| **Media** | Quirón y Lilith | Motor natal | Puntos modernos muy utilizados |
| **Media** | Eclipses y lunaciones | Tránsitos | Técnica predictiva mayor |
| **Media** | Profecciones | Predictiva | Complemento natural de direcciones |
| **Media** | Carta compuesta | Sinastría | Técnica relacional estándar |
| **Media** | Hemisferios y stelliums | Lectura guiada | Patrones visuales importantes |
| **Media** | Antiscios en horaria | Horaria | Aspectos ocultos de Lilly |
| **Baja** | Sistemas de casas configurables | Global | Flexibilidad profesional |
| **Baja** | Firdaria y períodos | Predictiva | Contextualización temporal |
| **Baja** | Aspectos a ASC/MC en sinastría | Sinastría | Refinamiento importante |
| **Baja** | Regencia moderna opcional | Global | Preferencia de usuario |
| **Baja** | Direcciones con latitud | Direcciones | Precisión astronómica |

---

## 12. Coherencia Doctrinal: Evaluación

### Puntos fuertes
- **Fuentes citadas**: Ptolomeo, Doroteo, Bonatti, Lilly. Hay trazabilidad.
- **Horaria estrictamente clásica**: Solo planetas tradicionales, Regiomontanus, moieties, hora planetaria. Correcto.
- **Regencia clásica en revoluciones**: Escorpio = Marte, Acuario = Saturno. Coherente con la línea del proyecto.
- **Corrección Luna fuera de curso**: No perfeccionar si el aspecto excede el cambio de signo. Excelente.

### Puntos débiles
- **Mezcla de tradiciones sin explicitar**: Los orbes natales son fijos por aspecto (estilo moderno), pero las dignidades son ptolemaicas. En horaria se usan moieties (Lilly), pero en natal no. No se explica esta decisión al usuario.
- **Planetas modernos en direcciones primarias**: Se incluyen Urano, Neptuno y Plutón como significadores y prómissores en DP, lo cual es anacrónico con la base doctrinal clásica. Debería ser opcional.
- **Escorpio/Piscis/Acuario sin corregencia**: La app usa solo la clásica, pero no ofrece al usuario la opción moderna. Muchos astrólogos profesionales usan ambas.

---

## 13. Lo que AstroMalik hace excepcionalmente bien

1. **Horaria nativa completa**: Tener un motor horario clásico en Swift, con hora planetaria real, moieties, traslación, colección y veredicto estructurado es raro incluso en software comercial.

2. **Tránsitos con scoring multidimensional**: El sistema de relevancia personal + impacto temporal + bandas de prioridad es más sofisticado que el de la mayoría de programas astrológicos, incluidos algunos comerciales caros.

3. **Direcciones primarias regiomontanas**: Con espéculo, clave Brahe por arco real, conversas invertidas y corpus Lilly. Esto es nivel de especialista.

4. **Filosofía local-first**: Todo el cálculo es determinista y local. El LLM es opcional y nunca sustituye el motor. Esta es una decisión arquitectónica impecable para software astrológico.

5. **Templates de revolución bien escritos**: Los textos de RevolutionTemplates son concisos, doctrinalmente correctos y útiles. No son genéricos ni vagos.

---

## 14. Lo que falta para ser profesionalmente completa

1. **Nodos, Quirón, Lilith y Parte de Fortuna en la natal**: Sin estos puntos, la carta natal está incompleta para la práctica profesional moderna.

2. **Síntesis automática**: Balance elemental, modal, hemisferios, stelliums, almuten, cadena de disposiciones. La lectura guiada actual es un esqueleto de navegación, no una síntesis.

3. **Cruce predictivo RS ↔ RL ↔ Tránsitos ↔ Direcciones**: Las técnicas predictivas viven en silos. Un astrólogo profesional busca confirmación: si la RS activa la casa 7, el tránsito de Saturno pasa por la 7 y la DP Sol-DSC se activa ese año, la predicción es fuerte. Necesita una vista integrada.

4. **Eclipses**: Son la técnica predictiva más antigua y siguen siendo las más impactantes. Su ausencia es notable.

5. **Ingresos por casa**: Un tránsito puede no formar aspecto pero dominar un año entero por presencia en una casa.

---

## 15. Conclusión

AstroMalik es un proyecto ambicioso y doctrinalmente serio que supera en profundidad a la mayoría del software astrológico independiente. Los módulos de horaria, direcciones primarias y tránsitos son particularmente maduros. Las áreas de mejora más urgentes son:

1. **Corregir los bugs doctrinales de exilio y triplicidad por secta** (impacto inmediato en la calidad de la lectura).
2. **Completar la carta natal** con nodos, y opcionalmente Quirón/Lilith/Fortuna.
3. **Añadir síntesis automáticas** (elementos, modalidades, hemisferios).
4. **Cruzar técnicas predictivas** para que RS, RL, tránsitos y DP se iluminen mutuamente.
5. **Implementar ingresos por casa** y **eclipses** en el módulo de tránsitos.

El proyecto tiene una base de cálculo sólida, una filosofía de diseño coherente y un corpus interpretativo trazable. Con las mejoras indicadas, especialmente las de prioridad crítica y alta, AstroMalik pasaría de ser una herramienta excelente para uso personal a una herramienta competitiva para práctica profesional.

---

*Análisis realizado por Claude Opus (Anthropic) el 3 de mayo de 2026, tras revisión completa del código fuente de AstroMalik-macOS.*
