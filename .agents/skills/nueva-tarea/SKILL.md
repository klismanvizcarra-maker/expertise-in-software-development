---
name: nueva-tarea
description: Convierte un requerimiento en tareas TASK-XXX con especialista y criterios verificables, y las registra tras confirmación. Usar cuando piden una funcionalidad sin tarea, o "crea una tarea" o "descompón". No usar para el plan completo (crear-plan) ni seguimiento o BLOCKED (orchestrator-agent).
---

# /nueva-tarea — Del Requerimiento al Tablero

Actúas como `orchestrator-agent` (carga su skill: contiene la tabla de enrutamiento y matrices de responsabilidad).

## Pasos

1. **Contexto**: lee `GLOBAL_STATE.md` (stack, contratos DTO en §4 y tareas existentes, para no duplicar) y `BRAIN.md` (lecciones aprendidas y gotchas).
2. **Claridad del Requerimiento**: si faltan usuarios, flujos, pantallas o criterios medibles, propone primero pasar por `/product-manager-agent` y detente.
3. **Descomposición Atómica**:
   - Una sola responsabilidad y un único especialista asignado por tarea.
   - Si la funcionalidad cruza capas (ej. nuevo endpoint + nueva pantalla):
     - **Paso previo obligatorio**: define y publica el borrador del contrato DTO en `GLOBAL_STATE.md` §4.
     - Divide el trabajo en dos tareas independientes que compartan el mismo contrato DTO para permitir desarrollo paralelo con mocks tipados.
4. **Propuesta Estructurada**: presenta la tabla de descomposición para revisión del usuario antes de tocar el tablero:

   | # | Descripción | Agente | Criterios de Aceptación Verificables | Depende de |
   | :- | :--- | :--- | :--- | :--- |
   | 1 | Contrato DTO de `POST /api/v1/login` | backend-agent | Esquema Zod documentado en §4 de GLOBAL_STATE.md | — |
   | 2 | Endpoint de login y autenticación | backend-agent | Tests pasando; 401 ante credenciales inválidas; rate limiting activo | 1 |
   | 3 | Vista de login interactiva | frontend-agent | Componente con 4 estados UI; validación en cliente con esquema DTO | 1 |

   *Criterios válidos = medibles mediante comando shell, test automatizado o aserción concreta. Rechaza criterios vagos ("funciona bien", "UI bonita").*
5. **Confirmación del Usuario**: espera aprobación explícita antes de persistir cambios.
6. **Registro en el Tablero**: registra cada tarea en orden:
   ```bash
   ./.agents/scripts/task.sh add "<descripción>" "<agente>" "<criterios verificables>"
   ```
   *Evita el carácter `|` dentro de los textos (rompe el formato Markdown de la tabla).*
7. **Cierre y Siguiente Paso**: ejecuta `./.agents/scripts/task.sh list` e indica la primera tarea que puede iniciar el especialista asignado (`task.sh start TASK-XXX`).

## Checklist antes de registrar tareas
- [ ] Requerimiento contrastado con `GLOBAL_STATE.md` y `BRAIN.md` para evitar duplicidades o antipatrones.
- [ ] Tareas atómicas: un solo especialista por tarea, acotadas a < 1 día de esfuerzo.
- [ ] Criterios de aceptación 100% verificables mediante comandos shell o pruebas automatizadas.
- [ ] Contrato DTO acordado y documentado en §4 si la funcionalidad cruza cliente y servidor.
- [ ] Aprobación explícita del usuario obtenida antes de ejecutar `task.sh add`.

## Prohibido
- Crear tareas con criterios ambiguos o subjetivos ("que funcione bien", "hacer refactor").
- Asignar una misma tarea a múltiples agentes especialistas simultáneamente.
- Registrar tareas en el tablero sin la confirmación previa del usuario.
- Crear tareas de implementación frontend y backend concurrentes sin haber fijado el contrato DTO en §4.
