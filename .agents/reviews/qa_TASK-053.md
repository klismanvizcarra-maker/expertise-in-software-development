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

---

# Segunda revisión (iteración 2): APROBADA

- **Fecha**: 2026-11-18
- **Revisor**: `qa-security-agent` (subagente, contexto limpio)
- **Resultado**: `APROBADA` → `DONE`
- **Alcance**: `git diff main...HEAD` (20 archivos) y el commit `f8dd203` (cambio desde el rechazo).

## 1. BUG-TASK-053-1 (doble registro de la fase 1): CORREGIDO

| Camino | Fase Actual (§1) | Hito en §7 | Registro de la fase 1 | Aprobación del usuario |
| :--- | :--- | :--- | :--- | :--- |
| Stack ya declarado en §2 y sin placeholders | `crear-plan` paso 11 (rama "Si no") | `crear-plan` paso 11 | `crear-plan` paso 11 con el flujo de `/nueva-tarea` | Plan `APPROVED` (paso 10) + confirmación de `/nueva-tarea` paso 5 |
| Stack `PENDIENTE DE CONFIRMAR` o placeholders | `iniciar-proyecto` paso 4 (fase 1 del plan) | `iniciar-proyecto` paso 4 (enlaza el plan) | `iniciar-proyecto` paso 5; `crear-plan` "termina aquí y no registra nada" | Plan `APPROVED` + stack confirmado (paso 3) + confirmación de `/nueva-tarea` paso 5 |

En cada camino una sola skill hace las tres acciones. Checklist de `crear-plan` ("una sola vez, por `/crear-plan` o por `/iniciar-proyecto`, no por ambas") y Prohibido 1 (nada sin aprobación del plan) son coherentes. `cerrar-fase` paso 7 sigue siendo el único que activa las fases siguientes, con confirmación. QUICKSTART (`/crear-plan` → `/iniciar-proyecto` → fase 1) coincide con el camino del stack pendiente. Sin contradicciones con AGENTS.md §3: todos los cambios de estado pasan por `task.sh add` vía `/nueva-tarea`.

## 2. BUG-TASK-053-2 (límites en un solo sentido): CORREGIDO

- `orchestrator-agent` → "ni para redactar el plan maestro del proyecto completo (crear-plan)"; `crear-plan` lo ejecuta el orchestrator, así que no necesita excluirlo.
- `product-manager-agent` ↔ `crear-plan`: ambos se excluyen.
- `nueva-tarea` ↔ `crear-plan`: ambos se excluyen.
- `orch-01` y `nt-01` tienen `crear-plan` en `forbid`.
- `lint_descriptions.py`: "Sin problemas".

## 3. Criterios de aceptación

Siguen cumpliéndose todos los de la primera revisión; el que quedó ⚠️ (registro solo de la fase 1) ahora es ✅. La activación sigue en 30/30 en `tests/triggers/results/2026-11-18_0151-claude.json` (plan-01, plan-02, orch-01, nt-01 y pm-01 ideales; ninguna skill prohibida). Una repetición de esos 5 casos (`2026-11-18_0154-claude.json`) no concluyó nada: nt-01 ✅ (ideal) y los otros 4 dieron error de entorno por el límite de uso de la cuenta ("hit your 5-hour limit"), no fallos de activación.

## 4. Comandos ejecutados

| Comando | Resultado |
| :--- | :--- |
| `bash tests/test-skills.sh` | 38 skills sin errores (exit 0) |
| `python3 tests/triggers/lint_descriptions.py` | Sin problemas (exit 0) |
| `bash tests/test-scripts.sh` | 338 OK, 0 fallidas (exit 0) |
| `bash tests/test-flow.sh` | 25 OK, 0 fallidas (exit 0) |
| `./.agents/scripts/validate-state.sh` | 0 advertencias (exit 0) |
| `./.agents/scripts/scan-secrets.sh --branch` | Sin hallazgos (exit 0) |
| `python3 tests/triggers/run_claude.py --only plan-01,plan-02,orch-01,nt-01,pm-01` | 1/5; los 4 restantes, error por límite de uso (no concluyente) |

## 5. Observaciones (BAJA, no bloqueantes)

1. `iniciar-proyecto` paso 5: el paréntesis de responsable único solo nombra el caso del stack `PENDIENTE DE CONFIRMAR`, mientras que `crear-plan` paso 11 también deriva cuando hay placeholders. La regla general del paso 5 ya cubre ese caso, pero el paréntesis podría decir "cuando `/crear-plan` le pasó la activación".
2. La descripción de `cerrar-fase` no excluye `crear-plan` ("qué sigue después de esta fase" frente a "en qué orden"); `crear-plan` sí excluye `cerrar-fase`. Hoy no hay casos que choquen.
3. Rama "Si no" de `crear-plan` paso 11: si `/iniciar-proyecto` ya registró tareas genéricas de la fase 1 antes de que existiera el plan, la única defensa contra duplicados es `/nueva-tarea` paso 1. Se podría repetir ahí el "si ya están en el tablero, no las repitas".
4. `product-manager-agent` mantiene "priorizar un roadmap" (activador compartido con `crear-plan`); el límite explícito y plan-02 (ideal) lo mitigan.

## 6. Lección y veredicto

- **Lección**: `LL-010`. Su antídoto ampliado en esta rama ("si dos skills encadenadas pueden ejecutar la misma acción, asignarla a una sola y que la otra lo diga, y que los límites de las descripciones vayan en los dos sentidos") cubre exactamente los dos bugs. No hace falta una lección nueva.
- **Deuda técnica**: ninguna.
- **Estado**: `APROBADA`, cierre con `task.sh close TASK-053 --lesson LL-010`. La fusión a `main` y el borrado de la rama quedan para el especialista o el orchestrator.
