# Veredicto de QA — `TASK-046`

- **Tarea**: `TASK-046` — Modo adopción brownfield (`adoptar-proyecto` y `--adopt`) y archivado de fases (`task.sh archive`)
- **Rama**: `feature/TASK-046-modo-adopcion-brownfield-adopt`
- **Commit auditado**: `fffdc94`
- **Revisor**: `qa-security-agent`
- **Subagente independiente**: `95b8f0b4-9056-4add-ba30-a7b41e92fb7b`
- **Veredicto**: `APROBADO`

## Resumen de Verificación Independiente
- **Criterios de aceptación**: todos cumplidos:
  - `.agents/skills/adoptar-proyecto/SKILL.md` cumple formato estructural completo, delimitaciones (`iniciar-proyecto`, `nueva-tarea`, `qa-review`), enlace a `stack_template.md` y comandos reales (`init-project.sh --adopt`, `task.sh debt`, `validate-state.sh`, `task.sh brain doctor`).
  - `init-project.sh --adopt` valida directorio destino y conflicto con `--update`, conserva código fuente, `README.md`, `.gitignore`, `.env.example`, `.mcp.json`, `.claude/settings.json`, `AGENTS.md`, `GLOBAL_STATE.md`, `BRAIN.md` y `.git/hooks/` personalizados (`install-hooks.sh --preserve-existing`), añade `@AGENTS.md` sin sobrescribir `CLAUDE.md` previo, y al crear `GLOBAL_STATE.md` nuevo limpia `TASK-001`/`TASK-002` y fija `FASE 0: Adopción e Inventario (Brownfield)`.
  - `task.sh archive [--keep N] [--phase "<fase>"]` archiva tareas `DONE` en `.agents/archive/tasks_YYYY-MM-DD.md` bajo lock de concurrencia preservando `next_id`, `task.sh metrics` (activas + archivadas + rechazos), `require_task` y `validate-state.sh` (validación y detección de IDs duplicados entre tablero y archivo).
  - `.agents/skills/cerrar-fase/SKILL.md` y `AGENTS.md` actualizados en coherencia; `tests/triggers/cases.json` cubre `adoptar-proyecto` (`adp-01`, `adp-02`); `tests/test-scripts.sh` añade 13 comprobaciones dedicadas en verde.
- **Suite ejecutada**:
  - `LC_ALL=C bash tests/test-scripts.sh`: `Resultado: 282 OK, 0 fallidas`
  - `bash tests/test-flow.sh`: `Resultado: 25 OK, 0 fallidas`
  - `bash tests/test-skills.sh`: `36 skills auditadas sin errores`
  - `python3 tests/triggers/lint_descriptions.py`: `Skills: 36 · Casos: 82` / `Sin problemas`
  - `./.agents/scripts/validate-state.sh`: `0 errores (0 advertencias)`
  - `./.agents/scripts/task.sh brain doctor`: `Cerebro sano`
  - `./.agents/scripts/scan-secrets.sh --branch`: `Escaneo de secretos sin hallazgos`
- **Observaciones no bloqueantes (`BAJA`)**: limpiar opcionalmente fila de ejemplo §7 y §4 en `GLOBAL_STATE.md` generado por `--adopt` sin `--stack`, normalizar `10#$KEEP` si se pasara `--keep 08`, y ejecutar `run_claude.py` en batería con LLM externa.
