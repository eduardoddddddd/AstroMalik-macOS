# Astrocartografía — metodología y límites

Qué calcula AstroMalik, con qué convenio y qué no afirma. El detalle de exportación está en [ASTROCARTOGRAFIA_EXPORTACION.md](ASTROCARTOGRAFIA_EXPORTACION.md). El cierre de pruebas de la fase 7 está en [ASTROCARTOGRAFIA_F7_INFORME.md](ASTROCARTOGRAFIA_F7_INFORME.md).

## Alcance de esta versión

Con una carta natal activa, el programa dibuja **10 planetas × 4 ángulos = 40 líneas**: Sol, Luna, Mercurio, Venus, Marte, Júpiter, Saturno, Urano, Neptuno y Plutón; Ascendente, Descendente, Medio Cielo y Fondo del Cielo.

Sobre un lugar se puede ver la distancia a cada línea, un resumen, las lecturas de las líneas cercanas, la carta relocada y una comparación de hasta 6 lugares. Los temas (profesión, pareja, hogar, identidad, crecimiento, intensidad) filtran y ordenan. No puntúan ni recomiendan dónde vivir.

Fuera de esta versión: parans, Local Space, bandas de incertidumbre horaria, nodos, cuerpos extra y narrativa generada por un modelo de lenguaje.

## Convenio de cálculo

Identificador: `geocentric-apparent-of-date-geometric-center-v1`.

- Posiciones **aparentes geocéntricas de la fecha**, con las efemérides Swiss vendorizadas (2.10.03) y los ficheros locales `_18` y `_24`.
- El horizonte es el del **centro geométrico**. No se aplica refracción, semidiámetro ni corrección topocéntrica.
- El instante natal se guarda como día juliano en la escala `utcApproximatedAsUT1`: la conversión actual no aplica DUT1. No es UT1 exacto.
- El rango de entrada es del 1800-01-01 incluido al 3000-01-01 excluido. En el límite inicial el Sol puede calcularse sin fichero Swiss; eso se muestra como diagnóstico, no se oculta.
- Longitud terrestre positiva hacia el este, en el intervalo canónico `[-180, 180)`.
- MC e IC son los meridianos de culminación, separados 180°. No significan que el planeta sea visible.
- ASC y DSC son el cruce del planeta con el horizonte geométrico. Si la declinación no deja un cruce único, la línea no se inventa: queda vacía y con aviso.
- La geometría adaptativa apunta a una cota de discretización de **1 km** en la esfera usada por el programa. Esa cota no es exactitud astronómica ni «intensidad» simbólica.

La carta relocada conserva las longitudes planetarias natales y recalcula casas y ángulos para el lugar. No reinterpreta la hora natal ni cambia la carta guardada.

## Distancias, lecturas y temas

La distancia es la mínima sobre los arcos de la curva, no sobre vértices sueltos ni sobre píxeles del mapa. Los umbrales de partida son **100 km** (cerca) y **300 km** (regional); se cambian en la pestaña Lugar. Una línea más cercana no es «más fuerte».

Las 40 lecturas son textos originales de AstroMalik, revisados por el usuario el 02/10/2026. Describen un tono simbólico del lugar. No predicen hechos, salud, pareja ni decisiones. Si faltara un texto, el programa lo dice y no lo rellena.

## Qué necesita red y qué no

El cálculo, las distancias, las lecturas, el SVG del informe y la CLI funcionan sin Internet. Pueden usar red, y solo si se piden:

- el mapa base de Apple en pantalla;
- la casilla de mapa base en el PDF (si falla o no hay red, el informe sale igual, con cuadrícula y el motivo);
- la búsqueda de lugares en línea, cuando el catálogo local no basta;
- Joplin, al pulsar «Exportar a Joplin» contra el Web Clipper local.

Nada de eso se envía solo.

## Ejemplo reproducible

El caso de referencia del benchmark no es una persona. Es el instante JD **2451545.0** (2000-01-01 12:00 en la escala del programa), diez cuerpos y tolerancia de 1 km. En la máquina de la fase 7 el motor y la geometría, ya en caliente y sin mapa, quedan muy por debajo del segundo. Los percentiles medidos están en el informe de la fase 7.

Con una carta ya guardada, la misma salida se pide así (no abre red ni el corpus):

```bash
astromalik-cli astrocartography --chart "Nombre" --lat 40.4168 --lon -3.7038 --format markdown
astromalik-cli astrocartography --chart "Nombre" --place "Madrid" --near-km 100 --regional-km 300
```

`--place` usa el catálogo local. JSON estable: `schemaVersion: 1`, `kind: "astromalik.astrocartography"`, sin marca de tiempo.

## Cómo leer un desacuerdo con otro programa

Antes de tratar una diferencia como un error, hay que igualar el convenio: geocéntrico aparente de la fecha, sin topocentro, sin refracción y sin DUT1. Un desfase de unos **4 minutos** en la hora mueve todas las líneas cerca de **1° de longitud**, unos **110 km** en el ecuador. Si la hora es dudosa, las líneas son una zona, no una frontera.
