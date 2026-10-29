# Autenticación JWT Propia (Express + Angular)

Diseño estándar del stack. Cualquier desviación se registra como ADR.

## Tokens

| Token | Formato | Vida | Dónde vive | Cómo viaja |
| :--- | :--- | :--- | :--- | :--- |
| **Access** | JWT firmado con `jose` (HS256, secreto ≥ 32 bytes en `JWT_ACCESS_SECRET`) | 15 min | Memoria del cliente (un `signal` en `AuthStore`) | Header `Authorization: Bearer …` |
| **Refresh** | Aleatorio opaco (32 bytes, `crypto.randomBytes`) | 7–30 días | Cookie `httpOnly; Secure; SameSite=Strict; Path=/api/v1/auth` + hash SHA-256 en BD | Cookie automática |

- **Nunca** guardar tokens en `localStorage` ni `sessionStorage`.
- Claims del access token: `sub` (id de usuario), `role`, `iat`, `exp`. Nada sensible: el payload es legible.

## Tabla `refresh_tokens` (Drizzle)
`id`, `userId` (FK `ON DELETE CASCADE`), `tokenHash` (único), `familyId`, `expiresAt`, `revokedAt` (nullable), `createdAt`. Índice por `userId`.

## Endpoints (`/api/v1/auth`)

| Endpoint | Comportamiento |
| :--- | :--- |
| `POST /register` | Valida con Zod (`packages/shared`), hash con **Argon2id** (`argon2`), crea usuario. Respuesta genérica si el email ya existe para no filtrar cuentas. |
| `POST /login` | Rate limit 5 intentos / 5 min por IP + email (`express-rate-limit` → 429 + `Retry-After`). Compara con `argon2.verify`. Emite access en el body y refresh en cookie. Mismo mensaje y tiempo de respuesta para email inexistente o contraseña errónea. |
| `POST /refresh` | Comprueba el header `Origin` contra la lista permitida. Busca el hash del refresh: si está revocado → **reuso detectado**: revoca toda la familia y responde 401. Si es válido, lo revoca y emite uno nuevo de la misma familia (rotación). |
| `POST /logout` | Revoca el refresh actual y borra la cookie. |
| `GET /me` | Requiere access token; devuelve el perfil sin `passwordHash`. |

## Middlewares Express
- `requireAuth`: verifica el JWT (`jwtVerify` de `jose`), adjunta `req.user = { id, role }`; 401 si falta o expiró.
- `requireRole(...roles)`: 403 si el rol no está permitido.
- **Propiedad del recurso (IDOR)**: se comprueba en el servicio (`where(and(eq(orders.id, id), eq(orders.userId, req.user.id)))`), nunca solo en la ruta.

## Angular
- `AuthStore` (`core/auth/auth.store.ts`): `accessToken = signal<string | null>(null)`, `user = signal<User | null>(null)`, `isAuthenticated = computed(...)`.
- **Interceptor funcional** (`withInterceptors([authInterceptor])`): añade el Bearer a peticiones a `/api`; ante un 401 llama a `/auth/refresh` **una sola vez** (las peticiones concurrentes esperan el mismo refresh) y reintenta; si el refresh falla, limpia el estado y navega a `/login`.
- Peticiones a `/api/v1/auth/*` con `withCredentials: true` para enviar la cookie.
- **Arranque**: `provideAppInitializer(() => inject(AuthStore).tryRefresh())` restaura la sesión al recargar la página.
- **Guards funcionales**: `authGuard` (`CanActivateFn`) redirige a `/login?returnUrl=…`; `roleGuard('admin')` para rutas restringidas. Los guards son UX: la seguridad real está en la API.

## Variables de Entorno
`JWT_ACCESS_SECRET`, `JWT_ACCESS_TTL=15m`, `REFRESH_TTL_DAYS=14`, `CORS_ORIGIN=http://localhost:4200`, `COOKIE_SECURE=true` (false solo en local). Todas validadas con Zod al arrancar (`config/env.ts`).

## Pruebas Obligatorias (supertest)
Login correcto, contraseña errónea, rate limit (6.º intento → 429), ruta protegida sin token (401), con rol insuficiente (403), acceso a recurso ajeno (404/403), rotación de refresh y detección de reuso (el refresh viejo revoca la familia), logout invalida el refresh.
