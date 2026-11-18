# Veredicto de QA: TASK-053

- **Tarea**: `TASK-053`
- **Fecha**: 2026-11-18
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `docs-architecture-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3` (primer rechazo)

Revisión con contexto limpio (subagente), sobre `git diff main...HEAD` de `feature/TASK-053-anadir-skill-de-flujo-crear-pl` (15 archivos, +214/-12).

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| SKILL.md con Pasos, Checklist y Prohibido, ejecutada por orchestrator-agent | ✅ | `.agents/skills/crear-plan/SKILL.md`: 12 pasos, checklist de 8 puntos, Prohibido de 6 puntos; `test-skills.sh` valida las secciones |
| Parte de la idea, `docs/research/` y `docs/product/` | ✅ | Paso 1; si no hay informe ni PRD y la idea es difusa, deriva a `research-agent` / `product-manager-agent` y se detiene |
| `docs/plan/plan-maestro.md` con plantilla nueva (visión, alcance MVP/v1/v2, arquitectura Mermaid y ADR, módulos con agente y skills, fases, Gantt con camino crítico y rangos con supuestos, riesgos, calidad, lanzamiento) | ✅ | `.agents/templates/plan_maestro_template.md` §1-§12; enlace relativo validado por `test-skills.sh` |
| Exige aprobación del usuario y registra con task.sh solo la fase 1 | ⚠️ MEDIA | Paso 11 y Prohibido 1-2 lo dicen, pero el responsable del registro de la fase 1 es ambiguo entre `crear-plan` e `iniciar-proyecto` (BUG-TASK-053-1) |
| Integrada en AGENTS.md §2.5 y §8, orchestrator, iniciar-proyecto, cerrar-fase, PM, research, README, QUICKSTART, system_map, CHANGELOG | ✅ | Presente en todos (diff); `ls .agents/skills` = 38 = README y system_map; sin "37 skills" fuera de reviews históricos |
| cerrar-fase toma la fase siguiente del plan y compara real vs planificado | ✅ | Paso 7 + checklist; §11 de la plantilla existe ("Seguimiento (real frente a planificado)") |
| ≥2 casos en cases.json que activan crear-plan contra Claude | ✅ | `plan-01`, `plan-02`; `tests/triggers/results/2026-11-18_0141-claude.json`: 20/20 pass, ambos casos cargan solo `crear-plan` (ideal) |
| test-skills, lint_descriptions y test-scripts en verde | ✅ | `test-skills.sh` 38 skills sin errores (exit 0); `lint_descriptions.py` "Sin problemas" (exit 0); `test-scripts.sh` 338 OK, 0 fallidas (exit 0) |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` sin hallazgos (exit 0) |
| Batería adicional | ✅ | `test-flow.sh` 25 OK, 0 fallidas; `validate-state.sh` 0 advertencias (exit 0) |
| Auditoría de seguridad | ✅ | Solo documentación; sin secretos, comandos destructivos ni rutas fuera del gobierno |

## 2. Contraste LL-010

- `docs/plan/`: en la matriz §8 (`orchestrator-agent`) y permitido por `require-active-task.sh` línea 64 (`*.md|docs/*`).
- Secciones citadas: GLOBAL_STATE §1, §2, §6, §7 existen en la plantilla; §11 de `plan_maestro_template.md` existe.
- Stack `PENDIENTE DE CONFIRMAR`: coherente entre crear-plan paso 3, iniciar-proyecto paso 3 y la plantilla §3.
- Antigravity `UserFacing: true`, `RequestFeedback: true`: igual que `research-agent` y `product-manager-agent`.
- Cambios de estado solo con `task.sh` (`/nueva-tarea` → `task.sh add`); cerrar-fase y crear-plan exigen confirmación del usuario antes de registrar o cambiar la fase.
- **Fallo**: el reparto de responsabilidades entre crear-plan paso 11 e iniciar-proyecto pasos 4-5 no es coherente (BUG-TASK-053-1). El motivo cita LL-010 y `task.sh reject` lo anotó como reincidencia.

## 3. Bugs

### BUG-TASK-053-1 — MEDIA — Componente: Docs/flujo

**Descripción**: dos skills se declaran responsables de registrar las tareas de la fase 1 del plan aprobado, y las dos tocan la Fase Actual (§1) y añaden un hito en §7, justo en el flujo principal documentado (QUICKSTART: `/crear-plan` → `/iniciar-proyecto` → fase 1).

**Reproducción**:
1. Proyecto nuevo: GLOBAL_STATE §2 sin stack, así que `crear-plan` marca el stack `PENDIENTE DE CONFIRMAR` (paso 3).
2. El plan se aprueba. `crear-plan` paso 11: actualiza la Fase Actual, registra la fase 1 con `/nueva-tarea` y "si el stack estaba PENDIENTE DE CONFIRMAR, ejecuta antes `/iniciar-proyecto`".
3. `iniciar-proyecto` paso 4 completa §1 y añade un hito en §7; el paso 5 dice "si hay un plan maestro aprobado, registra las tareas de su fase 1".
4. Al volver a `crear-plan` paso 11, el segundo punto vuelve a mandar registrar la fase 1 y añadir el hito → doble registro (solo lo evita la comprobación de duplicados del paso 1 de `nueva-tarea`) y dos hitos.

**Observado**: no hay un único responsable; además, el orden de los puntos del paso 11 (la condición "ejecuta antes" está en último lugar) contradice su propia secuencia.
**Esperado**: un solo dueño del registro de la fase 1 y de la actualización de §1/§7 cuando se encadenan las dos skills (criterio "registra con task.sh solo la fase 1"; LL-010).

**Recomendación**: en crear-plan paso 11, pon primero la condición del stack y di de forma explícita que, si se ejecuta `/iniciar-proyecto`, este registra la fase 1 del plan (pasos 4-5) y crear-plan no la vuelve a registrar ni añade otro hito. También vale lo contrario: que iniciar-proyecto paso 5 no registre nada si viene de `/crear-plan`. Revisa que QUICKSTART describa el mismo orden.

### BUG-TASK-053-2 — BAJA — Componente: Descripciones de skills

**Descripción**: `crear-plan` se activa con "roadmap", pero `product-manager-agent` dice "cuando hay que priorizar un roadmap" y `orchestrator-agent` dice "al planificar fases". Ninguna de las dos excluye `crear-plan`, así que el límite solo existe en un sentido (sí está en `nueva-tarea`). La activación medida pasa (plan-02 acepta product-manager-agent).
**Recomendación**: añade en esas dos descripciones el límite hacia `crear-plan` (plan completo del proyecto con todas sus fases) y vuelve a ejecutar `lint_descriptions.py`.

## 4. Observaciones (BAJA, no bloqueantes)

1. Gantt: el título dice "rangos estimados", pero las barras usan una duración única (`14d`, `28d`) porque Mermaid no admite rangos. Conviene indicar qué extremo se dibuja (p. ej. el superior) y remitir al rango de la cabecera de cada fase. Sintaxis `gantt` (`dateFormat`, `section`, `:id, fecha, Nd`, `after f1`) y `graph LR` (`[( )]`, etiquetas con `:` y comas) válidas; las fechas `YYYY-MM-DD` son marcadores que hay que rellenar.
2. Ningún caso negativo prohíbe `crear-plan` en prompts de una sola funcionalidad (p. ej. `orch-01` "planifica el trabajo", `nt-01`). Añadir `crear-plan` a su `forbid` protegería el límite frente a `nueva-tarea`.
3. `plan-01` y `plan-02` son coherentes con el resto (tipo `entrada`, como `ini-*` y `research-*`; sin solapes entre expect, accept y forbid).

- **Deuda Técnica**: ninguna registrada.
- **Lección**: obligatoria al cierre por el rechazo. Reincidencia de LL-010 registrada en `.agents/brain/recurrences.md`; conviene ampliar su antídoto con "las skills que se encadenan no deben duplicar ni dejar ambigua la misma acción (registro de tareas, cambio de fase, hitos)".

## 5. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Siguiente paso**: `docs-architecture-agent` retoma con `./.agents/scripts/task.sh start TASK-053`, corrige BUG-TASK-053-1 (y BUG-TASK-053-2) y vuelve a `/handoff`.
