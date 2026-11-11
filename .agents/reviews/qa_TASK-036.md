# Veredicto de QA: TASK-036

- **Tarea**: `TASK-036`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `2/3` (segunda revisión; la primera rechazó con BUG-TASK-036-1 a 4)

---

## 1. Criterios de Aceptación Verificados

Entorno: macOS, `/bin/bash` 3.2.57, awk BSD 20200816. Todas las pruebas manuales se hicieron en proyectos temporales fuera del repo. Los proyectos "antiguos" se crearon con el `init-project.sh` y el `task.sh` de `main` (`git archive main`): 5 lecciones registradas con el `learn` antiguo y una retirada con el `lesson-retire` antiguo (BRAIN.md de 7 columnas, `lessons_learned.md` de 6). Después se actualizaron con `init-project.sh --update` de la rama.

| Criterio / Control | Resultado | Evidencia (ejecutada por QA) |
| :--- | :---: | :--- |
| `lessons_learned.md` fuente única con Ámbito y Estado; BRAIN.md se regenera; `learn`/`lesson-retire` la mantienen | ✅ | Tras cada comando, filas `LL-` idénticas en ambos archivos y el resto de BRAIN.md con el mismo md5 |
| BUG-1: escenario original (proyecto de main, sin `lessons_learned.md`, `--update`, luego `learn`, `brain sync`, `lesson-retire`, `brain scope`, `brain for`, `start`) | ✅ | `learn` crea la fuente, adopta LL-001..005 y numera LL-006; estados conservados (LL-002 `OBSOLETA`); sin pérdidas ni duplicados; resto de BRAIN.md intacto |
| BUG-1: fuente ausente y primer comando distinto de `learn` | ✅ | `brain sync`, `lesson-retire`, `brain scope` adoptan las 5 lecciones; `brain for`, `start`, `brain search` leen de BRAIN.md sin escribir nada |
| BUG-1: fuente de 8 columnas vacía (plantilla nueva) + BRAIN.md antiguo | ✅ | `brain sync`, `learn`, `lesson-retire`, `brain scope`: 5 lecciones adoptadas con `*` y su estado |
| BUG-1: fuente sin tabla | ✅ | `brain sync`, `learn`, `lesson-retire`, `brain scope` abortan (código 1, "no se modifica BRAIN.md"); BRAIN.md idéntico byte a byte; `brain for`/`start` siguen mostrando las lecciones |
| BUG-1: fuente de 0 bytes | ✅ | Los cuatro comandos de escritura abortan con código 1 y BRAIN.md queda intacto |
| BUG-1: solape parcial (fuente LL-001..003, BRAIN LL-001..005) | ✅ | Se adoptan LL-004 y LL-005; la lección nueva es LL-006 |
| BUG-1: mismo ID con texto distinto | ✅ | Gana la fuente (texto, ámbito y estado). Documentado: nota "Tabla generada … no se edita a mano" en BRAIN.md y BRAIN_TEMPLATE.md, skill `aprender` y cabecera de brain-lib.sh |
| BUG-2: tabuladores en problema, causa, solución y ámbito | ✅ | Ningún tabulador en los archivos; la lección sigue `ACTIVO`, sale en `brain for`, `brain search` y `start`, y el detector de duplicados la reconoce. Fila editada a mano con tabuladores: se lee bien |
| BUG-3: ámbitos | ✅ | `a b/*.ts` se conserva; `"  a b/*.ts  ,  c d/  "` → `a b/*.ts,c d/`; `,,x/*,,` → `x/*`; `" , ,"`, solo espacios y `--paths ",,"` rechazados; `\|`, `\n`, `\r` rechazados; `--paths=` funciona. Directorio acabado en `/`: casa rutas relativas, absolutas, con `./` y subdirectorios; no casa `XMis Docs/…`, `…/appx/…` ni `tests/a.sh.bak` |
| BUG-4: sin brain-lib.sh | ✅ | `❌ Error: Falta …/brain-lib.sh (instalación incompleta). Restáurala con: init-project.sh --update <proyecto>`, código 1 |
| Idempotencia de `brain sync` | ✅ | 3 ejecuciones seguidas: BRAIN.md y fuente idénticos con `cmp` (en proyecto adoptado, en locale C y en proyecto nuevo) |
| Permisos de archivos | ✅ | BRAIN.md 600 y fuente 640 se conservan tras `sync`, `learn`, `lesson-retire`, `brain scope` |
| Portabilidad | ✅ | Escenario BUG-1 completo con `LC_ALL=C` y PATH sin python3 en bash 3.2: correcto, tildes y Ñ incluidas en duplicados y búsqueda |
| Inyección al adoptar | ✅ | Fila de BRAIN.md con `C:\temp\n`, `&`, `\1`, `$(touch PWNED)` y backticks: adoptada literal, sin ejecución |
| Concurrencia | ✅ | 6 `learn` en paralelo sobre proyecto antiguo sin fuente: LL-001..011, sin pérdidas ni duplicados |
| Proyecto NUEVO (init-project.sh de la rama) | ✅ | `brain sync` no cambia nada; `learn`, `lesson-retire`, `brain scope`, `brain for`, `start` correctos; `validate-state.sh` sin errores |
| Migración clásica (fuente 6 col + BRAIN 7 col) | ✅ | Sigue funcionando; estados conservados |
| Tests nuevos significativos | ✅ | Los tests de HEAD ejecutados contra los scripts de HEAD~1: 184 OK, 10 fallidas (las 10 son tests nuevos de esta iteración) |
| Suite | ✅ | `test-scripts.sh` 194 OK / 0; `test-flow.sh` 24 OK / 0; `test-skills.sh` 28 skills sin errores; `validate-state.sh` 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → sin hallazgos |
| Observaciones de la iteración 1 | ✅ | `brain search ""` ahora falla; ayuda bien sangrada; semántica del glob documentada; skill `aprender` y plantilla corregidas |

## 2. Defectos

Ninguno bloqueante. BUG-TASK-036-1 a 4 corregidos y verificados.

## 3. Observaciones (BAJA, no bloquean)

Todas requieren archivos editados a mano o formatos que `task.sh` nunca produjo:

- **Fila de BRAIN.md con 6 columnas (sin Estado) que solo esté en BRAIN.md**: al adoptarla, `adopt_brain_lessons` quita la última columna creyendo que es el Estado y se pierde la Solución (queda una fila de 7 columnas). El BRAIN.md de `main` siempre tuvo 7 columnas, así que solo ocurre con filas escritas a mano.
- **BRAIN.md con finales de línea CRLF**: las filas adoptadas quedan con 10 columnas (`\r` en medio de la fila). No se pierde ninguna lección ni su estado, pero el ámbito se lee mal.
- **ID duplicado dentro de BRAIN.md** (dos filas `LL-003` distintas, ninguna en la fuente): solo se adopta la primera, sin aviso.
- **Fuente de 0 bytes**: `adopt_brain_lessons` no detecta filas ausentes (con el primer archivo vacío, `FNR == 1` no cuenta el archivo). Hoy es inocuo porque los comandos abortan después por falta de tabla, pero el mensaje difiere según el comando ("No se encontró la tabla esperada", "LL-004 no existe").
- **Proyectos antiguos**: `--update` no toca BRAIN.md, así que la nota "Tabla generada … no se edita a mano" no aparece en su BRAIN.md (sí en la skill `aprender` y en la plantilla).
- Sigue abierta de la iteración 1: con ~1 MB de lecciones `brain for`/`brain search` fallan por `ARG_MAX` (datos por `ENVIRON`); `adopt_brain_lessons` pasa las filas adoptadas por la misma vía.
- Cabecera de brain-lib.sh sigue citando compatibilidad sin mencionar estas limitaciones; filas con `\|` escritas a mano siguen desplazando columnas (comportamiento previo en main).

## 4. Siguiente paso

`task.sh close TASK-036` ejecutado. Pendiente de quien integra: `git checkout main && git merge --no-ff <rama> && git branch -d <rama>`. QA no ha fusionado ni hecho commits.
