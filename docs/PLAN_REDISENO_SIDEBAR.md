# Rediseño gráfico de la navegación de AstroMalik

> [!NOTE]
> **✅ IMPLEMENTADO (2026-06-09).** Se aplicó la **Opción A** con tres ajustes acordados con el usuario:
> 1. Orden de secciones: **Predictivas antes que Retornos** (flujo real de consulta).
> 2. Renombrados: *Estado cross* → **"Panorama Predictivo"**; *Mis informes* → **"Informes"**. (*Lectura* se mantiene.)
> 3. Cabeceras sobrias sin emoji (small-caps + tracking + color acento teal); fila de Síntesis resaltada con `appSecondaryAccent`.
>
> **Decisión técnica clave:** se separó la identidad del caso (`rawValue`, estable) del texto visible (nueva propiedad `NavItem.label`), de modo que renombrar etiquetas nunca afecta la lógica de navegación. `selectedNav` es `@Published` sin persistencia, así que reordenar los cases fue seguro. El `switch` de `showDefaultDetail` y el de `detailRoute` no se tocaron.
>
> **Estructura final del sidebar (6 secciones):**
> Carta Natal · Predictivas · Retornos · Síntesis · Sinastría y Horaria · Herramientas.
>
> Archivos modificados: `AppNavigation.swift` (reorden + `label`), `ContentView.swift` (6 `Section` + `sidebarSectionHeader` + `sidebarItem(_:highlighted:)`). `AppTheme.swift` **no** requirió cambios (el header usa tokens existentes). Build limpio; app reempaquetada.

---

Reorganizar la presentación de opciones del sidebar sin cambiar la funcionalidad.
La app funciona perfectamente — el objetivo es que la estructura de navegación sea más intuitiva, agrupada por flujo de trabajo del astrólogo.

## User Review Required

> [!IMPORTANT]
> Este plan propone **una nueva agrupación conceptual** del sidebar. Necesito tu feedback sobre si la organización propuesta se ajusta a cómo tú usas la app, ya que como astrólogo tú sabes mejor que nadie cuál es el flujo natural.

> [!IMPORTANT]
> También propongo un cambio cosmético en la cabecera del sidebar. Confirma si quieres mantener el look actual o prefieres algo distinto.

## Estado actual

Sidebar con **16 items** en **4 secciones** (planas):

| Sección | Items |
|---------|-------|
| **Cartas** | Nueva Carta · Cartas Guardadas · Lectura |
| **Predictivas** | Profecciones · Firdaria · Zodiacal Releasing · Estado Cross |
| **Técnicas** | Tránsitos · Progresiones · Dir. Primarias · Rev. Solar · Rev. Lunar · Sinastría · Efemérides · Horaria |
| **Ajustes** | Mis Informes · Ajustes |

### Problemas de la organización actual

1. **"Técnicas" es un cajón de sastre** — mezcla técnicas predictivas (tránsitos, progresiones, direcciones), con comparativas (sinastría), retornos cíclicos (RS, RL) y referencia (efemérides)
2. **"Predictivas" vs "Técnicas" es confusa** — profecciones, firdaria y ZR son tan "técnicas" como tránsitos o progresiones; la distinción es arbitraria
3. **Sinastría** está perdida entre técnicas predictivas cuando es un concepto aparte (relación entre dos personas)
4. **Horaria** es una rama completamente distinta de la astrología (evento puntual, no basada en natal)
5. **Efemérides** es una herramienta de referencia, no una "técnica" per se
6. **Cross-personal** ("Estado cross") es realmente el resultado/síntesis de todas las predictivas, no una predictiva más

## Propuesta de nueva estructura

### Opción A — Agrupación por flujo de trabajo (Recomendada)

```
── ★ CARTA NATAL ──────────────────
   ☆ Nueva Carta
   ☆ Cartas Guardadas
   ☆ Lectura / Análisis

── ⟳ RETORNOS ─────────────────────
   ☆ Revolución Solar
   ☆ Revolución Lunar

── ⏳ PREDICTIVAS ──────────────────
   ☆ Tránsitos
   ☆ Progresiones
   ☆ Direcciones Primarias
   ☆ Profecciones
   ☆ Firdaria
   ☆ Zodiacal Releasing

── 🔮 SÍNTESIS ─────────────────────
   ☆ Panorama cross-personal

── ♎ OTRAS RAMAS ──────────────────
   ☆ Sinastría
   ☆ Horaria

── 📋 HERRAMIENTAS ────────────────
   ☆ Efemérides
   ☆ Mis Informes
   ☆ Ajustes
```

**Rationale:**
- **Carta Natal** = punto de entrada, donde empieza todo
- **Retornos** = técnicas cíclicas anuales/mensuales que giran en torno a un cumpleaños. Separadas por su identidad conceptual propia
- **Predictivas** = todas las técnicas que predicen evolución temporal sobre la natal, agrupadas juntas sin distinción artificial entre "técnicas" y "predictivas"
- **Síntesis** = cross-personal destaca como **culminación/resumen** de las predictivas, no como una más
- **Otras Ramas** = sinastría (relación) y horaria (pregunta) son ramas autónomas de la astrología, no son sobre la natal
- **Herramientas** = utilidades de apoyo (efemérides, informes, configuración)

### Opción B — Más compacta (menos secciones)

```
── CARTA NATAL ─────────────────────
   Nueva Carta · Guardadas · Lectura

── PREDICTIVAS Y RETORNOS ──────────
   Tránsitos · Progresiones · Dir. Primarias
   Profecciones · Firdaria · Zodiacal Releasing
   Rev. Solar · Rev. Lunar
   ─ Panorama cross ─

── SINASTRÍA Y HORARIA ─────────────
   Sinastría · Horaria

── HERRAMIENTAS ────────────────────
   Efemérides · Informes · Ajustes
```

### Opción C — Agrupar cross-personal dentro de predictivas

```
── CARTA NATAL ─────────────────────
   Nueva Carta · Guardadas · Lectura

── RETORNOS ────────────────────────
   Rev. Solar · Rev. Lunar

── PREDICTIVAS ─────────────────────
   Tránsitos · Progresiones · Dir. Primarias
   Profecciones · Firdaria · ZR
   ─ Panorama cross ─

── RELACIONES Y HORARIA ────────────
   Sinastría · Horaria

── HERRAMIENTAS ────────────────────
   Efemérides · Informes · Ajustes
```

## Open Questions

> [!IMPORTANT]
> **¿Cuál de las 3 opciones prefieres?** ¿O quieres mezclar ideas entre ellas?

> [!IMPORTANT]
> **¿Cross-personal debería tener sección propia ("Síntesis") o estar dentro de Predictivas?** En la Opción A lo destaco como culminación; en B y C está integrado.

> [!IMPORTANT]
> **¿Horaria debería ir con Sinastría o sola?** Conceptualmente ambas son ramas distintas de la astrología natal, pero horaria es más diferente aún.

> [!IMPORTANT]
> **¿Quieres renombrar algún item?** Por ejemplo:
> - "Estado cross" → "Panorama cross-personal" o "Síntesis predictiva"
> - "Lectura" → "Lectura / Análisis" o mantener "Lectura"
> - "Mis Informes" → "Informes PDF"

> [!IMPORTANT]
> **¿Quieres algún cambio visual adicional?** Por ejemplo:
> - Separadores visuales más marcados entre secciones
> - Iconos/emojis en las cabeceras de sección
> - Badges (puntos de color) para indicar si hay carta activa
> - Resaltado de la sección "Síntesis / Cross" con color de acento

## Proposed Changes

### Alcance del cambio

Solo se modifican **2 archivos principales** + opcionalmente toques cosméticos:

---

### Navegación

#### [MODIFY] [AppNavigation.swift](file:///Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/AppNavigation.swift)
- Reordenar los cases del enum `NavItem` para reflejar el nuevo orden lógico
- Opcionalmente renombrar rawValues si decides cambiar labels

#### [MODIFY] [ContentView.swift](file:///Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/Views/ContentView.swift)
- Restructurar las `Section(...)` del `List` en el sidebar:
  - Cambiar los grupos de `ForEach([NavItem...])` para reflejar la nueva agrupación
  - Cambiar los títulos de las secciones ("Cartas" → "Carta Natal", etc.)
  - Opcionalmente: añadir separadores visuales, cambiar estilo de headers de sección
- El `detailView` switch **NO cambia** — solo cambia dónde se muestra cada item en el sidebar

---

### Opcionales (según tu feedback)

#### [MODIFY] [AppTheme.swift](file:///Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/AppTheme.swift)
- Si quieres headers de sección más estilizados (color de acento, iconos)
- Si quieres un separador visual para la sección "Síntesis"

#### [MODIFY] [AstroMalikApp.swift](file:///Users/eduardoariasbravo/Developer/AstroMalik-macOS/Sources/AstroMalik/AstroMalikApp.swift)
- Solo si cambias rawValues de NavItem (habría que actualizar `showDefaultDetail`)

## Verification Plan

### Automated Tests
- `swift build` — verificar compilación limpia
- `swift test` — pasar tests existentes (no deberían romperse ya que no cambia lógica)

### Manual Verification
- `scripts/package_app.sh` — regenerar la app
- Verificar que el sidebar muestra las nuevas secciones
- Verificar que hacer clic en cada item sigue abriendo la vista correcta
- Verificar que el estado se mantiene al navegar entre items
- Verificar que `AstroMalik.app/Contents/MacOS/AstroMalik` tiene timestamp actualizado
