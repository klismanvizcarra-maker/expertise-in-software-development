---
name: stack-react-native-expo
description: Convenciones del stack móvil React Native 0.76+ con Expo SDK 52+ (New Architecture y Hermes) + Expo Router v3 + TypeScript + persistencia local (MMKV/SQLite) y TanStack Query. Define estructura de carpetas, enrutamiento por archivos, safe areas, hardware nativo y trampas de compilación móvil. Usar siempre que se desarrolle, pruebe o empaquete una app móvil nativa para iOS y Android con Expo o React Native. No usar para aplicaciones web basadas en stack-nextjs-tailwind-prisma, stack-angular-express-postgres, stack-fastapi-postgres, stack-vue-nuxt-postgres, stack-react-vite-node, stack-nestjs-postgres ni stack-fastapi-mongodb.
---

# Stack: React Native + Expo (New Architecture) + Expo Router + TypeScript

Esta skill define el **cómo técnico concreto** de aplicaciones móviles multiplataforma nativas para iOS y Android; las skills de rol (`mobile-agent`, `ui-ux-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Toda excepción se registra como ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Expo SDK** | 52+ | Compatible con React Native 0.76+ y React 18.3 / 19 |
| **React Native** | 0.76+ | New Architecture activa por defecto (Fabric render, TurboModules, Bridgeless) |
| **Motor JS** | Hermes | Compilación Bytecode anticipada (AOT), memoria reducida y arranque rápido |
| **Enrutador Móvil** | `expo-router` v3 | Enrutamiento basado en archivos (Stacks, Tabs, Modals) con deep linking automático |
| **Lenguaje** | TypeScript 5.6+ | Tipado estricto con paths alias (`@/components`, `@/services`, `@/stores`) |
| **Persistencia Local** | `react-native-mmkv` / `expo-sqlite` | MMKV para pares clave-valor síncronos ultrarrápidos; SQLite para bases relacionales offline |
| **Seguridad de Tokens** | `expo-secure-store` | Almacenamiento encriptado en iOS Keychain y Android Keystore |
| **Calidad y Tests** | Jest + React Native Testing Library | Pruebas unitarias de componentes y hooks |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto-mobile>/
├── app.json                      # Configuración de Expo (nombre, bundleId, scheme, plugins)
├── package.json
├── tsconfig.json
├── app/                          # Expo Router: enrutamiento por archivos
│   ├── _layout.tsx               # Root Layout (SafeAreaProvider, QueryClientProvider, Temas)
│   ├── (auth)/                   # Grupo de autenticación
│   │   ├── _layout.tsx           # Stack layout de auth
│   │   ├── login.tsx             # Pantalla de login
│   │   └── register.tsx
│   ├── (tabs)/                   # Grupo principal con navegación por pestañas
│   │   ├── _layout.tsx           # Tabs layout (iconos, badges, safe area bottom)
│   │   ├── index.tsx             # Pestaña Home
│   │   └── profile.tsx           # Pestaña Perfil
│   └── modal.tsx                 # Modal presentado sobre el stack
├── components/                   # Componentes visuales reutilizables
│   ├── ui/                       # Botones, inputs, tarjetas, badges
│   └── feedback/                 # Loaders, pantallas vacías y estados de error
├── hooks/                        # Custom hooks móviles (useKeyboard, useOrientation, useAuth)
├── services/                     # Consumo de API backend (cliente HTTP con Axios/Ky o TanStack Query)
├── storage/                      # Abstracción de MMKV y SecureStore
└── constants/                    # Colores de tokens, tamaños de espaciado y tipografía
```

---

## 3. Comandos Habituales

```bash
# Desarrollo local (Expo Go / Prebuild)
npx expo start -c

# Ejecución en simulador iOS / emulador Android
npx expo run:ios
npx expo run:android

# Verificación de TypeScript y Linting
npx tsc --noEmit
npm run lint

# Generación de binarios locales o cloud con EAS (Expo Application Services)
npx eas build --profile preview --platform all
```

---

## 4. Reglas y Convenciones Clave

1. **Gestión Defensiva de Safe Areas y Teclado**:
   - Envuelve siempre pantallas con `SafeAreaView` de `react-native-safe-area-context` (nunca el componente básico de React Native que solo soporta iOS).
   - Usa `KeyboardAvoidingView` con `behavior={Platform.OS === 'ios' ? 'padding' : undefined}` o controladores dedicados para evitar que los inputs queden tapados.

2. **Cero Secretos en el Binario Móvil**:
   - Las variables que comienzan por `EXPO_PUBLIC_` se incrustan en el bundle compilado y son legibles por cualquier usuario desensamblando la APK/IPA.
   - Tokens de API privados o claves de Stripe Secret NUNCA se incluyen en el código móvil; las operaciones privilegiadas siempre se delegan al `backend-agent`.

3. **Arquitectura Offline-First y Cache**:
   - Conecta las consultas de red con TanStack Query configurando `networkMode: 'offlineFirst'` y persistencia en MMKV para permitir navegación sin conexión fluida.

---

## 5. Trampas Conocidas (Quirks)

| Quirk / Trampa | Comportamiento Inesperado | Solución Obligatoria |
| :--- | :--- | :--- |
| **New Architecture y Librerías C++** | Módulos nativos antiguos crashean en build con errores de `TurboModule` | Comprobar compatibilidad con New Architecture o añadir flag `newArchEnabled: false` temporalmente si una dependencia crítica no ha migrado |
| **Bucle de navegación en Expo Router** | Redirecciones en `useEffect` antes de montar el layout disparan advertencias de router | Usar el hook `<Redirect href="..." />` condicional dentro del render o navegar tras comprobar `rootNavigationState?.key` |
| **Android StatusBar translúcida** | El contenido se solapa detrás de la barra de estado en Android | Configurar `StatusBar` de `expo-status-bar` y respetar los márgenes `insets.top` de `useSafeAreaInsets()` |
| **Dimensiones fijas y rotación** | `Dimensions.get('window')` estático no actualiza valores al rotar la pantalla o abrir teclado | Usar el hook reactivo `useWindowDimensions()` en lugar del método estático |
