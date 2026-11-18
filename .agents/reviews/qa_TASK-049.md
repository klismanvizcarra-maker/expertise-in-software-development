# Veredicto de QA: TASK-049

- **Tarea**: `TASK-049`
- **Fecha**: 2026-11-17
- **Revisor**: qa-security-agent
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `task.sh check` / `pre-edit-check.sh` unifica require-active-task + brain-context | ❌ MEDIA | Desde la raíz: paridad exacta en 49 rutas × 2 estados (sin tarea / con tarea y 5 lecciones), 0 diferencias. **Desde un subdirectorio falla**: las rutas relativas se resuelven contra la raíz, no contra el directorio actual (BUG-TASK-049-1) |
| Códigos de salida 0/1/2, sin modificar archivos | ✅ | Sin rutas → 1; bloqueada → 2; `git status` vacío tras varias ejecuciones; worktree y ejecución desde fuera con ruta absoluta al script correctos; `CLAUDE_PROJECT_DIR` ignorado a favor del proyecto del script (correcto para Antigravity y worktrees) |
| AGENTS.md §2.4/§7.4 y las 8 skills de rol lo documentan | ✅ | Leído; ayuda de `task.sh` lista `check` |
| `run_evals.py --verify-baselines` verifica FAIL_INIT sin LLM | ✅ | 15/15 en 4,7 s con `claude` fuera del PATH y un `claude` falso centinela en PATH y `CLAUDE_BIN`: nunca invocado; `--only` válido/inexistente (exit 2), `--file` con eval que siempre pasa y con setup roto → exit 1 (tests de test-scripts.sh); sin temporales nuevos tras una ejecución correcta |
| Integrado en test-scripts.sh y library.yml | ✅ | `bash tests/test-scripts.sh` → 323 OK, 0 fallidas; CI usa setup-node 24 y python3; las evals solo requieren node y python3 |
| QUICKSTART.md y CHANGELOG.md actualizados | ✅ | Leído (323 comprobaciones coincide con lo ejecutado) |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → sin hallazgos |
| Batería de pruebas | ✅ | test-scripts 323/323, test-flow 25/25, test-skills 36 skills sin errores, validate-state sin errores |

## 2. Bug Report

- **ID del Defecto**: `BUG-TASK-049-1`
- **Severidad**: `MEDIA` (control de gobierno que falla en abierto)
- **Componente**: DevOps (`.agents/scripts/pre-edit-check.sh`)

**Descripción**: `pre-edit-check.sh` pasa la ruta tal cual al hook, y el hook resuelve las rutas relativas contra la raíz del proyecto (correcto en Claude Code, que siempre envía rutas absolutas). Ejecutado desde un subdirectorio, `task.sh check` evalúa otro archivo distinto del que el agente va a editar.

**Pasos** (proyecto temporal de init-project.sh, sin tarea IN_PROGRESS):
1. `cd docs && ../.agents/scripts/task.sh check ../src/app.ts` → `✅ Se puede editar`, exit 0 (se resuelve a `<raíz>/../src/app.ts`, fuera del proyecto).
2. El hook con la ruta absoluta que enviaría Claude Code (`<raíz>/src/app.ts`) → exit 2 (bloqueado).
3. Con tarea activa y lección con ámbito `src/db/*.ts`: `cd src && ../.agents/scripts/task.sh check db/orders.ts` → "Sin lecciones específicas"; con ruta absoluta muestra LL-001. En un monorepo (`apps/api`, `apps/web`) las lecciones de `apps/api/**` no aparecen si el agente trabaja desde `apps/api`.

**Esperado**: misma decisión y mismas lecciones que Claude Code para el archivo real.

**Recomendación**: en `pre-edit-check.sh`, convertir las rutas relativas en absolutas contra `$PWD` antes de construir el JSON (como hace Claude Code); mantener vacías/no válidas tal cual. Añadir a test-scripts.sh los casos de los pasos 1 y 3, y aclarar en la ayuda/AGENTS.md que las rutas relativas se toman del directorio actual.

## 3. Observaciones (BAJA, no bloqueantes)

- Sin `python3`, `check` sale con 2 incluso con `MAESTRO_ALLOW_UNTRACKED=1` o sin `GLOBAL_STATE.md`, donde el hook deja pasar (falla en cerrado; documentarlo o igualarlo).
- `run_evals.py` `verify_baseline`: `make_project` está fuera del `try`; si `init-project.sh` falla se produce una traza sin capturar y quedan directorios `skill-eval-*` en el temporal. Además, un check que falla por falta de herramienta (p. ej. sin node) cuenta como FAIL_INIT válido.
- `.agents/skills/aprender/SKILL.md` línea 22 aún dirige Antigravity a `task.sh brain for`; podría citar `task.sh check`.

- **Lección**: Sin lección (rechazo en iteración 1; se registrará al cerrar).

## 4. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Siguiente paso**: `devops-cloud-agent` retoma con `task.sh start TASK-049`.
