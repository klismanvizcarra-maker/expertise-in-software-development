---
name: qa-review
description: Revisa una tarea en IN_REVIEW_QA y emite el veredicto - ejecuta de forma independiente tests y build, comprueba cada criterio de aceptación, audita seguridad, y aprueba (task.sh close) o rechaza con bug report (task.sh reject), aplicando el límite de 3 iteraciones. Usar cuando el usuario pide revisar, auditar, aprobar o validar una TASK-XXX, o dice "QA" o "revisa la entrega". Para auditorías de seguridad o pruebas sin una tarea en revisión, usar qa-security-agent.
---

# /qa-review — Veredicto de QA

Actúas como `qa-security-agent` (carga su skill: contiene el protocolo de revisión y la matriz de severidad).

## Pasos

1. **Elegir la tarea**: el ID que dio el usuario, o la única tarea en `IN_REVIEW_QA` de `./.agents/scripts/task.sh list`. Si la tarea no está en `IN_REVIEW_QA`, detente y dilo.
2. **Reunir la entrega**: criterios de la tarea, iteración `n/3`, la fila del registro (§7) con los comandos de verificación, `.agents/handoffs/handoff_TASK-XXX.json` y los escenarios Gherkin del PRD si existen.
   **Contexto limpio** (QA no revisa con la memoria de quien implementó):
   - **Claude Code**: si en esta conversación se implementó la tarea, delega los pasos 3–4 a un subagente (herramienta `Agent`) cuyo prompt contenga **solo** lo reunido aquí, la rama y la instrucción de cargar `qa-security-agent` y devolver los hallazgos con severidad y evidencia. No le pases tu razonamiento ni el historial de la implementación. Tú aplicas el veredicto (paso 5) con lo que devuelva.
   - **Antigravity**: si esta conversación implementó la tarea, pide al usuario que abra una conversación nueva y ejecute ahí `/qa-review TASK-XXX`.
3. **Verificar por tu cuenta**: ejecuta los comandos de verificación, los tests y el build. Revisa el diff de los archivos entregados.
4. **Recorrer el protocolo** de `qa-security-agent` (criterios, casos límite, errores provocados, auditoría de seguridad) y clasifica cada hallazgo por severidad.
5. **Veredicto**:
   - **Aprobado** (sin hallazgos o solo BAJA):
     ```bash
     ./.agents/scripts/task.sh close TASK-XXX
     ```
   - **Rechazado** (al menos una CRÍTICA/ALTA, o MEDIA no aceptada como deuda): escribe cada bug con [bug_report_template.md](../../templates/bug_report_template.md) en el historial de `GLOBAL_STATE.md` o en `docs/qa/BUG-TASK-XXX-N.md`, y ejecuta:
     ```bash
     ./.agents/scripts/task.sh reject TASK-XXX "<motivo en una línea>"
     ```
   - **Si el rechazo deja la tarea en 3/3** (`BLOCKED`): no sigas; pide al `orchestrator-agent` el informe de escalamiento al humano.
6. **Historial**: `close` y `reject` ya registran el veredicto en §7 automáticamente. Si se aprobó la corrección de un defecto no trivial, sugiere `/aprender`.

## Formato del Veredicto
```markdown
## QA · TASK-XXX · iteración n/3 → ✅ APROBADA | ❌ RECHAZADA

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| <criterio 1> | ✅ | `npm test` → 24/24 |
| IDOR en `GET /orders/:id` | ❌ ALTA | Usuario B lee el pedido de A |

**Bugs**: BUG-TASK-XXX-1 (ALTA) …
**Siguiente paso**: <close realizado | especialista retoma con `task.sh start TASK-XXX`>
```
