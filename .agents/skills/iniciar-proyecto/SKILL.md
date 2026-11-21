---
name: iniciar-proyecto
description: Arranca un proyecto nuevo con el sistema multi-agente - verifica la instalación, acuerda el stack, completa GLOBAL_STATE.md y planifica las primeras tareas. Usar al empezar un proyecto o si GLOBAL_STATE.md falta o tiene placeholders. No usar en repositorios ya construidos (adoptar-proyecto).
---

# /iniciar-proyecto — Kickoff

Actúas como `orchestrator-agent` (carga su skill).

## Pasos

1. **Verificar instalación** en la raíz: `.agents/skills/`, `.agents/scripts/task.sh`, `AGENTS.md`, `CLAUDE.md` y `GLOBAL_STATE.md`.
   - Si falta `GLOBAL_STATE.md`, créalo desde [GLOBAL_STATE_TEMPLATE.md](../../templates/GLOBAL_STATE_TEMPLATE.md).
   - Si falta el resto, indica al usuario que ejecute `init-project.sh` desde el repositorio de skills (ver `QUICKSTART.md`) y detente.
2. **Entender el proyecto**: si el usuario no lo dio ya, pregunta en un solo mensaje:
   - Qué se construye y para quién (una frase).
   - Plataformas: web, móvil, ambas, API.
   - Preferencias o restricciones de stack, hosting y presupuesto.
   Si la idea es difusa, propone pasar antes por `/product-manager-agent`. Si hay productos de referencia que conviene estudiar (p. ej. Uber o InDrive para una app de taxis), propone `/research-agent` primero.
3. **Proponer el stack** (frontend, backend, persistencia, auth, despliegue) con una línea de justificación por pieza y pide confirmación. Si existe `docs/plan/plan-maestro.md`, parte del stack que propone (marcado `PENDIENTE DE CONFIRMAR`) y, una vez confirmado, actualiza su estado en el plan.
4. **Completar `GLOBAL_STATE.md`**: metadatos (§1), stack (§2), la decisión de stack como primera fila ADR (§6) y un hito en el registro (§7). Con un plan maestro aprobado, la Fase Actual es su fase 1 y el hito enlaza `docs/plan/plan-maestro.md`. Elimina las tareas de ejemplo `TASK-001`/`TASK-002` de la plantilla si siguen sin tocar.
5. **Planificar la fase 1** con el flujo de `/nueva-tarea`: si hay un plan maestro aprobado, registra las tareas de su fase 1 (es la única skill que lo hace cuando `/crear-plan` le pasó el stack `PENDIENTE DE CONFIRMAR`; si ya están en el tablero, no las repitas); si no, típicamente estructura del repositorio y CI, sistema de diseño, esquema base y autenticación. Si el usuario quiere ver antes el proyecto completo (fases, cronograma, riesgos), propone `/crear-plan`.
6. **Cerrar** con `./.agents/scripts/validate-state.sh` (sin placeholders pendientes) y un resumen tipo `/estado`.
