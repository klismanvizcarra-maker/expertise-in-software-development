---
name: cerrar-fase
description: Cierra una fase del proyecto - comprueba que todas sus tareas están DONE y fusionadas, revisa la deuda técnica y la salud del cerebro, consolida las lecciones de la fase, redacta el resumen de lo entregado en GLOBAL_STATE.md y propone, con confirmación del usuario, la fase siguiente y sus primeras tareas. Usar cuando todas las tareas de la fase están terminadas, cuando el usuario dice "cerramos la fase", "fin del sprint", "retrospectiva" o "qué sigue después de esta fase". No usar para publicar una versión (release) ni para crear tareas sueltas (nueva-tarea).
---

# /cerrar-fase — Cierre de Fase y Retrospectiva

El `orchestrator-agent` debe revisar la deuda técnica al empezar cada fase (paso 7 de su skill y `.agents/brain/tech_debt.md`) y `AGENTS.md` §7 exige registrar lo aprendido. Esta skill es el paso que lo hace. Lo ejecuta el `orchestrator-agent`.

## Pasos

1. **Leer el estado**: `GLOBAL_STATE.md` (fase actual en §1, tablero y registro §7) y:
   ```bash
   ./.agents/scripts/task.sh metrics
   ./.agents/scripts/task.sh list
   ./.agents/scripts/validate-state.sh
   ```
2. **Comprobar que la fase está terminada**:
   - Ninguna tarea de la fase en `TODO`, `IN_PROGRESS` ni `IN_REVIEW_QA`. Las que no se vayan a hacer se replanifican con `task.sh move TASK-XXX BACKLOG` **con confirmación del usuario**.
   - Ninguna tarea `BLOCKED` sin decisión humana: si la hay, la fase no se cierra; emite primero el escalamiento (`orchestrator-agent`).
   - Todas las ramas de tareas `DONE` fusionadas: `git branch --list 'feature/*' 'fix/*' 'refactor/*'` no muestra ramas de la fase.
3. **Revisar el cerebro**:
   ```bash
   ./.agents/scripts/task.sh brain doctor
   ./.agents/scripts/task.sh brain stats
   ```
   - Corrige cualquier `ERROR` de `brain doctor` antes de seguir.
   - **Reincidencias**: una lección que reincidió no está llegando al agente; revisa su ámbito (`task.sh brain scope LL-XXX "<globs>"`) o reescribe su antídoto en `.agents/brain/lessons_learned.md` y ejecuta `task.sh brain sync`.
   - **Lecciones generales** (ámbito `*`): asígnales rutas si aplican a archivos concretos, para que el hook las muestre al editar.
   - **Lecciones que ya no aplican** (se cambió de librería, se eliminó el módulo): retíralas con `task.sh lesson-retire LL-XXX`.
4. **Revisar la deuda técnica** (`.agents/brain/tech_debt.md`): para cada deuda pendiente decide con el usuario si se salda en la fase siguiente (crea su tarea) o se mantiene. Deuda de prioridad `ALTA` que sigue abierta va al principio de la fase siguiente. Las deudas ya resueltas se cierran con `task.sh debt-resolve TD-XXX`.
5. **Resumen de la fase**: añade a `GLOBAL_STATE.md` §7 una fila de hito (en la columna Tarea, el rango de la fase, p. ej. `TASK-024..TASK-038`) con lo entregado (tareas, nº de rechazos de QA, lecciones nuevas, deuda saldada y abierta). Si hubo decisiones de arquitectura, comprueba que están como ADR en §6 (`docs-architecture-agent` si faltan).
6. **Archivar las tareas `DONE` cerradas** (recomendado cuando el tablero crece, opcionalmente conservando las `N` más recientes):
   ```bash
   ./.agents/scripts/task.sh archive --phase "<nombre de la fase>" --keep 0
   ```
   Mueve las tareas `DONE` de `GLOBAL_STATE.md` §5 a `.agents/archive/` preservando `next_id`, `task.sh metrics` y `validate-state.sh`. Verifica después con `./.agents/scripts/validate-state.sh`.
7. **Proponer la fase siguiente**: si existe `docs/plan/plan-maestro.md`, anota en su §11 lo real frente a lo planificado de la fase que cierra y toma de él la fase siguiente y sus tareas candidatas, ajustadas a lo aprendido (si el alcance o las fechas cambian, actualiza el plan con una nueva versión en su historial, con confirmación del usuario). Presenta al usuario el nombre de la fase, su objetivo, y de 3 a 7 tareas candidatas con agente y criterios de aceptación (incluidas las de deuda del paso 4). **No registres nada sin su confirmación.** Con el visto bueno:
   - Actualiza la **Fase Actual** en §1 de `GLOBAL_STATE.md`.
   - Registra las tareas con `/nueva-tarea`.
8. **Siguiente paso**: si la fase cierra con una versión publicable, recomienda `/release`.

## Checklist antes de dar la fase por cerrada
- [ ] Ninguna tarea de la fase en `TODO`, `IN_PROGRESS`, `IN_REVIEW_QA` ni `BLOCKED` sin decisión humana.
- [ ] Ramas de las tareas `DONE` fusionadas a `main` con `--no-ff` y borradas.
- [ ] `task.sh brain doctor` sin errores; reincidencias y lecciones generales revisadas.
- [ ] Cada deuda pendiente con decisión explícita (tarea en la fase siguiente o se mantiene).
- [ ] Hito de cierre registrado en §7 de `GLOBAL_STATE.md`.
- [ ] Tareas `DONE` archivadas con `task.sh archive` si corresponde y `validate-state.sh` en verde.
- [ ] Fase siguiente y sus tareas confirmadas por el usuario antes de registrarlas.
- [ ] Si hay plan maestro, su seguimiento real frente a planificado actualizado.

## Prohibido
- Cerrar una fase con tareas `BLOCKED` pendientes de decisión humana o con ramas sin fusionar.
- Mover tareas a `BACKLOG`, retirar lecciones o saldar deuda sin que el usuario lo confirme.
- Registrar tareas de la fase siguiente sin su confirmación.
- Marcar tareas como `DONE` o cambiar estados a mano en `GLOBAL_STATE.md`: solo con `task.sh`.
