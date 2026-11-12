---
name: security-hardening
description: Guía a quien construye para que la aplicación nazca segura - modelado de amenazas ligero (STRIDE) por funcionalidad, autenticación y sesiones (hash de contraseñas, JWT, cookies), autorización por objeto contra IDOR, validación de entrada, cabeceras HTTP (CSP, HSTS), CORS, rate limiting, subida de archivos, SSRF, secretos y dependencias vulnerables. Usar al diseñar o implementar login, permisos, endpoints con datos de usuarios, subidas de archivos, llamadas a URLs externas o al endurecer una app antes de exponerla. No usar para auditar o aprobar una entrega (qa-security-agent) ni para configurar infraestructura o pipelines (devops-cloud-agent).
---

# Endurecimiento de Seguridad (Security Hardening)

QA **detecta** vulnerabilidades; esta skill las **evita** mientras se construye. La carga el especialista que implementa (normalmente `backend-agent`, también `frontend-agent` y `devops-cloud-agent`) junto con la skill de su rol y la del stack. Los ejemplos de código concretos viven en la skill `stack-*` del proyecto; aquí están los controles y cómo verificarlos.

## Pasos

1. **Modelar amenazas de la funcionalidad (10 minutos)**: antes de escribir código, lista los datos que toca, quién puede llamarla y por dónde entra la entrada. Repasa STRIDE y anota en la tarea las amenazas que aplican y el control de cada una: [threat-model.md](references/threat-model.md).
2. **Autenticación y sesiones**: contraseñas con argon2id o bcrypt (nunca hashes rápidos), comparación en tiempo constante, mensajes de error que no revelen si el usuario existe, rate limiting en login, registro y recuperación, JWT de vida corta con algoritmo fijado al verificar y refresh rotatorio, cookies `HttpOnly; Secure; SameSite`. Detalle: [checklist.md](references/checklist.md#autenticación-y-sesiones).
3. **Autorización en cada acceso**: toda consulta de un recurso filtra por el usuario o el tenant que lo posee, en el servidor. Un recurso ajeno responde `404`, no `403`. Los roles se comprueban en el servidor, nunca solo ocultando botones.
4. **Entrada no confiable**: valida con esquema estricto en la frontera (Zod, Pydantic) y rechaza campos desconocidos; consultas parametrizadas siempre; nada de entrada del usuario en `eval`, comandos de shell, rutas de archivo ni plantillas sin escapar.
5. **Superficie HTTP**: cabeceras de seguridad (CSP, HSTS, `X-Content-Type-Options`, `frame-ancestors`), CORS con lista explícita de orígenes, límites de tamaño de cuerpo, protección CSRF si la sesión va en cookies, y errores genéricos hacia el cliente.
6. **Casos especiales** cuando apliquen: subida de archivos (tipo verificado por contenido, tamaño máximo, nombre generado, almacenamiento fuera del webroot), SSRF en llamadas a URLs que da el usuario (esquema http/https, destinos permitidos, host de IP literal validado directamente tras normalizar la URL, nombres resueltos una vez y la IP validada usada para conectar manteniendo el nombre para TLS, solo unicast global, redirecciones validadas, tests con IPs literales IPv4 e IPv6 y con un nombre que resuelve a IP interna), webhooks (firma verificada). Ver [checklist.md](references/checklist.md).
7. **Secretos y dependencias**: secretos solo en variables de entorno y `.env.example` sin valores reales; ejecuta la auditoría de dependencias del ecosistema (`npm audit --omit=dev`, `pip-audit`) y corrige toda vulnerabilidad alta o crítica (actualizar, sustituir la librería o eliminar el uso afectado). Una vulnerabilidad de seguridad **nunca** se acepta como deuda técnica (`tech_debt.md` solo admite deuda media o baja sin riesgo de seguridad): si no hay parche ni alternativa, la tarea no se entrega y el `orchestrator-agent` escala la decisión al usuario. El especialista nunca decide por su cuenta que una vulnerabilidad "no aplica".
8. **Probar los controles**: cada control importante lleva un test que demuestra que bloquea (acceso a recurso ajeno → 404, primer intento por encima del límite de login → 429, campo extra → 400, cabeceras presentes). Ejecuta `./.agents/scripts/scan-secrets.sh --branch` antes del handoff.

## Checklist antes de `task.sh handoff`
- [ ] Amenazas STRIDE de la funcionalidad anotadas en la tarea, cada una con su control.
- [ ] Todo acceso a recursos filtra por propietario o tenant en el servidor; test de acceso cruzado en verde.
- [ ] Entrada validada con esquema estricto; consultas parametrizadas; sin `eval` ni shell con datos del usuario.
- [ ] Contraseñas con argon2id/bcrypt; rate limiting en autenticación; JWT con algoritmo fijado y expiración corta.
- [ ] Cabeceras de seguridad y CORS explícito configurados; errores sin trazas ni detalles internos.
- [ ] Auditoría de dependencias sin vulnerabilidades altas ni críticas (corregidas, nunca aplazadas como deuda); escaneo de secretos limpio.

## Prohibido
- Confiar en el cliente para autorizar (ocultar un botón no es un control de acceso).
- Guardar contraseñas con MD5, SHA-1, SHA-256 simples o cifrado reversible.
- Aceptar `alg: none` o no fijar el algoritmo al verificar un JWT.
- Reflejar el `Origin` recibido en CORS junto con credenciales.
- Concatenar entrada del usuario en SQL, comandos de shell, rutas de archivo o HTML.
- Desactivar un control de seguridad para que pase un test o una demo.
- Registrar una vulnerabilidad como deuda técnica (`task.sh debt`) para entregar antes: la deuda nunca es de seguridad.
