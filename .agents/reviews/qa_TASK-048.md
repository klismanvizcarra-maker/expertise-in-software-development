# Veredicto de QA: TASK-048

- **Tarea**: `TASK-048`
- **Fecha**: 2026-11-17
- **Revisor**: `devops-cloud-agent`
- **Especialista Asignado**: `qa-security-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `2/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de `feature/TASK-048-ampliar-evals-json-a-roles-de` (`7162ac6`) frente a `main` (`0b27ffa`); diffs `git diff HEAD~1` y `git diff main...HEAD` inspeccionados. Entorno: macOS, `/bin/bash` 3.2.57 (único `bash` del `PATH`), `sed` BSD. Cada eval se probó con el arnés de la iteración 1 (`run_evals.make_project` + `setup` + tag `eval-start` + solución + `task.sh commit/handoff` + checks) con **39 soluciones nuevas escritas por el revisor** (distintas de las de la ronda 1 y de las del especialista), cada check repetido 3 veces. También se re-ejecutó la matriz de 50 soluciones del especialista (1 repetición): 50/50 con el resultado esperado. No se ejecutó `run_evals.py` contra Claude.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `evals.json` con >=14 evals | ✅ | 15 evals; `python3 -m json.tool` OK |
| Cobertura de los 7 roles/técnicas | ✅ | Una eval por skill; `test-scripts.sh` lo exige |
| Fixtures `100755` | ✅ | `test-scripts.sh` lo verifica |
| README actualizado | ✅ | Tabla y sección "Añadir una eval" con matriz de soluciones |
| FAIL_INIT | ✅ | Las 7 evals nuevas fallan al menos un check tras el setup (`__init`) |
| BUG-TASK-048-1..5 de la iteración 1 | ✅ | Las 41 soluciones de la ronda 1 dan el resultado esperado (salvo las 3 que contradecían la regla ahora explícita) |
| Evals deterministas **que miden el comportamiento** | ❌ ALTA | Con soluciones nuevas: 6 trampas relevantes pasan los 5-6 checks y 3 soluciones correctas fallan. Ver BUG-TASK-048-6..10 |
| Determinismo | ✅ | 39 soluciones x 3 repeticiones: 0 FLAKY |
| Portabilidad (bash 3.2, `sed -i.bak -E` BSD) | ✅ | Check de mutación ejecutado con `sed` BSD; `mktemp -d`, `cp -R`, `awk` portables |
| `bash tests/test-scripts.sh` | ✅ | 308 OK, 0 fallidas |
| `bash tests/test-skills.sh` | ✅ | 36 skills sin errores |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |

### Cambios de criterio de los fixtures (valoración)
- `proration.sh` ("siempre hacia abajo", 666,67 → 666 y -666,67 → -667): **legítimo**. Elimina la contradicción de la iteración 1 (redondear hacia -infinito favorece al cliente en ambos sentidos) y la regla queda en la tarea que lee el agente. Pero la tarea dice además "sin aritmética de coma flotante" y el check no lo mide (BUG-6).
- `flaky_clock.sh` (firma `createLink(userId, { now, newId } = {})`, `isExpired(link, { now } = {})`): **legítimo**. Coherente con `testing-strategy` (reloj inyectable) y con "sin cambiar el comportamiento de producción"; fijar la firma es lo que permite un check de comportamiento. El check de mutación, en cambio, es demasiado estrecho sintácticamente (BUG-9).
- `email_worker.sh` (un fallo no marca el mensaje; backoff con tope): **legítimo** y alineado con `async-jobs`. Pero "idempotente" en `async-jobs` implica estado durable (store), no memoria del proceso, y el check no lo distingue (BUG-7).

### Matriz de soluciones nuevas (3 repeticiones; ✅ = resultado esperado)

| Eval | Correctas (deben pasar todo) | Trampas / incorrectas (deben fallar alguno) |
| :--- | :--- | :--- |
| backend-paginacion-validacion | ✅ cursor = id plano con `findIndex`; ✅ `ValidationError` + cursor hex | ✅ `nextCursor` no nulo en la última página → falla; ⚠️ `parseInt` acepta `"5abc"` → pasa (BAJA) |
| frontend-cuatro-estados | ✅ helper `h()` + `textNode` con comillas simples y `<svg>` en el botón; ❌ escape con entidades numéricas `&#60;` → **falla** | ✅ quitar etiquetas → falla; ❌ lista negra de etiquetas `/<(\/?)(b\|img\|script)\b/` → **pasa todo** (y deja `<svg onload>` sin escapar) |
| database-indice-migracion | ✅ `CONCURRENTLY IF NOT EXISTS` con nombres entre comillas; ✅ multilínea + `INCLUDE`; ⚠️ `ON "public"."orders"` → falla (BAJA) | ✅ dos índices simples → falla; ⚠️ índice solo en un comentario `-- TODO: CREATE INDEX ...` → pasa (BAJA); ⚠️ down que borra otro índice → pasa (BAJA) |
| domain-prorrateo-centimos | ✅ BigInt con división entera hacia -inf; ✅ enteros con módulo positivo | ✅ `\| 0` → falla; ✅ trunc hacia cero en abonos → falla; ❌ `Math.floor((n-o) * (d/p))` (coma flotante) → **pasa todo**, `prorate(0,90,7,10)` da 62 en vez de 63 |
| devops-docker-no-root | ✅ distroless + `USER 1000:1000` + HEALTHCHECK exec multilínea; ❌ `.dockerignore` con `**/.env` y `**/node_modules` → **falla** | ✅ `ENV JWT_SECRET=${JWT_SECRET}` → falla; ❌ `USER node` solo en la etapa de build y etapa final como root → **pasa todo**; ❌ `ENV NODE_ENV=production \` + `JWT_SECRET=otro-secreto-fijo` en la línea siguiente → **pasa todo**; ⚠️ `.dockerignore` solo con `.env.*` (no excluye `.env`) → pasa; ⚠️ `RUN echo "JWT_SECRET=..." > .env` → pasa (BAJA) |
| testing-reloj-determinista | ✅ `!(now() < link.expiresAt)` con `describe/it` tabular; ❌ `return link.expiresAt <= now();` → **falla la mutación** | ✅ límites a ±1 s (no el instante exacto) → falla la mutación; ❌ `newId` por defecto constante `() => 'token'` → **pasa todo**; ⚠️ reloj real implícito (`createLink('u1')` sin inyectar + alias `globalThis['Da'+'te']`) → pasa (BAJA) |
| async-worker-idempotente | ✅ sin lanzar, devuelve estado, tope 30 min; ✅ relanza el error tras `retry`/`deadLetter`, tope 5 min | ✅ jitter que crece sin tope → falla; ❌ dedupe en un `Set` del módulo (ignora `store`) → **pasa todo**; ❌ consulta `store.has` pero nunca llama a `store.add` → **pasa todo**; ⚠️ `retry(msg)` sin incrementar `attempt` → pasa (BAJA, depende del contrato de la cola) |

---

## 2. Bugs

### BUG-TASK-048-6 (ALTA) — `domain-prorrateo-centimos` acepta coma flotante + `Math.floor`
- **Reproducir**: `return Math.floor((newCents - oldCents) * (daysLeft / daysInPeriod));` (el arreglo mínimo sobre el fixture) → los 5 checks pasan. `prorate(0, 90, 7, 10)` devuelve 62 (correcto: 63); 4021 combinaciones con `|diff| <= 5000` y `daysInPeriod <= 31` difieren.
- **Causa**: los valores del check (`20/30`, `10/30`, `1/7`) no separan `floor(x*(d/p))` de `floor(x*d/p)`; la tarea dice "sin aritmética de coma flotante en el resultado" y nada lo comprueba (LL-017: elegir valores que separen las implementaciones candidatas).
- **Esperado**: añadir `prorate(0,90,7,10) === 63` y `prorate(90,0,7,10) === -63` (o `prorate(0,170,7,10) === 119`).

### BUG-TASK-048-7 (ALTA) — `async-worker-idempotente` acepta deduplicar en memoria del proceso
- **Reproducir**: `const processed = new Set()` a nivel de módulo, sin usar `store` → los 5 checks pasan; también pasa una variante que consulta `store.has` pero nunca escribe `store.add`. Tras un reinicio o con dos réplicas del worker, el email se reenvía.
- **Causa**: el check usa el mismo proceso y el mismo `msg.id` para las tres llamadas; nunca observa el `store`.
- **Esperado**: (a) con un `store` precargado (`has: async id => id === 'm1'`) no se envía nada; (b) tras un envío con éxito, `seen.has('m1') === true`. `async-jobs` lo pide ("no la dispares directo en memoria"; idempotente por clave verificada en servidor).

### BUG-TASK-048-8 (MEDIA) — `devops-docker-no-root`: root en la etapa final, `ENV` multilínea y `.dockerignore` con `**/`
- **Falso positivo 1**: `USER node` en la etapa de build y ningún `USER` en la etapa final → pasa "usuario no root" (el check toma el último `USER` del archivo, no el de la última etapa). Esperado: `awk '/^[[:space:]]*FROM[[:space:]]/{u=""} /^[[:space:]]*USER[[:space:]]/{u=$2} END{print u}'`.
- **Falso positivo 2**: `ENV NODE_ENV=production \` + `    JWT_SECRET=otro-secreto-fijo` → pasa "sin secretos". La unión de líneas con `\` se aplicó al HEALTHCHECK pero no al check de secretos.
- **Falso negativo**: `**/.env` y `**/node_modules` (patrón habitual de `.dockerignore`) → falla. Y `.env.*` solo (que no excluye `.env`) se acepta. Esperado: `^(\*\*/)?\.env\*?$` y `^(\*\*/)?/?node_modules/?$`.

### BUG-TASK-048-9 (MEDIA) — `testing-reloj-determinista`: la mutación depende de la sintaxis y el id por defecto no se comprueba
- **Falso negativo**: `return link.expiresAt <= now();` (equivalente exacto y con tests correctos del instante límite) → falla "los tests detectan la mutación": no hay `>=` ni `<` seguido de algo distinto de `=`, y el check sale con `exit 1` sin mutar nada.
- **Esperado**: mutar por comportamiento, no por texto: sustituir en la copia temporal `src/links.js` por una implementación mutante con la misma API (`now() > link.expiresAt`) y exigir que los tests del agente fallen. Como mínimo, tratar también `<=` → `<`.
- **Falso positivo (BAJA-MEDIA)**: `newId = () => 'token'` por defecto pasa; la tarea pide "un id aleatorio por defecto". Esperado: `createLink('u1').token !== createLink('u1').token`.

### BUG-TASK-048-10 (MEDIA) — `frontend-cuatro-estados`: el XSS se comprueba con una lista fija de etiquetas y una única forma de escapar
- **Falso positivo**: escapar solo `<b`, `<img`, `<script` (lista negra) pasa los 5 checks y deja `<svg onload=alert(1)>` sin escapar.
- **Falso negativo**: escapar con entidades numéricas (`&#60;`, lo que hacen librerías como `he`) falla porque se cuentan solo `&lt;`.
- **Esperado**: contar `&lt;|&#0*60;|&#x0*3c;` (sin distinguir mayúsculas) y comprobar de forma genérica que el título no aporta ningún `<`: número de `<` con el título malicioso = número de `<` con un título inocuo, usando además una etiqueta fuera de cualquier lista (`<svg/onload=...>`, `<x-y>`).

### Observaciones (BAJA, no bloquean por sí solas)
- `database-indice-migracion`: un índice dentro de un comentario SQL pasa (quitar líneas `--` antes del grep); un down que borra otro índice pasa (comparar el nombre); `ON "public"."orders"` falla.
- `backend-paginacion-validacion`: `parseInt` acepta `limit="5abc"`; añadir `"5abc"` o `"1.5"` a los valores inválidos.
- `async-worker-idempotente`: `queue.retry(msg, d)` sin incrementar `attempt` pasa; aclarar en el contrato quién incrementa `attempt`.
- `GLOBAL_STATE.md` §7 (iter 2) y el handoff citan la lección como `LL-016`; la registrada es `LL-017` (`task.sh brain search tramposas`). `LL-016` es de TASK-050.

## 3. Lo que está bien
- Los cinco bugs de la iteración 1 están corregidos y la matriz del especialista se reproduce (50/50).
- Los tres cambios de criterio son legítimos: fijan en la tarea la regla y la firma que el check comprueba, coherentes con `domain-logic-agent`, `testing-strategy` y `async-jobs`.
- El check de mutación es una mejora real (detecta límites a ±1 s), portable con `sed` BSD, y el conteo con `--test-reporter=tap` acepta matrices tabulares.
- 0 FLAKY en 117 ejecuciones de checks sobre soluciones nuevas.

## 4. Conclusión y Veredicto Final
- **Estado**: `RECHAZADA` (2/3).
- **Siguiente paso**: el especialista retoma con `task.sh start TASK-048`, corrige BUG-6..10 añadiendo estas soluciones (`/private/tmp/claude-501/-Users-klismanvizcarra-Desktop-PROYECTOS-SKILL--MAESTRO/93d4f4ac-7cb6-4e0f-9815-84fb011827e5/scratchpad/qa048/sol2/`, temporales; los casos clave están descritos en cada bug) a su matriz, y corrige la referencia a `LL-017`. Queda **una** iteración antes de `BLOCKED`.
- **Lección**: N/A en el rechazo; al cerrar, `LL-017` (ya registrada) cubre el caso.
