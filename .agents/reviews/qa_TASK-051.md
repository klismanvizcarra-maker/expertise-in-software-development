# Veredicto de QA: TASK-051

- **Tarea**: `TASK-051`
- **Fecha**: 2026-11-17
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `1/3` (segunda revisión, tras el rechazo por BUG-TASK-051-1)

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de `fix/TASK-051-saldar-td-005-falsos-negativos` (`cf7eff8`) frente a `main` (`dcdccc1`), diff `git diff main...HEAD`; cambio desde el rechazo: `cf7eff8`. Entorno: macOS, `/bin/bash` 3.2, Node en `/usr/local/bin`. Arnés del revisor: `run_evals.make_project` + `setup` + solución + checks de `evals.json` de la rama y de `git show main:tests/evals/evals.json`.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| **BUG-TASK-051-1 corregido** | ✅ | El check "deduplica" conserva el fallo con `code: ECONNRESET` y añade `new Error("550 mailbox unavailable")` sin `code` que no debe marcar. La trampa del rechazo (solo trata `err.code === 'ECONNRESET'` y cae a `store.add`) falla "deduplica" en la rama (y en `main`) |
| Soluciones correctas de async pasan | ✅ | Clasificar por `err.code` + DLQ para no transitorios, `err.code` + relanzar, regex del mensaje, reintentar todo, relanzar todo con reintento fuera del `try`: los 4 checks de comportamiento y la suite pasan |
| testing-reloj-determinista acepta `new Date(iso)` y módulos auxiliares | ✅ | Solución con `new Date('2026-01-01T00:00:00Z')` pasa los 5 checks (en `main` fallaba el grep); tests de `test-scripts.sh` en verde |
| Trampas de reloj siguen fallando | ✅ | `new Date(\`${new Date}\`)` falla "reloj bloqueado"; `new Date()`/`new Date)`/`Date.now` siguen en el grep |
| devops-docker-no-root ignora comentarios con JWT_SECRET | ✅ | Sin cambios desde la iteración 1 (verificado entonces); tests de `test-scripts.sh` en verde |
| Las trampas previas siguen fallando | ✅ | Matriz async (9 variantes) y reloj (3) en rama y `main`; ver observaciones para dos variantes límite |
| `make_project` no deja `skill-eval-*` huérfanos | ✅ | `env -i PATH=/nonexistent TMPDIR=<propio>` y `PATH=/usr/bin:/bin` sobre las 15 evals: 0 temporales |
| exit 126/127 = error de entorno | ✅ | Sin `node` en el `PATH`: "no pudo ejecutarse (exit 127, ¿falta una herramienta?)", no FAIL_INIT |
| `pre-edit-check.sh` con el cwd borrado sale con 2 | ✅ | `cd d && rmdir d && pre-edit-check.sh src/app.ts` → exit 2 |
| Paridad con los hooks (LL-018) | ✅ | Sección "task.sh check / pre-edit-check.sh (paridad Antigravity)" de `test-scripts.sh` en verde |
| Tests nuevos fallan con `main` | ✅ | Worktree temporal de `main` + `test-scripts.sh` de la rama: 331 OK, **7 fallidas** (las 7 esperadas); el test nuevo de la trampa también pasa en `main` porque comprueba que la trampa sigue fallando |
| `bash tests/test-scripts.sh` | ✅ | 338 OK, 0 fallidas |
| `bash tests/test-flow.sh` | ✅ | 25 OK, 0 fallidas |
| `bash tests/test-skills.sh` | ✅ | 36 skills sin errores |
| `run_evals.py --verify-baselines --jobs 4` | ✅ | 15/15 |
| `validate-state.sh` | ✅ | 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` sin hallazgos |
| Auditoría de seguridad | ✅ | Cambios solo en evals, arnés de pruebas y un script local; sin entrada de red ni secretos |

## 2. Observaciones y Hallazgos

- **Observaciones (BAJA, no bloquean)**:
  - `async-worker-idempotente`: un worker que ante un error sin `code` lo registra y sale sin DLQ, sin relanzar y sin marcar (el email se pierde en silencio) pasa todos los checks. En `main` fallaba solo porque el error transitorio no tenía `code`; la variante con regex del mensaje y el mismo descarte ya pasaba en `main`, y los criterios de la tarea de la eval no exigen DLQ para fallos permanentes. Si se quiere cubrir, exigir en el caso sin `code` que haya `deadLetter` o excepción.
  - `testing-reloj-determinista`: `new Date(performance.timeOrigin)` pasa el grep (reloj real con argumento). Es otra forma de `performance.timeOrigin`, que ya pasaba en `main`; el resultado sigue siendo determinista. Se podría añadir `performance.timeOrigin` al grep.
  - Las observaciones BAJA de la iteración 1 siguen vigentes (preexistentes en `main`).
  - Sigue en `$TMPDIR` un `skill-eval-dbg-*` ajeno a `run_evals.py`.
- **Deuda Técnica**: ninguna nueva. TD-005 y TD-006 las salda el orquestador al fusionar.
- **Lección**: `LL-017` (su antídoto se reforzó en esta rama: al cambiar una entrada simulada para aceptar una solución correcta, conservar la variante anterior como caso adicional del check y repasar la matriz completa). Cubre lo aprendido del rechazo.

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-051 --lesson LL-017`; fusión a `main` con `--no-ff` y borrado de la rama a cargo del orquestador o del especialista.
