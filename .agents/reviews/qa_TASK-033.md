# Veredicto de QA: TASK-033

- **Tarea**: `TASK-033`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `2/3` (rechazo 2; revisión con contexto limpio)

---

## 1. Criterios de Aceptación y Controles

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skills con referencias, Checklist y Prohibido | ✅ | Leídos `SKILL.md` y `references/` de ambas |
| Enlaces relativos y anclas | ✅ | Script de comprobación: 5/5 enlaces resuelven, ancla `#autenticación-y-sesiones` y `#logs` existen |
| AGENTS.md §2.7 las lista | ✅ | `git diff main...HEAD -- AGENTS.md` |
| ≥ 2 casos de activación por skill | ✅ | Sin cambios en esta iteración (`git diff HEAD~1 --stat -- tests/` vacío); batería no relanzada |
| Descripciones sin cambios en la iteración | ✅ | `git diff HEAD~1 -- .agents/skills` sin líneas `name:`/`description:` |
| `test-skills.sh` | ✅ | 32 skills auditadas sin errores |
| `lint_descriptions.py` | ✅ | "Sin problemas" |
| `test-scripts.sh` | ✅ | 239 OK, 0 fallidas |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |
| BUG-TASK-033-2 (rutas de salud) | ✅ | grep `/(health\|ready)\b` sin `z` en `.agents/skills`, `AGENTS.md`, plantillas y QUICKSTART: solo quedan `stack-fastapi-postgres/references/fastapi-api.md:78` y `templates/handoff_template.json:22`, ambos preexistentes en `main` y fuera del diff |
| BUG-TASK-033-1 (vulnerabilidad como deuda) | ⚠️ parcial | Paso 7, Checklist, Prohibido y checklist ya no admiten deuda. Queda una vía nueva sin control: BUG-TASK-033-5 |
| BUG-TASK-033-3 (SSRF) | ⚠️ parcial | Esquemas, rangos, normalización, redirecciones y límites añadidos. La indicación concreta contra DNS rebinding es imprecisa y no hay test del caso por nombre: BUG-TASK-033-4 |
| Observaciones BAJA de la iteración 1 | ✅ | Todas aplicadas y correctas (ver §3) |

## 2. Bugs

### BUG-TASK-033-4 (MEDIA) — La receta anti-DNS-rebinding de `checklist.md` §SSRF es imprecisa y no se prueba
- **Observado**: "En Node se fija con la opción `lookup` del agente HTTP; en Python, conectando a la IP con la cabecera `Host` original." La lista de tests solo usa IPs literales y una redirección.
- **Problemas**:
  1. **Python + HTTPS**: pedir `https://<ip>/` con `Host: <nombre>` hace que el SNI y la verificación del certificado se hagan contra la IP: falla con *hostname mismatch* y empuja a poner `verify=False`. Hay que conectar a la IP validada **manteniendo el nombre original para SNI y verificación** (p. ej. urllib3 con `server_hostname`/`assert_hostname`, un transporte de httpx con resolución propia, o validar en el `connect` del socket).
  2. **Node + `fetch`**: la opción `lookup` de `http.Agent`/`https.Agent` no aplica al `fetch` global (undici); ahí se usa `new undici.Agent({ connect: { lookup } })` como `dispatcher`. Además, desde Node 20 (`autoSelectFamily`), `lookup` puede llamarse con `{ all: true }` y debe devolver un array: la función propia debe respetar las opciones recibidas y validar **todas** las direcciones antes de devolverlas. (Con `https.Agent` + `lookup` el SNI y el certificado sí usan el nombre original: esa parte es correcta.)
  3. **Rangos**: la lista enumera rangos pero deja fuera, entre otros, `224.0.0.0/4`, `240.0.0.0/4`, `198.18.0.0/15`, `192.0.0.0/24`, NAT64 `64:ff9b::/96` y 6to4 `2002::/16` (que incrustan IPv4 internas). Más robusto: permitir solo unicast global (`ipaddress.ip_address(x).is_global` en Python, normalizando antes las IPv4 mapeadas; `ipaddr.js` `range() === 'unicast'` en Node) y dejar la lista como ejemplo.
  4. **Test**: falta el caso que motivó BUG-3: un **nombre** que resuelve a IP interna (`http://localhost/`, o un resolvedor simulado que devuelve `127.0.0.1` / `169.254.169.254`) debe ser rechazado; y la validación debe estar en el punto de conexión, no antes.
- **Recomendación**: reescribir la viñeta así (o equivalente): "Resolver una vez, validar todas las IPs y conectar a esa IP conservando el nombre para SNI y verificación TLS. Node: `lookup` propio en `http(s).Agent` o, con `fetch`, en `undici.Agent({ connect: { lookup } })`, respetando `options.all`; o una librería probada (`request-filtering-agent`). Python: transporte/adaptador que fije la IP y mantenga `server_hostname`; nunca `verify=False`." Sustituir la lista cerrada por "solo unicast global" con la lista como ejemplo y añadir el test por nombre. Opcional: IMDSv2 como defensa en profundidad.

### BUG-TASK-033-5 (MEDIA) — La vía "no alcanzable → ADR" no tiene quién la valide y contradice el Checklist
- **Observado**: `checklist.md` §Secretos y dependencias: "Si un análisis demuestra que el código vulnerable no es alcanzable en este proyecto, se documenta como ADR en `GLOBAL_STATE.md` §6 con la evidencia, no como deuda."
- **Problemas**:
  1. No dice quién acepta esa conclusión: el propio especialista puede escribir el ADR y entregar con la vulnerabilidad presente. Es una aceptación de riesgo, la misma puerta que BUG-1 cerró, con otro nombre.
  2. Contradice el Checklist de `SKILL.md` ("sin vulnerabilidades altas ni críticas (corregidas, nunca aplazadas)") y el paso 7, que no mencionan la excepción; ni `qa-security-agent` ni `qa-review` saben que existe.
  3. Propiedad (§8 / `docs-architecture-agent`): los ADR van a `docs/adr/ADR-NNN-*.md` con fila en §6, no los escribe cualquier especialista directamente en `GLOBAL_STATE.md`.
- **Recomendación**: o eliminar la vía, o acotarla: la excepción "no alcanzable" la **verifica QA** en el veredicto y la **aprueba el usuario** vía `orchestrator-agent`; queda como ADR (`docs/adr/` + fila §6) con el identificador (CVE/GHSA), la evidencia, y una fecha de revisión; mencionarla en el paso 7 y en el Checklist de `SKILL.md` ("…o excepción no alcanzable aprobada por QA y el usuario").

## 3. Observaciones BAJA (no bloqueantes)
- Revisadas y correctas: argon2id 19 MiB/t=2/p=1 (mínimo OWASP vigente), bcrypt 72 bytes, rate limit "N+1 → 429", `frame-ancestors` frente a `X-Frame-Options`, CORS reflejado con credenciales, SVG, `Content-Disposition: attachment` + `nosniff`, bombas de descompresión, webhooks en tiempo constante con tolerancia de 5 min, `redact` de pino por rutas, `request_id` frente a `traceparent`, `ParentBased(TraceIdRatioBased)` + tail sampling en el Collector, `/readyz` y dependencias compartidas, burn rate 1h/5m y 6h/30m (pares del SRE Workbook), mínimo de tráfico, autoría de runbooks.
- `observability` paso 7 dice "las mismas rutas que usan `devops-cloud-agent` y las skills `stack-*`", pero `stack-fastapi-postgres` usa `/health`. La cláusula "si el stack define otras, mandan las del stack" lo salva; mejor decir "y `stack-angular-express-postgres`".
- El rate limit "por cuenta" no advierte del bloqueo de la cuenta de la víctima (observación de la iteración 1 no recogida); p. ej. ralentizar o pedir CAPTCHA en lugar de bloquear.
- Preexistente, fuera del diff: `templates/handoff_template.json` usa `/api/v1/health` como ejemplo; valorar alinearlo en otra tarea.

## 4. Lección
- No se cierra en esta iteración. `LL-010` (`task.sh brain search skill gobierno`) es adecuada para BUG-1/2. Al cierre conviene ampliarla, o añadir otra, con lo de esta iteración: "en una skill de seguridad, cada receta concreta (API, opción, librería) se comprueba con la documentación del lenguaje y su variante HTTPS/`fetch`, y cada control lleva el test del ataque que motiva el control".

## 5. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA` (2/3). El siguiente rechazo bloquea la tarea y obliga a escalar al usuario.
- **Siguiente paso**: `docs-architecture-agent` retoma con `task.sh start TASK-033` y corrige BUG-TASK-033-4 y BUG-TASK-033-5 con los textos recomendados; nada más está pendiente.
