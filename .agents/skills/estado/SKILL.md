---
name: estado
description: Muestra el estado actual del proyecto multi-agente en un resumen breve - progreso, tareas por estado, tareas BLOCKED que requieren decisión humana, tareas esperando QA, deuda técnica pendiente y siguiente paso recomendado. Solo lectura. Usar cuando el usuario pregunta cómo va el proyecto, qué falta, qué sigue, o al retomar el trabajo en una sesión nueva.
---

# /estado — Resumen del Proyecto

Flujo de solo lectura: no modifica ningún archivo.

## Pasos

1. Si no existe `GLOBAL_STATE.md`, dilo y sugiere `/iniciar-proyecto`. Fin.
2. Ejecuta desde la raíz del proyecto:
   ```bash
   ./.agents/scripts/task.sh metrics
   ./.agents/scripts/task.sh list
   ./.agents/scripts/validate-state.sh
   ```
3. Lee de `GLOBAL_STATE.md` la fase actual y los últimos 3 hitos del registro cronológico, y de `.agents/brain/tech_debt.md` las deudas de prioridad `ALTA`.
4. Responde con este formato, omitiendo las secciones vacías:

   ```markdown
   **<Proyecto>** · <Fase actual> · <N>% completado (<done>/<total>)

   🚨 **Requieren tu decisión** (BLOCKED): TASK-XXX — <descripción>
   🔍 **Esperando QA**: TASK-XXX — <descripción> (iteración n/3)
   🛠 **En curso**: TASK-XXX — <descripción> (<agente>)
   📋 **Siguientes**: TASK-XXX — <descripción>
   ⚠️ **Deuda técnica alta**: TD-XXX — <descripción>

   **Siguiente paso recomendado**: <una acción concreta, p. ej. "/qa-review TASK-004">
   ```

## Regla para el siguiente paso
Prioridad: tareas `BLOCKED` (pedir decisión) → `IN_REVIEW_QA` (`/qa-review`) → `IN_PROGRESS` (continuar) → `TODO` (empezar la de menor ID sin dependencias pendientes) → sin tareas (`/nueva-tarea`).
