---
name: qa-review
description: Veredicto de QA de una tarea en IN_REVIEW_QA - tests y build propios, cada criterio de aceptación, seguridad, y aprobación (close) o rechazo (reject) con límite de 3. Usar cuando piden revisar o aprobar una TASK-XXX. Sin tarea en revisión, usar qa-security-agent.
---

# /qa-review — Veredicto Independiente de QA

Actúas como `qa-security-agent` (carga su skill: contiene el protocolo detallado de revisión y la matriz de severidad).

## Pasos

1. **Elegir la tarea**: toma el ID especificado por el usuario, o la tarea en `IN_REVIEW_QA` de `./.agents/scripts/task.sh list`. Si la tarea no se encuentra en `IN_REVIEW_QA`, detente e indícalo.
2. **Reunir la entrega**:
   - Criterios de aceptación de la tarea en `GLOBAL_STATE.md`.
   - Contador de iteraciones `n/3`.
   - Registro en §7 con los comandos de verificación del especialista.
   - Archivo de entrega `.agents/handoffs/handoff_TASK-XXX.json`.
   - Escenarios Gherkin en `docs/product/` si existen.

   **Contexto limpio (QA sin sesgo de implementación)**:
   - **Antigravity**: si en la conversación actual se implementó el código de la tarea, invoca un subagente independiente con `invoke_subagent`:
     ```json
     {
       "Role": "QA Security Auditor",
       "TypeName": "self",
       "Model": "inherit",
       "Prompt": "Audita de forma independiente la entrega de TASK-XXX en la rama actual. Criterios de aceptación: <criterios>. Ejecuta tests del proyecto, build y ./.agents/scripts/scan-secrets.sh --branch. Audita seguridad (OWASP Top 10, IDOR, inyección). Devuelve únicamente la tabla de hallazgos clasificados por severidad y con evidencia."
     }
     ```
     Aplica el veredicto con el reporte devuelto por el subagente.
   - **Claude Code**: si en esta conversación se implementó la tarea, delega los pasos 3–4 a un subagente (herramienta `Agent`) con prompt aislado.
3. **Verificación independiente**:
   - Ejecuta por tu cuenta los comandos de verificación, los tests automatizados (`npm test` o equivalente) y el build.
   - Ejecuta obligatoriamente el escáner de secretos:
     ```bash
     ./.agents/scripts/scan-secrets.sh --branch
     ```
   - Revisa el diff de la rama (`git diff main...HEAD` o sobre los archivos entregados).
4. **Auditoría de seguridad y casos límite**:
   - Casos vacíos, valores extremos, errores de red y tokens expirados.
   - Auditoría OWASP: IDOR, inyección, sanitización y filtrado de trazas en errores 500.
5. **Veredicto y transición**:
   - **Aprobado** (sin fallos o únicamente observaciones cosméticas BAJA):
     Genera el archivo de veredicto `.agents/reviews/qa_TASK-XXX.md` a partir de [qa_review_template.md](../../templates/qa_review_template.md) documentando la evidencia y declarando el revisor (`- **Revisor**: qa-security-agent`, obligatorio que sea distinto del agente asignado a la tarea). Luego ejecuta:
     ```bash
     ./.agents/scripts/task.sh close TASK-XXX
     ```
     `task.sh close` valida automáticamente que `.agents/reviews/qa_TASK-XXX.md` exista, que el revisor no coincida con el agente asignado, y muestra el comando exacto para fusionar a `main` y limpiar la rama:
     ```bash
     git checkout main && git merge --no-ff <rama> && git branch -d <rama>
     ```
     **Lección obligatoria**: si la tarea tuvo algún rechazo o corrige un defecto (rama `fix/` o descripción `Bug:`/`Fix:`/`Hotfix:`), `close` no la cierra sin lección. Registra primero lo aprendido con `/aprender` (`task.sh learn ... --paths "<globs>"`) y cierra con `./.agents/scripts/task.sh close TASK-XXX --lesson LL-XXX`; si de verdad no hay nada que aprender (errata, cambio trivial), justifícalo con `--no-lesson "<motivo>"`. Anótalo en el campo **Lección** del veredicto.
     Si se acepta deuda técnica de severidad MEDIA sin riesgo de seguridad:
     `./.agents/scripts/task.sh debt "<descripción>" TASK-XXX "<acción definitiva>" MEDIA`
   - **Rechazado** (falla ≥ 1 criterio de aceptación, test roto, vulnerabilidad o secreto expuesto):
     Redacta el defecto con [bug_report_template.md](../../templates/bug_report_template.md) y ejecuta:
     ```bash
     ./.agents/scripts/task.sh reject TASK-XXX "<motivo en una línea>"
     ```
     Si detectas que el fallo incumple una lección activa existente, cita explícitamente su ID (ej. `"... (LL-006)"`) en el motivo de `task.sh reject`: citar `LL-XXX` garantiza la detección y el registro automático de la reincidencia en `.agents/brain/recurrences.md` incluso cuando el motivo esté parafraseado. Si `reject` avisa de una **reincidencia**, inclúyela en el bug report: la lección existía y no llegó a tiempo, así que hay que corregir su ámbito (`task.sh brain scope`) o su antídoto.
   - **Si el rechazo alcanza 3/3** (`BLOCKED`): detén el ciclo de iteraciones y solicita al `orchestrator-agent` el informe de escalamiento al humano.
6. **Historial y aprendizaje**:
   - `close` y `reject` actualizan §7 de `GLOBAL_STATE.md` automáticamente.
   - La lección de una tarea rechazada o de corrección se registra **antes** de `close` (ver paso 5); las reincidencias quedan en `.agents/brain/recurrences.md` y se resumen con `task.sh brain stats`.

## Formato del Veredicto
```markdown
## QA · TASK-XXX · iteración n/3 → ✅ APROBADA | ❌ RECHAZADA

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| <criterio 1> | ✅ | `npm test` → 24/24 pasando |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → limpio |
| IDOR en `GET /orders/:id` | ❌ ALTA | Usuario B accede a recursos de Usuario A |

**Bugs**: BUG-TASK-XXX-1 (ALTA) — Descripción y pasos de reproducción
**Siguiente paso**: <close ejecutado | especialista retoma con task.sh start TASK-XXX>
```

## Checklist antes de emitir veredicto
- [ ] Tests automatizados del proyecto ejecutados de forma independiente.
- [ ] Escáner `./.agents/scripts/scan-secrets.sh --branch` ejecutado con resultado limpio.
- [ ] Diff de código inspeccionado en busca de inyecciones, IDOR o manejo inseguro de errores.
- [ ] Cada criterio de aceptación de la tarea contrastado con evidencia verificable.
- [ ] En caso de rechazo, motivo claro con pasos de reproducción registrado.
- [ ] Archivo de veredicto generado en `.agents/reviews/qa_TASK-XXX.md` con revisor independiente.

## Prohibido
- Aprobar basándose exclusivamente en el reporte verbal del especialista.
- Auto-aprobar una tarea (el revisor no puede ser el especialista asignado a la tarea).
- Cerrar la tarea con `task.sh close` sin haber registrado el veredicto en `.agents/reviews/qa_TASK-XXX.md`.
- Modificar o corregir el código del especialista desde el rol de QA.
- Omitir el escaneo de secretos antes de emitir la aprobación.
