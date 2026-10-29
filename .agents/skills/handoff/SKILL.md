---
name: handoff
description: Entrega formal de una tarea terminada a QA - verifica el checklist de la skill del especialista, ejecuta tests y build, registra entregables y comandos de verificación en GLOBAL_STATE.md y pasa la tarea a IN_REVIEW_QA con task.sh handoff. Usar cuando un especialista termina su trabajo en una TASK-XXX o el usuario dice "entrega", "listo para QA" o "handoff". No usar para emitir el veredicto (qa-review) ni para crear tareas (nueva-tarea).
---

# /handoff — Entrega a QA

Lo ejecuta el especialista dueño de la tarea, nunca QA ni el Orchestrator.

## Pasos

1. **Identificar la tarea**: usa el ID que dio el usuario; si no hay, toma la tarea `IN_PROGRESS` del tablero (`./.agents/scripts/task.sh list`). Si hay varias, pregunta.
2. **Cargar la skill del agente asignado** y recorrer su sección *Checklist antes de `task.sh handoff`*, ítem por ítem.
3. **Verificar con evidencia**: ejecuta los tests y el build del proyecto (ej. `npm test`, `npm run build`) y comprueba cada criterio de aceptación de la tarea.
   - Si algo falla, **no hagas el handoff**: corrige o informa al usuario qué falta.
4. **Registrar** una fila en el registro cronológico de `GLOBAL_STATE.md` (§7):
   ```markdown
   | `YYYY-MM-DD` | <agente> | qa-security-agent | `TASK-XXX` | <qué se entregó>. Verificar: `<comando 1>`, `<comando 2>` |
   ```
   Si la tarea cambió un contrato de API, confirma que §4 está actualizado.
5. **Commit** de los cambios en la rama de la tarea (aplica la convención `tipo(TASK-XXX): …`; los archivos nuevos se añaden antes con `git add`):
   ```bash
   ./.agents/scripts/task.sh commit TASK-XXX "<descripción en imperativo>" [feat|fix|test|refactor|docs|...]
   ```
6. **Transicionar**:
   ```bash
   ./.agents/scripts/task.sh handoff TASK-XXX
   ```
   Esto pasa la tarea a `IN_REVIEW_QA` y genera `.agents/handoffs/handoff_TASK-XXX.json` con la iteración y los archivos modificados (cambios de la rama + sin commitear).
7. **Informar** al usuario: tarea, entregables, resultados de los tests y siguiente paso (`/qa-review TASK-XXX`).

## Formato del resumen de entrega
```markdown
📦 **TASK-XXX entregada a QA**
- Entregables: <archivos o módulos principales>
- Tests: <comando> → <resultado, p. ej. 24/24 en verde>
- Criterios: ✅ <criterio 1> · ✅ <criterio 2>
- Limitaciones conocidas: <ninguna | detalle>
```
