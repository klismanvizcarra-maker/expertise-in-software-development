# Registro de Deuda Técnica Aceptada (Technical Debt Register)

> **Propósito**: Documentar soluciones temporales (*workarounds*) o compromisos técnicos aceptados durante el desarrollo para evitar que se conviertan en defectos ocultos o bugs silenciosos a largo plazo.

---

## 1. Tablero de Deuda Técnica

| ID | Tarea Vinculada | Fecha | Módulo | Descripción de la Deuda | Solución Temporal Aplicada | Acción Definitiva Pendiente | Prioridad |
| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |
| `TD-001` | `TASK-029` | 2026-11-10 | General | task.sh commit acepta trailers multilinea: la validacion no rechaza saltos de linea y rompe el bloque de trailers | Workaround temporal | Rechazar trailers con salto de linea (anclar el patron y comprobar una sola linea) y anadir test en tests/test-scripts.sh | `SALDADA` |
| `TD-002` | `TASK-030` | 2026-11-10 | General | task.sh learn: sin python3 y en locale C el detector de duplicados queda desactivado en silencio (el sed y/// de norm_text falla con caracteres multibyte y devuelve vacio) | Workaround temporal | Hacer el camino sin python3 de norm_text independiente del locale (o degradar a tr sin quitar tildes si sed falla) y anadir test con PATH sin python3 | `SALDADA` |
| `TD-003` | `TASK-037` | 2026-11-11 | General | brain-context.sh marca la leccion como vista aunque otro hook bloquee la edicion y el registro de sesion no es atomico ni se limpia | Workaround temporal | Verificar en Claude Code si additionalContext llega cuando require-active-task bloquea; si no, no anotar la leccion sin tarea activa; registro atomico y limpieza de archivos antiguos | `SALDADA` |
| `TD-004` | `TASK-038` | 2026-11-11 | General | Pendiente documental de TD-004: documentar en qa-review que citar LL-XXX garantiza el registro (comparacion de causa raiz/plurales y filtro de close resueltos en TASK-039) | Workaround temporal | Documentar en qa-review/SKILL.md que citar LL-XXX garantiza el registro y saldar en TASK-041 | `SALDADA` |
| `TD-005` | `TASK-048` | 2026-11-17 | General | Evals con falsos negativos: testing-reloj-determinista rechaza new Date(iso) en tests (lo recomienda testing-strategy) y modulos auxiliares en src/ o exports nuevos en el check de mutacion; devops-docker-no-root rechaza un comentario que menciona JWT_SECRET; async-worker-idempotente lanza Error sin code y rechaza clasificar transitorios por err.code | Workaround temporal | grep de tests solo contra new Date() vacio; mutante con copia de src/ y export * sobre el modulo del agente; ignorar comentarios # en el check de secretos; error simulado con code ECONNRESET; anadir esas soluciones a la matriz | `SALDADA` |
| `TD-006` | `TASK-049` | 2026-11-17 | General | run_evals.py make_project deja directorios skill-eval-* huerfanos en el temporal si git o init-project.sh fallan tras mkdtemp (verificado con PATH minimo: 15 por ejecucion); ademas un check que falla por falta de herramienta (p. ej. sin node) cuenta como FAIL_INIT valido | Workaround temporal | Limpiar el temporal dentro de make_project ante cualquier excepcion (try/except con rmtree y re-raise) y anadir un test con PATH minimo que cuente los skill-eval-* antes y despues; distinguir exit 127 de un fallo real del check | `SALDADA` |

---

## 2. Criterios de Aceptación de Deuda Técnica
1. **Solo severidad Media o Baja**: Queda terminantemente prohibido aceptar deuda técnica que comprometa la seguridad (OWASP), vulnere la privacidad de datos o cause crashes del servidor.
2. **Tarea vinculada obligatoria**: Toda deuda técnica debe estar asociada a una tarea formal (`TASK-XXX`).
3. **Revisión periódica**: El `orchestrator-agent` debe revisar este tablero al inicio de cada nueva fase del proyecto para planificar tareas de refactorización y saneamiento.
