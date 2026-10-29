---
name: iniciar-proyecto
description: Arranca un proyecto con el sistema multi-agente - verifica la instalación (.agents, AGENTS.md, CLAUDE.md, GLOBAL_STATE.md), acuerda con el usuario el stack tecnológico, completa los metadatos de GLOBAL_STATE.md, limpia las tareas de ejemplo y planifica las primeras tareas. Usar cuando el usuario quiere empezar un proyecto nuevo, configurar el stack o cuando GLOBAL_STATE.md no existe o aún tiene placeholders.
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
   Si la idea es difusa, propone pasar antes por `/product-manager-agent`.
3. **Proponer el stack** (frontend, backend, persistencia, auth, despliegue) con una línea de justificación por pieza y pide confirmación.
4. **Completar `GLOBAL_STATE.md`**: metadatos (§1), stack (§2), la decisión de stack como primera fila ADR (§6) y un hito en el registro (§7). Elimina las tareas de ejemplo `TASK-001`/`TASK-002` de la plantilla si siguen sin tocar.
5. **Planificar la fase 1** con el flujo de `/nueva-tarea`: típicamente estructura del repositorio y CI, sistema de diseño, esquema base y autenticación.
6. **Cerrar** con `./.agents/scripts/validate-state.sh` (sin placeholders pendientes) y un resumen tipo `/estado`.
