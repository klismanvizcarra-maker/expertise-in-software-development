# Glosario del Dominio e Invariantes (Domain Glossary)

> **Propósito**: Lenguaje común de la librería SKILL MAESTRO, para que todos los agentes llamen igual a las mismas cosas. Los proyectos que la instalan parten de `.agents/templates/domain_glossary_template.md`.

---

## 1. Conceptos Clave

| Concepto | Definición | Dónde vive |
| :--- | :--- | :--- |
| **Skill** | Paquete de instrucciones que el asistente carga cuando la petición coincide con su `description` o se invoca con `/nombre` | `.agents/skills/<nombre>/SKILL.md` |
| **Skill de rol** | Define el proceso y los límites de un agente (`*-agent`) | `.agents/skills/*-agent/` |
| **Skill de flujo** | Paso recurrente del ciclo (`/nueva-tarea`, `/handoff`, `/qa-review`...) | `.agents/skills/` |
| **Skill de stack** | Convenciones concretas de una tecnología (`stack-*`); manda sobre la de rol en estructura y comandos | `.agents/skills/stack-*/` |
| **Skill de técnica** | Conocimiento transversal (pagos, SEO, rendimiento, i18n, E2E) | `.agents/skills/` |
| **Tarea (`TASK-XXX`)** | Unidad de trabajo con agente asignado y criterios de aceptación verificables | Tablero de `GLOBAL_STATE.md` |
| **Handoff** | Entrega formal del especialista a QA, con entregables y comandos de verificación | `.agents/handoffs/handoff_TASK-XXX.json` |
| **Veredicto** | Resultado de la revisión de QA (aprobada o rechazada) con evidencia | `.agents/reviews/qa_TASK-XXX.md` |
| **Iteración (`n/3`)** | Número de rechazos de QA acumulados por una tarea | Columna del tablero |
| **Lección (`LL-XXX`)** | Problema, causa raíz y antídoto que no debe repetirse; `ACTIVO` u `OBSOLETA` | `BRAIN.md` y `.agents/brain/lessons_learned.md` |
| **Deuda técnica (`TD-XXX`)** | Solución provisional aceptada, vinculada a una tarea; termina `SALDADA` | `.agents/brain/tech_debt.md` |
| **Plantilla** | Archivo genérico que `init-project.sh` copia a un proyecto | `.agents/templates/` |
| **Instancia** | Estado y cerebro de un proyecto concreto (incluida esta librería) | `GLOBAL_STATE.md`, `BRAIN.md`, `.agents/brain/` |

---

## 2. Invariantes (Reglas Inviolables)

1. **Transiciones solo con `task.sh`**: el estado de una tarea no se edita a mano en `GLOBAL_STATE.md`.
2. **Nadie aprueba su propio trabajo**: el revisor del veredicto es distinto del agente asignado, y revisa con contexto limpio.
3. **Tres rechazos bloquean**: a `3/3` la tarea queda `BLOCKED` y solo una decisión humana la reabre.
4. **Fuente única de skills**: se editan en `.agents/skills/`; `.claude/skills` es un enlace, nunca una copia divergente.
5. **Los IDs no se reutilizan**: `TASK-`, `LL-` y `TD-` son permanentes aunque la entrada se cierre, se retire o se salde.
6. **Las plantillas no llevan estado**: ninguna lección, deuda o tarea real de la librería entra en `.agents/templates/`.
