# Veredicto de QA: TASK-051

- **Tarea**: `TASK-051`
- **Fecha**: 2026-11-17
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de `fix/TASK-051-saldar-td-005-falsos-negativos` (`be2459c`) frente a `main` (`dcdccc1`), diff `git diff main...HEAD`. Entorno: macOS, `/bin/bash` 3.2, Node en `/usr/local/bin`. Arnés del revisor: `run_evals.make_project` + `setup` + solución + checks extraídos de `evals.json` (rama y `git show main:tests/evals/evals.json` para comparar).

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| testing-reloj-determinista acepta `new Date(iso)` en tests | ✅ | `new Date('2026-…')`, `new Date(0)` y `new Date(` multilínea pasan los 5 checks |
| … y módulos auxiliares en `src/` / exports nuevos | ✅ | `links.js` que reexporta de `expiry.js` pasa el mutante; test de `test-scripts.sh` con `src/clock.js` y `describeTtl` pasa |
| Trampas de reloj siguen fallando | ✅ | `new Date(Date.now())`, `+new Date` (grep + reloj bloqueado), `new Date(...[])`, `new Date/**/()`, `Reflect.construct(Date, [])` (reloj bloqueado) fallan |
| devops-docker-no-root ignora comentarios con JWT_SECRET | ✅ | Comentario normal e indentado pasan; `ENV JWT_SECRET`, `ARG jwt_secret`, `ENV ... # coment.`, `#` en continuación + `ENV` multilínea fallan |
| async-worker-idempotente con `code: ECONNRESET` y clasificación por `err.code` | ✅ | Clasificar por `err.code`, por regex del mensaje o reintentar todo pasan |
| **Las trampas previas siguen fallando / ninguna trampa pasa de nuevo** | ❌ MEDIA | **BUG-TASK-051-1** (abajo): un worker que traga un fallo sin `code` y marca el mensaje como enviado pasa todos los checks en la rama y fallaba en `main` |
| `make_project` no deja `skill-eval-*` huérfanos | ✅ | `env -i PATH=/nonexistent TMPDIR=<propio>` sobre las 15 evals: 0 temporales |
| exit 126/127 = error de entorno, no FAIL_INIT | ✅ | eval con comando inexistente → `exit 127`; script no ejecutable → `exit 126`; check `false` sigue contando como FAIL_INIT; sin `node` en el `PATH`, 9 evals se reportan como error de entorno |
| `pre-edit-check.sh` con el cwd borrado sale con 2 | ✅ | `cd d && rmdir d && pre-edit-check.sh src/app.ts` → exit 2 |
| Paridad con los hooks en el caso normal (LL-018) | ✅ | Tests de paridad (raíz, subdirectorio, `..`) de `test-scripts.sh` en verde |
| Tests nuevos fallan con `main` | ✅ | Worktree de `main` + `test-scripts.sh` nuevo: 330 OK, **7 fallidas** (las 7 esperadas) |
| `bash tests/test-scripts.sh` | ✅ | 337 OK, 0 fallidas |
| `bash tests/test-flow.sh` | ✅ | 25 OK, 0 fallidas |
| `bash tests/test-skills.sh` | ✅ | 36 skills sin errores |
| `run_evals.py --verify-baselines --jobs 4` | ✅ | 15/15 |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |

## 2. Bugs

### BUG-TASK-051-1 (MEDIA) — async-worker-idempotente acepta ahora un worker que pierde emails (reincidencia de LL-017)

- **Componente**: DevOps (evals)
- **Descripción**: al dar `code: "ECONNRESET"` a **todos** los errores simulados, ningún check ejercita ya un fallo de envío sin `code` (permanente o inesperado). Un worker que solo trata como fallo los errores con `code` transitorio y, ante cualquier otro error, lo registra y sigue hasta `store.add(msg.id)` marca como enviado un email que no se envió y pasa todos los checks. En `main` esa misma solución fallaba "deduplica en el store…" (el error sin `code` la obligaba a no marcar). Incumple el criterio de la tarea de la eval ("un fallo de envio no marca el mensaje como procesado") y el criterio de TASK-051 "las trampas previas siguen fallando".
- **Pasos para reproducir**: `src/worker.js` con el `computeBackoff` correcto y
  ```js
  export async function handleMessage(msg, deps) {
    if (await deps.store.has(msg.id)) return;
    try { await deps.mailer.send(msg.to, msg.template); } catch (err) {
      if (err.code === 'ECONNRESET') { if (msg.attempt >= deps.maxAttempts) { deps.queue.deadLetter(msg, err); return; }
        deps.queue.retry({ ...msg, attempt: msg.attempt + 1 }, computeBackoff(msg.attempt)); return; }
      console.error('fallo permanente', err.message);   // ni DLQ ni relanzar
    }
    await deps.store.add(msg.id);                        // marca como enviado tras un fallo
  }
  ```
  Ejecutar los checks de `async-worker-idempotente` con `run_evals.make_project` + `setup`.
- **Observado**: rama → deduplica PASS, fallo transitorio PASS, backoff PASS, suite PASS. `main` → deduplica FAIL, fallo transitorio FAIL.
- **Esperado**: "deduplica en el store" falla: un fallo de envío, tenga o no `code`, no marca el mensaje.
- **Recomendación**: en el check "deduplica", mantener el fallo transitorio con `code` y añadir un segundo caso con un error sin `code` (p. ej. `new Error("550 mailbox unavailable")`) tras el que `store.has(id)` debe seguir siendo falso (DLQ o relanzar, ambos válidos). Añadir esta trampa a la matriz y a `test-scripts.sh` (debe fallar), y comprobar que las tres soluciones correctas de arriba siguen pasando.

## 3. Observaciones (BAJA, no bloquean; preexistentes en `main`)
- `testing-reloj-determinista`: unos tests que comprueban el texto de la fuente (`readFileSync('src/links.js').includes('>=')`) en vez del límite pasan el mutante; ya pasaba en `main`.
- `testing-reloj-determinista`: tests que usan un `export default` del módulo fallan el mutante (`export *` no reexporta `default`); ya fallaban en `main`.
- `devops-docker-no-root`: un `#JWT_SECRET=...` dentro de un heredoc (`COPY <<EOF`) seguido de un `sed` que quita el `#` evitaría el check; requiere ofuscación deliberada.
- `run_evals.py`: la detección de exit 127 solo ve el código final del check; en checks compuestos (`(… node …) || exit 1`) la falta de la herramienta se sigue viendo como exit 1. En la práctica el primer check con `node` de cada eval la detecta.
- Queda en `$TMPDIR` un `skill-eval-dbg-*` ajeno a `run_evals.py` (prefijo de depuración, probablemente del especialista).

**Siguiente paso**: el especialista retoma con `task.sh start TASK-051`.
