# Distribución directa de aplicaciones macOS fuera del Mac App Store: guía técnica y práctica 2025–2026

Para una app indie nativa SwiftUI como AstroMalik / Astromagic — desarrollada en España, con CSwissEph y SQLite locales y un precio objetivo de 52–79 € en pago único — la distribución directa fuera del Mac App Store es perfectamente viable, está estandarizada por Apple y es la opción dominante entre desarrolladores indie de Mac de nicho. La pila moderna habitual es: **Apple Developer Program (99 USD/año) → firma con certificado Developer ID Application → Hardened Runtime → notarización con `xcrun notarytool` → `xcrun stapler` → DMG firmado y notarizado → actualizaciones con Sparkle 2 → ventas mediante un Merchant of Record (típicamente Paddle, Lemon Squeezy o FastSpring) que se encarga del IVA europeo (OSS/IOSS) en tu lugar**. Setapp puede sumarse como canal complementario, y publicar simultáneamente en el Mac App Store es legal y compatible. A continuación se desarrollan los siete puntos solicitados con el detalle técnico y comercial actualizado a mayo de 2026.

---

## 1. Firma y notarización Apple

### 1.1 Apple Developer Program y Developer ID Signing

Para distribuir una app firmada fuera del Mac App Store es obligatorio inscribirse en el **Apple Developer Program**. La cuota es de **99 USD/año** (renovación anual; convertida a la moneda local en España, suele facturarse en EUR), y la inscripción puede hacerse como **Individual / sole proprietor** (tu nombre legal aparecerá como "Seller") o como **Organization** (requiere personalidad jurídica reconocida y un D-U-N-S Number gratuito). El programa Enterprise (299 USD/año) **no es la opción adecuada**: está pensado para distribución interna a empleados con MDM y no permite vender al público.

Una vez inscrito, generas en *Certificates, Identifiers & Profiles* (o directamente desde Xcode → Settings → Accounts → Manage Certificates) un certificado **"Developer ID Application"**, que se usa para firmar el `.app`, y opcionalmente un **"Developer ID Installer"** si distribuyes `.pkg`. Este certificado permite a Gatekeeper verificar que la app proviene de un desarrollador identificado por Apple. Apps firmadas con Developer ID también pueden usar capacidades avanzadas como CloudKit y Apple Push Notifications.

### 1.2 Notarización con notarytool

La **notarización** es un paso obligatorio desde macOS 10.15 Catalina (junio 2019) para todo software distribuido con Developer ID. Consiste en enviar el binario al servicio de Apple, que lo escanea automáticamente en busca de malware y comprueba que la firma de código y el Hardened Runtime cumplen los requisitos. No es una revisión humana ni una "App Review"; es un análisis automatizado que normalmente termina en minutos, aunque ocasionalmente puede quedarse en estado "In Progress" durante horas (los foros de Apple Developer recogen casos persistentes en 2026, especialmente para cuentas recién creadas).

La herramienta moderna es **`xcrun notarytool`**, integrada en Xcode 13+ (Apple desactivó `altool` y Xcode ≤13 el 1 de noviembre de 2023, por lo que cualquier flujo nuevo debe usar notarytool). El proceso típico desde línea de comandos:

```bash
# 1. Almacenar credenciales en el keychain (una sola vez)
xcrun notarytool store-credentials "AC_PROFILE" \
  --apple-id "tu@apple.id" \
  --team-id "ABCDE12345" \
  --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password de appleid.apple.com

# 2. Enviar el DMG/ZIP/PKG y esperar el resultado
xcrun notarytool submit AstroMalik.dmg \
  --keychain-profile "AC_PROFILE" --wait

# 3. Si Accepted, "grapar" el ticket al DMG
xcrun stapler staple AstroMalik.dmg
```

Para una pipeline CI/CD, lo recomendado es generar una **App Store Connect API Key** (archivo `.p8` con KeyID e IssuerID) y pasarla a `notarytool store-credentials --key`, evitando depender de contraseñas de cuenta personales.

Requisitos previos para que la notarización tenga éxito:

- El binario debe estar firmado con un certificado **Developer ID Application** válido.
- Debe activarse **Hardened Runtime** (`--options runtime` en `codesign`, o capability "Hardened Runtime" en Xcode).
- Todos los binarios anidados (frameworks, dylibs, helpers, herramientas CLI dentro de Resources) deben estar firmados individualmente.
- Las entitlements deben ser conservadoras; si necesitas JIT, librerías sin firmar, etc., debes activar entitlements explícitas (`com.apple.security.cs.allow-jit`, etc.). Para una app SwiftUI con CSwissEph (C estático compilado dentro del binario) y SQLite (libsqlite3 del sistema), normalmente no necesitas entitlements adicionales.
- En Xcode, lo más sencillo es: *Product → Archive → Distribute App → Direct Distribution*, que firma, notariza y exporta el `.app` automáticamente.

Desde Xcode 14 también existe la opción "Direct Distribution" en el archivo, que encadena firma + notarización + export en un único paso.

### 1.3 Gatekeeper

**Gatekeeper** es el subsistema de macOS que, en el primer lanzamiento de un binario con el atributo de cuarentena `com.apple.quarantine` (puesto automáticamente al descargar de internet), comprueba:

1. Que esté firmado con un certificado **Developer ID** válido y no revocado.
2. Que el código no haya sido alterado desde la firma.
3. Que esté **notarizado** (en macOS 10.15+).
4. Que el desarrollador no esté en una lista negra de XProtect.

Si todo es correcto, se muestra un único diálogo amistoso ("AstroMalik se descargó de internet. ¿Estás seguro de que quieres abrirla?") y la app se ejecuta. En aperturas posteriores no se vuelve a preguntar.

Importante: **macOS Sequoia 15.0 (otoño 2024) eliminó el "Control-click → Open" como atajo para saltarse Gatekeeper**. Desde 15.0 el usuario debe ir explícitamente a *System Settings → Privacy & Security → "Open Anyway"* para ejecutar una app no firmada/no notarizada, y existen reportes de que macOS 15.1 dificulta aún más las excepciones. Esto refuerza que **firmar y notarizar deja de ser opcional en la práctica para cualquier app que aspire a parecer profesional en 2025–2026**.

### 1.4 Diferencias entre app firmada, notarizada y stapled

- **Firmada (signed)**: tiene una firma criptográfica con tu Developer ID. Permite a macOS verificar identidad e integridad, pero por sí sola **no es suficiente** desde Catalina.
- **Notarizada (notarized)**: además de firmada, ha pasado por el servicio de Apple y existe un "ticket" en los servidores de Apple. Gatekeeper consulta online si hay ticket; si el Mac tiene internet, la app se abre limpiamente.
- **Stapled (grapada)**: se ha ejecutado `xcrun stapler staple` sobre el `.app` o el DMG, **incrustando el ticket** en el propio fichero. Esto permite que Gatekeeper verifique la notarización **incluso sin conexión a internet**. Es altamente recomendable para distribución comercial: el primer lanzamiento de tu app en un Mac sin Wi-Fi o en una empresa con red restringida funcionará igualmente.

Buena práctica: notarizar y grapar **el DMG** (que contiene el `.app` ya firmado y notarizado por separado). Apple recomienda este enfoque porque el DMG es lo que el usuario descarga.

### 1.5 Qué pasa sin firma/notarización

- Sin firma con Developer ID: el usuario verá *"'AstroMalik' no se puede abrir porque no se puede verificar el desarrollador"* y, en 15.1+, tendrá que entrar manualmente en Privacidad y Seguridad. Muchos usuarios cancelan en este punto.
- Firmada pero **no** notarizada en macOS 10.15+: aparece *"Apple no pudo verificar 'AstroMalik' para confirmar que está libre de malware que pueda dañar tu Mac o comprometer tu privacidad"*. Es un mensaje todavía más alarmante para el usuario final.
- Sin firma alguna: Gatekeeper directamente la mueve a Papelera o muestra *"'AstroMalik' está dañada y no se puede abrir. Deberías moverla a la Papelera"*. Este mensaje es engañoso (la app no está dañada, simplemente no firmada) y destruye toda credibilidad comercial.

Para una app de pago a 52–79 €, distribuir sin firma y sin notarización es inviable.

---

## 2. Formatos de distribución

### 2.1 DMG vs PKG vs ZIP

- **DMG (Apple Disk Image)**: el **estándar de facto** para apps Mac comerciales fuera del App Store en 2025–2026. Es una imagen de disco que el usuario hace doble-click; se monta en Finder mostrando el icono de la app y un alias a `/Applications`, invitando visualmente a arrastrar y soltar. Permite fondo personalizado, layout de iconos y se firma + notariza + grapa como un único contenedor.
- **PKG (Installer Package)**: paquete de instalador que ejecuta scripts. Adecuado solo si tu app necesita instalar componentes en directorios privilegiados, daemons en LaunchDaemons, o helpers root. Para una app SwiftUI estándar es overkill y los usuarios Mac suelen preferir DMG (ven el PKG con menos cariño porque "instala cosas" en lugar de simplemente copiarse).
- **ZIP**: aceptado por notarización, pero estéticamente pobre y no transmite profesionalidad. Adecuado para descargas técnicas, herramientas open source y betas, no para producto comercial.

**Recomendación para AstroMalik: DMG**, con fondo personalizado (logo + flecha al alias de Applications), volumen renombrado a "Astromagic", icono propio (`.VolumeIcon.icns`) y compresión UDZO.

### 2.2 Herramientas para crear DMG profesionales

- **`create-dmg` de sindresorhus** (Node.js, https://github.com/sindresorhus/create-dmg): muy popular, una sola línea: `create-dmg 'Astromagic.app' Build/Releases`. Genera DMG con nombre versionado (`Astromagic 1.0.0.dmg`), intenta firmarlo automáticamente y soporta CI con `--no-code-sign` para evitar fallos.
- **`create-dmg` de andreyvit / DMGCanvas script** (Bash, distinto al anterior): permite mayor control sobre el layout (posición exacta de iconos, fondo, ventana).
- **DMG Canvas** (app comercial, https://www.araelium.com/dmgcanvas, ~50 USD): editor visual WYSIWYG; genera scripts reutilizables. Recomendable si quieres iterar el branding del DMG sin tocar línea de comandos.
- **Disk Utility + `hdiutil`** (incluido en macOS): si te molesta una dependencia más, puedes scriptarlo directamente con `hdiutil create -volname "Astromagic" -srcfolder ./payload -ov -format UDZO Astromagic.dmg`. Es lo que usan internamente las otras herramientas.
- **Tauri / electron-builder**: generan DMG nativos pero solo aplican si tu app fuera Tauri/Electron, no es tu caso.

Atención: en CI (GitHub Actions con runners macOS) el posicionamiento de iconos del DMG puede no aplicarse por un bug conocido — puede ser necesario generar el DMG en una máquina física o documentarlo como limitación.

### 2.3 Pipeline completa: Xcode → firma → notarización → staple → DMG

Flujo recomendado para AstroMalik:

```bash
# 1. Archive desde Xcode (Product → Archive) o xcodebuild
xcodebuild -scheme Astromagic -configuration Release \
  -archivePath build/Astromagic.xcarchive archive

# 2. Export firmado con Developer ID
xcodebuild -exportArchive \
  -archivePath build/Astromagic.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
# ExportOptions.plist contiene method=developer-id, signingStyle=manual,
# teamID y signingCertificate=Developer ID Application

# 3. Verificar firma
codesign --verify --deep --strict --verbose=2 build/export/Astromagic.app
spctl --assess --type execute -vv build/export/Astromagic.app

# 4. Crear DMG
create-dmg 'build/export/Astromagic.app' build/dist/

# 5. Firmar el DMG con Developer ID
codesign --sign "Developer ID Application: Tu Nombre (TEAMID)" \
         --timestamp build/dist/Astromagic-1.0.0.dmg

# 6. Notarizar el DMG y esperar
xcrun notarytool submit build/dist/Astromagic-1.0.0.dmg \
  --keychain-profile "AC_PROFILE" --wait

# 7. Grapar el ticket
xcrun stapler staple build/dist/Astromagic-1.0.0.dmg

# 8. Verificar
xcrun stapler validate build/dist/Astromagic-1.0.0.dmg
spctl --assess --type open --context context:primary-signature -vv \
  build/dist/Astromagic-1.0.0.dmg
```

Este flujo es totalmente automatizable en GitHub Actions (necesitarás importar el certificado `.p12` al keychain del runner antes de codesign — hay actions populares como `apple-actions/import-codesign-certs`).

---

## 3. Gestión de licencias

### 3.1 Plataformas de activación (visión combinada con sección 4)

Para apps Mac vendidas fuera del App Store hay esencialmente dos enfoques:

1. **Plataforma todo-en-uno (MoR + entrega + licencias)**: Paddle, Lemon Squeezy, FastSpring. Te abstrae del IVA, genera la clave y envía el email automáticamente.
2. **Stripe + backend propio**: máximo control y comisiones bajas (2,9 % + 0,30 €), pero te conviertes en responsable del IVA-OSS, generación de claves, emails, refunds y disputas.

Gumroad es viable pero su comisión del 10 % flat lo hace caro a partir de cierto volumen.

### 3.2 Frameworks y SDKs de protección de licencia para Swift/macOS

| SDK / Framework | Tipo | Notas |
|---|---|---|
| **Paddle SDK (Mac-Framework-V4)** | Comercial, ligado a Paddle Classic | Provee UI de activación, trial, verificación remota y "activation reclaim" (deactivar dispositivos antiguos). Sigue mantenido (releases recientes adaptados a Sequoia). El problema: **Paddle Billing (Paddle nuevo) no tiene un SDK equivalente**; está orientado a SaaS y suscripciones, y el camino para gestionar one-time licenses con Paddle Billing es construir tú la lógica con webhooks y un Paddle Licenses propio. |
| **LicenseKit** (Kankoda, https://github.com/Kankoda/LicenseKit) | Comercial Swift SDK | SwiftUI nativo, compatible con iOS/macOS/tvOS/watchOS/visionOS. Define licencias en código, parsea ficheros cifrados, lee CSV, integra APIs externas y trae integración pre-hecha para **Gumroad**. Modelo: gratuito para empezar, licencia comercial al escalar. Closed source. |
| **AquaticPrime** (https://github.com/bdrister/AquaticPrime, fork mantenido) | Open source, BSD | Clásico desde el Mac Indie de los 2000. Genera ficheros `.aquaticprime` firmados con RSA en el servidor; en el cliente solo necesitas la clave pública embebida. Sin UI ni trial — tú implementas el flujo. Suficiente para un Indie con backend propio. |
| **DMCoreLicensing** (fumoboy007) | Open source Swift, MIT | Diseñado explícitamente con la filosofía de "no requerir internet en cada lanzamiento" y "que romper la firma del ejecutable sea la única vía de pirateo". Tested en macOS 11+. Compatible con Swift 5.3+. |
| **TrialLicensing** (CleanCocoa) + **CocoaFob** | Open source | Maneja trial por tiempo y licencias DSA. Pensado para apps Cocoa/Mac. |
| **Keygen.sh** | SaaS de licensing | Integra con Paddle/Lemon Squeezy/Stripe vía webhook; ofrece API REST para activación, política de máquinas, expiración. Buen complemento si no quieres el SDK propietario de Paddle. |

**Recomendación para AstroMalik**: si vas con Paddle Classic, su SDK V4 es el camino más rápido y gestiona trial + verificación. Si vas con Lemon Squeezy o Stripe, **LicenseKit** o **AquaticPrime** + un endpoint propio (incluso una Cloudflare Worker) son la combinación más sensata. Si valoras la simplicidad y el control total, AquaticPrime + un Worker para emitir licencias firmadas tras webhook de pago es solución probada y de mantenimiento mínimo.

### 3.3 Online vs offline

- **Online (server-side validation)**: cada cierto tiempo (al lanzar la app, una vez al día, etc.) la app llama a tu servidor para validar la licencia y verificar que no ha sido desactivada/refundeada. Ventaja: puedes invalidar claves filtradas, contar instalaciones, hacer "deactivate this Mac". Desventaja: el usuario sin internet se queja y nunca debes bloquear el lanzamiento por falta de conexión.
- **Offline (firma criptográfica local)**: la licencia es un fichero o string firmado con tu clave privada y verificado localmente con la pública embebida (el modelo de AquaticPrime, DMCoreLicensing). Ventaja: nunca requiere red. Desventaja: imposible revocar una clave individual sin actualizar la app.

**Patrón recomendado** (lo que hace Paddle SDK y la mayoría de apps Mac indie maduras): híbrido. Validación criptográfica local en cada lanzamiento (la app siempre arranca), más una verificación online silenciosa periódica (cada 7–14 días) que solo invalida la licencia si recibe explícitamente "revoked". Si no hay internet, no pasa nada.

### 3.4 Anti-piratería razonable para apps indie

La realidad pragmática (consenso entre devs Mac indie como Eternal Storms, fumoboy007, etc.):

1. **No persigas la piratería al 100%** — quien quiere piratear, lo hará. Tu objetivo es que sea **más fácil pagar 60 € que buscar un crack**.
2. Que romper la firma del binario sea **el único vector de bypass** (filosofía DMCoreLicensing). Esto:
   - Asusta al usuario casual (Gatekeeper avisará).
   - Obliga al cracker a re-romper cada actualización.
3. Verificación criptográfica de licencia con clave pública embebida (RSA o Ed25519).
4. Identifica el Mac por una combinación de `IOPlatformUUID` + MAC en `en0` (con fallback). Paddle SDK ya lo hace y permite `customUUIDDelegate`.
5. Permite 2 activaciones por licencia "Personal" y 1 por "Commercial", con un mecanismo de **reset/transferencia** accesible desde un email + endpoint.
6. **No** pongas bombas de tiempo agresivas, no contactes el servidor en cada arranque, no rompas la app si el reloj cambia. Estas anti-features dañan más a usuarios legítimos que a piratas.
7. Para nicho astrológico (tu mercado): la base de usuarios es pequeña y comprometida; un sistema de licencia sencillo y un buen servicio post-venta convierte mejor que cualquier DRM agresivo.

---

## 4. Pagos y plataformas de venta

### 4.1 Comparativa actualizada 2025–2026

| Plataforma | Comisión | MoR (gestiona IVA) | Licencias nativas | Idoneidad indie macOS |
|---|---|---|---|---|
| **Paddle** | 5 % + 0,50 USD/transacción | Sí | Sí (SDK Mac maduro en Paddle Classic; Paddle Billing requiere construir flujo con webhooks) | Históricamente la opción "estándar" de apps Mac indie; aprobación lenta (semanas); soporte mejor para SaaS B2B grande. Adquirieron DevMate hace años. |
| **Lemon Squeezy** | 5 % + 0,50 USD | Sí | Sí (license keys, validación API) | **Adquirida por Stripe en 2024**, integrada con métodos de pago Stripe en 2025. Aprobación rápida (~48 h). UI moderna, buenas conversiones. La favorita de indie hackers en 2025–2026. Bug-prone según algunos reviews críticos post-adquisición. |
| **FastSpring** | ~5–8 % (custom según volumen) | Sí | Sí (muy maduro, B2B fuerte) | Veterana (desde 2005), centrada en software. Mejor para empresas establecidas con ventas internacionales complejas; overkill para indie pequeño. |
| **Gumroad** | **10 % flat** + procesador (~3,5 % + 0,30 USD si pago externo) | Sí | Básicas | Setup en minutos; ideal para vender el primer ebook / template. Cara a partir de cierto volumen. UI de checkout criticada por bajar conversiones. |
| **Stripe + código propio** | 2,9 % + 0,30 € (Europa: 1,4 % + 0,25 € tarjetas EU) | **No** (tienes que añadir Stripe Tax 0,5 % + alta en OSS) | No (la implementas tú) | Comisiones más bajas pero **tú** eres legalmente vendedor: facturas, IVA, refunds, disputas, cumplimiento. Solo merece la pena con volumen alto o si ya tienes infraestructura. |

### 4.2 ¿Quién usa qué en 2025–2026?

El consenso en foros indie (Indie Hackers, Hacker News, MacRumors devs, blogs como mjtsai.com, eternalstorms.at, Aptabase) y la lectura de las ofertas de SDK:

- **Lemon Squeezy** se ha convertido en la primera elección de **indie hackers nuevos** y solo-founders en 2024–2025 por la simplicidad y velocidad de aprobación. Tras la adquisición por Stripe en 2024 hay cierta inquietud sobre el roadmap, pero sigue siendo recomendada en publicaciones recientes (2026).
- **Paddle** sigue siendo dominante en **apps Mac establecidas** que llevan años (su SDK V4 es difícil de igualar en flujos one-time con trial). Migran lentamente porque su Paddle Classic todavía funciona; sin embargo, Paddle empuja a los nuevos hacia Paddle Billing, que no tiene el mismo SDK.
- **FastSpring** y **2Checkout/Verifone** son menos comunes en indie puro y más en software empresarial.
- **Stripe directo** lo eligen quienes ya tienen un equipo técnico, web propia robusta y volumen suficiente como para que el ahorro de comisiones cubra Stripe Tax y la gestión de OSS.

Para **AstroMalik a 52–79 €** y un único desarrollador en España, las opciones más sensatas son **Lemon Squeezy** (rapidez, IVA gestionado, integración con LicenseKit) o **Paddle Classic** (si quieres su SDK Mac listo para usar con UI de activación y trial). Stripe directo solo si te divierte construir el backend de licencias y facturas.

### 4.3 Merchant of Record (MoR) vs Reseller — y por qué importa para el IVA

Un **Merchant of Record** es la entidad legalmente vendedora de cara al cliente final. Tu factura comercial es entre tú y la plataforma (B2B); la factura al consumidor la emite la plataforma con su CIF y aplica el IVA local del país del comprador. Paddle, Lemon Squeezy, FastSpring y Gumroad funcionan así.

Un **Reseller** o procesador de pagos puro (Stripe) solo procesa la transacción; **tú sigues siendo el vendedor legal**, lo que en la UE significa que **tú** debes:

- Cobrar el IVA del país del comprador (umbral pan-UE de 10 000 €/año combinado para B2C servicios digitales y ventas a distancia; **superado el umbral, es obligatorio aplicar el tipo del país del consumidor**).
- Estar registrado en el régimen **OSS – Unión** (la antigua MOSS, ampliada desde 1 de julio de 2021), declarando trimestralmente desde la AEAT en España.
- Conservar dos pruebas no contradictorias de la ubicación del consumidor (IP + dirección de facturación; emisor de la tarjeta, etc.).
- Guardar los registros 10 años.
- Para ventas fuera de la UE (EE.UU., Canadá, Reino Unido, Australia, Japón, etc.), gestionar el sales tax / GST cuando aplique.

Con un MoR, todo eso lo asumen ellos. Para un solo desarrollador indie en España vendiendo a 100+ países, **el ahorro administrativo y el riesgo legal evitado compensan ampliamente el 5 % de comisión adicional respecto a Stripe**. Es la conclusión casi unánime de los hilos sobre el tema en JUCE/Indie Hackers/Hacker News.

### 4.4 Notas específicas para España

- Como autónomo o sociedad española, tu relación con la plataforma MoR es **B2B intracomunitaria** (Lemon Squeezy es de EE.UU., Paddle es del Reino Unido pero con entidad UE; FastSpring de EE.UU. con entidad UE). Las plataformas te pagan **netas de IVA**: tú emites una factura sin IVA con la mención "Inversión del sujeto pasivo / Reverse charge" según corresponda.
- Debes seguir presentando IVA trimestral (Modelo 303) y el 349 (operaciones intracomunitarias), declarando los ingresos.
- En IRPF tributas como rendimientos de actividad económica (autónomo) o como sociedad.
- ViDA (VAT in the Digital Age) eliminó el umbral de registro a 0 € para B2C transfronterizo, pero al usar un MoR este punto te es indiferente.

Recomendación: confirma este montaje con un asesor fiscal especializado en SaaS / digital antes de la primera factura.

---

## 5. Actualizaciones automáticas

### 5.1 Sparkle 2

**Sparkle** (https://sparkle-project.org, MIT, mantenido en GitHub por sparkle-project/Sparkle) es **el estándar de facto** desde hace más de 15 años para auto-actualización de apps Mac fuera del App Store. La versión actual es **Sparkle 2**, que requiere macOS 10.13+ y soporta sandboxing, custom UI, actualización de bundles externos, canales (beta/stable), phased rollouts, deltas, "critical updates" y firmas tanto **EdDSA (Ed25519)** propias como **Apple Code Signing**.

Características clave:

- Update silencioso en segundo plano (opcional para el usuario).
- Delta updates pequeños y rápidos.
- Comprobación una vez al día por defecto, configurable.
- Pregunta permiso al segundo lanzamiento, no en el primero (mejor first-run UX).
- Sin branding propio: tu icono y nombre, no se ve "Sparkle".
- Integración con Swift Package Manager: `https://github.com/sparkle-project/Sparkle`.

### 5.2 Integración SwiftUI

Para una app SwiftUI puramente (sin AppDelegate ni MainMenu.xib), el setup es **programático**, documentado oficialmente en https://sparkle-project.org/documentation/programmatic-setup/. Resumen:

```swift
import SwiftUI
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var vm: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    init(updater: SPUUpdater) {
        self.updater = updater
        self.vm = CheckForUpdatesViewModel(updater: updater)
    }
    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!vm.canCheckForUpdates)
    }
}

@main
struct AstromagicApp: App {
    private let updaterController: SPUStandardUpdaterController
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
    }
    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandGroup(after: .appInfo) {
                    CheckForUpdatesView(updater: updaterController.updater)
                }
            }
    }
}
```

Pasos adicionales necesarios:

1. **Generar par de claves EdDSA**: en el SwiftPM, click derecho sobre el paquete Sparkle → "Show in Finder" → subir un nivel a `artifacts/` → `Sparkle/bin/generate_keys`. Guarda la clave privada en el keychain (NUNCA en el repo).
2. En `Info.plist`:
   - `SUFeedURL` → URL HTTPS a tu `appcast.xml` (p. ej. `https://updates.astromagic.app/appcast.xml`).
   - `SUPublicEDKey` → la clave pública EdDSA generada.
   - `SUEnableAutomaticChecks` = `YES`.
3. En *Signing & Capabilities* → activar **Outgoing Connections (Client)** (y Incoming si fuera sandboxed con XPC).
4. En la entitlements, si la app está sandboxed: añadir las claves específicas de Sparkle (ver doc oficial).
5. **Generar y firmar el appcast** con `generate_appcast Updates/` (incluido en `artifacts/Sparkle/bin/`). Esta herramienta:
   - Lee los `.dmg/.zip` en una carpeta.
   - Calcula tamaños y firmas EdDSA.
   - Genera `appcast.xml` con todos los items.
   - Genera deltas binarios entre versiones consecutivas.
6. Subir DMG firmado/notarizado/grapado + `appcast.xml` a tu hosting (S3, Cloudflare R2, GitHub Releases, Backblaze B2, Netlify, etc.). HTTPS obligatorio (App Transport Security).

### 5.3 Hospedar el appcast

Opciones populares para indie:

- **GitHub Releases + GitHub Pages**: gratis, fácil, suficiente para volúmenes pequeños/medios. Subes el DMG como release asset y `appcast.xml` lo sirve Pages.
- **Cloudflare R2** + **Cloudflare Pages** o **Workers**: prácticamente gratis para apps indie, ancho de banda ilimitado sin egress fees.
- **Amazon S3 + CloudFront**, **Backblaze B2 + Bunny CDN**: clásicos.
- **Netlify** o **Vercel**: bien si ya alojas tu landing ahí.
- **Supabase + Edge Functions**: si quieres servir un appcast dinámico que dependa de la versión, canal beta, etc. (hay artículos recientes ("Itsuki", marzo 2026) describiendo exactamente esta arquitectura para SwiftUI + Supabase + Sparkle).

Buenas prácticas:

- Sirve siempre por HTTPS con TLS moderno.
- Firma cada DMG/ZIP en el appcast con la clave EdDSA (Sparkle lo refuerza).
- El propio binario sigue notarizado y grapado: Sparkle no sustituye la notarización Apple, complementa.
- Lleva una `CHANGELOG.md` y enlázala en `<sparkle:releaseNotesLink>` para que el usuario vea qué cambia.

### 5.4 Alternativas a Sparkle

En la práctica, **no hay alternativa madura comparable** para macOS fuera del App Store. Las opciones existentes son:

- **Squirrel.Mac** (de Mattermost; el motor que usaba Slack): viable pero menos documentado y menos mantenido para casos genéricos.
- **electron-updater** (autoUpdater de Electron): solo aplica si tu app es Electron, no es tu caso.
- **Sistema casero**: comprobar tú mismo una URL JSON con la versión, descargar el DMG, pedir al usuario que lo arrastre. Posible pero reinventas mucho — y pierdes deltas, firmas y manejo de quarantine.

**Recomendación clara: Sparkle 2 vía SwiftPM**.

---

## 6. App Store vs distribución directa

### 6.1 Comisión y términos económicos

- **Mac App Store**: 30 % de comisión sobre cada venta (15 % si entras al **Small Business Program**, requisito: ingresos < 1 M USD/año en App Store; tu caso seguro). Apple gestiona pagos, factura, IVA, devoluciones. Pagos en EUR mensuales.
- **Distribución directa con MoR (Paddle / Lemon Squeezy)**: ~5 % + 0,50 USD por transacción + el coste implícito del IVA gestionado. Total efectivo ~7–9 % en muchos casos. Mucho más margen (~91 % vs 70 % o 85 %).
- **Stripe directo**: ~3 % + Stripe Tax (~0,5 %) + tu trabajo administrativo + alta en OSS.

### 6.2 Sandbox del App Store y CSwissEph + SQLite

El Mac App Store **exige App Sandbox**. Esto es el obstáculo principal en tu caso. Implicaciones concretas para AstroMalik:

- **CSwissEph embebido**: como librería estática **dentro** de tu binario, funciona bien en sandbox; no hace nada que la sandbox bloquee. Lo crítico es que los **ficheros de efemérides** (`.se1`, las tablas SEMOXX, SEPLXX, SEASXX, etc.) que Swiss Ephemeris consulta deben estar **dentro del bundle** (ej. en `Resources/ephe/`) y referenciarlos con `swe_set_ephe_path` apuntando al path absoluto del bundle. Si dependes de que el usuario añada efemérides externas, tendrás que usar un `NSOpenPanel` y *security-scoped bookmarks* para mantener acceso entre sesiones. Esto es factible pero añade complejidad.
- **SQLite local**: SQLite funciona en sandbox **siempre que la base de datos esté en el contenedor de la app** (`~/Library/Containers/[bundle-id]/Data/...`) o en una carpeta seleccionada por el usuario con bookmark. **El problema clásico** es el fichero auxiliar `*-journal` (o `-wal`/`-shm` en modo WAL): cuando el usuario elige `~/Documents/mibase.sqlite`, el sandbox concede acceso a ese fichero, pero al escribir SQLite crea `mibase.sqlite-journal` que no está en la lista de permisos → **error `deny(1) file-write-create`**. La solución oficial es declarar relaciones de archivos en `Info.plist` (`NSIsRelatedItemType`) e implementar `NSFilePresenter` con `primaryPresentedItemURL` y `presentedItemURL`. Más sencillo: mantener la BD dentro del contenedor o en `Application Support` de la sandbox y exportarla con un comando explícito del usuario.
- **Sistema de archivos general**: en sandbox no puedes leer ni escribir libremente fuera del contenedor; toda interacción con `~/Documents`, escritorio, otras carpetas, requiere `NSOpenPanel`/`NSSavePanel` + bookmarks security-scoped, que el usuario percibe como "diálogos extra" pero que son aceptados.
- **Hardened Runtime + entitlements**: iguales en MAS y direct distribution.
- **APIs prohibidas en MAS**: `getppid` para detectar el padre, llamadas privadas, ciertas fuentes inyectadas, daemons system-wide. Para una app astrológica de cálculo no aplica.

Si tu app puede vivir cómodamente con la BD dentro del contenedor y CSwissEph con efemérides bundled, el sandbox **no es un bloqueante** y publicar en MAS es factible en paralelo. Si quisieras (por ejemplo) abrir bases de datos compartidas con otra app de astrología en `~/Documents`, la fricción aumenta y la distribución directa (sin sandbox) es muchísimo más cómoda.

### 6.3 Ventajas y desventajas resumidas

| Aspecto | Mac App Store | Distribución directa |
|---|---|---|
| Comisión | 30 % (15 % SMB) | ~5–8 % MoR / ~3 % Stripe |
| IVA / facturas | Lo hace Apple | MoR lo hace; Stripe lo haces tú |
| Descubrimiento | Buscador del MAS, posibles features Apple | SEO, blog, X, comunidad astrológica |
| Confianza usuario | Alta ("desde el App Store") | Alta si firmada+notarizada |
| Sandbox | Obligatorio | Opcional |
| Trials | No (workarounds: free + IAP) | Sí, naturalmente |
| Pagos únicos > 79 € | Permitido | Permitido |
| Updates | Push automático Apple | Sparkle |
| Acceso a APIs avanzadas | Limitado por sandbox | Total (con Hardened Runtime + entitlements) |
| Refunds | Apple decide unilateralmente | Tú o el MoR deciden |
| Datos del cliente | Apple no te da el email | Tienes email para soporte y marketing |

### 6.4 ¿Se puede distribuir por ambos canales simultáneamente?

**Sí, totalmente**, y es una práctica común entre apps Mac indie maduras (Bear, Things, Reeder, NetNewsWire, ScreenFloat, CleanShot X, etc.). El flujo típico es:

- **Mismo bundle ID** en ambos.
- Dos targets/configurations en Xcode: uno con sandbox + entitlements MAS, otro con Hardened Runtime + Developer ID + Sparkle.
- Lógica condicional `#if APP_STORE` para activar StoreKit en MAS y Paddle/license-key + Sparkle en Direct.
- Compartes precios o no — habitualmente el mismo precio para no canibalizar.
- Tu base de licencias direct y la de MAS son independientes; un usuario que compre por un canal no obtiene automáticamente el otro (a menos que implementes "redeem MAS receipt → direct license", lo cual es factible pero opcional).

Setapp se suma como **tercer canal** sin exclusividad ni conflicto contractual (Setapp confirma explícitamente: "No, we never put any limitations on where and how you distribute your apps").

---

## 7. Casos reales y plataformas adicionales

### 7.1 Apps Mac indie de nicho con éxito en distribución directa

Ejemplos relevantes para inspirar tu modelo:

- **Hookmark** (productividad, conexión de documentos): vendida directamente a través de Paddle, 30+ USD pago único, con una mecánica de licencia por URL elegantemente simple (Paddle envía un email con `https://hook.cogsciapps.com/activate?info=…` y al hacer click activa la app). Tiene también versión App Store.
- **ScreenFloat** (Eternal Storms / Matthias Gansrigler): el desarrollador documenta públicamente en su blog (eternalstorms.at) la migración a Paddle Billing en 2024 con webhooks propios, validación de licencias y mecanismos de recovery; vende en MAS y direct simultáneamente.
- **Timing** (Daniel Alm, time-tracking): venta directa + Setapp; el propio Daniel ha comentado públicamente que Setapp le aporta exposición a usuarios que de otro modo no le habrían encontrado.
- **CleanShot X** (MacPaw): direct + Setapp.
- **Bear**, **Things**, **Reeder**, **NetNewsWire**: combinaciones distintas de MAS, direct y Setapp.
- **iMazing**, **DaisyDisk**, **Soulver**: direct distribution + MAS, con Sparkle y licencia propia.
- En el nicho **astrológico Mac específicamente**, los referentes históricos son **TimePassages** (AstroGraph Software, Mac App Store y direct), **Solar Fire** (Astrolabe, Windows-first pero con paridad Mac), **iPhemeris**, **Cosmic Patterns / Sirius / Kepler** (Windows). El nicho tiende a tolerar precios más altos (60–300 €) y compradores serios; hay espacio para una app SwiftUI nativa moderna que se posicione bien.

### 7.2 Setapp para apps de nicho

**Setapp** (de MacPaw, Ucrania, lanzada en 2017) es un servicio de suscripción a un catálogo curado de >250 apps Mac y iOS. Modelo económico:

- El usuario paga ~9,99 USD/mes por acceso a todo el catálogo (Mac).
- Setapp reparte los ingresos a desarrolladores en función del **uso**: si el usuario abre la app al menos una vez al mes, te llega tu parte.
- Setapp se queda **10 %**. El desarrollador recibe **70 %** garantizado del fee + hasta un 20 % adicional si la app se descubre por canales de partners (total **hasta 90 %**).
- **No exclusivo**: puedes seguir vendiendo en MAS y direct sin restricciones.
- Vida media de un suscriptor Setapp: ~24 meses según ellos.

**Notas importantes para 2025–2026**:

- **Setapp Mobile (alternativa a App Store en EU)** se cierra el **16 de febrero de 2026** por las "complejas y cambiantes condiciones comerciales" del Core Technology Fee de Apple bajo la DMA. **Setapp para Mac sigue funcionando con normalidad** y no está afectado por este cierre.
- Setapp es de Ucrania y opera durante la guerra; ha sido públicamente respetada por la comunidad.
- En 2025 introdujeron **Eney**, un asistente IA integrado al sistema; no afecta a apps de terceros, pero indica el rumbo del producto.

**¿Tiene sentido para AstroMalik?** Probablemente **sí, como canal complementario** una vez que la app esté madura y haya recogido cierto feedback. La clave es:

- Tu app astrológica de nicho probablemente **no es un fit perfecto** para el suscriptor Setapp medio (que busca utilidades de productividad/limpieza/captura). El revenue Setapp para apps muy nicho suele ser modesto.
- Pero el descubrimiento es real: un nuevo lanzamiento Setapp recibe **~30 000 impresiones únicas** en los primeros días según Setapp, y tienes una audiencia internacional sin coste de marketing.
- La barrera es la revisión de calidad de Setapp: si entras, es un sello de calidad adicional.

**Recomendación**: lanza primero en distribución directa (con LemonSqueezy/Paddle + Sparkle + licencia propia), valida el producto en el mercado durante 6–12 meses, y entonces aplica a Setapp **si** tu app puede sostener un modelo donde el ingreso por usuario activo sea menor que un pago único pero el volumen de usuarios pueda compensarlo.

---

## Recomendación global para AstroMalik / Astromagic

Sintetizando todo lo anterior para el contexto concreto (España, indie solo, SwiftUI, CSwissEph, SQLite, 52–79 € pago único):

1. **Inscríbete en el Apple Developer Program como individual / autónomo (99 USD/año)** y emite un certificado *Developer ID Application*.
2. **Pipeline de release** (idealmente automatizada en GitHub Actions):
   - `xcodebuild archive` con Hardened Runtime activado.
   - Export con Developer ID.
   - `create-dmg` con fondo personalizado y alias de Applications.
   - `codesign` del DMG.
   - `xcrun notarytool submit --wait` con API Key de App Store Connect.
   - `xcrun stapler staple` del DMG.
3. **Auto-update con Sparkle 2 vía SwiftPM**, appcast XML servido desde Cloudflare R2 + Pages o GitHub Releases + Pages, firmado con clave EdDSA.
4. **Plataforma de venta**: empieza por **Lemon Squeezy** (simplicidad, MoR, integración LicenseKit, aprobación rápida) o **Paddle Classic** (si prefieres su SDK Mac listo para usar). Ambas se encargan del IVA en España y resto de UE/mundo, dejándote como autónomo solo declarar la factura B2B intracomunitaria recibida.
5. **Sistema de licencias**: **AquaticPrime** o **LicenseKit** + un endpoint mínimo (Cloudflare Worker o Supabase Edge Function) que reciba el webhook de la plataforma y emita la licencia firmada. Permite 2 activaciones por licencia personal, validación criptográfica local en cada arranque y verificación online silenciosa cada 14 días.
6. **Asegúrate** desde el principio de que tu DB SQLite vive dentro del contenedor de Application Support (no en `~/Documents`) para no cerrarte la puerta a publicar también en MAS más adelante. Bundle de efemérides de Swiss Ephemeris dentro del `Resources/ephe`.
7. **Mac App Store**: opcional pero recomendable como **segundo canal** (más adelante, una vez estabilizado el producto en directo). Mismo bundle ID, target distinto con sandbox + StoreKit. Aceptas perder un 30 % a cambio de descubrimiento orgánico Apple y la confianza extra de algunos usuarios.
8. **Setapp**: explorar **6–12 meses tras el lanzamiento**, tras tener tracción y reviews. No es exclusivo y solo aporta si la app pasa su review de calidad.
9. **Asesoría fiscal en España**: confirma el tratamiento del IVA con un asesor (autónomo o SL) antes de la primera venta — la reverse charge B2B intracomunitaria con un MoR fuera de España requiere los modelos 303, 349 y posiblemente alta en ROI.
10. **Posicionamiento de precio**: tu rango 52–79 € es razonable y consistente con apps Mac indie de nicho profesional (TimePassages ronda los 60 USD, apps de productividad serias 30–60 USD). El pago único sin suscripción es bien recibido en el nicho astrológico, donde la suscripción se asocia a webs de carta y no a herramientas profesionales del astrólogo.

Esta combinación es la "stack" estándar utilizada por el grueso de los desarrolladores Mac indie de nicho en 2025–2026 y minimiza tanto el coste fijo como las fricciones legales/técnicas que más tiempo roban a un solo desarrollador.