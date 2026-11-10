# Veredicto de QA: TASK-030

- **Tarea**: `TASK-030`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA` (con deuda técnica MEDIA registrada)
- **Iteración**: `2/3` (segunda revisión; la primera se rechazó con BUG-TASK-030-1, -2 y -3)

---

## 1. Criterios de Aceptación Verificados

Entorno: macOS, bash 3.2, awk/sed BSD, `LC_CTYPE=C` por defecto (el entorno real de los agentes). Pruebas manuales en proyectos temporales nuevos creados con `init-project.sh` (nunca en el repo), con `task.sh` idéntico al de la rama (`cmp`).

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `debt-resolve TD-XXX` elimina/marca la deuda en `tech_debt.md` y `BRAIN.md` | ✅ | Marca `SALDADA` solo la fila exacta y conserva las columnas; acepta `td-001`; rechaza segunda ejecución, `TD-099`, `TD-00.*` y sin argumento; sin `.tmp` huérfanos |
| BUG-TASK-030-3: no reutilizar IDs de deuda | ✅ | `debt` x3, `debt-resolve TD-003`, `debt` → `TD-004` (antes volvía a `TD-003`). En el repo, `TD-001` queda como `SALDADA` |
| `learn` avisa si existe una lección similar y admite `--force` | ✅ (deuda MEDIA) | Ver BUG-1 abajo. `--force` funciona al principio y al final de los argumentos |
| BUG-TASK-030-1: duplicados idénticos cortos, mayúsculas en locale C, sin tildes | ✅ con python3 / ⚠️ sin python3 | Con python3: `Error en login` x2 rechazada; `error EN login.` rechazada; `PAGINACIÓN INCORRECTA EN MIGRACIÓN AUTOMÁTICA` rechazada con locale por defecto, `LC_ALL=C` y `es_ES.UTF-8`; versión sin tildes rechazada; `Error en logout` aceptada. Sin python3: ver OBS-1 |
| `lesson-retire LL-XXX` marca OBSOLETA en ambas fuentes | ✅ | `OBSOLETA` en `BRAIN.md`, `[OBSOLETA]` en `lessons_learned.md`; idempotente; rechaza `LL-999` y `LL-0.*`; la lección retirada deja de mostrarse en `start` y no bloquea un `learn` idéntico |
| `start` muestra las lecciones ACTIVAS de la categoría o un recordatorio | ✅ | Ver BUG-2 abajo |
| BUG-TASK-030-2: priorizar la categoría del agente asignado | ✅ | 2 lecciones BACKEND antiguas + 7 FRONTEND recientes, tarea de `backend-agent` → las 2 BACKEND primero y las 3 más recientes del resto. Funciona también con el agente entre backticks en el tablero |
| Recordatorio de `start`: casos límite | ✅ | Más de 5 de la categoría (7 FRONTEND) → muestra las 7, sin relleno; agente sin categoría (`orchestrator-agent`, `product-manager-agent`) o sin lecciones de la suya (`mobile-agent`) → las 5 más recientes; `ui-ux-agent` → `[UI/UX]` primero; sin lecciones o todas OBSOLETAS → recordatorio genérico; sin `BRAIN.md` → silencio, `start` no falla |
| Ayuda y skill `aprender` actualizadas | ✅ | `help` documenta `learn ... [--force]`, `debt-resolve` y `lesson-retire`; skill con sección "Mantenimiento del Cerebro" |
| Tests nuevos; suite al 100% | ✅ | `bash tests/test-scripts.sh` → 147 OK, 0 fallidas; `bash tests/test-flow.sh` → 24 OK, 0 fallidas; `bash tests/test-skills.sh` → 28 skills sin errores |
| Estado del proyecto | ✅ | `./.agents/scripts/validate-state.sh` → sin errores críticos, 0 advertencias |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` → sin hallazgos |
| `/estado` no se ve afectado por filas SALDADA | ✅ | La skill lee las deudas de prioridad `ALTA`; al saldar, la columna Prioridad pasa de `ALTA` a `SALDADA`, de modo que la fila deja de contar. Ningún script (`validate-state.sh`, `metrics`) interpreta `tech_debt.md` |
| Auditoría de seguridad | ✅ | IDs validados con regex anclada antes de usarse en `grep -E` y `awk -v`; el texto del usuario llega a python por stdin y a awk por `-v` (sin `eval` ni concatenación en comandos); trailers con `\n`/`\r` rechazados |

## 2. Observaciones y Hallazgos

### OBS-1 (MEDIA, aceptada como deuda técnica `TD-002`) — Sin python3 y en locale C, el detector de duplicados queda desactivado en silencio
- **Reproducir** (proyecto temporal, `PATH` con enlaces a `/bin` y `/usr/bin` salvo `python*`):
  `PATH=<sin python3> LC_ALL=C task.sh learn "Fallo C en login" backend c s` dos veces → se registran `LL-001` y `LL-002` idénticas; tampoco se detectan las variantes en mayúsculas, con tildes o sin ellas. Ocurre igual con el entorno por defecto (`LC_CTYPE=C` sin `LC_ALL`).
- **Causa**: en el camino alternativo de `norm_text`, `sed 'y/áàä.../aaa.../'` falla en locale C (`transform strings are not the same length`: los caracteres con tilde ocupan 2 bytes), el error se descarta con `2>/dev/null` y la salida queda vacía, así que `similar_lesson` compara contra una lista vacía. Con `LC_ALL=es_ES.UTF-8` el mismo camino sí detecta los cuatro casos.
- **Por qué no bloquea**: python3 ya es requisito de hecho del sistema (el hook `require-active-task.sh` bloquea toda edición sin python3 e `init-project.sh` lo usa), no hay riesgo de seguridad y `learn` sigue registrando correctamente. Es, eso sí, peor que la iteración 1 en ese entorno concreto, donde los casi-duplicados largos sí se detectaban.
- **Acción definitiva**: hacer que el camino sin python3 no dependa del locale (por ejemplo `LC_ALL=C` con sustituciones por secuencia de bytes, o caer a `tr '[:upper:]' '[:lower:]'` sin quitar tildes si `sed` falla) y añadir un test con `PATH` sin python3. También cubre el caso de un `python3` presente pero no funcional (stub de macOS sin Command Line Tools).

### Observaciones (BAJA)
- `debt-resolve` busca `SALDADA` en toda la fila: una deuda cuyo texto contenga esa palabra (`debt "... SALDADA ..."`) responde "ya estaba marcada como SALDADA" y no se puede saldar. Debería mirar solo la columna Prioridad.
- Dos lecciones formadas solo por signos (`¿?` y `!!`) se consideran iguales porque ambas se normalizan a cadena vacía; lo mismo pasaría con textos sin caracteres latinos.
- La heurística del 60% da falsos positivos en textos de 3 palabras significativas: `Backend viejo dos beta` se rechaza por parecida a `Backend viejo uno alfa` (2 de 3). `--force` lo resuelve.
- `substr(p, 1, 90)` en `start` corta por bytes en locale C y puede partir un carácter multibyte al final de la línea.
- `lesson-retire` sobre una fila editada a mano sin `|` final sobrescribiría la columna de solución (usa `$(NF-1)`).
- Con más de 5 lecciones de la categoría, `start` las muestra todas (sin tope); con muchas lecciones el recordatorio puede hacerse largo.
- El handoff de la iteración 2 lista solo `test-scripts.sh` y `scan-secrets.sh` como comandos de verificación; QA ejecutó además `test-flow.sh`, `test-skills.sh` y `validate-state.sh`.

### Fuera de alcance (preexistente, no causado por TASK-030)
- `init-project.sh "Nombre"` con un solo argumento falla en bash 3.2 (`positional[1]: unbound variable`).
- `say`/`die` usan `printf %b`: los `\n`, `\r`, `\x` del texto del usuario se interpretan en pantalla (el archivo se escribe bien).
- `append_to_table` deja el archivo con permisos `0600` (por `mktemp` + `mv`).

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`. Los tres bugs de la iteración 1 están corregidos en el entorno soportado (con python3, también con `LC_ALL=C`); todos los criterios de aceptación se cumplen y las suites pasan al 100%.
- **Deuda técnica**: `TD-002` (MEDIA) por OBS-1.
- **Siguiente paso**: `task.sh close TASK-030`; después, fusión a `main` con `git merge --no-ff` y borrado de la rama (a cargo del especialista o del `orchestrator-agent`).
