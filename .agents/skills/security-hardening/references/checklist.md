# Controles de Seguridad por Área

Cada control indica cómo comprobarlo. Los ejemplos de código concretos están en la skill `stack-*` del proyecto.

## Autenticación y sesiones
- **Hash de contraseñas**: argon2id (o bcrypt con coste ≥ 12). Verificar: el valor guardado empieza por `$argon2id$` o `$2b$`.
- **Mensajes neutros**: login y recuperación responden igual exista o no el usuario. Verificar: misma respuesta y tiempo similar para un correo inexistente.
- **Rate limiting**: 5–10 intentos por IP y por cuenta en login, registro y recuperación. Verificar: el intento 11 devuelve `429`.
- **JWT**: algoritmo fijado al verificar (`algorithms: ['HS256']` o `['RS256']`), expiración de minutos, `iss`/`aud` comprobados, refresh rotatorio que invalida el anterior. Verificar: un token con `alg: none` o caducado devuelve `401`.
- **Cookies de sesión**: `HttpOnly; Secure; SameSite=Lax` (o `Strict`). Si la sesión va en cookie, protección CSRF en las mutaciones.
- **Recuperación de contraseña**: token aleatorio de un solo uso, caducidad corta, guardado como hash.

## Autorización
- **Por objeto**: toda consulta incluye el filtro por propietario o tenant (`WHERE id = $1 AND owner_id = $2`). Verificar: test de un usuario pidiendo el recurso de otro → `404`.
- **Por rol**: middleware de servidor en cada ruta protegida; la UI solo refleja.
- **Asignación masiva**: los esquemas de entrada no aceptan `role`, `isAdmin`, `ownerId`, `price` ni campos calculados. Verificar: enviar `"role":"admin"` no cambia nada (o devuelve `400` con esquema estricto).

## Entrada y salida
- **Validación**: esquema estricto en la frontera; rechazar campos desconocidos; límites de longitud y rango.
- **Inyección**: consultas parametrizadas u ORM; nada de entrada en `eval`, `child_process`/`subprocess` con shell, rutas de archivo (`path traversal`) ni HTML sin escapar.
- **Salida**: esquemas de respuesta explícitos (nunca devolver el modelo completo de BD); sin hashes, tokens ni campos internos.
- **Errores**: mensaje genérico y un identificador de correlación al cliente; el detalle va al log.

## Superficie HTTP
- **Cabeceras**: `Content-Security-Policy` (sin `unsafe-inline` en scripts si es posible), `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `frame-ancestors 'none'` o la CSP equivalente. Verificar con `curl -sI <url>`.
- **CORS**: lista explícita de orígenes; nunca `*` con credenciales.
- **Tamaños**: límite de cuerpo (p. ej. 1 MB en JSON) y de archivos.

## Archivos subidos
- Tipo verificado por contenido (bytes mágicos), no por extensión ni por `Content-Type`.
- Tamaño máximo; nombre generado por el servidor; almacenamiento fuera del directorio público o en almacenamiento de objetos con URL firmada.
- Imágenes reprocesadas (elimina metadatos y cargas ocultas).

## SSRF (el servidor llama a una URL que da el usuario)
- Lista de dominios permitidos; resolver el DNS y bloquear IPs privadas, `localhost`, `169.254.169.254` (metadatos de la nube) y rangos internos; sin seguir redirecciones a destinos no permitidos; timeout corto.

## Webhooks
- Firma verificada sobre el cuerpo crudo antes de parsearlo; rechazar si falta o no coincide; idempotencia por ID de evento (ver `payments-stripe`).

## Secretos y dependencias
- Secretos solo en variables de entorno; `.env` en `.gitignore`; `.env.example` sin valores reales.
- `./.agents/scripts/scan-secrets.sh --branch` limpio antes del handoff.
- Auditoría de dependencias: `npm audit --omit=dev` (Node) o `pip-audit` (Python). Vulnerabilidades altas: actualizar, o registrar deuda con `task.sh debt` si no hay parche y no son explotables en este uso (nunca deuda de seguridad crítica).
