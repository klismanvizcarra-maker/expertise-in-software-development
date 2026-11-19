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
| `domain-prorrateo-centimos` | `domain-logic-agent` | Prorrateo en céntimos enteros redondeado siempre hacia abajo (a favor del cliente; distingue `floor` de `round` y `trunc`), días inválidos rechazados, función pura y al menos 3 tests de límite |
| `devops-docker-no-root` | `devops-cloud-agent` | Dockerfile multi-etapa no root con `HEALTHCHECK` a `/healthz`, sin secretos, `.env.example` y `.dockerignore` |
| `testing-reloj-determinista` | `testing-strategy` | Reloj e id inyectables con la firma de la tarea; los tests pasan con una implementación correcta y fallan con una mutante (`>` en vez de `>=`, que conserva los módulos y exports propios de `src/`), siguen pasando con `Date.now`, `new Date()` sin argumentos, `Math.random` y `crypto` bloqueados (una fecha fija `new Date('…')` está permitida), y 20 ejecuciones seguidas en verde |
| `async-worker-idempotente` | `async-jobs` | Consumidor idempotente por `msg.id` que no marca como enviado un mensaje cuyo envío falló, reintento con backoff exponencial con jitter y tope, y DLQ tras `maxAttempts` |
| `research-benchmark-report` | `research-agent` | Genera benchmark comparativo con fuentes fechadas, pros/contras y propuesta con MVP MoSCoW en `docs/research/` sin inventar métricas ni copiar texto de referencia |
| `plan-maestro-fases` | `crear-plan` | Elabora `docs/plan/plan-maestro.md` con arquitectura Mermaid, fases con criterios de salida, cronograma Gantt y registra solo las tareas de la Fase 1 tras aprobación |
| `adoptar-proyecto-brownfield` | `adoptar-proyecto` | Incorpora gobierno en proyecto existente: detecta stack, mapea componentes en `GLOBAL_STATE.md` sin sobreescribir código y planifica la primera tarea incremental |

## Ejecutar
```bash
python3 tests/evals/run_evals.py                          # todas (~15 sesiones)
python3 tests/evals/run_evals.py --only qa-reject-idor    # una
python3 tests/evals/run_evals.py --keep                   # conserva los proyectos temporales para inspeccionarlos
python3 tests/evals/run_evals.py --verify-baselines       # sin LLM ni coste: cada eval debe fallar tras el setup (FAIL_INIT)
```
- Requisitos: los mismos que `run_claude.py` (CLI con sesión iniciada) y Node.js para los fixtures.
- Cada eval corre en un proyecto temporal con `Edit`, `Write` y `Bash` permitidos; este repositorio no se modifica.
- Gasta uso de tu cuenta: límite por eval con `--budget` (1,5 USD por defecto). Resultados en `tests/evals/results/` (ignorado por git).
- Son de un solo intento: una eval que falla de forma aislada puede ser variabilidad del modelo. Repite antes de cambiar una skill.

## Añadir una eval
En `evals.json`: `setup` (bash; fixtures en `$FIXTURES`), `prompt` y `checks` (`[nombre, bash]`, exit 0 = cumple). En setup y checks están `$T` (task.sh), `col <TASK-ID> <n>` y el tag git `eval-start` (estado tras el setup). Antes de gastar, comprueba que los checks **fallan** en el estado inicial (*FAIL_INIT*: tras el setup, al menos un check falla); si pasan sin que la skill haga nada, no miden nada. Comprueba también que varias soluciones correctas los hacen pasar todos y que las trampas típicas (escapar solo la primera aparición, marcar como procesado antes de enviar, redondear con `round`, mantener el reloj real...) hacen fallar al menos uno. Prefiere checks de comportamiento a `grep` sobre el código: ejecutar el código con entradas que separen las implementaciones candidatas, sustituir la implementación por una mutante con la misma API y ver que los tests fallan, o ejecutar los tests con el reloj y la aleatoriedad del sistema bloqueados (`node --import`). Si un check sale con `127`/`126` (falta una herramienta), `--verify-baselines` lo trata como error del entorno, no como FAIL_INIT. Los fixtures llevan permisos `755` (lo verifica `tests/test-scripts.sh`).
