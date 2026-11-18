# Veredicto de QA: TASK-048

- **Tarea**: `TASK-048`
- **Fecha**: 2026-11-17
- **Revisor**: `devops-cloud-agent`
- **Especialista Asignado**: `qa-security-agent`
- **Resultado**: `APROBADA` (con deuda técnica MEDIA registrada)
- **Iteración**: `3/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de `feature/TASK-048-ampliar-evals-json-a-roles-de` (`d86a0e4`) frente a `main` (`0b27ffa`); diffs `git diff HEAD~1` y `git diff main...HEAD` inspeccionados. Entorno: macOS, `/bin/bash` 3.2.57 (único `bash` del `PATH`, el que usa `run_evals.sh`), `sed`/`awk` BSD, Node 24.21.0. Arnés del revisor (`run_evals.make_project` + `setup` + tag `eval-start` + solución + `task.sh commit/handoff` + checks). No se ejecutó `run_evals.py` contra Claude.

Matrices ejecutadas:
- `sol2/` (45 soluciones de la iteración 2, 3 repeticiones): **45/45** con el resultado esperado.
- `sol3/` (**36 soluciones nuevas** del revisor, 14 correctas y 22 trampas, distintas de `sol/`, `sol2/` y `all3/`; 3 repeticiones): 26/36 con el resultado esperado; las 10 discrepancias se detallan abajo (todas MEDIA o BAJA).
- `all3/` (95 soluciones de la matriz del especialista, 1 repetición): **95/95** con el resultado esperado.
- **0 FLAKY** en 81 x 3 + 95 ejecuciones de checks.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `evals.json` con >=14 evals | ✅ | 15 evals; `python3 -m json.tool` OK |
| Cobertura de los 7 roles/técnicas | ✅ | Una eval por skill; `test-scripts.sh` lo exige |
| Fixtures `100755` y README | ✅ | `test-scripts.sh` lo verifica; README describe mutante por API y reloj bloqueado |
| FAIL_INIT | ✅ | `__init` / `__init2` de las 7 evals fallan al menos un check |
| BUG-TASK-048-6 (domain, coma flotante) | ✅ | `bad_floatfloor` y `bad_bitor` fallan; `ok_bigint`, `ok_intmod`, `ok_floordiv` (nuevo) pasan |
| BUG-TASK-048-7 (async, dedupe en memoria) | ✅ | `bad_memset`, `bad_storeignored` fallan; nuevo `bad_noawaithas` (`store.has` sin `await`) falla |
| BUG-TASK-048-8 (devops, etapa final / ENV multilínea / `**/`) | ✅ | `bad_finalroot`, `bad_envcont`, `bad_envdotstar` fallan; `ok_globs`, `ok_numeric`, `ok_wget` (nuevo) pasan |
| BUG-TASK-048-9 (testing, mutación sintáctica / id constante) | ✅ | `ok_lte`, `ok_negated` pasan; `bad_constid`, `bad_offbyone` y nuevo `bad_weakbound` (límites a TTL/2 y 4·TTL) fallan |
| BUG-TASK-048-10 (frontend, lista negra / `&#60;`) | ✅ | `bad_blacklist`, `bad_svg` fallan, `ok_numeric` pasa; nuevos `bad_doubleescape`, `bad_firstitem`, `bad_deletelt` fallan |
| Observaciones BAJA de la iteración 2 | ✅ | índice en comentario, down de otro índice, `"public"."orders"`, `limit=5abc`/`2.5`, `retry` sin `attempt+1`: todos corregidos |
| `LL-016` → `LL-017` en §7 | ✅ | `GLOBAL_STATE.md` §7 (iter 3) y handoff citan `LL-017` |
| Mecanismo (a): mutante por API | ✅ con deuda | Rechaza `bad_weakbound`, `bad_offbyone`, `bad_prodchange`; no depende de la sintaxis. Falsos negativos con módulos auxiliares en `src/` (deuda TD) |
| Mecanismo (b): `node --import` con reloj/azar bloqueados | ✅ | No rompe `node:test` (Node 24); se propaga a los procesos de test; compatible con `t.mock.timers` (`ok_mockutc` pasa) y con un reloj falso propio (`ok_fakeclock` pasa); rechaza `bad_realuuid` y `bad_implicitclock`; determinista (3/3) |
| Determinismo | ✅ | 0 FLAKY |
| Portabilidad (bash 3.2, BSD) | ✅ | Todos los checks ejecutados con `/bin/bash` 3.2 y `sed`/`awk`/`grep` de macOS |
| `bash tests/test-scripts.sh` | ✅ | 308 OK, 0 fallidas |
| `bash tests/test-skills.sh` | ✅ | 36 skills sin errores |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |
| Auditoría de seguridad | ✅ | Solo cambian evals, fixtures y documentación; los checks escriben en `mktemp -d` y limpian |

## 2. Observaciones y Hallazgos

### Falsos negativos (MEDIA, sin riesgo de seguridad → deuda técnica)
Soluciones correctas y razonables que fallan un check:
1. **`testing-reloj-determinista`, `ok_isodate`**: `const T0 = new Date('2026-01-15T12:00:00Z').getTime()` en los tests falla "los tests no usan el reloj real" (el `grep` prohíbe `new Date` con argumento). La propia skill `testing-strategy` recomienda `vi.setSystemTime(new Date('2026-01-15T12:00:00Z'))`. Ahora que el check (b) bloquea `new Date()` sin argumentos, el `grep` debería prohibir solo `new Date()` vacío (mismo patrón que BUG-4 de la iteración 1).
2. **`testing-reloj-determinista`, `ok_clockmodule` / `ok_extraexport`**: si `links.js` importa un módulo propio (`src/clock.js` con `fixedClock`) que los tests también importan, o si se exporta y prueba un helper nuevo (`remainingMs`), el check (a) falla con la implementación **correcta**, porque la copia temporal solo contiene `src/links.js` generado. Arreglo: copiar `src/`, renombrar el `links.js` del agente y que el correcto/mutante haga `export * from './links.agent.js'` sobrescribiendo solo `createLink`/`isExpired`/`TTL_MS`.
3. **`devops-docker-no-root`, `ok_commentjwt`**: un comentario `# Los secretos (JWT_SECRET) se inyectan en tiempo de ejecucion` falla "sin secretos en la imagen". Arreglo: descartar las líneas `^[[:space:]]*#` antes del `grep`.
4. **`async-worker-idempotente`, `ok_transientcode`**: clasificar como transitorios solo los errores con `code` `ECONNRESET`/`ETIMEDOUT`, 429 o 5xx (como dice `async-jobs`) falla, porque el check lanza `new Error("ECONNRESET")` sin `code`, y los errores reales de Node llevan `code`. Arreglo: `Object.assign(new Error("ECONNRESET"), { code: "ECONNRESET" })`.

### Observaciones (BAJA)
- `database-indice-migracion`: un índice sin nombre (`CREATE INDEX ON orders (...)` + `DROP INDEX orders_customer_id_created_at_idx`) falla el down; un down que borra `idx_orders_cc_old` pasa con un up `idx_orders_cc` (coincidencia por subcadena; usar `grep -w`).
- `devops-docker-no-root`: `HEALTHCHECK` solo en la etapa de build pasa (no llega a la imagen final); `USER ${RUN_AS}` con `ARG RUN_AS=root` pasa; `COPY secrets.env ./.env` con un secreto en otro archivo pasa.
- `testing-reloj-determinista`: `crypto.getRandomValues` en los tests no está bloqueado ni en el `grep` (no produce inestabilidad).
- `backend-paginacion-validacion`: un comentario `// TODO ... 400` en los tests satisface "hay tests nuevos de validación" (el comportamiento se comprueba aparte).
- `async-worker-idempotente`: un backoff cuadrático pasa como "exponencial" (comprobar la razón entre intentos consecutivos).

- **Deuda Técnica**: registrada como `TD-005` (MEDIA) con `task.sh debt` para los 4 falsos negativos.
- **Lección**: `LL-017` (ya registrada; su antídoto "varias correctas que deben pasar" cubre los falsos negativos restantes).

## 3. Lo que está bien
- BUG-6 a BUG-10 y todas las BAJA de la iteración 2 están corregidos y verificados con soluciones nuevas.
- El mutante por API ya no depende de la sintaxis (`<=`, negaciones) y detecta tests débiles; el reloj bloqueado con `node --import` es efectivo, determinista y compatible con `t.mock.timers`.
- Ninguna trampa sobre el comportamiento central (redondeo, idempotencia, XSS, root en la imagen final, límite exacto) pasa ya los checks.

## 4. Conclusión y Veredicto Final
- **Estado**: `APROBADA` (3/3), sin hallazgos CRÍTICOS ni ALTOS; 4 falsos negativos MEDIA sin riesgo de seguridad aceptados como deuda técnica según la matriz de severidad.
- **Siguiente paso**: `task.sh close TASK-048 --lesson LL-017`; fusión a `main` con `--no-ff` y borrado de la rama por el especialista o el `orchestrator-agent` (no la hace QA).
