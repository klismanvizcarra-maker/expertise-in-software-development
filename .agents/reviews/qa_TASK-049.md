# Veredicto de QA: TASK-049

- **Tarea**: `TASK-049`
- **Fecha**: 2026-11-17
- **Revisor**: qa-security-agent
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `2/3` (un rechazo previo: BUG-TASK-049-1)

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| BUG-TASK-049-1: rutas relativas desde subdirectorios | ✅ | Script de paridad en proyecto temporal de init-project.sh (ruta con espacios, 5 lecciones con ámbito): 15 directorios de trabajo (raíz, `docs`, `src`, `src/db`, `dir con espacio`, `dir con espacio/sub`, symlinks `linksrc`, `linksrc/db`, `docs/srclink`, `docs/srclink/db`, `docs/apilink`, `apps/api`, `apps/api/src`, `specs`, `.agents/scripts`) × 54 rutas (relativas con `..`, absolutas, exentas, fuera del proyecto, vía symlink, vacía, espacio, `\n`, `\r`, unicode, `~`, `-x.ts`). `task.sh check` comparado con los hooks recibiendo "directorio actual + ruta" absoluta: sin tarea 810 casos, 0 diferencias (526 bloqueos, 284 permitidos); con tarea IN_PROGRESS 810 casos, 0 diferencias en código de salida y en IDs de lecciones |
| `task.sh check` / `pre-edit-check.sh` unifica require-active-task + brain-context | ✅ | Lecciones correctas desde subdirectorios y symlinks (p. ej. desde `linksrc`: `db/orders.ts` → LL-001, `app.ts` → LL-005; desde `docs/apilink`: LL-003) |
| Códigos 0/1/2, sin modificar archivos | ✅ | Igual que iteración 1; `git status` del proyecto temporal solo muestra el cambio de `task.sh start` |
| AGENTS.md §2.4/§7.4 y skills de rol lo documentan | ✅ | Leído; §2.4 aclara que las relativas se toman del directorio actual; `aprender` cita `task.sh check` |
| `run_evals.py --verify-baselines` (FAIL_INIT sin LLM) | ✅ | 15/15 en 4,7 s; sin temporales nuevos tras una ejecución correcta |
| Integrado en test-scripts.sh y library.yml | ✅ | `bash tests/test-scripts.sh` → 326 OK, 0 fallidas (3 tests nuevos desde subdirectorios) |
| QUICKSTART.md y CHANGELOG.md | ✅ | 326 comprobaciones coincide con lo ejecutado |
| BAJA sin python3 (`MAESTRO_ALLOW_UNTRACKED=1` / sin GLOBAL_STATE.md) | ✅ | PATH sin python3: allow=0 → check 2 / hook 2; allow=1 → 0 / 0; sin GLOBAL_STATE.md → 0 / 0 |
| BAJA `verify_baseline` con init-project.sh fallando | ⚠️ BAJA | PATH mínimo sin bash y con bash sin coreutils: exit 1, 0 trazas sin capturar, mensaje "no se pudo preparar el proyecto". **Pero** quedan 15 `skill-eval-*` huérfanos por ejecución (mkdtemp dentro de `make_project` antes del fallo; `project` sigue en `None`). Registrado como TD-006 |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → sin hallazgos |
| Batería | ✅ | test-flow 25/25, test-skills 36 sin errores, validate-state sin errores |

## 2. Observaciones (BAJA, no bloqueantes)

- **TD-006**: el arreglo de `run_evals.py` evita la traza pero no los temporales huérfanos cuando falla `git` o `init-project.sh` (el §7 del especialista afirma "sin trazas ni temporales": la segunda parte no se cumple). Sigue sin distinguirse un check que falla por herramienta ausente (exit 127) de un FAIL_INIT real.
- Si el directorio actual se ha borrado, `hook_json` falla (`os.getcwd`), el JSON queda vacío y `check ../src/app.ts` sale 0 sin tarea (falla en abierto). Caso exótico; conviene que `pre-edit-check.sh` salga con 2 si no puede construir el JSON.

- **Lección**: `LL-018` (envoltorio que reenvía rutas a un hook con otra base que el cliente real).

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-049 --lesson LL-018`; fusión a `main` por el orquestador.
