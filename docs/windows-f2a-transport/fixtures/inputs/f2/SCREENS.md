# Capturas de la aplicación Mac real

`screens-inventory.json` inventaría las 19 entradas del sidebar de
`AppNavigation.swift`/`ContentView.swift` y ocho detalles adicionales. Es una
lista de navegación, **no evidencia de que haya capturas**. Las imágenes
generadas por IA, páginas HTML, SVG exportados o Flutter Windows no sirven como
capturas de la interfaz SwiftUI Mac.

La app upstream no acepta `--data-dir`: AppState instancia UserStore,
ReadingNotesStore y HoraryStore con rutas de Application Support, y preferencias
mediante UserDefaults. Para crear entradas de prueba debe usarse una cuenta de
pruebas o una copia derivada con parche de aislamiento autorizado por root;
redirigir también caché, migraciones, sesiones, horaria, notas y preferencias.
No asumir que cambiar HOME redirige Foundation en macOS. La interfaz y los
renderizadores conservan sus fuentes originales; solo cambian las rutas.

1. Preparar/abrir la app real en la cuenta/copia aislada. Importar las tres
   cartas completas de F1 en su almacén aislado. Abrir Eduardo para fijarla
   activa. Datos civiles, fechas y parámetros están en manifest-template.json.
2. Navegar por la lista de screens-inventory.json. Elegir tema claro y tamaño
   1100×780 o mayor; esperar que termine el cálculo. Registrar la fecha y los
   filtros realmente observados. Si una vista no admite fijar una entrada,
   describir la entrada real en metadata y no declarar igualdad numérica.
3. `swift scripts/mac/list-windows.swift` lista solo ventanas AstroMalik para
   obtener el windowID sin depender de coordenadas o títulos personales.
4. Capturar cada ventana y estado ya comprobados:

```sh
python3 scripts/mac/capture-screen.py \
  --inventory fixtures/inputs/f2/screens-inventory.json \
  --output fixtures/mac/screens --screen natal-rueda \
  --window-id 1234 --mac-commit SHA_VERIFICADO \
  --theme light --observed-state 'Eduardo; Rueda; Ascendente Géminis; cálculo terminado'
```

5. Inspeccionar visualmente PNG: ventana correcta, etiquetas/cifras visibles,
   ningún spinner ocultando datos y ningún token. El JSON adjunto registra
   commit, fecha, resolución, hash, navegación y observación. `screencapture`
   requiere Screen Recording; una denegación es bloqueo real de captura.

Una pantalla vacía documentada (por ejemplo Informes en cuenta aislada) sí
sirve como referencia de ese estado; no prueba el estado poblado. Horaria,
rectificación y sinastría usan las entradas de prueba documentadas, sin
atribuir sus preguntas/eventos/relaciones a la biografía de Eduardo. Se debe
dejar explícita cualquier pantalla pendiente; F2a no está cerrada solo con JSON.
