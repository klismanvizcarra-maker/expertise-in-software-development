---
name: nueva-tarea
description: Convierte un requerimiento en tareas TASK-XXX registradas en GLOBAL_STATE.md - las descompone, asigna cada una al especialista correcto con criterios de aceptación verificables, propone el orden y las registra con task.sh add tras la confirmación del usuario. Usar cuando el usuario pide una funcionalidad, un cambio o un bugfix que aún no tiene tarea, o dice "crea una tarea", "planifica" o "descompón". No usar para seguimiento, desbloqueo de tareas BLOCKED o escalamiento (orchestrator-agent).
---

# /nueva-tarea — Del Requerimiento al Tablero

Actúas como `orchestrator-agent` (carga su skill: contiene la tabla de enrutamiento).

## Pasos

1. **Contexto**: lee `GLOBAL_STATE.md` (stack, contratos y tareas existentes, para no duplicar) y `BRAIN.md`.
2. **¿Está claro?** Si faltan usuarios, flujos o criterios medibles, propone primero `/product-manager-agent` y detente.
3. **Descomponer** en tareas atómicas: un especialista y un entregable verificable por tarea. Si cruza capas, una tarea por capa que comparten contrato.
4. **Proponer antes de registrar**. Muestra:

   | # | Descripción | Agente | Criterios de aceptación | Depende de |
   | :- | :--- | :--- | :--- | :--- |
   | 1 | Contrato DTO de `POST /api/v1/login` | backend-agent | Contrato publicado en §4 | — |
   | 2 | Endpoint de login | backend-agent | Tests en verde; 401 sin credenciales; 429 tras 5 intentos | 1 |

   Criterios válidos = comprobables con un comando o una prueba. Rechaza tus propios criterios vagos ("funciona bien", "UI bonita").
5. **Con la confirmación del usuario**, registra cada fila en orden:
   ```bash
   ./.agents/scripts/task.sh add "<descripción>" "<agente>" "<criterios>"
   ```
   Evita el carácter `|` dentro de los textos (rompe la tabla).
6. **Cerrar**: muestra `./.agents/scripts/task.sh list` y la primera tarea que puede empezar (`task.sh start TASK-XXX` por el agente asignado).
