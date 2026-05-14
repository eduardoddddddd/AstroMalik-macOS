# Instrucciones para agentes

- Utiliza siempre Joplin como notas. Está en local con Web Clipper.
- No abras editores interactivos de terminal como Vim/Nano/Emacs para editar archivos ni para commits. Usa `apply_patch` o comandos no interactivos, y haz commits siempre con `git commit -m` para evitar ventanas de editor en primer plano.
- En este repo, después de cambios de código o UI, no basta con `swift build`: regenera siempre la app con `scripts/package_app.sh`.
- Antes de cerrar una tarea, verifica que `AstroMalik.app/Contents/MacOS/AstroMalik` tenga timestamp actualizado.
- **Entrega de documentos:** cuando generes archivos .md, .txt o cualquier entregable para el proyecto, escríbelos SIEMPRE directamente en la estructura del repo (normalmente `docs/`) usando Desktop Commander o herramientas locales. NUNCA escribas primero en `/home/claude/` o `/mnt/user-data/outputs/` y luego copies — el `cp` desde el container al filesystem del Mac falla silenciosamente y deja el fichero vacío o un placeholder. Escribe el contenido completo directamente en la ruta final del proyecto.
