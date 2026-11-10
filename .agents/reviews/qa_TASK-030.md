# Veredicto de QA: TASK-030

- **Tarea**: `TASK-030`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Entorno: macOS, bash 3.2.57, awk BSD 20200816, `LC_CTYPE=C` (el entorno real de los agentes). Pruebas manuales en un proyecto temporal creado con `init-project.sh`.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `debt-resolve TD-XXX` elimina la deuda en `tech_debt.md` y `BRAIN.md` | ✅ | Elimina solo la fila exacta (no toca `TD-0010` ni filas que mencionan el ID en el texto); acepta `td-001`; rechaza `TD-00.*`, ID inexistente y sin argumento; sin `.tmp` huérfanos. Observación: BUG-TASK-030-3 |
| `learn` avisa si existe una lección similar y admite `--force` | ❌ MEDIA | Detecta casi-duplicados largos y `--force` funciona en cualquier posición, pero deja pasar duplicados **idénticos** (BUG-TASK-030-1) |
| `lesson-retire LL-XXX` marca OBSOLETA en ambas fuentes | ✅ | 7 columnas conservadas, resto de filas intactas (diff de 1 línea por archivo), idempotente, acepta `ll-001`, textos con `&`, `\1`, `\n`, comillas y tildes sin corrupción |
| `start` muestra las lecciones ACTIVAS de la categoría o un recordatorio | ❌ MEDIA | Muestra las 5 últimas activas de cualquier categoría; no filtra por categoría (BUG-TASK-030-2). El recordatorio genérico sin lecciones y el silencio sin `BRAIN.md` funcionan |
| Ayuda y skill `aprender` actualizadas | ✅ | `help` lista `debt-resolve` y `lesson-retire`; skill con sección de mantenimiento. BAJA: la línea de `learn` en la ayuda no menciona `--force` |
| Tests nuevos; suite al 100% | ✅ | `test-scripts.sh` 141 OK / 0; `test-flow.sh` 24 OK / 0; `test-skills.sh` 28 skills sin errores |
| Trailers multilínea rechazados en `commit` | ✅ | `\n` y `\r` rechazados vía `--trailer`, `--trailer=` y `MAESTRO_COMMIT_TRAILER`; HEAD intacto; trailers válidos siguen funcionando |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` limpio |
| Auditoría de seguridad | ✅ | IDs validados con regex anclada antes de usarse en `grep -E`/`awk -v`; sin inyección; sin extensiones GNU de awk |

## 2. Observaciones y Hallazgos

### BUG-TASK-030-1 (MEDIA) — El detector de duplicados acepta lecciones idénticas
- **Reproducir** (proyecto temporal):
  1. `task.sh learn "Error en login" backend c s` dos veces → se registran `LL-003` y `LL-004` idénticas (menos de 3 palabras de 4+ letras: no se compara nunca).
  2. `task.sh learn "Paginación incorrecta en migración automática" database c s` y después el mismo texto en MAYÚSCULAS → se registra (con `LC_CTYPE=C`, `tolower` de awk BSD no baja `Ó`/`Á`; con `LC_ALL=es_ES.UTF-8` sí se detecta).
  3. El mismo texto sin tildes (`Paginacion incorrecta en migracion automatica`, la convención de este repo) → se registra.
- **Esperado**: una lección idéntica o que solo difiere en mayúsculas/tildes debe avisarse.
- **Recomendación**: comparar primero el texto normalizado completo (igualdad exacta) sin umbral de palabras; normalizar tildes y mayúsculas acentuadas con sustituciones explícitas (`gsub` de `á|Á`→`a`, etc.) en ambos lados para no depender del locale; añadir tests para los tres casos.

### BUG-TASK-030-2 (MEDIA) — `start` no filtra por categoría
- **Reproducir**: con 8 lecciones activas de categorías distintas, `task.sh start TASK-003` (backend-agent) lista `tail -5` sin mirar la categoría; las lecciones backend más antiguas quedan fuera.
- **Esperado** (criterio): lecciones ACTIVAS de la categoría de la tarea, o el recordatorio genérico.
- **Recomendación**: derivar la categoría del agente asignado (`backend-agent`→`BACKEND`, etc.), priorizar esas lecciones y caer al listado/recordatorio general si no hay; o pedir al orchestrator-agent que cambie el criterio si se prefiere el comportamiento actual. Añadir test.

### BUG-TASK-030-3 (MEDIA, trazabilidad) — `debt-resolve` permite reutilizar IDs
- **Reproducir**: `debt` x3, `debt-resolve TD-003`, `debt "otra" ...` → la nueva deuda vuelve a ser `TD-003`. En este mismo repo la próxima deuda será `TD-001`, el ID que el historial de `GLOBAL_STATE.md` §7 ya atribuye a TASK-029.
- **Recomendación**: que `next_id TD` no reutilice IDs (p. ej. marcar la fila como `SALDADA` en lugar de borrarla —el criterio admite "elimina/marca"—, o calcular el máximo incluyendo `GLOBAL_STATE.md`/historial). El test actual solo comprueba que no se reutiliza un ID vivo.

### Observaciones (BAJA)
- La ayuda de `learn` no documenta `--force`.
- `cut -c 1-90` en `start` corta por bytes con locale C: puede partir un carácter multibyte al final de la línea.
- `lesson-retire` sobre una fila editada a mano sin `|` final sobrescribiría la columna de solución (usa `$(NF-1)`).

### Fuera de alcance (preexistente, no causado por TASK-030)
- `init-project.sh "Nombre"` con un solo argumento falla en bash 3.2: `positional[1]: unbound variable` (línea 77).
- `say`/`die` usan `printf %b`: los `\n`, `\r`, `\x` del texto del usuario se interpretan en pantalla (el archivo se escribe bien).
- `append_to_table` deja el archivo con permisos `0600` (por `mktemp` + `mv`).

## 3. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Siguiente paso**: `task.sh reject TASK-030 "<motivo>"`; el especialista retoma con `task.sh start TASK-030`.
