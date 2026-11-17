# Evals de Calidad de Salida

La batería de `tests/triggers/` mide **qué skill se carga**. Estas evals miden **si lo que hace la skill es correcto**: cada una prepara un proyecto real, ejecuta la skill en Claude Code con permisos de escritura y comprueba el estado final con comandos deterministas (tablero, tests, git, `BRAIN.md`), sin un LLM juez.

| Eval | Skill | Qué demuestra |
| :--- | :--- | :--- |
| `qa-reject-idor` | `qa-review` | Detecta un IDOR que los tests no cubren, rechaza (1/3), documenta el bug y no toca el código |
| `qa-approve-ok` | `qa-review` | Aprueba (DONE) una entrega correcta: evita un QA que lo rechaza todo |
| `bugfix-threshold` | `bugfix` | Corrige un error de umbral con test de regresión, rama `fix/`, commit `fix(TASK-XXX)` y entrega a QA |
| `nueva-tarea-reset-password` | `nueva-tarea` | Descompone en ≥ 2 tareas con agentes reales, backend + frontend y criterios verificables |
| `aprender-stripe` | `aprender` | Registra la lección con causa raíz y solución, no solo el síntoma |
| `handoff-verificacion` | `handoff` | Pasa a `IN_REVIEW_QA`, genera `handoff_TASK-003.json` con entregables/comandos y deja registro en `GLOBAL_STATE.md` |
| `refactor-caracterizacion` | `refactor` | Extrae lógica duplicada preservando el comportamiento público y los tests en rama `refactor/` |
| `security-hardening-sql-idor` | `security-hardening` | Sustituye SQL concatenado e IDOR por consulta parametrizada vinculada a `authUserId` |
| `backend-paginacion-validacion` | `backend-agent` | Paginación por cursor con límite por defecto, validación de `limit` con `400 VALIDATION_ERROR`, errores sin trazas y entrega a QA |
| `frontend-cuatro-estados` | `frontend-agent` | Estados loading (`aria-busy`), vacío, error (`role="alert"` y Reintentar) y éxito, con el texto escapado contra XSS |
| `database-indice-migracion` | `database-architect-agent` | Migración nueva con índice compuesto y su `down`, sin editar la migración existente |
| `domain-prorrateo-centimos` | `domain-logic-agent` | Prorrateo en céntimos enteros redondeado a favor del cliente, días inválidos rechazados, función pura y matriz de casos límite |
| `devops-docker-no-root` | `devops-cloud-agent` | Dockerfile multi-etapa no root con `HEALTHCHECK` a `/healthz`, sin secretos, `.env.example` y `.dockerignore` |
| `testing-reloj-determinista` | `testing-strategy` | Reloj e id inyectables, límite exacto de expiración probado, sin reloj real ni esperas aleatorias, 20 ejecuciones seguidas en verde |
| `async-worker-idempotente` | `async-jobs` | Consumidor idempotente por `msg.id`, reintento con backoff exponencial con jitter acotado y DLQ tras `maxAttempts` |

## Ejecutar
```bash
python3 tests/evals/run_evals.py                          # todas (~15 sesiones)
python3 tests/evals/run_evals.py --only qa-reject-idor    # una
python3 tests/evals/run_evals.py --keep                   # conserva los proyectos temporales para inspeccionarlos
```
- Requisitos: los mismos que `run_claude.py` (CLI con sesión iniciada) y Node.js para los fixtures.
- Cada eval corre en un proyecto temporal con `Edit`, `Write` y `Bash` permitidos; este repositorio no se modifica.
- Gasta uso de tu cuenta: límite por eval con `--budget` (1,5 USD por defecto). Resultados en `tests/evals/results/` (ignorado por git).
- Son de un solo intento: una eval que falla de forma aislada puede ser variabilidad del modelo. Repite antes de cambiar una skill.

## Añadir una eval
En `evals.json`: `setup` (bash; fixtures en `$FIXTURES`), `prompt` y `checks` (`[nombre, bash]`, exit 0 = cumple). En setup y checks están `$T` (task.sh), `col <TASK-ID> <n>` y el tag git `eval-start` (estado tras el setup). Antes de gastar, comprueba que los checks **fallan** en el estado inicial (*FAIL_INIT*: tras el setup, al menos un check falla); si pasan sin que la skill haga nada, no miden nada. Comprueba también que una solución correcta los hace pasar todos. Los fixtures llevan permisos `755` (lo verifica `tests/test-scripts.sh`).
