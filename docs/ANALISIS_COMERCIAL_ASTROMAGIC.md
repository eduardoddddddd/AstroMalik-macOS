# Análisis comercial de Astromagic

> **Nota de alcance:** el repositorio actual es `AstroMalik-macOS`; este documento usa **Astromagic** como nombre comercial/provisional solicitado para el análisis.
>
> **Fecha:** 2026-05-04  
> **Objetivo:** evaluar la oportunidad comercial de una app astrológica de escritorio frente a software profesional de pago y alternativas gratuitas potentes.

---

## 1. Tesis principal

La oportunidad comercial más clara no está en competir con apps móviles masivas de horóscopos diarios, sino en el segmento **desktop / semi-pro / pro ligero**, especialmente en macOS.

El mercado de escritorio tiene precios altos:

- TimePassages Desktop: desde unos 79 USD hasta paquetes de cientos de dólares.
- iPhemeris Mac: alrededor de 99 EUR/USD.
- Astro Gold macOS: alrededor de 250 USD.
- Solar Fire / suites Windows profesionales: habitualmente varios cientos.

En ese contexto, una app nativa macOS seria, en español, privada, moderna y con motores clásicos fuertes podría tener sentido comercial en un rango inicial de **52–79 €**, siempre que se presente como producto terminado y no como experimento técnico.

La pregunta crítica es:

> Si existen alternativas gratuitas bastante potentes, ¿por qué alguien pagaría?

La respuesta corta:

> Porque en software profesional no se paga solo por “calcular una carta”. Se paga por **confianza, comodidad, soporte, flujo de trabajo, informes, integración con el sistema, estética, continuidad, documentación, licencia clara y ahorro de tiempo**.

---

## 2. Qué hace hoy AstroMalik / Astromagic

AstroMalik ya cubre una base muy superior a una simple calculadora natal:

- Carta natal.
- Rueda interactiva SwiftUI.
- Lectura natal guiada.
- Archivo local de cartas.
- Sinastría.
- Revolución solar.
- Revolución lunar.
- Tránsitos con scoring, prioridad y timeline.
- Ingresos por casa en tránsitos.
- Direcciones primarias Regiomontanas.
- Horaria clásica nativa.
- Corpus local en SQLite.
- Exportación a Joplin / Markdown.
- Funcionamiento local, sin cuenta obligatoria.
- Swiss Ephemeris embebido.
- Enfoque clásico y español.

Esto ya permite posicionar el producto como una herramienta astrológica de escritorio seria, sobre todo si se dirige a:

1. estudiantes avanzados;
2. astrólogos que quieren trabajar en español;
3. usuarios Mac que no quieren Windows, Wine ni Parallels;
4. personas que valoran privacidad/local-first;
5. practicantes de astrología clásica interesados en horaria y direcciones primarias.

---

## 3. Qué hacen las apps profesionales de pago que AstroMalik no hace todavía

### 3.1 Informes PDF profesionales

Este es el gap comercial más importante.

Las apps de pago venden mucho porque permiten entregar productos al cliente:

- informe natal PDF;
- informe de sinastría;
- informe predictivo anual;
- informe de revolución solar;
- reportes imprimibles;
- cartas y tablas exportables;
- branding o presentación suficientemente cuidada.

AstroMalik exporta Markdown/Joplin, pero todavía no tiene un sistema comercial de informes PDF con portada, rueda, tablas, interpretación, notas y estilo visual consistente.

**Prioridad comercial:** muy alta.

---

### 3.2 Progresiones secundarias y arco solar

Casi todos los programas desktop de pago incluyen:

- progresiones secundarias;
- Luna progresada;
- aspectos progresados a natal;
- arco solar;
- bi-ruedas natal/progresada;
- listados predictivos por fecha.

AstroMalik tiene direcciones primarias, que son más especializadas y valiosas en astrología clásica, pero le faltan progresiones secundarias y solar arc, que muchos usuarios modernos esperan como estándar.

**Prioridad comercial:** alta.

---

### 3.3 Composite / Davison / relación avanzada

AstroMalik tiene sinastría, pero muchas apps profesionales añaden:

- carta compuesta;
- carta Davison;
- grids de sinastría;
- bi-ruedas y tri-ruedas relacionales;
- informe de compatibilidad imprimible.

**Prioridad comercial:** alta-media.

---

### 3.4 Calendario astrológico y efemérides

Las herramientas de escritorio suelen ofrecer una capa de calendario:

- aspectos diarios del cielo;
- estaciones planetarias;
- retrogradaciones;
- lunaciones;
- eclipses;
- ingresos en signos;
- Luna vacía de curso;
- calendario mensual;
- efeméride textual o gráfica;
- búsqueda de eventos futuros.

AstroMalik tiene tránsitos por rango y timeline, pero no una pestaña completa de **Calendario / Efemérides**.

**Prioridad comercial:** alta.

---

### 3.5 Atlas y zonas horarias robustas

Los programas caros suelen presumir de atlas amplios y zonas horarias históricas.

AstroMalik tiene seed local + Nominatim, suficiente para uso personal, pero una app comercial debería mejorar:

- búsqueda de ciudades;
- histórico de zonas horarias y cambios DST;
- edición manual de coordenadas;
- lugares favoritos;
- validación clara de timezone;
- funcionamiento razonable offline.

**Prioridad comercial:** alta si se vende a profesionales.

---

### 3.6 Personalización pro

Software como Astro Gold, Solar Fire, Mastro o Astrolog permite tocar muchos parámetros:

- sistema de casas;
- orbes natales;
- orbes de tránsito;
- aspectos activados;
- puntos visibles;
- nodos medios/verdaderos;
- asteroides;
- Lilith;
- Quirón;
- Vertex;
- Parte de Fortuna;
- estilos de rueda;
- colores;
- símbolos;
- formatos de grados.

AstroMalik es más curado y cerrado. Eso mejora la experiencia, pero limita al usuario pro.

**Prioridad comercial:** media-alta.

---

### 3.7 Aspect grids, midpoints y tablas técnicas

Muchos programas desktop ofrecen:

- aspect grid natal;
- grid de sinastría;
- midpoints;
- midpoint trees;
- declinaciones;
- paralelos y contra-paralelos;
- velocidades planetarias;
- dignidades;
- aplicar/separar;
- exportación CSV.

AstroMalik tiene tablas por módulo, pero no una capa global de análisis técnico tabular.

**Prioridad comercial:** media.

---

### 3.8 Astrocartografía / relocación

Astro Gold y Solar Fire incluyen o venden módulos de astro-localidad / astrocartografía.

AstroMalik no tiene todavía:

- carta relocada como módulo explícito;
- mapas astrocartográficos;
- líneas ASC/DS/MC/IC;
- paran lines;
- local space.

**Prioridad comercial:** media-baja para una primera versión de 52 €, alta si se quiere competir con Astro Gold macOS.

---

### 3.9 Búsqueda astrológica e investigación

Programas avanzados permiten buscar en bases de cartas:

- cartas con Luna en casa 8;
- Venus cuadratura Saturno;
- Sol angular;
- próximos tránsitos exactos;
- eventos astrológicos por rango;
- cartas por planeta, casa, signo, aspecto o velocidad.

AstroMalik tiene búsqueda textual y archivo local, pero no un buscador astrológico semántico/técnico.

**Prioridad comercial:** media, pero con alto valor diferencial.

---

### 3.10 Import/export, backup y portabilidad

Una app comercial necesita:

- backup completo;
- restore;
- export JSON;
- export CSV;
- import CSV;
- export de carta como imagen;
- formato propio `.astromagic` o `.astromalik`;
- quizá compatibilidad parcial con formatos de otras apps.

**Prioridad comercial:** alta.

---

## 4. Apps gratuitas potentes: cuáles son y qué implican

La existencia de software gratuito potente es real. No debe ignorarse.

### 4.1 Planetdance

Planetdance es probablemente una de las alternativas gratuitas más peligrosas para cualquier producto de pago en Windows.

Según reseñas y documentación pública, ofrece:

- Windows y Android;
- Swiss Ephemeris;
- natal;
- antiscia;
- progresiones;
- retornos;
- armónicos;
- sinastría;
- composite;
- bi-ruedas progresadas y de tránsito;
- estrellas fijas;
- partes arábigas;
- midpoint trees;
- efemérides mensuales;
- asteroides;
- sectores Gauquelin;
- gestor de archivos;
- búsqueda por planeta/signo/casa/aspecto;
- lenguaje propio de scripting, Astrobasic;
- módulos ampliables;
- gráficas de tránsitos;
- atlas de cambios horarios.

**Lectura:** si el usuario trabaja en Windows y tolera su interfaz, Planetdance puede cubrir muchísimo sin pagar.

**Dónde puede ganar Astromagic:** Mac nativo, español, UX más moderna, informes, soporte, estética, foco clásico integrado y menor fricción.

Fuente: [Planetdance review / feature overview](https://www.soulhealing.com/planetdance.htm)

---

### 4.2 Astrolog

Astrolog es freeware/open source y existe desde 1991. La web oficial indica que Astrolog 7.80 es 100% freeware, con versiones para Windows, Unix y Macintosh, y código fuente disponible.

Tiene una amplitud enorme:

- rueda estándar;
- bi-wheel;
- quad-wheel;
- hexa-wheel;
- aspect/midpoint grid;
- graphic ephemeris;
- graphic transits;
- transit calendar;
- local horizon;
- astrocartography;
- mapas;
- Gauquelin sectors;
- diales;
- estilos de astrología india;
- animaciones;
- muchos cuerpos menores;
- línea de comandos.

**Lectura:** Astrolog demuestra que “gratis” no significa “pobre”. En breadth técnico puede superar a muchas apps comerciales.

**Dónde puede ganar Astromagic:** interfaz moderna, producto enfocado, idioma español, informes interpretativos, flujo de consulta, soporte comercial, menor curva de aprendizaje.

Fuentes: [Astrolog oficial](https://www.astrolog.org/astrolog.htm), [features](https://www.astrolog.org/astrolog/astdemo.htm)

---

### 4.3 Morinus

Morinus es una alternativa gratuita/open-source muy relevante para astrología tradicional. Es conocida por su trabajo con direcciones primarias y técnicas clásicas.

Suele cubrir:

- cartas natales;
- tránsitos;
- progresiones;
- retornos;
- sinastría;
- tablas;
- sistemas de casas clásicos;
- técnicas tradicionales;
- direcciones primarias.

**Lectura:** Morinus compite especialmente con la parte clásica de AstroMalik, pero suele tener una experiencia menos comercial, menos moderna y menos integrada para usuario final.

Fuente: [Morinus overview](https://sugggest.com/software/morinus)

---

### 4.4 Astrocalc

Astrocalc fue software comercial desde 1982 y pasó a ser gratuito. Su propia web explica que se liberó como software gratuito no comercial, con funcionalidad completa y sin límite temporal.

Cubre:

- cartas natales;
- tránsitos;
- progresiones;
- retornos;
- midpoints;
- sinastría;
- cálculos Huber;
- uso offline.

**Lectura:** hay programas gratuitos porque algunos autores ya amortizaron el producto, lo mantienen por vocación, o prefieren donaciones/comunidad a venta directa.

Fuente: [Astrocalc](https://www.astrocalc.com/)

---

### 4.5 Mastro Standard

Mastro es especialmente importante porque parece responder a la descripción de “gratuita, vistosa y profesional”. Su web presenta Mastro 7 como software Windows moderno, práctico y completo. La edición **Standard** es gratuita, mientras que **Expert** cuesta 240 CAD.

Mastro anuncia:

- natal;
- tránsitos;
- bi-wheel y tri-wheel;
- progresiones;
- armónicos;
- retornos;
- profecciones;
- direcciones primarias;
- midpoints;
- nodos;
- asteroides;
- estrellas fijas;
- eclipses;
- ingresos;
- interpretación;
- personalización de casas, estilos, orbes y zodiaco tropical/sidereal.

La edición Expert añade interpretación natal/evento/sinastría, forecast curves, research, guardado avanzado de eventos, gestión avanzada de cartas y base de figuras públicas.

**Lectura:** Mastro confirma que el modelo freemium existe también en escritorio pro: se regala una base muy potente y se cobra por interpretación, investigación, gestión avanzada y predicción asistida.

Fuente: [Mastro](https://mastroapp.com/en/)

---

### 4.6 Jagannatha Hora

Jagannatha Hora es una referencia gratuita en astrología védica/Jyotish para Windows.

No compite directamente con AstroMalik si el foco es astrología occidental/clásica, pero sí demuestra que en escritorio hay herramientas gratuitas de enorme profundidad técnica.

**Lectura:** el usuario védico probablemente no pagará por AstroMalik si busca Jyotish. No debe ser el mercado inicial.

Fuente: [Jagannatha Hora / VedicAstrologer](https://vedicastrologer.org/jh/index.htm)

---

## 5. Entonces, ¿por qué existen apps gratuitas y de pago a la vez?

Porque no venden exactamente lo mismo.

### 5.1 Las gratuitas suelen nacer de motivaciones distintas

Muchas gratuitas existen por:

- vocación personal;
- comunidad open-source;
- software antiguo liberado;
- donaciones;
- versión gratuita que empuja a una versión Expert;
- prestigio del autor;
- investigación;
- nichos técnicos donde el autor no busca maximizar ingresos.

Eso explica por qué pueden ser muy buenas y aun así no destruir el mercado de pago.

---

### 5.2 La potencia no equivale a producto comercial

Una app gratuita puede tener 200 funciones, pero fallar en:

- onboarding;
- estética;
- claridad;
- soporte;
- documentación moderna;
- instalador seguro;
- firma/notarización;
- actualizaciones previsibles;
- idioma;
- informes vendibles al cliente;
- integración con macOS;
- continuidad comercial.

El usuario profesional muchas veces no paga por más fórmulas, sino por **menos fricción**.

---

### 5.3 Windows no es macOS

Muchas gratuitas potentes están en Windows. Algunas funcionan en Mac de forma antigua, limitada o mediante capas no ideales.

El usuario Mac puede pagar por:

- app nativa Apple Silicon;
- interfaz SwiftUI moderna;
- firma y notarización;
- instalación limpia;
- buen rendimiento;
- integración con Finder, PDF, Share Sheet, iCloud o Joplin;
- no depender de Wine, Parallels o una VM.

Aquí AstroMalik/Astromagic tiene una oportunidad real.

---

### 5.4 El usuario que cobra consultas necesita entregables

Un astrólogo que cobra una consulta puede amortizar 52 € muy rápido si la app le permite:

- preparar informes;
- guardar clientes;
- exportar PDF;
- generar notas;
- revisar tránsitos del año;
- hacer horarias;
- imprimir ruedas limpias;
- ahorrar tiempo.

Ese usuario no pregunta “¿hay una gratis?”. Pregunta:

> ¿Me ahorra tiempo, me da confianza y me permite entregar mejor trabajo?

---

### 5.5 La licencia importa

Algunas gratuitas son GPL/open-source, freeware, non-commercial o tienen condiciones concretas.

Para uso personal no importa mucho. Para uso comercial/profesional, empresas, academias o distribución interna, puede importar:

- qué licencia tiene;
- si permite uso comercial;
- si obliga a publicar cambios;
- si el motor ephemeris tiene licencia compatible;
- si hay soporte;
- si hay facturación.

Una app de pago puede vender también **claridad legal y soporte**.

---

## 6. Quién compraría Astromagic si hay gratis

### 6.1 Usuario Mac que quiere algo nativo

Perfil:

- usa Mac como máquina principal;
- no quiere instalar software Windows;
- no quiere emuladores;
- valora diseño limpio;
- pagaría 52 € por una app que “simplemente funciona”.

Este es el perfil más obvio.

---

### 6.2 Astrólogo hispanohablante

La mayoría de herramientas potentes están en inglés, francés o interfaces técnicas poco localizadas.

Astromagic puede diferenciarse por:

- español nativo;
- textos interpretativos en español;
- documentación en español;
- enfoque clásico comprensible;
- informes exportables en español.

---

### 6.3 Estudiante serio de astrología clásica

Perfil:

- quiere aprender horaria;
- quiere ver dignidades;
- quiere direcciones primarias;
- quiere entender por qué un tránsito importa;
- no quiere una app tipo Co-Star;
- quiere una herramienta didáctica pero seria.

AstroMalik ya tiene ventaja aquí.

---

### 6.4 Consultor que quiere informes y archivo

Perfil:

- guarda clientes;
- prepara sesiones;
- exporta documentos;
- necesita organizar cartas;
- quiere notas por carta;
- quiere PDF o Markdown;
- valora Joplin/Obsidian/archivo local.

Este usuario sí paga si la app le ahorra una hora de trabajo.

---

### 6.5 Usuario que no quiere suscripciones

El mercado está cansado de suscripciones. Una app a 52 € con licencia clara puede venderse como:

> “Pago único. Sin cuenta. Sin nube obligatoria. Sin suscripción.”

Eso es un argumento comercial muy fuerte.

---

## 7. Riesgo real: qué pasa si el usuario compara contra Planetdance/Mastro/Astrolog

Si Astromagic se vende solo como:

> “Calcula cartas, tránsitos y sinastría”

entonces pierde contra las gratuitas.

Porque Planetdance, Astrolog o Mastro Standard pueden hacer muchísimo.

Pero si se vende como:

> “La app macOS nativa, moderna, en español, privada, con horaria clásica, direcciones primarias, tránsitos explicables e informes profesionales”

entonces ya no compite en la misma categoría.

---

## 8. Gaps prioritarios para que 52 € sea defendible

Antes de vender a 52 €, priorizaría estas mejoras:

### Imprescindibles

1. **Exportación PDF profesional.**
2. **Backup / restore / export / import de cartas.**
3. **Preferencias pro mínimas:** orbes, casas, puntos, aspectos.
4. **Progresiones secundarias.**
5. **Solar Arc.**
6. **Composite o Davison.**
7. **Calendario astrológico mensual.**
8. **Firma/notarización/instalador limpio.**
9. **Licencia Swiss Ephemeris resuelta para uso comercial.**
10. **Corpus textual limpio legalmente.**

### Muy recomendables

11. Efeméride gráfica.
12. Aspect grid natal y sinastría.
13. Midpoints básicos.
14. Relocación natal.
15. Gestor de lugares/timezones mejorado.
16. Manual rápido dentro de la app.
17. Landing page comercial.
18. Sistema de licencia/pago simple.

### No prioritarios para primera versión

19. Astrocartografía avanzada.
20. Uranian/cosmobiology completa.
21. Vedic completo.
22. Rectificación automática.
23. Cientos de partes arábigas.
24. Page designer tipo Solar Fire.
25. Scripting interno tipo Astrobasic.

---

## 9. Posicionamiento recomendado frente a gratuitas

No decir:

> “Más funciones que Planetdance.”

Sería difícil y no necesario.

Decir:

> “Astromagic es una app nativa para macOS, pensada para trabajar astrología clásica y predictiva en español, con privacidad local, informes exportables y una interfaz moderna.”

Mensajes posibles:

- “Sin suscripción. Sin cuenta. Sin nube obligatoria.”
- “Más simple que Solar Fire, más barata que Astro Gold, más seria que una app de horóscopos.”
- “Horaria, direcciones primarias, tránsitos explicados y revoluciones en una app Mac nativa.”
- “Para estudiantes y consultores que quieren trabajar, no pelearse con el software.”

---

## 10. Precio recomendado

### Opción A: lanzamiento fundador

- **52 € pago único**.
- Licencia personal.
- Actualizaciones menores incluidas.
- Precio fundador limitado.

Ventaja: convierte fácil y valida mercado.

Riesgo: puede quedar bajo si la app crece mucho.

### Opción B: precio normal

- **79 € pago único**.
- Descuento lanzamiento a 52 €.

Ventaja: posiciona mejor frente a iPhemeris/TimePassages.

### Opción C: dos ediciones

- **Astromagic Basic — 39/49 €**: natal, archivo, tránsitos, sinastría, revoluciones.
- **Astromagic Pro — 79/99 €**: horaria, direcciones primarias, informes PDF, progresiones, solar arc.

Ventaja: permite competir contra gratuitas sin regalar todo.

---

## 11. Veredicto

Sí, existen apps gratuitas de escritorio muy potentes. Algunas son incluso más amplias que AstroMalik en número de técnicas.

Pero eso no elimina la oportunidad comercial.

La oportunidad de Astromagic no es ser “el software con más funciones del mundo”. La oportunidad es ser:

> **la herramienta macOS nativa, privada, en español, enfocada en astrología clásica/predictiva, con una experiencia moderna y entregables profesionales.**

A 52 €, el producto puede ser defendible si se cierra el gap de informes/exportación y se añaden algunas técnicas esperadas por usuarios desktop: progresiones, solar arc, composite/Davison y calendario/efemérides.

El usuario que compra no será el que disfruta configurando Astrolog o Planetdance durante horas. Será el que quiere una app limpia, actual, Mac-first, en español, con soporte y flujo de trabajo profesional.

---

## 12. Fuentes consultadas

- Astro Gold macOS: https://www.astrogold.io/get-astro-gold/for-macos/
- TimePassages Desktop: https://www.astrograph.com/timepassages/editions.php
- iPhemeris Mac/iOS App Store: https://apps.apple.com/us/app/iphemeris-astrology/id908985824
- Solar Fire overview: https://astrologysuite.com/
- Planetdance overview: https://www.soulhealing.com/planetdance.htm
- Astrolog official site: https://www.astrolog.org/astrolog.htm
- Astrolog features: https://www.astrolog.org/astrolog/astdemo.htm
- Morinus overview: https://sugggest.com/software/morinus
- Astrocalc: https://www.astrocalc.com/
- Mastro: https://mastroapp.com/en/
- Jagannatha Hora: https://vedicastrologer.org/jh/index.htm
