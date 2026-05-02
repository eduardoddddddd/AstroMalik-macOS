# Evaluación Astrológica Profesional de AstroMalik

He examinado a fondo la suite completa de motores de cálculo de AstroMalik (`AstroEngine`, `EssentialDignityEngine`, `TransitEngine`, `PrimaryDirectionCalculator`, `SolarReturnEngine`, `LunarReturnEngine`).

**Veredicto General:** AstroMalik tiene una base matemática excelente gracias a la integración con *Swiss Ephemeris*. El motor de dignidades tradicionales y el de direcciones primarias son matemáticamente superiores a la media de las apps comerciales. Sin embargo, carece de ciertas configuraciones básicas que un astrólogo profesional da por sentadas (como el cambio de sistema de casas), y tiene algunas decisiones de diseño predictivo que mezclan conceptos natales con tránsitos.

A continuación, el diagnóstico detallado por módulos.

---

## 1. Motor Base y Configuración (AstroEngine & Settings)

> [!WARNING]
> **El problema de la rigidez estructural**

* **Sistema de Casas Fijo:** El motor tiene el sistema de Placidus incrustado en código duro (`hsys = 80 // 'P'`). Un astrólogo profesional necesita poder cambiar a Casas Signo Completo (Whole Sign), Koch o Regiomontanus (especialmente si usas direcciones primarias Regiomontanas).
* **Ausencia de Nodos y Lilith:** La lista `PLANET_LIST` se detiene en Plutón. La falta de los Nodos Lunares (Verdadero y Medio) es una carencia crítica para cualquier análisis kármico, evolutivo o de eclipses. Lilith (Luna Negra) y Quirón también son estándares en la astrología moderna.
* **Zodiaco Fijo:** No hay opción para calcular cartas sidéreas (Lahiri, Fagan/Bradley), asumiendo siempre el zodiaco Tropical.

## 2. Astrología Tradicional y Dignidades (EssentialDignityEngine)

> [!TIP]
> **La joya de la corona tradicional**

* **Fortaleza excepcional:** Este motor es brillante. Calcula domicilios, exaltaciones, triplicidades (respetando la secta diurna/nocturna de Doroteo), términos egipcios y decanatos caldeos. Además, calcula perfectamente la Secta de la carta (diurna/nocturna según si el Sol está sobre el horizonte) y las recepciones mutuas.
* **Mejoras posibles:** 
  * Permitir elegir entre Términos Egipcios y Ptolemaicos (muchos astrólogos prefieren Ptolomeo).
  * Calcular el *Almuten Figuris* (el señor de la carta) sumando estas dignidades para los lugares hylegíacos. Dado que ya tienes el cálculo de puntos de dignidad exacto (+5, +4, +3...), calcular el Almuten sería trivial y un rasgo muy pro.

## 3. Direcciones Primarias (PrimaryDirectionCalculator)

> [!NOTE]
> **Precisión matemática impecable con sesgos interpretativos**

* **Fortalezas:** Usa trigonometría esférica real con el *Speculum* de Regiomontanus (algoritmo de Morinus). Las claves de tiempo (Naibod, Ptolomeo, Brahe real) y el soporte para direcciones conversas y mundanas/zodiacales lo ponen al nivel de software como *Solar Fire*.
* **Deficiencias:**
  * **Pesos Transpersonales:** Urano, Neptuno y Plutón están codificados como de impacto `.minor`. En la práctica, una dirección de Plutón al Ascendente marca la crisis de una década. Degradarlos por defecto es un error.
  * **Ausencia de Direcciones por los Términos:** En la astrología tradicional, la técnica reina es dirigir el Hyleg (ej. el Sol) a través de los Términos. Saber cuándo la vida pasa del "término de Venus" al "término de Saturno" es clave, y el motor actual solo dirige planetas a aspectos.

## 4. Tránsitos (TransitEngine)

> [!CAUTION]
> **Fallo crítico en los orbes**

* **El problema de los Orbes:** El motor reutiliza `ASPECT_DEFS` (que tiene orbes natales, ej. 8° para una conjunción). En tránsitos, un orbe de 8° para Plutón significa que el tránsito dura 6 años seguidos sin parar. Los tránsitos requieren orbes independientes y muy cerrados (1° a 3° máximo).
* **Ingresos (Ingresses):** El motor detecta aspectos a planetas natales, pero ignora cuando un planeta lento *cambia de casa*. Un ingreso de Saturno en la Casa 1 es un evento monumental que no aparece en la tabla actual.
* **Aspectos Menores:** Falta el Quincuncio (150°), crucial para tránsitos de ajuste (sobre todo con planetas exteriores).

## 5. Retornos Solares y Lunares (Solar & Lunar Return Engines)

> [!TIP]
> **Buena síntesis temática**

* **Fortalezas:** El cálculo exacto (solcross/mooncross) es perfecto. Evaluar la intensidad del retorno lunar basándose en planetas en casas angulares y cuadraturas a la Luna es una técnica analítica excelente y muy "humana". Rastrear repeticiones natales (planeta de RS en la misma casa que en la natal) es un toque profesional muy sofisticado.
* **Mejoras posibles:**
  * **Precesión:** No permite retornos solares con corrección de precesión (Sidereal Solar Returns), una técnica que muchos astrólogos predictivos prefieren para mantener el retorno alineado con las estrellas fijas en lugar del punto vernal a medida que la persona envejece.
  * **Orbes de Retorno:** Al igual que en los tránsitos, usa los orbes natales para calcular los aspectos dentro del retorno. La carta de retorno suele interpretarse con orbes algo más estrictos.

---

## Conclusión

AstroMalik tiene "el motor de un Ferrari" gracias a Swiss Ephemeris y al excelente código trigonométrico y de dignidades. Sin embargo, el "salpicadero" no le da al piloto (al astrólogo profesional) los controles básicos (casas, nodos, orbes diferenciados). 

Para que la app compita o deslumbre a profesionales, el orden de prioridades arquitectónicas debería ser:
1. **Separar los orbes** (Natal vs Tránsitos).
2. **Añadir los Nodos Lunares** a todos los motores.
3. **Parametrizar el sistema de Casas** (`SettingsView` -> `AstroEngine`).
4. Añadir Ingresos (cambios de casa) a los Tránsitos.
