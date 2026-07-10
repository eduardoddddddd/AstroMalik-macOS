# Rectificación de hora natal — Guía de uso

> Guía correspondiente a AstroMalik 1.1.0. Describe el flujo completo de las Fases 0–4.

## 1. Qué hace la herramienta

La rectificación compara varias horas posibles de nacimiento con una cronología de acontecimientos reales. Para cada hora candidata, AstroMalik recalcula la carta y busca concordancias mediante técnicas astrológicas deterministas. El resultado es un ranking auditable de hipótesis horarias.

El flujo está pensado para dos situaciones:

- existe una hora aproximada y se quiere examinar un margen anterior y posterior;
- la hora es desconocida y se necesita explorar el día completo.

La aplicación separa deliberadamente tres capas:

1. **Cálculo local determinista**: genera candidatas, scores, clusters, evidencias y advertencias.
2. **Narrativa IA opcional**: compara y redacta únicamente sobre el resultado ya calculado.
3. **Archivo profesional**: conserva la sesión y permite exportar JSON, PDF o una nota Joplin.

## 2. Límites: evitar la falsa precisión

La rectificación es un procedimiento investigativo. AstroMalik no certifica una hora de nacimiento ni convierte una correlación astrológica en un hecho histórico.

- Un **score no es un porcentaje de probabilidad**.
- La primera candidata es la que mejor se ajusta al dataset y configuración empleados, no necesariamente la hora verdadera.
- Diferencias de segundos o pocos minutos no deben presentarse como certeza si varias candidatas forman un mismo cluster.
- Un dataset pobre, repetitivo o impreciso puede producir un ranking aparente pero poco discriminante.
- Las advertencias de empate, baja cobertura o cruce de secta forman parte del resultado y no deben omitirse.
- La narrativa IA no realiza cálculos nuevos y no debe usarse para rellenar evidencias inexistentes.
- La carta rectificada se guarda como una carta nueva, con procedencia y advertencia; la original no se sobrescribe.

Siempre que exista una partida, certificado, registro hospitalario o testimonio contemporáneo fiable, debe conservarse como fuente principal y documentarse junto con la hipótesis.

## 3. Antes de empezar

### 3.1. Carta base

Guarda una carta natal con:

- fecha de nacimiento;
- mejor hora declarada o aproximada disponible;
- zona horaria correcta;
- lugar y coordenadas correctos;
- sistema de casas deseado.

La rectificación parte de una carta guardada. Revisar zona y coordenadas antes de analizar evita comparar candidatas construidas sobre datos geográficos incorrectos.

### 3.2. Cronología vital recomendada

Prepara al menos tres eventos con precisión de día, semana o mes. Seis o más acontecimientos diversos suelen ofrecer una base más útil. Conviene combinar ámbitos diferentes:

- identidad o cambios vitales decisivos;
- inicio de relación, matrimonio o separación;
- nacimientos y fallecimientos familiares;
- mudanzas, compra de vivienda o traslado al extranjero;
- inicio de estudios, graduación, carrera, ascenso o pérdida de empleo;
- reconocimiento público;
- accidente, cirugía o enfermedad;
- asuntos legales;
- ganancias o pérdidas económicas;
- cambios espirituales relevantes.

Prioriza eventos fechables y biográficamente importantes. Diez cambios laborales parecidos no necesariamente aportan más discriminación que seis eventos independientes de áreas diferentes.

## 4. Flujo paso a paso

### Paso 1 — Abrir Rectificación

En la navegación principal, entra en **Carta Natal → Rectificación**. Si no hay cartas guardadas, la vista pedirá crear una antes de continuar.

### Paso 2 — Seleccionar la carta

En **Carta y rango**, selecciona la carta base. La sesión hereda fecha, hora declarada, zona, coordenadas y lugar.

Cambiar de carta inicializa una sesión para la nueva carta. Si ya se ha trabajado en otra sesión, guárdala antes de cambiar.

### Paso 3 — Definir el rango horario

Configura:

- **Hora central**: admite `HH:mm` y `HH:mm:ss`.
- **Antes / Después**: margen alrededor de la hora central.
- **Paso grueso**: separación de candidatas en la primera pasada.
- **Paso fino**: resolución usada para refinar las zonas mejor puntuadas.
- **Buscar en las 24 horas**: explora todo el día cuando no existe una aproximación útil.

La interfaz muestra una estimación de candidatas de primera pasada. Un paso menor aumenta el coste de cálculo y no garantiza una conclusión más fiable.

Configuración inicial práctica:

| Situación | Rango sugerido | Paso grueso | Paso fino |
|---|---:|---:|---:|
| Hora bastante fiable | ±30–60 min | 5 min | 30–60 s |
| Hora aproximada | ±2–4 h | 5–10 min | 60–120 s |
| Hora desconocida | 24 h | 10–15 min | 60–300 s |

Estas cifras son puntos de partida, no reglas doctrinales. Si el resultado queda muy agrupado, puede hacerse una segunda sesión con un rango más estrecho.

### Paso 4 — Añadir eventos

Pulsa **Añadir evento** y completa cada fila:

- **Título**: descripción breve e identificable.
- **Tipo**: categoría simbólica del evento.
- **Fecha**: fecha inicial conocida o estimada.
- **Precisión**: día exacto, semana, mes, trimestre, año o rango.
- **Importancia**: escala de 1 a 5.

La precisión modifica el peso: día, semana y mes son más discriminantes que trimestre o año. Los eventos aproximados por trimestre o año pueden aportar contexto, pero no cuentan para satisfacer por sí solos el mínimo operativo. Un evento debe ser posterior al nacimiento, no futuro y tener un título.

Buenas prácticas:

- no marcar como “día exacto” una fecha recordada solo por mes;
- no inflar todos los eventos a importancia 5;
- describir el hecho, no la interpretación astrológica esperada;
- documentar por separado cualquier duda de fecha;
- evitar duplicar un mismo proceso como muchos eventos para aumentar artificialmente su peso.

### Paso 5 — Completar el cuestionario preliminar de Ascendente

El **Cuestionario preliminar de Ascendente** contiene cinco preguntas sobre presencia, reacción espontánea, ritmo, búsqueda de control y respuesta al conflicto. Cada respuesta suma afinidad a varios signos y la vista muestra:

- hipótesis preliminar de signo ascendente;
- porcentaje completado;
- aviso de que se trata de una señal orientativa de baja ponderación.

No adaptes las respuestas para hacerlas coincidir con el signo esperado. El cuestionario puede ayudar a discriminar, pero no sustituye eventos fechados ni debe dominar el score.

### Paso 6 — Ajustar la configuración profesional

En **Configuración profesional** se puede controlar:

- **Escuela**: Tradicional, Equilibrada o Moderna.
- **Casas**: sistema de casas usado para recalcular cada candidata.
- **Multiplicador de orbe**: estrecha o amplía de forma explícita los orbes técnicos.
- **Planetas modernos**: permite excluir Urano, Neptuno y Plutón de los tránsitos angulares.
- **Ventana cluster**: separación temporal usada para agrupar candidatas cercanas.
- **Penalizar sobreajuste**: activa el ajuste por concentración y complejidad.
- **Técnicas habilitadas**: permite incluir o excluir cada familia de evidencia.
- **Pesos y sensibilidad anti-overfitting**: ajusta la fuerza de penalización y el peso individual de las técnicas activas.

Los presets son puntos de partida coherentes:

- **Tradicional** prioriza direcciones primarias y confirmaciones clásicas como profecciones, Firdaria, ZR, lotes y revolución solar; reduce el peso de tránsitos y progresiones.
- **Equilibrada** conserva una combinación intermedia de técnicas tradicionales y modernas.
- **Moderna** eleva arco solar, progresiones, tránsitos a ángulos y cuestionario; reduce el peso de los señores del tiempo.

Al elegir un preset se aplican sus pesos. Después pueden afinarse manualmente. Para comparar dos ejecuciones de forma válida, conserva o documenta la misma configuración.

### Paso 7 — Ejecutar el análisis

Pulsa **Analizar candidatas**. La barra indica el progreso y **Cancelar** detiene cooperativamente el trabajo.

El motor realiza una pasada gruesa, selecciona las zonas más prometedoras y las refina. Todo el cálculo base es local y no llama a Anthropic ni OpenRouter.

### Paso 8 — Revisar el resultado

No guardes inmediatamente la primera fila. Revisa, en este orden:

1. confianza global y advertencias;
2. separación entre las primeras candidatas;
3. clusters horarios;
4. cobertura de eventos;
5. evidencias de la candidata principal;
6. coherencia entre varias técnicas;
7. posibles cambios de Ascendente, MC o secta dentro del rango.

### Paso 9 — Guardar la candidata

**Guardar candidata principal** crea una carta nueva, con UUID y nombre propios. Las notas incluyen la sesión, el score y la advertencia de que se trata de una hipótesis. La carta base permanece intacta.

## 5. Técnicas deterministas

La configuración profesional puede combinar:

- **Direcciones primarias**: tienen un peso técnico alto y buscan activaciones dirigidas relevantes.
- **Arco solar**: compara arcos simbólicos con factores natales y angulares.
- **Progresiones secundarias**: añade activaciones progresadas asociadas a los eventos.
- **Tránsitos a ángulos**: examina contactos de tránsito con ASC/MC y otros factores angulares sensibles a la hora.
- **Cuestionario de Ascendente**: aporta una señal preliminar de baja ponderación según el signo resultante.
- **Profecciones**: usa el señor del año y activaciones por casa como confirmación temporal.
- **Firdaria**: contrasta regentes de periodo con la simbología del evento.
- **Zodiacal Releasing**: añade confirmaciones de periodos y hitos relevantes.
- **Lotes sensibles a hora**: evalúa activaciones de Fortuna y Espíritu respecto a factores angulares.
- **Revolución solar**: comprueba angularidad y énfasis anual como confirmación adicional.

El tipo de evento se traduce mediante reglas simbólicas centralizadas. La consolidación limita el premio por acumular muchos contactos parecidos, de modo que la **calidad, diversidad y ajuste** de la evidencia valgan más que el volumen bruto.

Los señores del tiempo, lotes y revolución solar actúan como **confirmaciones**: enriquecen la convergencia, pero no deberían convertir por sí solos una candidata débil en conclusión fuerte. Las técnicas activas y sus pesos quedan registrados en la configuración usada por el resultado.

## 6. Cómo leer scores, clusters y evidencias

### 6.1. Score total

El score sirve para ordenar candidatas calculadas bajo la misma sesión y configuración. Es una medida interna comparativa.

- Compáralo con los scores vecinos, no con una escala universal.
- Una diferencia pequeña puede indicar una misma franja plausible.
- Un score alto con poca cobertura de eventos merece cautela.
- Repetir el análisis con eventos mejores puede cambiar el orden legítimamente.

### 6.2. Confianza

La confianza global puede ser baja, media, alta o inconclusa. Resume la separación y calidad del resultado, pero no reemplaza la revisión de evidencia. “Alta” significa que el dataset discrimina bien dentro del experimento realizado, no que la hora esté documentalmente demostrada.

### 6.3. Clusters

Un cluster reúne candidatas cercanas dentro de una ventana temporal. Interprétalo como una **zona horaria plausible**, especialmente cuando varias horas contiguas puntúan de forma parecida.

Si el cluster abarca varios minutos:

1. conserva el intervalo en el informe;
2. busca uno o dos eventos independientes y mejor fechados;
3. repite con un rango estrecho alrededor del cluster;
4. evita publicar segundos exactos sin discriminación suficiente.

La sección desplegable **Distribución y clusters** representa hasta ocho grupos mediante barras relativas, score medio, intervalo horario y signo ascendente. La barra compara cada media con el cluster principal; no representa una probabilidad absoluta.

### 6.4. Comparación lado a lado

Cuando existen al menos dos candidatas, abre **Comparación lado a lado** y elige Candidata A y Candidata B. Cada columna muestra:

- hora, ASC y MC;
- score y banda de confianza;
- hasta seis scores técnicos principales.

Esta vista permite detectar si dos horas próximas obtienen el mismo total por razones distintas. Prefiere la candidata respaldada por evidencia diversa y coherente, no la que dependa de una sola técnica muy ponderada.

### 6.5. Evidencias

Cada evidencia indica:

- evento asociado;
- técnica;
- factor astrológico;
- fecha exacta calculada cuando procede;
- diferencia temporal u orbe;
- ajuste simbólico;
- score parcial;
- explicación y datos técnicos de auditoría.

Una candidata sólida debería sostenerse en varios eventos y, preferiblemente, en más de una técnica. Una única evidencia espectacular no compensa automáticamente muchas contradicciones o eventos sin cubrir.

### 6.6. Auditoría anti-overfitting

Para la candidata principal, AstroMalik muestra:

- **score bruto** antes del ajuste;
- **penalización** aplicada;
- participación del evento dominante;
- participación de la técnica dominante;
- score ajustado usado para el ranking.

La penalización aumenta cuando una parte desproporcionada del resultado procede de un solo evento o técnica, y también controla la complejidad al habilitar muchas técnicas. Su fuerza se regula entre 0 y 1. Desactivarla puede ser útil para auditoría comparativa, pero no convierte el score bruto en una medida más objetiva.

### 6.7. Advertencias

Presta especial atención a:

- empate o poca separación entre candidatas;
- dataset insuficiente o cobertura desigual;
- cambio de secta dentro del rango;
- cambio de signo de Ascendente;
- contactos débiles o contradictorios;
- búsqueda demasiado amplia o costosa.
- concentración excesiva de evidencia o ajuste anti-overfitting relevante.

Las advertencias deben conservarse en cualquier conclusión compartida.

## 7. Comparación narrativa con IA

Después del cálculo determinista puede elegirse Anthropic u OpenRouter y pulsar **Generar comparación con IA**.

Esta acción:

- es opcional y nunca se ejecuta automáticamente;
- usa red y puede generar coste;
- envía un payload compacto y versionado con resultados ya calculados;
- instruye al modelo para comparar candidatas sin inventar posiciones, aspectos ni scores;
- muestra proveedor, modelo, tokens de entrada/salida y coste estimado cuando está disponible.

La narrativa es una ayuda para síntesis y preguntas de revisión. Si contradice los datos técnicos, prevalecen el resultado determinista y la auditoría de evidencias.

Antes de usarla, configura las credenciales del proveedor en **Ajustes**. No exportes una narrativa como si fuera cálculo independiente: conserva siempre su trazabilidad.

## 8. Guardado e historial

La sesión puede guardarse con **Guardar sesión**. AstroMalik persiste en SQLite:

- datos de la sesión y cronología;
- último resultado determinista;
- narrativa opcional;
- versiones sucesivas del análisis.

El menú **Historial** permite abrir o eliminar sesiones. Al reabrir una, pueden editarse eventos y rango y volver a calcular. El historial deduplica resultados idénticos: guardar o exportar repetidamente sin recalcular no crea versiones artificiales.

La base de usuario reside en:

```text
~/Library/Application Support/AstroMalik/user.db
```

Eliminar una sesión no elimina automáticamente las cartas rectificadas que ya se hayan guardado como cartas independientes.

## 9. Intercambio JSON

**Exportar JSON** crea un archivo de sesión versionado que puede contener sesión, resultado y narrativa. Sirve para:

- copia de seguridad;
- traslado entre instalaciones compatibles;
- auditoría técnica;
- intercambio reproducible con otro profesional.

**Importar JSON** valida y guarda el archivo antes de abrirlo. Conserva el original sin editar como respaldo. No modifiques manualmente identificadores, versiones de esquema ni fechas salvo que se conozca el contrato del formato.

Si una versión futura cambia el esquema, la aplicación debe migrar o rechazar explícitamente el archivo; no debe interpretar silenciosamente campos incompatibles.

## 10. Informe PDF

Con un resultado disponible, **Exportar PDF** genera un informe técnico autocontenido que incluye:

- identidad de la sesión y hora declarada;
- advertencia sobre el carácter hipotético;
- candidatas principales con hora, ASC, MC y score;
- signo preliminar del cuestionario, cuando existe;
- clusters horarios;
- diagnóstico anti-overfitting;
- advertencias;
- evidencias principales;
- narrativa y trazabilidad si se generó previamente.

El PDF es adecuado para archivo o revisión profesional. Antes de entregarlo, añade contexto sobre las fuentes biográficas, calidad de fechas y rango explorado; esos elementos determinan el alcance real de la conclusión.

## 11. Nota Joplin

**Crear nota Joplin** solo aparece cuando existe un resultado y solo actúa al pulsarlo. La nota Markdown contiene candidatas, clusters, auditoría anti-overfitting, evidencias, advertencias y narrativa opcional.

Requisitos:

1. Joplin Desktop y Web Clipper disponibles;
2. host, puerto, token y cuaderno configurados en Ajustes, o token resoluble desde la configuración local/variable de entorno;
3. servicio local accesible.

La nota es una copia documental. Editarla en Joplin no modifica la sesión SQLite de AstroMalik.

## 12. Método de trabajo recomendado

1. **Primera pasada**: rango razonable y eventos mejor conocidos.
2. **Auditoría**: descartar conclusiones sostenidas por un solo ámbito o técnica.
3. **Segunda pasada**: añadir eventos independientes y estrechar alrededor de los clusters relevantes.
4. **Comparación**: observar estabilidad del ranking entre versiones.
5. **Síntesis**: usar narrativa IA solo después de revisar evidencias.
6. **Archivo**: guardar sesión, JSON y PDF con fecha y notas sobre las fuentes.
7. **Carta rectificada**: guardar únicamente cuando la hipótesis sea suficientemente defendible, manteniendo siempre la carta original.

## 13. Resolución de problemas

### “Analizar candidatas” está desactivado

- Comprueba que hay al menos tres eventos calificables.
- Los eventos con precisión de trimestre o año no satisfacen el mínimo por sí solos.
- Revisa que la carta y la sesión estén cargadas.

### La hora central no es válida

Usa `HH:mm` o `HH:mm:ss`, por ejemplo `08:35` o `08:35:20`. Evita texto libre o formatos de 12 horas.

### El análisis rechaza un evento

Verifica que tenga título, importancia entre 1 y 5, fecha posterior al nacimiento y no futura. Si es un rango, la fecha final debe existir y no ser anterior a la inicial.

### El cálculo tarda demasiado

- aumenta el paso grueso;
- reduce los márgenes;
- evita el día completo si existe una aproximación fiable;
- cancela y realiza primero una exploración amplia menos densa.

### El resultado es inconcluso

- añade eventos independientes y mejor fechados;
- reduce duplicados biográficos;
- revisa zona horaria y coordenadas;
- interpreta un cluster como rango, no fuerces una hora puntual;
- conserva la conclusión “inconclusa” si la evidencia no discrimina.

### La narrativa IA falla

- comprueba proveedor y credenciales;
- verifica conexión de red;
- revisa límites o saldo del proveedor;
- conserva el resultado determinista: el fallo de la narrativa no invalida el análisis local.

### No se puede crear la nota Joplin

- abre Joplin Desktop;
- habilita Web Clipper;
- revisa host, puerto, token y cuaderno en Ajustes;
- prueba de nuevo sin asumir que el error afecta a la sesión guardada.

### Un JSON no se importa

- confirma que procede de Rectificación y no de una carta natal genérica;
- evita modificarlo manualmente;
- comprueba la versión de AstroMalik y el `schemaVersion`;
- conserva el mensaje de error y el archivo original para diagnóstico.

## 14. Privacidad y reproducibilidad

El cálculo y la persistencia son locales. Solo salen datos del Mac cuando el usuario inicia una integración que lo requiere, como una narrativa IA o una operación Joplin mediante su servicio local.

Para que una rectificación sea reproducible, conserva juntos:

- versión de AstroMalik;
- JSON de la sesión;
- PDF técnico;
- fuentes y nivel de certeza de cada evento;
- configuración y rango usados;
- modelo/proveedor de la narrativa, si existe;
- justificación profesional final, separada de los scores automáticos.

## 15. Estado de implementación

- **Fase 0**: precisión temporal, modelos y validación — completada.
- **Fase 1**: motor determinista y flujo UI — completada.
- **Fase 2**: narrativa IA opcional — completada.
- **Fase 3**: persistencia, historial y exportaciones — completada.
- **Fase 4**: cuestionario, confirmaciones profesionales, comparación, escuelas, pesos y control anti-overfitting — completada.

Validación final de AstroMalik 1.1.0: 386 tests ejecutados, 1 omitido y 0 fallos. Aplicación empaquetada y binario verificado con timestamp `2026-07-11 00:38:17 CEST`.

El diseño y seguimiento técnico detallado se mantienen en [`RECTIFICACION_HORA_NATAL_PLAN.md`](RECTIFICACION_HORA_NATAL_PLAN.md).
