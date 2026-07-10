# Build universal de AstroMalik para macOS

## Objetivo

Generar una única aplicación con dos slices Mach-O nativos:

- `arm64` para Apple Silicon;
- `x86_64` para Intel.

La ruta universal es adicional. `scripts/package_app.sh` y el `AstroMalik.app` local de arquitectura nativa continúan funcionando sin cambios. El nuevo empaquetador escribe exclusivamente en `dist/`.

## Generar artefactos

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  scripts/package_universal_app.sh
```

Salidas:

```text
dist/AstroMalik.app
dist/astromalik-cli
dist/AstroMalik-macOS-universal.zip
dist/AstroMalik-macOS-universal.zip.sha256
dist/astromalik-cli-macOS-universal.zip
dist/astromalik-cli-macOS-universal.zip.sha256
```

El script:

1. compila release para `arm64`;
2. compila release para `x86_64`;
3. combina los ejecutables con `lipo -create`;
4. copia una sola vez los recursos independientes de arquitectura;
5. aplica firma ad-hoc;
6. ejecuta el verificador;
7. crea ZIP y checksum SHA-256.

## Verificación independiente

```bash
scripts/verify_universal_app.sh
```

Comprueba:

- slices `arm64` y `x86_64` en app y CLI;
- validez de `Info.plist`;
- presencia del bundle de recursos;
- integridad de la firma ad-hoc.

Comprobación manual:

```bash
lipo -archs dist/AstroMalik.app/Contents/MacOS/AstroMalik
lipo -archs dist/astromalik-cli
codesign --verify --deep --strict dist/AstroMalik.app
```

## Firma y notarización

El proyecto usa:

```bash
codesign --sign -
```

Es una firma ad-hoc gratuita. Sirve para que el paquete tenga una firma coherente después de ejecutar `lipo`, pero:

- no contiene una identidad Developer ID;
- no produce un ticket de notarización de Apple;
- Gatekeeper puede exigir autorización manual en la primera apertura.

Esta decisión evita la cuota anual del programa de desarrolladores. La experiencia de instalación está documentada en [`INSTALACION_MACOS.md`](INSTALACION_MACOS.md).

No se desactiva Gatekeeper en el build ni se recomienda hacerlo al usuario.

## Automatización GitHub Actions

`.github/workflows/universal-macos.yml` ejecuta el mismo script en `macos-14` para actualizaciones de `main`, tags `v*` o ejecución manual. Publica como artefactos temporales:

- ZIP universal;
- checksum;
- CLI universal.

Cuando la ejecución procede de un tag `v*`, crea además la GitHub Release —o actualiza la existente— y adjunta los dos ZIP con sus checksums. Utiliza únicamente el `GITHUB_TOKEN` efímero del workflow; no necesita secretos, certificados ni cuentas de Apple.

El runner estándar `macos-14` es ARM64 y realiza compilación cruzada para Intel, igual que la máquina de desarrollo. [GitHub documenta `macos-14` como runner ARM64](https://docs.github.com/en/actions/reference/runners/github-hosted-runners); el script no depende de ejecutar el binario Intel en ese runner.

## Compatibilidad

El deployment target continúa en macOS 14:

```swift
platforms: [.macOS(.v14)]
```

La distribución cubre Apple Silicon e Intel siempre que puedan ejecutar Sonoma o posterior. Ampliar a Intel antiguos con macOS 12/13 es un proyecto de compatibilidad de APIs distinto; no es necesario para construir el binario universal actual.

## Qué no cambia

- cálculos y motores;
- formato de `user.db`;
- recursos y corpus;
- integración Joplin/LLM;
- empaquetador nativo existente;
- ubicación de datos de usuario.
