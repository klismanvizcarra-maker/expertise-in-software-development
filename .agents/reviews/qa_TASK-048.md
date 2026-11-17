# Veredicto de QA: TASK-048

- **Tarea**: `TASK-048`
- **Fecha**: 2026-11-17
- **Revisor**: `devops-cloud-agent`
- **Especialista Asignado**: `qa-security-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de la rama `feature/TASK-048-ampliar-evals-json-a-roles-de` (`d3dea7c`) frente a `main` (`0b27ffa`). Entorno: macOS, `/bin/bash` 3.2.57 (el único `bash` del `PATH`), node v24.21.0. Cada eval nueva se probó en proyectos temporales creados con `run_evals.make_project` + `run_evals.sh` (setup, tag `eval-start`, solución, `task.sh commit` + `task.sh handoff`, checks), con **soluciones escritas por el revisor** (no las de referencia) y cada check ejecutado 3 veces. No se ejecutó `run_evals.py` contra Claude.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `evals.json` pasa de 8 a >=14 evals | ✅ | 15 evals; `python3 -m json.tool` OK; ids únicos |
| Cubre backend, frontend, database, domain, devops, testing-strategy y async-jobs | ✅ | Una eval por skill; `test-scripts.sh` lo exige |
| Fixtures `100755` | ✅ | `ls -l tests/evals/fixtures/` → todos `-rwxr-xr-x`; `test-scripts.sh` lo exige |
| README actualizado | ✅ | Tabla con las 7 evals y nota FAIL_INIT |
| FAIL_INIT (las 15 fallan tras el setup) | ✅ | 15/15 con al menos un check fallando |
| Evals **deterministas** que miden el comportamiento | ❌ ALTA | 3 evals aceptan soluciones incorrectas (falsos positivos) y 4 rechazan soluciones correctas (falsos negativos). Ver bugs |
| Determinismo de los checks | ✅ | 3 repeticiones por check sin resultados FLAKY |
| Portabilidad (bash 3.2, solo node y git) | ✅ | Todo ejecutado con `/bin/bash` 3.2.57; solo usan node, git, grep, awk, tr, seq |
| `bash tests/test-scripts.sh` | ✅ | 308 OK, 0 fallidas |
| `bash tests/test-skills.sh` | ✅ | 36 skills sin errores |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → sin hallazgos |

### Matriz de soluciones probadas (checks de comportamiento; `IN_REVIEW_QA` pasó en todas)

| Eval | Correctas (deben pasar) | Incorrectas (deben fallar) |
| :--- | :--- | :--- |
| backend-paginacion-validacion | ✅ cursor base64 + error anidado; ✅ cursor id + código plano | ✅ ignora cursor → falla; ✅ `stack` en el body → falla; ✅ clamp sin 400 → falla |
| frontend-cuatro-estados | ✅ estándar; ❌ atributos con comillas simples + icono `<span>` dentro del botón → falla | ✅ escapado parcial (`&`, `"`) → falla; ✅ sin botón/empty vacío → falla; ❌ `replace('<','&lt;')` (solo primera ocurrencia) → **pasa todo** |
| database-indice-migracion | ✅ `CONCURRENTLY ... (customer_id, created_at DESC)`; ❌ `ON public.orders USING btree (customer_id, created_at)` → falla | ✅ edita 0001 → falla; ✅ 0002 + toca 0001 → falla; ✅ orden de columnas inverso → falla; ✅ down sin DROP → falla |
| domain-prorrateo-centimos | ❌ `Math.floor` (abono -334, a favor del cliente) → falla; ❌ matriz con `for (...) test(...)` → falla el conteo de tests | ❌ `Math.round` → **pasa todo**; ❌ coma flotante `x*(d/p)` + `Math.trunc` → **pasa todo**; ✅ sin validar días → falla |
| devops-docker-no-root | ✅ multi-etapa `USER node`; ❌ estilo de la propia skill (`.env*` en `.dockerignore`, `HEALTHCHECK` en dos líneas con `\`) → falla | ✅ una etapa → falla; ✅ `ARG JWT_SECRET` + `JWT_SECRET=$...` → falla; ❌ `ENV JWT_SECRET otro-secreto` (sintaxis con espacio) → **pasa todo**; ❌ `USER 0:0` al final → **pasa todo** |
| testing-reloj-determinista | ✅ reloj/id inyectados; ✅ `t.mock.timers` | ✅ sigue con `Date.now()` → falla; ✅ borra los tests flaky → falla; ❌ `new Date().getTime()` + comentario "limite" → **pasa todo** |
| async-worker-idempotente | ✅ marca tras enviar, cap 5 min; ❌ cap de 15 min (acotado) → falla | ❌ marca el id **antes** de enviar (pierde el email al fallar) → **pasa todo**; ✅ sin jitter → falla; ✅ sin tope → falla |

---

## 2. Bugs

### BUG-TASK-048-1 (ALTA) — `domain-prorrateo-centimos` no distingue el redondeo y contradice "a favor del cliente"
- **Reproducir**: `prorate` con `Math.round((n-o)*(d/p))` o `Math.trunc` en coma flotante → los 5 checks pasan.
- **Causa**: los tres casos del check (`10/30`, `1/3`) tienen fracción `.33`, donde `round`, `trunc`, `floor/ceil` coinciden. Además el check exige `prorate(2000,1000,10,30) === -333`: eso abona **menos** al cliente (redondea hacia cero), mientras que el criterio dice "a favor del cliente (... hacia arriba si abona)". Una solución que abona -334 (lo que favorece al cliente) falla.
- **Esperado**: casos con fracción >= .5 en ambos signos (p. ej. `prorate(0,1000,2,3)` = 666.67 → 666 con floor y 667 con round; `prorate(1000,0,2,3)` = -666.67 → -667 o -666 según el sentido acordado) y desambiguar en el criterio el sentido del abono (magnitud) y alinear el check.
- **Extra (MEDIA)**: el conteo `^\+.*(test|it)\(` >= 3 rechaza una matriz tabular con un solo `test(` dentro de un `for`, que es precisamente el patrón de "matriz de casos límite".

### BUG-TASK-048-2 (ALTA) — `async-worker-idempotente` acepta marcar el id antes de enviar
- **Reproducir**: `await store.add(msg.id)` antes de `mailer.send` → los 5 checks pasan. Ese worker pierde el email: tras el primer fallo, el reintento ve `has(id) === true` y no reenvía.
- **Causa**: el check de reintento usa `store: { has: async () => false }`, así que nunca observa el efecto de `add`.
- **Esperado**: un check con store real (Set) en el que el primer `send` falla y el segundo funciona, y se exija que el reintento envíe (o que `store.has(id)` sea false tras el fallo).
- **Extra (MEDIA)**: `capped <= 10*60*1000` es un umbral arbitrario que no está en el criterio de la tarea ni en la skill `async-jobs`; un tope de 15 min, igualmente acotado, falla. Declararlo en el criterio o relajar el check (p. ej. finito y `computeBackoff(50) === computeBackoff(60)`).

### BUG-TASK-048-3 (ALTA) — `testing-reloj-determinista`: el check principal no mide y hay una evasión trivial
- **Reproducir**: estado inicial → el check "reloj e id inyectables" ya **pasa** (el código original contiene `Date.now`, que cumple `/now|clock/i`). Una solución que no inyecta nada y usa `new Date().getTime()` en el test con la palabra "limite" en un comentario pasa los 5 checks.
- **Esperado**: el check de inyección debe ser de comportamiento (p. ej. aceptar `createLink('u1', { now: () => 1000 })` o `{ clock }` y comprobar `expiresAt === 1000 + TTL_MS`, o fijar la firma en el criterio de la tarea), y la búsqueda de reloj real debe cubrir `new Date(` y `performance.now`. La `const fixed` del check no se usa.

### BUG-TASK-048-4 (MEDIA) — `devops-docker-no-root` rechaza el estilo que prescribe su propia skill y deja pasar evasiones
- **Falsos negativos**: `.dockerignore` con `.env*` (lo que pide `devops-cloud-agent/SKILL.md:18`) falla `grep -qxE '\.env'`; `HEALTHCHECK --interval=30s \` con `CMD ... /healthz` en la línea siguiente falla.
- **Falsos positivos**: `ENV JWT_SECRET otro-secreto` (sintaxis sin `=`) pasa "sin secretos"; `USER 0:0` o `USER root:root` como último `USER` pasa "no root".
- **Esperado**: aceptar `.env*`/`.env`, unir líneas con `\` antes de buscar `/healthz`, detectar `JWT_SECRET` en `ENV`/`ARG` con valor por cualquier sintaxis, y comparar solo la parte de usuario antes de `:`.

### BUG-TASK-048-5 (BAJA) — Acoplamientos menores
- `frontend-cuatro-estados`: exige comillas dobles en `aria-busy="true"`/`role="alert"` y que el texto "Reintentar" vaya justo tras `<button ...>` (un icono `<span>` dentro lo rompe). El check de XSS usa un único `<` y `>`: un `replace('<', '&lt;')` sin regex global pasa (usar dos etiquetas, p. ej. `<b>x</b><img ...>`).
- `database-indice-migracion`: `ON orders USING btree (customer_id, created_at)` o `ON public.orders` + `USING` falla; permitir `(USING[[:space:]]+[a-z]+[[:space:]]*)?` antes del paréntesis.

## 3. Lo que está bien
- `backend-paginacion-validacion`: mide de verdad (cursor ignorado, trazas, falta de 400 detectados; dos implementaciones correctas distintas pasan).
- `database-indice-migracion`: detecta la edición de 0001, el orden de columnas y el down vacío.
- Cobertura, permisos, README, CHANGELOG y `test-scripts.sh` correctos.

## 4. Siguiente paso
`task.sh reject TASK-048` (1/3). El especialista retoma con `task.sh start TASK-048`, endurece los checks de BUG-1..4 (BUG-5 opcional) y añade al verificador casos de soluciones tramposas además de la de referencia.

- **Lección**: N/A (rechazo; al cerrar será obligatoria por haber tenido un rechazo).
