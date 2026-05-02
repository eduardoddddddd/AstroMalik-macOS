# Revisión del Módulo de Direcciones Primarias

He realizado un análisis profundo de `PrimaryDirectionCalculator.swift` y su modelo de datos `PrimaryDirection.swift`. A diferencia del motor de Tránsitos, este módulo tiene una arquitectura mucho más robusta y moderna, pero contiene un error lógico matemático en la asignación de pesos y algunas decisiones astrológicas debatibles.

A continuación, te presento el informe completo:

---

## 1. Fortalezas Técnicas y Arquitectónicas (¡Muy bien hecho!)

* **Rendimiento Soberbio:** El algoritmo está altamente optimizado. A diferencia de otros programas que iteran día por día para encontrar la dirección, este motor **calcula las coordenadas ecuatoriales una sola vez** (`computeEquatorialBodies`) en el momento del nacimiento y usa trigonometría esférica pura para proyectar los arcos. Esto hace que calcular 120 años de direcciones tome milisegundos.
* **Concurrencia (Swift 6):** La clase `PrimaryDirectionCalculator` está marcada como `Sendable` y sus funciones son puras (no tienen estado mutado). Esto es perfecto para ejecutarlo en un `Task.detached` sin bloquear la UI.
* **Precisión Matemática:** 
  * El uso del `RegiomontanusSpeculum` para calcular la Distancia Meridiana y el Polo es matemáticamente exacto según el algoritmo de Morinus.
  * Diferencia correctamente entre direcciones **Zodiacales** (usando la latitud del prómissor pero latitud 0 para el aspecto eclíptico) y **Mundanas** (proyección directa sobre el polo).
  * Soporta direcciones directas y **conversas**.
* **Cálculo de Secta:** El Parte de Fortuna se calcula correctamente diferenciando nacimientos diurnos y nocturnos comprobando si el Sol está sobre el horizonte (`solSpec.aboveHorizon`).

---

## 2. Bug Lógico Crítico en el Scoring (`computeWeight`)

He detectado un error de lógica de programación en la función que asigna la importancia a la dirección.

```swift
let isLuminary = ["SOL", "LUNA"].contains(promissor)
let isMalefic = ["MARTE", "SATURNO"].contains(promissor)
let isBenefic = ["JUPITER", "VENUS"].contains(promissor)

// Más abajo...
if isLuminary && (isMalefic || isBenefic) {
    return .major
}
```
**Problema:** Estás comprobando si la variable `promissor` es una Luminaria **Y a la vez** es un Maléfico o Benéfico. Una cadena de texto no puede ser "SOL" y "MARTE" al mismo tiempo. Esa condición **siempre es falsa (`false`)** y ese bloque de código nunca se ejecuta.
* **Solución:** Lo más probable es que quisieras comprobar si el *Significador* es una luminaria y el *Prómissor* es el planeta:
  `let isSigLuminary = ["SOL", "LUNA"].contains(significator)`
  `if isSigLuminary && (isMalefic || isBenefic) { return .major }`

---

## 3. Decisiones Astrológicas Debatibles (Scoring)

El sistema de pesos (`weight`) deforma un poco la prioridad de los eventos astrológicos importantes:

* **Desprecio a los Transpersonales:** 
  ```swift
  let isTranspersonal = ["URANO", "NEPTUNO", "PLUTON"].contains(promissor)
  if isTranspersonal { return .minor }
  ```
  En astrología, cuando un transpersonal hace un aspecto exacto por dirección primaria a un ángulo o luminaria, marca las crisis o cambios más profundos de una vida (ej. Plutón cuadratura Ascendente). Rebajarlos automáticamente a `.minor` contradice tanto la astrología evolutiva como la predictiva moderna. Deberían ser `.major` o `.critical` dependiendo de a qué toquen.
* **Ángulos y Benéficos:** Solo das categoría `.critical` si un Ángulo es tocado por una Luminaria o un Maléfico en aspecto duro. Pero una conjunción de Júpiter o Venus al MC/ASC por dirección primaria es uno de los indicadores más famosos de matrimonio, éxito o cumbre profesional. Deberían poder alcanzar la categoría `.critical`.

---

## 4. Funcionalidades Astrológicas Faltantes (Para el futuro)

Si en el futuro quieres llevar este módulo al nivel de software profesional como *Solar Fire* o *Delphic Oracle*, faltan dos conceptos tradicionales clave:

1. **Dirección a través de los Términos (Bounds):** La astrología clásica medieval (Ptolomeo, Doroteo, Egipcios) no solo dirigía planetas contra planetas, sino que dirigía el Hyleg (ej. el Ascendente o el Sol) a través de los "Términos" de los signos. El cambio de término de un significador (ej. pasar del término de Venus al término de Marte) dictaba la narrativa de un periodo de 5-10 años.
2. **Antiscios:** Muchos astrólogos tradicionales consideran las direcciones primarias de los antiscios (planetas reflejados en el eje solsticial Cáncer-Capricornio) como direcciones mayores.

---
*No he modificado ningún archivo de código, tal y como solicitaste.*
