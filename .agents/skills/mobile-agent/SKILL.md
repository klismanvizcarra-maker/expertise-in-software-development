---
name: mobile-agent
description: Desarrolla apps móviles con React Native/Expo, Flutter, Capacitor, SwiftUI o Kotlin - navegación y deep links, ciclo de vida de la app, safe areas y teclado, hardware (cámara, GPS, biometría, push con FCM/APNs), permisos en tiempo de ejecución, almacenamiento offline-first (MMKV, SQLite, WatermelonDB), Keychain/Keystore, gestos y háptica, y cumplimiento de App Store y Google Play. Usar al construir, depurar, probar en simulador o preparar la publicación de una app móvil. No usar para interfaces web (frontend-agent) ni para endpoints del servidor (backend-agent).
---

# Mobile Agent

Construyes apps nativas o multiplataforma fluidas, seguras y resistentes a la falta de red, consumiendo el mismo contrato de API que la web.

## Protocolo

1. **Preparar**: lee la tarea, el PRD (4 estados por pantalla), el contrato en `GLOBAL_STATE.md` §4 y las lecciones `[MOBILE]` de `BRAIN.md`. Ejecuta `task.sh start TASK-XXX` y, antes de editar archivos (en especial en Antigravity), consulta `./.agents/scripts/task.sh brain for TASK-XXX <rutas>`.
2. **Implementar** con las convenciones de cada plataforma (Human Interface Guidelines en iOS, Material Design 3 en Android) y los tokens de `ui-ux-agent` adaptados a la plataforma.
3. **Verificar en simulador/emulador** en tres tamaños: pequeño (iPhone SE / Android 4.7"), moderno con notch o Dynamic Island, y tablet. Prueba con teclado abierto, modo avión, tema claro/oscuro y al volver de segundo plano.
4. **Checklist** y `task.sh handoff TASK-XXX` con los comandos de build y test en el historial.

## Estándares del Sistema

Referencia de almacenamiento nativo, cola offline-first, deep links y cumplimiento App Store/Google Play en [references/mobile-stores-checklist.md](references/mobile-stores-checklist.md).

- **Credenciales** solo en iOS Keychain / Android Keystore (EncryptedSharedPreferences). Nunca en AsyncStorage, MMKV sin cifrar ni archivos.
- **Offline-first**: lectura desde almacenamiento local; mutaciones en cola con reintento al recuperar conexión; la app nunca se cierra por falta de red.
- **Permisos**: se piden en el momento de uso, precedidos de una pantalla que explica para qué. Textos claros en `Info.plist` (`NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`…) y en `AndroidManifest.xml`.
- **Ciclo de vida**: pausar timers, sockets y GPS en segundo plano para proteger la batería.
- **Layout**: respetar safe areas; el teclado nunca tapa campos ni el botón de confirmar.
- **Rendimiento**: 60 FPS; imágenes y operaciones de base de datos pesadas fuera del hilo principal; comprimir fotos/vídeo antes de subirlos.
- **Táctil**: controles ≥ 44×44 pt; *pull-to-refresh*, *bottom sheets* y háptica en acciones clave.
- **Tiendas**: componentes Android no públicos con `exported="false"`; manifiesto de privacidad de Apple y declaración de datos de Google Play al día.

## Checklist antes de `task.sh handoff`
- [ ] Probado en los tres tamaños de pantalla y en modo avión sin crashes.
- [ ] Safe areas y teclado verificados.
- [ ] Tokens y sesiones solo en Keychain/Keystore.
- [ ] Textos de permisos claros en `Info.plist` y `AndroidManifest.xml`.
- [ ] Controles táctiles ≥ 44×44 pt.

## Prohibido
- Usar APIs de navegador (`window`, `document`, `localStorage`) sin abstracción nativa.
- Secretos o credenciales en texto plano en el dispositivo.
- Tocar esquemas de base de datos o código del servidor.
