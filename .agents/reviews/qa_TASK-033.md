# Veredicto de QA: TASK-033

- **Tarea**: `TASK-033`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3` (rechazo 1)

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| Skills `security-hardening` y `observability` con referencias, Checklist y Prohibido | ✅ | Leídos `SKILL.md` y `references/` de ambas; enlaces relativos y anclas resuelven |
| Delimitadas frente a `qa-security-agent` y `devops-cloud-agent` | ❌ | Descripciones delimitadas en ambos sentidos, pero el contenido de `observability` contradice a `devops-cloud-agent`, `backend-agent` y `stack-angular-express-postgres` en los endpoints de salud (BUG-TASK-033-2) |
| AGENTS.md §2.7 las lista | ✅ | `git diff main...HEAD -- AGENTS.md` |
| ≥ 2 casos de activación por skill | ✅ | `sec-01..03`, `obs-01..02` en `tests/triggers/cases.json` (74 casos) |
| `test-skills.sh` y `lint_descriptions.py` al 100 % | ✅ | 32 skills sin errores; lint "Sin problemas" |
| Casos nuevos ejecutados contra Claude real | ✅ | `tests/triggers/results/2026-11-11_2113-claude.json`: 5/5 pass (3 ideales; `sec-02` y `obs-01` cargaron `nueva-tarea`, aceptable por AGENTS §2.3) |
| Batería de scripts | ✅ | `bash tests/test-scripts.sh` → 239 OK, 0 fallidas |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` limpio |
| Coherencia con gobernanza (deuda nunca de seguridad) | ❌ ALTA | BUG-TASK-033-1 |
| Corrección técnica de los consejos de SSRF | ❌ MEDIA | BUG-TASK-033-3 |

## 2. Bugs

### BUG-TASK-033-1 (ALTA) — La skill ordena registrar vulnerabilidades altas como deuda técnica
- **Observado**: `security-hardening/SKILL.md` paso 7: "corrige o documenta como deuda (`task.sh debt`) las vulnerabilidades altas sin parche". `references/checklist.md` §Secretos y dependencias: "Vulnerabilidades altas: ... registrar deuda ... (nunca deuda de seguridad crítica)".
- **Esperado**: `BRAIN.md` ("Nunca de seguridad"), `.agents/brain/tech_debt.md` regla 1 ("Solo severidad Media o Baja ... prohibido aceptar deuda técnica que comprometa la seguridad (OWASP)"), `qa-review` ("deuda MEDIA sin riesgo de seguridad"), `qa-security-agent` ("nunca si compromete seguridad"), `aprender` (prohibido deuda que vulnere OWASP). Una dependencia vulnerable es OWASP A06. La frase "nunca deuda de seguridad crítica" implica que la de severidad alta sí se admite.
- **Recomendación**: una vulnerabilidad alta se corrige (actualizar, sustituir la librería, mitigar el camino vulnerable) o bloquea la entrega y se escala. Si se demuestra que no es explotable en este uso, eso se documenta como excepción justificada en la tarea o en un ADR (no como `TD-XXX`), y el veredicto lo decide QA. Alinear paso 7, checklist y el ítem de Checklist "sin vulnerabilidades altas sin tratar".

### BUG-TASK-033-2 (MEDIA) — Nombres de endpoints de salud incompatibles con las skills vecinas
- **Observado**: `observability` (SKILL paso 7, Checklist, `logs-metrics-traces.md` §Health, `alerts-runbook.md` "`/ready` falla") usa `GET /health` y `GET /ready`.
- **Esperado**: `devops-cloud-agent` (pasos 6–7 y checklist), `backend-agent` y `stack-angular-express-postgres/references/api-express.md` usan `/healthz` y `/readyz`. `devops-cloud-agent` ahora dice "cargar también observability", así que un agente recibe dos convenciones a la vez y las sondas/alertas apuntarán a rutas que no existen.
- **Recomendación**: usar `/healthz` y `/readyz` (o decir explícitamente que la ruta concreta la fija la skill `stack-*`, como hace `stack-fastapi-postgres` con `/health`).

### BUG-TASK-033-3 (MEDIA) — El control SSRF descrito es eludible
- **Observado**: `checklist.md` §SSRF: "resolver el DNS y bloquear IPs privadas ...". No habla de DNS rebinding ni de TOCTOU: si se valida la IP resuelta y luego la librería HTTP vuelve a resolver el nombre, un atacante devuelve una IP pública en la validación y `169.254.169.254` en la conexión.
- **Esperado**: un control SSRF correcto incluye: conectar a la IP ya validada (fijarla con un `lookup`/agente personalizado o validar en el socket), volver a validar en cada salto de redirección (o no seguir redirecciones), cubrir IPv6 (`::1`, `fc00::/7`, `fe80::/10`, IPv4 mapeada `::ffff:0:0/96`), `0.0.0.0/8`, `100.64.0.0/10` y codificaciones decimales/octales, solo `http`/`https`, y limitar el tamaño de la respuesta además del timeout. En la nube, IMDSv2 como defensa en profundidad.
- **Recomendación**: ampliar la sección SSRF con esos puntos y añadir al paso 8 un test (host que resuelve a IP interna → bloqueado; redirección a `169.254.169.254` → bloqueada).

## 3. Observaciones (BAJA, no bloqueantes; corregir de paso)
- **Rate limit**: "5–10 intentos" y "el intento 11 devuelve 429" no casan con un límite de 5; `stack-angular-express-postgres/auth-jwt.md` prueba el 6.º intento. Mejor "el intento N+1 devuelve 429". El límite por cuenta debe evitar bloquear a la víctima (DoS por bloqueo de cuenta).
- **`frame-ancestors 'none'` o la CSP equivalente**: `frame-ancestors` ya es una directiva CSP; lo equivalente para navegadores antiguos es `X-Frame-Options: DENY`.
- **CORS**: el riesgo real habitual no es `*` con credenciales (los navegadores lo rechazan) sino reflejar el `Origin` recibido con `Access-Control-Allow-Credentials: true`; decirlo en Prohibido.
- **Archivos**: falta SVG (XSS) y servir con `Content-Disposition: attachment` + `nosniff`; límite de píxeles ante bombas de descompresión.
- **Webhooks**: comparación en tiempo constante y tolerancia de marca de tiempo contra replays.
- **bcrypt**: limitar la contraseña a 72 bytes (bcrypt trunca) o preferir argon2id; parámetros de partida de argon2id (OWASP: m=19 MiB, t=2, p=1).
- **pino `redact`**: trabaja con rutas exactas (`req.headers.authorization`, `*.password`), no con nombres de clave a cualquier profundidad; la lista tal como está sugiere lo contrario.
- **`traceparent` como `request_id`**: `traceparent` es contexto de traza (trace-id + parent-id), no un ID de petición; usar el `trace_id` que extrae el propagador de OpenTelemetry y no tratar la cabecera entera como `request_id`. Un `X-Request-Id` entrante desde clientes públicos debe validarse (longitud, caracteres).
- **Muestreo**: "por cabeza 10 % más todas las trazas con error" no es posible solo con muestreo por cabeza (se decide antes de saber si hay error); requiere muestreo por cola (tail sampling en el OpenTelemetry Collector). Usar `ParentBased` para respetar la decisión del llamante.
- **Readiness**: advertir que hacer depender `/ready` de dependencias compartidas puede sacar de servicio todas las réplicas a la vez; `/health` nunca toca la base de datos (ya está bien dicho).
- **Alertas**: mencionar alertas por burn rate en ventanas múltiples (p. ej. 1 h y 5 min) y un mínimo de peticiones para que el % de error no salte con poco tráfico.
- **Propiedad (§8)**: los runbooks van a `docs/runbooks/` (propiedad de `docs-architecture-agent`); indicar quién los escribe.

## 4. Valoración de la batería de activación
`sec-02` y `obs-01` cargaron `nueva-tarea`: es aceptable porque piden trabajo nuevo sin tarea y AGENTS §2.3 manda el punto de entrada; la skill de técnica llega luego por §2.7. Ningún `forbid` se activó y `sec-03` delimitó bien frente a `qa-review`. Limitación: esos dos casos no prueban que la descripción de la skill gane por sí sola; si se quiere medirlo, añadir casos con una tarea ya en curso.

## 5. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Lección**: pendiente; al cerrar tras este rechazo será obligatoria (`--lesson`).
- **Siguiente paso**: `docs-architecture-agent` retoma con `task.sh start TASK-033`, corrige BUG-TASK-033-1..3 (y las observaciones BAJA que pueda) y vuelve a entregar.
