# Veredicto de QA: TASK-033

- **Tarea**: `TASK-033`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `3/3` (rechazo 3; revisión con contexto limpio) → `BLOCKED`, escalamiento al usuario

---

## 1. Criterios de Aceptación y Controles

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skills con referencias, Checklist y Prohibido | ✅ | Leídos `SKILL.md` y `references/` de ambas |
| AGENTS.md §2.7 las lista | ✅ | `git diff main...HEAD -- AGENTS.md` |
| ≥ 2 casos de activación por skill | ✅ | Sin cambios en `tests/` en las dos últimas iteraciones; batería no relanzada |
| Descripciones sin cambios en la iteración | ✅ | `git diff HEAD~2 -- .agents/skills \| grep '^[+-]\(name\|description\):'` vacío |
| `test-skills.sh` | ✅ | 32 skills auditadas sin errores |
| `lint_descriptions.py` | ✅ | "Sin problemas" |
| `test-scripts.sh` | ✅ | 239 OK, 0 fallidas |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |
| BUG-TASK-033-5 (vía "no alcanzable → ADR") | ✅ | Eliminada en `checklist.md` y `SKILL.md`; grep de `alcanzable\|no aplica\|deuda\|ADR\|excepci` en ambas skills: solo quedan las prohibiciones. Paso 7, Checklist, Prohibido y checklist coinciden: corregir o escalar al usuario |
| Detalle: rutas de salud | ✅ | `observability` paso 7 cita `devops-cloud-agent`, `backend-agent` y `stack-angular-express-postgres` (que usan `/healthz`/`/readyz`, comprobado con grep) y la excepción de `stack-fastapi-postgres` (`/health`, `fastapi-api.md:78`) |
| Detalle: rate limit sin bloqueo indefinido | ✅ | `checklist.md:8` |
| BUG-4: Python `is_global` | ✅ | Ejecutado Python 3.9.6: `224.0.0.1`, `239.255.255.250`, `ff02::1` → `is_global=True` (multicast); `64:ff9b::7f00:1`, `64:ff9b::a9fe:a9fe`, `2002:7f00:1::`, `2002:a9fe:a9fe::` → `is_global=True` con IPv4 interna; `sixtofour` las extrae; `::ffff:127.0.0.1` → `False` y `ipv4_mapped` la extrae. Las dos afirmaciones del commit 48a7f9d son correctas |
| BUG-4: Python HTTPS (`server_hostname`, nunca `verify=False`) | ✅ | Correcto (leído) |
| BUG-4: Node `lookup` con `{ all: true }` | ✅ | Ejecutado Node 24.21: `http.Agent({ lookup })` recibe `{ all: true }` para `localhost` |
| BUG-4: Node `lookup` frente a IP literal | ❌ MEDIA | Ejecutado Node 24.21: el `lookup` propio **no se invoca** cuando el host es una IP: BUG-TASK-033-6 |
| `ipaddr.js` `range() === 'unicast'`, IMDSv2, test por nombre | ✅ | Correctos (leído; `ipaddr.js` no instalado aquí). `rfc6052`, `6to4`, `ipv4Mapped`, `teredo` y `multicast` no son `unicast`, así que se rechazan |

## 2. Bugs

### BUG-TASK-033-6 (MEDIA, seguridad) — La receta Node valida en `lookup`, que no se llama con IPs literales
- **Observado** (`checklist.md:41-42`): "La validación va en el punto de conexión" y, para Node, "función `lookup` propia en `http.Agent`/`https.Agent` o, con el `fetch` global, en `new undici.Agent({ connect: { lookup } })` […] y validar cada dirección".
- **Problema**: `net.connect` omite `lookup` cuando el host ya es una IP. Un `lookup` que rechaza todo deja pasar `http://127.0.0.1` y `http://2130706433` (el parser de URL lo convierte en `127.0.0.1`), y por tanto también `http://169.254.169.254/`, que es el ataque SSRF más habitual. `undici` conecta con `net`/`tls.connect`, así que tiene el mismo hueco (leído, no ejecutado: `undici` no está instalado aquí).
- **Reproducción** (Node 24.21, script en el scratchpad de QA): servidor en `127.0.0.1` y `http.Agent({ lookup: () => error })`. Resultado: `http://127.0.0.1:<p>/` → 200, `http://2130706433:<p>/` → 200, `http://localhost:<p>/` → bloqueado; `lookup` se llama 1 vez.
- **Impacto**: quien siga la receta de Node tal como está escrita queda expuesto con las IPs literales. La lista de tests de `checklist.md:48` lo detectaría, pero la receta dirige la validación a un punto que no se ejecuta en el caso principal. Es un control de seguridad, así que no se puede aceptar como deuda.
- **Origen**: el texto recomendado por QA en la iteración 2 tenía este mismo hueco. El especialista lo aplicó fielmente.
- **Corrección recomendada** (una frase en la viñeta de Node): "`lookup` no se llama si el host es una IP literal: valida también el host literal (`net.isIP`) con las mismas reglas antes de conectar, o comprueba `socket.remoteAddress` al conectar. `request-filtering-agent` cubre los dos casos (para clientes con `http(s).Agent`, no para el `fetch` global)."

## 3. Observaciones BAJA (no bloqueantes)
- `checklist.md:44`: `ipaddress` de Python no normaliza `2130706433` ni `0177.0.0.1`, los **rechaza** (ejecutado). No es un fallo, porque se valida la IP ya resuelta por `getaddrinfo`, que sí está normalizada. Convendría decir "valida la IP resuelta, no el texto de la URL".
- `request-filtering-agent` aparece justo después de la línea de `fetch`/undici, pero es un `http(s).Agent`: no sirve como `dispatcher` del `fetch` global.
- `task.sh brain search rebinding` (y `DNS`) no encuentra LL-011: `brain_search` busca en el problema y el antídoto, no en la causa. Eso viene del script y queda fuera del diff. Si la lección mencionara "SSRF / DNS rebinding" en el problema o el antídoto, sería más fácil de encontrar.

## 4. Lección
- No se cierra la tarea. LL-010 y LL-011 están registradas y son adecuadas. Al resolver el bloqueo conviene ampliar LL-011: "un hook de resolución (`lookup`) no es el punto de conexión: comprobar con un test qué entradas lo saltan (IP literal)".

## 5. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA` (3/3) → `BLOCKED`.
- **Siguiente paso**: el `orchestrator-agent` emite el informe de escalamiento al usuario. Todo lo demás de la tarea está verificado. El único pendiente es la frase de BUG-TASK-033-6. Opciones: (a) desbloquear con `task.sh move TASK-033 IN_PROGRESS`, aplicar esa frase y hacer una revisión corta; (b) que el usuario acepte el texto actual sabiendo el hueco (no recomendado: es un control de seguridad).
