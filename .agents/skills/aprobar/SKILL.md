---
name: aprobar
description: Punto de control formal Human-in-the-loop - presenta al usuario el plan, arquitectura o cambios criticos para su revision y confirmacion explicita, pausando la tarea con task.sh hold y reanudandola con task.sh approve tras el visto bueno humano. Usar cuando se requiere aprobacion humana previa antes de crear codigo masivo, al alcanzar un hito de arquitectura, o cuando el usuario dice "aprueba", "punto de control", "visto bueno" o "revisar antes de seguir". No usar para la revision de QA (qa-review) ni para crear tareas (nueva-tarea).
---

# /aprobar — Punto de Control Human-in-the-Loop

Este flujo implementa el punto de control formal entre la IA y el usuario humano antes de ejecutar cambios de alto impacto (diseño de arquitectura, cambios en esquema de base de datos, planes masivos o refactorizaciones estructurales). Lo orquesta el `orchestrator-agent` o el especialista asignado a la tarea.

## Pasos

1. **Identificar la tarea y el motivo del punto de control**:
   - Detecta la tarea activa o indicada por el usuario con `./.agents/scripts/task.sh list`.
   - Resume en un párrafo claro: qué se propone hacer, qué alternativas se descartaron y qué archivos se modificarán o crearán.

2. **Pausar la tarea formalmente (Hold)**:
   - Si la tarea aún está en `TODO` o `IN_PROGRESS`, ponla en espera de aprobación humana:
     ```bash
     ./.agents/scripts/task.sh hold TASK-XXX "Esperando visto bueno humano para [diseño/arquitectura/plan]"
     ```
   - El estado de la tarea pasa a `AWAITING_HUMAN_APPROVAL`, bloqueando inicios prematuros y dejando rastro en el historial de `GLOBAL_STATE.md`.

3. **Presentar el artefacto o propuesta al usuario**:
   - Muestra de forma concisa:
     - **Objetivo**: Qué problema resuelve la propuesta.
     - **Alcance**: Rutas exactas que se verán afectadas.
     - **Riesgos y mitigaciones**: Puntos críticos de ruptura o incompatibilidad.
     - **Decisión requerida**: Pregunta concreta al usuario (ej. "¿Confirmas este enfoque para iniciar la implementación?").

4. **Esperar la decisión del usuario humano**:
   - Si el usuario solicita ajustes: no reanudes la tarea; ajusta el documento o propuesta y vuelve a presentarla.
   - Si el usuario rechaza la propuesta: replanifica o cancela con `./.agents/scripts/task.sh move TASK-XXX BACKLOG` con su confirmación.

5. **Reanudar la tarea tras el visto bueno (Approve)**:
   - Una vez confirmada la aprobación explícita del humano, ejecuta:
     ```bash
     ./.agents/scripts/task.sh approve TASK-XXX --status TODO --comment "Plan maestro y arquitectura confirmados por el usuario"
     ```
   - O si el especialista va a comenzar de inmediato:
     ```bash
     ./.agents/scripts/task.sh approve TASK-XXX --status IN_PROGRESS --comment "Aprobado por el usuario"
     ./.agents/scripts/task.sh start TASK-XXX
     ```

## Prohibido

- Prohibido modificar código fuente de producción mientras la tarea esté en `AWAITING_HUMAN_APPROVAL`.
- Prohibido auto-aprobar una tarea sin la confirmación explícita del usuario humano.
- Prohibido usar `/aprobar` para la revisión de entregables listos para QA (para eso rige `/qa-review`).
- Prohibido saltar el paso `task.sh hold` cuando el usuario ha pedido expresamente revisar antes de continuar.

## Checklist

- [ ] Tarea pausada en `AWAITING_HUMAN_APPROVAL` mediante `task.sh hold TASK-XXX`.
- [ ] Propuesta estructurada con objetivo, alcance, riesgos y decisiones presentada al usuario.
- [ ] Espera activa de confirmación sin ejecutar código ni herramientas destructivas.
- [ ] Visto bueno humano explícito recibido en la conversación.
- [ ] Tarea reanudada en `TODO` o `IN_PROGRESS` mediante `task.sh approve TASK-XXX`.
