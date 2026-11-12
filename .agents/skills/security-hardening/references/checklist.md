# Controles de Seguridad por Área

Cada control indica cómo comprobarlo. Los ejemplos de código concretos están en la skill `stack-*` del proyecto.

## Autenticación y sesiones
- **Hash de contraseñas**: argon2id (parámetros de partida de OWASP: 19 MiB de memoria, 2 iteraciones, paralelismo 1) o bcrypt con coste ≥ 12; bcrypt ignora lo que pase de 72 bytes, así que limita la longitud de la contraseña o usa argon2id. Verificar: el valor guardado empieza por `$argon2id$` o `$2b$`.
- **Mensajes neutros**: login y recuperación responden igual exista o no el usuario. Verificar: misma respuesta y tiempo similar para un correo inexistente.
- **Rate limiting**: 5–10 intentos por ventana, por IP y por cuenta, en login, registro y recuperación. El límite por cuenta debe frenar, no bloquear la cuenta de forma indefinida: un atacante podría dejar fuera a la víctima (retraso creciente o bloqueo temporal corto). Verificar: el primer intento que supera el límite configurado (el 6.º si el límite es 5) devuelve `429`.
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
- **Cabeceras**: `Content-Security-Policy` (sin `unsafe-inline` en scripts si es posible), `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy` y la directiva CSP `frame-ancestors 'none'` contra el clickjacking (o `X-Frame-Options: DENY` para navegadores antiguos). Verificar con `curl -sI <url>`.
- **CORS**: lista explícita de orígenes comparada de forma exacta. El error peligroso es **reflejar** el `Origin` recibido en `Access-Control-Allow-Origin` junto con `Access-Control-Allow-Credentials: true` (los navegadores ya rechazan `*` con credenciales). Verificar: una petición con `Origin: https://evil.example` no recibe ese origen de vuelta.
- **Tamaños**: límite de cuerpo (p. ej. 1 MB en JSON) y de archivos.

## Archivos subidos
- Tipo verificado por contenido (bytes mágicos), no por extensión ni por `Content-Type`.
- Tamaño máximo; nombre generado por el servidor; almacenamiento fuera del directorio público o en almacenamiento de objetos con URL firmada.
- Imágenes reprocesadas (elimina metadatos y cargas ocultas); SVG rechazado o saneado, porque puede llevar scripts.
- Descarga servida con `Content-Disposition: attachment` y `X-Content-Type-Options: nosniff`, desde otro dominio si es posible.
- Archivos comprimidos: límite de tamaño descomprimido y de número de entradas (bombas de descompresión).

## SSRF (el servidor llama a una URL que da el usuario)
- **Mejor opción**: no aceptar URLs arbitrarias. Si basta con elegir entre destinos conocidos, el usuario envía un identificador y el servidor construye la URL.
- **Si hay que aceptarlas**, todos estos controles a la vez:
  - Solo esquemas `http` y `https`; nada de `file:`, `gopher:`, `ftp:` ni `data:`.
  - Lista de dominios permitidos cuando sea posible.
  - Resolver el nombre **una vez**, validar **todas** las IPs resultantes y **conectar a esa IP validada conservando el nombre original para el SNI y la verificación TLS** (no volver a resolver al conectar): así se evita el *DNS rebinding*. La validación va en el punto de conexión, no antes.
    - **Primero, la URL ya normalizada**: pásala por el parser de URL estándar (`new URL()` en Node, `urllib.parse` más `ipaddress` en Python) y, si el host es una **IP literal**, valídala directamente. Los ganchos de resolución DNS **no se ejecutan** con una IP literal: en Node, `net.connect` se salta `lookup` y `http://127.0.0.1/`, `http://2130706433/` o `http://169.254.169.254/` pasarían (comprobado con Node 24). El parser de URL de Node ya convierte `2130706433` y `0177.0.0.1` en `127.0.0.1`; `ipaddress` de Python, en cambio, rechaza esas formas, así que normaliza con el parser de URL antes.
    - **Node, para nombres**: función `lookup` propia en `http.Agent`/`https.Agent` o, con el `fetch` global, en `new undici.Agent({ connect: { lookup } })` pasado como `dispatcher`. La función debe respetar las opciones recibidas (desde Node 20 puede llegar `{ all: true }` y hay que devolver un array) y validar cada dirección. Esto **complementa**, no sustituye, la validación de la IP literal del punto anterior. Alternativa: `request-filtering-agent`, que cubre nombres e IPs literales pero solo para clientes que usan `http(s).Agent` (no sirve como `dispatcher` del `fetch` global). Con `https.Agent`, el SNI y el certificado siguen usando el nombre original.
    - **Python**: un transporte o adaptador que fije la IP validada y mantenga el nombre en `server_hostname` para el SNI y la verificación del certificado (urllib3, o un transporte propio de httpx). **Nunca** `verify=False`; pedir `https://<ip>/` con la cabecera `Host` falla la verificación por *hostname mismatch*.
  - Permitir **solo direcciones unicast globales**. En Python, `ipaddress.ip_address(x)` y exigir `is_global` **y** `not is_multicast`, tras normalizar las IPv4 mapeadas (`ipv4_mapped`) y extraer la IPv4 incrustada en NAT64 (`64:ff9b::/96`) y 6to4 (`2002::/16`, `sixtofour`) para validarla también: `is_global` por sí solo acepta multicast (`224.0.0.1`) y esas direcciones con una IPv4 interna dentro (comprobado con Python 3.9). En Node, `ipaddr.js` con `range() === 'unicast'`, aplicado también a la IPv4 incrustada. Usa siempre una librería que normalice la IP (formas decimales, octales o abreviadas como `2130706433` o `0177.0.0.1`), nunca comparaciones de texto. A modo de ejemplo, quedan fuera: `0.0.0.0/8`, `10.0.0.0/8`, `100.64.0.0/10`, `127.0.0.0/8`, `169.254.0.0/16` (metadatos de la nube: `169.254.169.254`), `172.16.0.0/12`, `192.0.0.0/24`, `192.168.0.0/16`, `198.18.0.0/15`, `224.0.0.0/4`, `240.0.0.0/4`, y en IPv6 `::`, `::1`, `fc00::/7`, `fe80::/10`, las IPv4 mapeadas `::ffff:0:0/96`, NAT64 `64:ff9b::/96` y 6to4 `2002::/16`.
  - Redirecciones desactivadas, o seguidas a mano pasando cada `Location` por **todo** el proceso anterior (normalizar, validar la IP literal y resolver con el gancho).
  - Timeout corto y tamaño máximo de respuesta.
- Defensa en profundidad en la nube: exigir IMDSv2 (o el equivalente del proveedor) para que el servicio de metadatos no responda a una petición simple.
- Comprobación: tests con `http://127.0.0.1`, `http://[::1]`, `http://2130706433`, `http://169.254.169.254/latest/meta-data/`, una redirección a una IP interna y, sobre todo, **un nombre que resuelve a una IP interna** (`http://localhost/`, o un resolvedor simulado que devuelve `127.0.0.1` o `169.254.169.254`); todos rechazados. Prueba las IPs literales **con el mismo cliente HTTP** que usa la aplicación: un control que solo actúa en la resolución DNS no las ve.

## Webhooks
- Firma verificada sobre el cuerpo crudo antes de parsearlo, con comparación en tiempo constante; rechazar si falta o no coincide.
- Marca de tiempo firmada con tolerancia corta (p. ej. 5 minutos) contra reenvíos, e idempotencia por ID de evento (ver `payments-stripe`).

## Secretos y dependencias
- Secretos solo en variables de entorno; `.env` en `.gitignore`; `.env.example` sin valores reales.
- `./.agents/scripts/scan-secrets.sh --branch` limpio antes del handoff.
- Auditoría de dependencias: `npm audit --omit=dev` (Node) o `pip-audit` (Python). Vulnerabilidades altas o críticas: actualizar, sustituir la librería o eliminar el uso afectado. **Nunca** se registran como deuda técnica: si no hay parche ni alternativa, la tarea no se entrega y se escala al usuario (`orchestrator-agent`). El especialista no puede declarar por su cuenta que una vulnerabilidad "no aplica": esa decisión (esperar el parche, sustituir la librería, retirar la funcionalidad) es del usuario tras el escalamiento.
