# Instrucciones para agentes

- Utiliza siempre Joplin como notas. Está en local con Web Clipper.
- No abras editores interactivos de terminal como Vim/Nano/Emacs para editar archivos ni para commits. Usa `apply_patch` o comandos no interactivos, y haz commits siempre con `git commit -m` para evitar ventanas de editor en primer plano.
- En este repo, después de cambios de código o UI, no basta con `swift build`: regenera siempre la app con `scripts/package_app.sh`.
- Antes de cerrar una tarea, verifica que `AstroMalik.app/Contents/MacOS/AstroMalik` tenga timestamp actualizado.
