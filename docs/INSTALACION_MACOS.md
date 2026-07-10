# Instalar AstroMalik en cualquier Mac compatible

Esta guía está escrita para personas sin conocimientos informáticos. No necesitas saber si tu Mac usa un procesador Intel o un chip de Apple.

## 1. ¿Sirve para mi Mac?

La descarga **universal** contiene dos versiones dentro de la misma aplicación:

- una para Apple Silicon: M1, M2, M3, M4 y posteriores;
- otra para procesadores Intel.

macOS elige automáticamente la correcta. No hace falta instalar Rosetta ni descargar dos aplicaciones distintas.

El requisito es **macOS 14 Sonoma o superior**. Esto significa que algunos Mac Intel antiguos que no puedan actualizar a Sonoma no son compatibles, aunque tengan procesador Intel.

Para comprobar tu versión:

1. Pulsa el menú ** Apple** de la esquina superior izquierda.
2. Selecciona **Acerca de este Mac**.
3. Comprueba que indique macOS 14, 15, 26 o una versión posterior.

## 2. Descargar e instalar

1. Descarga `AstroMalik-macOS-universal.zip` desde la publicación oficial del proyecto.
2. Abre la carpeta **Descargas**.
3. Haz doble clic en el ZIP si macOS no lo ha descomprimido automáticamente.
4. Arrastra `AstroMalik.app` a la carpeta **Aplicaciones**.
5. Abre **Aplicaciones** y localiza AstroMalik.

## 3. ¿Por qué macOS muestra una advertencia?

Apple cobra una cuota anual por el certificado Developer ID y el servicio de notarización. Este proyecto no utiliza esa suscripción de pago. La aplicación lleva una **firma ad-hoc gratuita**, que permite comprobar la integridad técnica del paquete, pero no permite que Apple identifique al desarrollador como miembro de pago.

Por ello, la primera vez macOS puede decir que no puede verificar al desarrollador. Esto es una protección normal de Gatekeeper para aplicaciones distribuidas fuera de la App Store y sin notarización.

La advertencia no demuestra por sí sola que haya un virus, pero debes descargar AstroMalik solamente desde el repositorio o publicación oficial.

## 4. Primera apertura: método recomendado

1. Abre la carpeta **Aplicaciones**.
2. Mantén pulsada la tecla **Control** y haz clic en `AstroMalik.app`; también puedes usar el botón derecho.
3. Selecciona **Abrir**.
4. En la nueva ventana, vuelve a pulsar **Abrir**.

Normalmente macOS recordará esta decisión y las siguientes aperturas serán normales.

## 5. Si no aparece el segundo botón “Abrir”

1. Intenta abrir AstroMalik una vez y cierra el aviso.
2. Abre **Ajustes del Sistema**.
3. Entra en **Privacidad y seguridad**.
4. Baja hasta la sección **Seguridad**.
5. Verás que AstroMalik fue bloqueado. Pulsa **Abrir igualmente**.
6. Confirma con la contraseña, Touch ID o la cuenta administradora del Mac.

Esta autorización afecta únicamente a AstroMalik. No desactiva la seguridad general del equipo.

Apple describe este mismo procedimiento en [Abrir apps de forma segura en el Mac](https://support.apple.com/es-es/102445). Apple advierte que solo debe autorizarse software obtenido de una fuente en la que se confíe; por eso esta guía insiste en usar la publicación oficial y comprobar el checksum.

## 6. Si macOS afirma que la aplicación está “dañada”

Primero vuelve a descargar el ZIP desde la publicación oficial. Si el checksum coincide y el aviso continúa, macOS puede haber conservado la marca de cuarentena debido a la ausencia de notarización.

Como último recurso, abre **Terminal** desde Aplicaciones → Utilidades y pega exactamente:

```bash
xattr -dr com.apple.quarantine /Applications/AstroMalik.app
```

Después vuelve a abrir la aplicación con Control-clic → **Abrir**.

Este comando:

- actúa únicamente sobre AstroMalik;
- no necesita `sudo` ni contraseña de administrador;
- no desactiva Gatekeeper para otras aplicaciones.

Úsalo solo si descargaste el archivo desde la fuente oficial. **No ejecutes comandos que contengan `spctl --master-disable` ni desactives Gatekeeper globalmente.**

## 7. Comprobar que la descarga es la correcta

Junto al ZIP se publica `AstroMalik-macOS-universal.zip.sha256`. Es una huella digital del archivo.

La comprobación es opcional, pero recomendable:

1. Abre Terminal.
2. Escribe `shasum -a 256 `, dejando un espacio al final.
3. Arrastra el ZIP desde Descargas a la ventana de Terminal.
4. Pulsa Intro.
5. Compara la combinación de letras y números con la del archivo `.sha256`.

Si son idénticas, el ZIP no cambió después de generarse. Si no coinciden, elimínalo y vuelve a descargarlo.

## 8. Preguntas frecuentes

### ¿Tengo que pagar algo?

No. AstroMalik y este método de instalación no requieren una cuenta de desarrollador de pago.

### ¿Necesito conexión a internet?

No para los cálculos deterministas. Las funciones opcionales de Anthropic, OpenRouter o Joplin sí pueden necesitar red o servicios locales.

### ¿La versión Intel tiene menos funciones?

No. El mismo código y los mismos recursos se compilan para ambas arquitecturas.

### ¿Puedo conservar una versión anterior?

Sí. Antes de sustituirla, cambia el nombre de la aplicación anterior, por ejemplo a `AstroMalik anterior.app`.

### ¿Perderé mis cartas al sustituir la app?

No. Los datos viven en `~/Library/Application Support/AstroMalik/user.db`, fuera del paquete de la aplicación. Aun así, es prudente conservar copias de seguridad.

## 9. Ayuda

Al solicitar ayuda indica:

- modelo y año aproximado del Mac;
- versión de macOS;
- si el procesador aparece como Intel o Apple en **Acerca de este Mac**;
- texto exacto del aviso mostrado.
