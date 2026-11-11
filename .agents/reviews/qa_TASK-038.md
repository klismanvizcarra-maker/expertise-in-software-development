# Veredicto de QA · TASK-038 · iteración 1/3 → RECHAZADA

- **Tarea**: `TASK-038` — Cerebro: captura obligatoria de lecciones, reincidencias, doctor y stats
- **Asignada a**: devops-cloud-agent
- **Revisor**: `qa-security-agent`
- **Fecha**: 2026-11-11
- **Rama**: `feature/TASK-038-cerebro-captura-obligatoria-de` (commit `7166d92`)

## 1. Verificación independiente (ejecutado por QA)

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `bash tests/test-scripts.sh` | ✅ | 234 OK, 0 fallidas |
| `bash tests/test-flow.sh` / `tests/test-skills.sh` | ✅ | 24 OK / 28 skills sin errores |
| `validate-state.sh` / `scan-secrets.sh --branch` | ✅ | 0 errores, cerebro sano / sin hallazgos |
| `close` exige lección si la tarea **tuvo rechazos** | ❌ MEDIA | BUG-TASK-038-2: tras 3 rechazos, `BLOCKED` y `move` (0/3) cierra sin lección |
| `close` exige lección en correcciones (Bug:/Fix:/Hotfix:, rama fix/) | ✅ | Matriz 4 descripciones × 3 historiales × 9 opciones (108 cierres) en proyecto temporal |
| Controles previos de `close` (estado, veredicto, revisor) actúan antes y nada se escribe si falla | ✅ | GLOBAL_STATE.md idéntico tras cada fallo |
| `reject` avisa y cuenta la reincidencia | ⚠️ | Funciona, pero BUG-TASK-038-1 (aborta el rechazo) y BUG-TASK-038-4 (falsos positivos) |
| `brain doctor` (columnas, duplicados, vacíos) en `validate-state.sh` | ✅ | Códigos de salida correctos; esquema antiguo = aviso; proyectos de main, pre-036 y pre-035 actualizados con `--update` siguen pudiendo hacer commit con hooks; +~60 ms |
| `brain stats` | ✅ | Correcto con 0 lecciones, sin tech_debt.md, con reincidencias de lecciones retiradas |
| Lock | ✅ | doctor/stats/search/for/validate-state/commit no esperan con el lock tomado; sync/scope sí |
| Portabilidad | ✅ | /bin/bash 3.2.57, awk BSD 20200816, `LC_ALL=C`, PATH sin python3 |
| Documentación coherente con el código | ❌ BAJA | BUG-TASK-038-5 |

## 2. Defectos

### BUG-TASK-038-1 (MEDIA) — un fallo al escribir `recurrences.md` impide el rechazo
- **Reproducir**: lección activa "Listado de pedidos sin paginacion..."; tarea en `IN_REVIEW_QA`; `chmod 444 .agents/brain/recurrences.md` (o `chmod 555 .agents/brain` sin el archivo, o que sea un directorio); `task.sh reject TASK-X "pedidos sin paginacion"`.
- **Observado**: `brain-lib.sh: line 421: .../recurrences.md: Permission denied`, rc=1, la tarea sigue en `IN_REVIEW_QA` con el contador sin incrementar y sin fila en el historial. El veto de QA queda bloqueado por un archivo de métricas (el tablero no queda a medias: no se escribe nada).
- **Esperado**: el rechazo se registra siempre; el fallo del cerebro solo produce un aviso.
- **Recomendación**: llamar a `record_recurrence` después de `set_task`/`log_history` y de forma no fatal (`record_recurrence ... 2>/dev/null || say "aviso..."`), con test.

### BUG-TASK-038-2 (MEDIA) — `BLOCKED` + `move` borra la obligación de lección
- **Reproducir**: tarea "Feature: ..." → 3 rechazos → `BLOCKED` → `task.sh move TASK-X IN_PROGRESS` (0/3) → `handoff` → `task.sh close TASK-X`.
- **Observado**: `✅ aprobada y cerrada (DONE)` sin `--lesson` ni `--no-lesson`. La tarea con peor historial posible es justo la que escapa del control. No está documentado.
- **Esperado**: criterio "exige lección cuando la tarea tuvo rechazos".
- **Recomendación**: decidir por el historial (filas `Rechazo n/3` de la tarea en §7) además del contador, o documentar el hueco explícitamente si se acepta; test.

### BUG-TASK-038-3 (BAJA) — `close --lesson` acepta una lección `OBSOLETA`
- `task.sh lesson-retire LL-002` y `close TASK-X --lesson LL-002` cierra. Usa `all_lessons` en vez de `active_lessons`. Una lección retirada no acredita aprendizaje vigente; rechazarla o avisar.

### BUG-TASK-038-4 (BAJA) — falsos positivos del detector de reincidencias
- Dos palabras de 5+ letras en común bastan y no hay lista de palabras vacías. Con el cerebro de este repo (8 lecciones): "El formulario no valida el correo antes de enviar" → LL-008; "Los tests de integracion fallan al ejecutar la suite completa" → LL-006 (2 de 10 motivos genéricos). En proyecto temporal: "Los tests fallan siempre en la consulta" → lección de paginación (por "siempre" y "consulta"). Cada falso positivo queda en `recurrences.md`, en el historial ("reincidencia de LL-XXX") y en `brain stats`, y crece con el tamaño del cerebro.
- **Recomendación**: excluir palabras vacías (siempre, antes, cuando, falta, tests, falla...), comparar solo con el problema o exigir una proporción mínima; tests de negativos. Correcto hoy: `LL-001` literal, `ll-1` y `LL-0010` no coinciden, obsoletas ignoradas, `|`/tabuladores/backslashes/`$(...)` saneados.

### BUG-TASK-038-5 (BAJA) — documentación
- `.agents/skills/qa-security-agent/SKILL.md:47` y `.agents/skills/orchestrator-agent/SKILL.md` paso 7 siguen diciendo que la lección se registra tras la aprobación y solo para defectos complejos; contradice "antes de `close`".
- `AGENTS.md` §7.2 solo cita "rama `fix/`" (el código también mira `Bug:`/`Fix:`/`Hotfix:` y, de hecho, la rama es redundante: borrarla no esquiva nada) y sigue asignando el registro al orchestrator "cuando QA apruebe".
- No se documenta lo que no se detecta: `Bugfix:`, `Bugs:`, `[Bug]`, `Corregir bug:` cierran sin lección (coherente con el prefijo de rama de `start`, pero implícito).

## 3. Observaciones no bloqueantes
- `lessons_learned.md` vacío (0 bytes) es `ERROR` y bloquea el pre-commit, mientras que el archivo ausente es solo aviso; el mensaje no indica cómo repararlo.
- Editar a mano un antídoto sin `brain sync`, o guardar el archivo con CRLF/espacios finales, es `ERROR` de sincronía y bloquea el pre-commit hasta ejecutar `task.sh brain sync` (el mensaje lo indica; aceptable).
- `--lesson=` y `--no-lesson=` vacíos se ignoran en silencio en tareas sin obligación.
- Faltan tests de: BLOCKED+move, recurrences.md no escribible, `--lesson` obsoleta, falsos positivos.
- **Lección**: no aplica (rechazo).

## 4. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Siguiente paso**: `task.sh reject TASK-038 "<motivo>"`; el especialista retoma con `task.sh start TASK-038`.
