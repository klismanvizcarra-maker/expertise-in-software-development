---
name: handoff
description: Entrega formal de una tarea terminada a QA - verifica el checklist de la skill del especialista, ejecuta tests y build, registra entregables y comandos de verificación en GLOBAL_STATE.md y pasa la tarea a IN_REVIEW_QA con task.sh handoff. Usar cuando un especialista termina su trabajo en una TASK-XXX o el usuario dice "entrega", "listo para QA" o "handoff". No usar para emitir el veredicto (qa-review) ni para crear tareas (nueva-tarea).
---

# /handoff — Entrega Formal a QA

Este flujo lo ejecuta exclusivamente el especialista responsable de la tarea, nunca QA ni el Orchestrator.

## Pasos

1. **Identificar la tarea**:
   - Utiliza el ID proporcionado por el usuario, o detecta la tarea en `IN_PROGRESS` mediante `./.agents/scripts/task.sh list`.
   - Si existen varias tareas en curso, solicita clarificación antes de proceder.
2. **Auto-auditoría con la skill del especialista**:
   - Carga la skill del rol asignado y revisa exhaustivamente su sección *Checklist antes de `task.sh handoff`*, ítem por ítem.
3. **Verificación técnica obligatoria (Tests, Build y Secretos)**:
   - Ejecuta la suite de pruebas del proyecto (`npm test`, `pytest`, etc.).
   - Ejecuta la compilación o build del proyecto (`npm run build`).
   - Ejecuta de forma obligatoria el escáner de secretos:
     ```bash
     ./.agents/scripts/scan-secrets.sh --branch
     ```
   - *Si alguna prueba falla, el build se rompe o se detecta un secreto expuesto, **ABORTA el handoff de inmediato**, corrige el fallo y no continúes.*
4. **Confirmar contratos y preparar comandos de verificación**:
   - Si la tarea modificó endpoints o payloads, confirma que los contratos DTO en §4 estén sincronizados.
   - Identifica los comandos reproducibles de verificación empleados durante la tarea (tests, builds, escaneo de secretos).
5. **Commit convencional de los cambios**:
   - Asegúrate de haber agregado los archivos nuevos con `git add`.
   - Realiza el commit con el formato del sistema:
     ```bash
     ./.agents/scripts/task.sh commit TASK-XXX "<descripción en imperativo>" [feat|fix|test|refactor|docs]
     ```
6. **Transición formal a QA con comandos de verificación**:
   - Ejecuta el comando de traspaso indicando los comandos de verificación (`--verify` repetible) y opcionalmente un resumen personalizado (`--summary`):
     ```bash
     ./.agents/scripts/task.sh handoff TASK-XXX qa-security-agent \
       --verify "npm test" \
       --verify "npm run build" \
       --verify "./.agents/scripts/scan-secrets.sh --branch"
     ```
   - Este comando cambia el estado a `IN_REVIEW_QA`, genera el manifiesto `.agents/handoffs/handoff_TASK-XXX.json` con `verification_commands` y **registra automáticamente** la entrega en el historial cronológico (§7) de `GLOBAL_STATE.md`.
7. **Notificación de entrega**:
   - Informa al usuario emitiendo el resumen estructurado.

## Formato del Resumen de Entrega
```markdown
📦 **TASK-XXX entregada a QA**
- **Especialista**: <tu-rol>
- **Entregables**: <archivos principales modificados/creados>
- **Tests**: `<comando de prueba>` → <ej. 28/28 pasando>
- **Secretos**: `./.agents/scripts/scan-secrets.sh --branch` → ✅ Limpio
- **Criterios validados**:
  - [x] <criterio 1 de aceptación>
  - [x] <criterio 2 de aceptación>
- **Siguiente paso recomendado**: `/qa-review TASK-XXX`
```

## Checklist de Handoff
- [ ] Checklist específico de la skill del especialista completado al 100%.
- [ ] Tests automatizados pasando sin fallos.
- [ ] Build del proyecto exitoso y sin errores de tipado o compilación.
- [ ] Escaneo de secretos limpio ejecutado con `./.agents/scripts/scan-secrets.sh --branch`.
- [ ] Cambios confirmados con commit convencional referenciando a `TASK-XXX`.
- [ ] Manifiesto de handoff y registro en historial generados con `task.sh handoff TASK-XXX --verify "<cmd>"`.

## Prohibido
- Ejecutar `task.sh handoff` con pruebas fallidas o builds con errores.
- Realizar handoff con credenciales, tokens o archivos `.env` detectados por `scan-secrets.sh --branch`.
- Marcar la propia tarea como `DONE` (únicamente `qa-security-agent` puede cerrar tareas tras revisión).
- Omitir los comandos reproducibles de verificación en el registro de `GLOBAL_STATE.md`.
