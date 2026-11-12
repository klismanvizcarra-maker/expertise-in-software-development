# Veredicto de QA · TASK-038 · iteración 2/3 → APROBADA

- **Tarea**: `TASK-038` — Cerebro: captura obligatoria de lecciones, reincidencias, doctor y stats
- **Asignada a**: devops-cloud-agent
- **Revisor**: `qa-security-agent`
- **Fecha**: 2026-11-11
- **Rama**: `feature/TASK-038-cerebro-captura-obligatoria-de` (commit `ba60bc2`)
- **Veredicto anterior**: iteración 1/3, RECHAZADA con BUG-TASK-038-1 a 5 (commit `7166d92`)

## 1. Verificación independiente (ejecutado por QA)

Todo lo de esta tabla se ejecutó en proyectos temporales creados con `init-project.sh` o en copias de `git archive`; nunca en el repositorio.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `bash tests/test-scripts.sh` | ✅ | 239 OK, 0 fallidas |
| `bash tests/test-flow.sh` / `tests/test-skills.sh` | ✅ | 25 OK / 28 skills sin errores |
| `validate-state.sh` / `scan-secrets.sh --branch` | ✅ | 0 errores, cerebro sano / sin hallazgos |
| Los tests nuevos fallan con el código anterior | ✅ | Tests de HEAD + scripts de `git archive HEAD~1`: 7 fallos en test-scripts (BLOCKED+move, OBSOLETA, motivos genéricos, recurrences.md no escribible y derivados) y 1 en test-flow |
| BUG-1: `reject` no depende de `recurrences.md` | ✅ | `recurrences.md` en 444, `.agents/brain` en 555 y `recurrences.md` como directorio: los rechazos 1, 2 y 3 (BLOCKED) salen con rc=0, estado, contador y fila de historial correctos, aviso "No se pudo anotar la reincidencia", sin ruido de stderr y con el lock libre; `validate-state.sh` sigue pasando. En el caso normal se anota una sola fila, saneada |
| BUG-2: `BLOCKED` + `move` no borra la obligación | ✅ | 3 rechazos → BLOCKED → `move IN_PROGRESS` (0/3) → handoff → `close` falla sin escribir ("tuvo 3 rechazo(s)"); con `--lesson` y con `--no-lesson` cierra. También por BLOCKED → TODO → start |
| BUG-2: sin herencia entre IDs con prefijo común | ✅ | TASK-1 y TASK-01 sin rechazos cierran sin lección aunque TASK-12 y TASK-010 tengan 1 rechazo; estas sí quedan obligadas |
| BUG-2: texto "Rechazo 1/3" sin rechazo real | ⚠️ BAJA | No obliga si está en medio de la descripción o del resumen, ni con barras verticales inyectadas. Sí obliga si el resumen del handoff (o la descripción, que se copia al historial) EMPIEZA por "Rechazo n/m" (ver observación 1) |
| BUG-2: historial con formato antiguo | ✅ | Historial escrito con el `task.sh` de `main`: la tarea con 3 rechazos y 0/3 queda obligada y la limpia cierra. Con el historial podado, el contador 1/3 sigue obligando |
| BUG-3: `--lesson` con lección OBSOLETA | ✅ | Falla con mensaje claro; hash de todo el árbol idéntico antes y después; lock libre; también con `ll-001`, `--lesson=LL-001` y en tareas sin obligación |
| BUG-4: falsos positivos del detector | ✅ | Contra una copia del cerebro real (8 lecciones), 28 motivos genéricos: 1 falso positivo (antes 5). Queda "La copia de seguridad no comprueba que el archivo de destino exista antes de sobrescribir" → LL-008 |
| BUG-4: falsos negativos del detector | ⚠️ BAJA | 17 paráfrasis de lecciones concretas: 6 no detectadas (antes 2). LL-006 no se detecta en ninguna de sus 3 paráfrasis (ver observación 2). El ID literal siempre casa (`LL-006`, `ll-001`); `LL-0010`, `ll-1`, `LL-999` y `XLL-001` no casan |
| Portabilidad | ✅ | `/bin/bash` 3.2.57 con `LC_ALL=C`: 239 OK y 25 OK. Los 45 escenarios de QA repetidos con `task.sh` sin python3 en el PATH y `LC_ALL=C`: mismo resultado. Detector sin python3: mismas cifras |
| El propio repo sigue siendo cerrable | ✅ | TASK-038 (1 rechazo en el historial) se cierra con `--lesson LL-009` |

## 2. Revisado por lectura (no ejecutado)

- Diff `git diff HEAD~1` y `git diff main...HEAD` de `task.sh`, `brain-lib.sh`, `validate-state.sh`, skills y `AGENTS.md`.
- BUG-5: `qa-security-agent/SKILL.md`, `orchestrator-agent/SKILL.md` paso 7 y `AGENTS.md` §7.2 dicen lo mismo que el código: lección **antes** del cierre, prefijos `Bug:`/`Fix:`/`Hotfix:` (mismo criterio que la rama `fix/`), rechazos contados en el historial, `--lesson` exige lección activa. Coherentes con `qa-review`, `bugfix`, `aprender` y la plantilla de veredicto.
- Seguridad: sin `eval` ni expansión de texto del usuario; el ID de tarea llega a awk por `ENVIRON`; motivos saneados (`|`, tabuladores, saltos de línea) antes de escribirse.

## 3. Observaciones no bloqueantes (BAJA)

1. **Fila de handoff que empieza por "Rechazo n/m"**: `close` cuenta como rechazo cualquier fila del historial de la tarea cuyo detalle empiece así, sin mirar quién la escribió. `task.sh handoff TASK-X --summary "Rechazo 1/3: ahora se muestra en el panel"`, o una tarea cuya descripción empieza por ese texto, quedan obligadas a lección sin haber sido rechazadas. Falla hacia el lado seguro y se resuelve con `--no-lesson`. Arreglo sugerido: exigir además que la columna de origen sea `qa-security-agent`.
2. **Exhaustividad del detector**: solo compara con el problema y el antídoto, no con la causa raíz, y no agrupa plurales ("patron" frente a "patrones"). Una lección con problema corto, como LL-006, es prácticamente indetectable por paráfrasis. El equilibrio es aceptable porque la reincidencia es una métrica informativa y un falso positivo ensucia historial y estadísticas, pero la regla solo está en un comentario de `brain-lib.sh`: ninguna skill ni `AGENTS.md` dicen que citar el `LL-XXX` en el motivo garantiza el registro, ni mencionan el falso negativo conocido de LL-006.
3. `init-project.sh` exige python3 (línea 256); es anterior a esta tarea y queda fuera de su alcance.

- **Lección**: `LL-009` registrada con `task.sh learn` (obligaciones decididas por el historial y no por contadores reiniciables; efectos secundarios opcionales después de la transición principal y no fatales).

## 4. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-038 --lesson LL-009`; fusión a `main` con `--no-ff` pendiente (no la hace QA).
