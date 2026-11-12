# Arquitectura Offline-First, Seguridad Móvil y Checklist de Tiendas

Guía práctica complementaria a `mobile-agent` para React Native/Expo, Flutter, Capacitor, SwiftUI o Kotlin.

## 1. Almacenamiento Seguro y Ciclo de Vida Nativo

- **Credenciales y secretos**: tokens de acceso/refresh y claves derivadas viven **exclusivamente** en iOS Keychain / Android Keystore (`expo-secure-store`, `flutter_secure_storage`, `EncryptedSharedPreferences`). Prohibido guardar tokens en `AsyncStorage`, `UserDefaults`, `SharedPreferences` plano o SQLite sin cifrado.
- **Ciclo de vida y privacidad en background**:
  - Al pasar la app a segundo plano (`AppState` / `Lifecycle`), pausa timers, polling, GPS de alta precisión y sockets.
  - En pantallas con datos bancarios o médicos activa protección de captura/miniatura (`FLAG_SECURE` en Android, vista de privacidad en `applicationWillResignActive` en iOS).
- **Red y TLS**: exige HTTPS (`NSAllowsArbitraryLoads = false`, `usesCleartextTraffic = false` en release); nunca valides webhooks ni secretos de terceros dentro del cliente móvil.

## 2. Patrón Offline-First y Subida Multimedia

1. **Lectura local inmediata**: la UI lee primero de almacenamiento local (`SQLite`/`WatermelonDB`/`MMKV` para estado no sensible) mostrando marca de última sincronización en lugar de bloquear con un *spinner* infinito cuando no hay señal.
2. **Cola de mutaciones persistente**:
   - Cada mutación offline se guarda en una cola local con `clientOperationId` (UUID usado como `Idempotency-Key` en el servidor).
   - Al recuperar conectividad (`NetInfo`/`Connectivity`), drena en orden FIFO con *backoff* exponencial y maneja conflictos (`409` / versión divergente) con estado claro para el usuario.
3. **Multimedia antes de subir**: comprime fotos/vídeo en segundo plano eliminando metadatos EXIF innecesarios, respeta límites de tamaño de `async-jobs` / `security-hardening` y sube por URL pre-firmada mostrando barra de progreso reanudable si aplica.

## 3. Deep Links, Accesibilidad Táctil y Tiendas (App Store / Google Play)

- **Deep links verificados**:
  - iOS Universal Links: `/.well-known/apple-app-site-association` servido por HTTPS sin redirecciones.
  - Android App Links: `/.well-known/assetlinks.json` con el SHA-256 del certificado de firma de Play App Signing (`android:autoVerify="true"`).
  - Valida y sanitiza todos los parámetros entrantes de un deep link igual que una petición HTTP pública (nunca ejecutes navegación arbitraria o acciones sensibles sin comprobar sesión/autorización).
- **Safe Areas, teclado y táctil**:
  - Respeta `SafeAreaInsets` en pantallas con notch/Dynamic Island y barras gestuales inferiores.
  - Verifica con el teclado abierto que ningún input ni el botón de confirmación queden tapados (`KeyboardAvoidingView` / `imePadding`), y mantén todo control tocable `>= 44×44 pt` (`48×48 dp` Android).
- **Checklist pre-publicación en tiendas**:
  - [ ] iOS `Info.plist`: descripciones concretas y honestas (`NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, etc.) y manifiesto `PrivacyInfo.xcprivacy` actualizado con razones declaradas de APIs requeridas.
  - [ ] Android `AndroidManifest.xml`: componentes internos (services, receivers, providers) con `android:exported="false"`, `targetSdkVersion` vigente exigido por Play Console y formulario Data Safety al día.
  - [ ] Cuentas demo funcionales documentadas para revisión de Apple/Google si la app requiere login; probada en tamaño compacto, moderno con notch, tablet y modo avión.

