---
name: adoptar-proyecto
description: Incorpora el gobierno multi-agente a un repositorio ya construido (brownfield) sin reescribirlo - mapea rutas reales, deuda heredada y primeras tareas. Usar tras init-project.sh --adopt. No usar para proyectos desde cero (iniciar-proyecto).
---

# /adoptar-proyecto — Incorporación en Proyecto Existente (Brownfield)

Actúas como `orchestrator-agent` (carga su skill). Integras el sistema multi-agente de forma progresiva sobre un repositorio que ya tiene código, historial o configuración previa, sin sobrescribir ni romper lo existente.

## Pasos

1. **Verificar instalación en modo `--adopt`**:
   - Comprueba en la raíz que existen `.agents/skills/`, `.agents/scripts/task.sh`, `AGENTS.md`, `CLAUDE.md` (con `@AGENTS.md`), `GLOBAL_STATE.md` y `BRAIN.md`.
   - Si todavía no se ha instalado el sistema sobre el repositorio existente, indica al usuario ejecutar desde la librería:
     ```bash
     ./.agents/scripts/init-project.sh --adopt "/ruta/al/proyecto-existente"
     ```
     (añade `--stack nextjs|angular|fastapi` y `--ci` si aplica y todavía no existe workflow en `.github/workflows/`).

2. **Inventariar el codebase existente (solo lectura)**:
   - Manifiestos y runtimes: `package.json`, `pyproject.toml`, `requirements.txt`, `Dockerfile`, `docker-compose.yml`, lockfiles.
   - Arquitectura y datos: árbol principal de código fuente (`src/`, `app/`, `apps/`, `server/`), migraciones/esquemas (`prisma/`, `alembic/`, `drizzle/`).
   - Verificación previa: comandos actuales de `lint`, `typecheck`, `test`, `build` y pipelines en `.github/workflows/`.
   - Documentación y reglas previas: `README.md`, `docs/`, `AGENTS.md`, `CLAUDE.md` y hooks previos.

3. **Alinear `GLOBAL_STATE.md` y `AGENTS.md` con la realidad del repo**:
   - Completa §1 (nombre real, alcance en una frase, `Estado Actual: IN_PROGRESS`, `Fase Actual`) y §2 (stack real detectado) en `GLOBAL_STATE.md`. Elimina filas de ejemplo (`TASK-001`, `TASK-002` de plantilla) si siguieran presentes.
   - Documenta en §2 la skill de stack correspondiente si coincide (`stack-nextjs-tailwind-prisma`, `stack-angular-express-postgres`, `stack-fastapi-postgres`); si el proyecto usa otro stack, documenta las convenciones locales partiendo de [stack_template.md](../../templates/stack_template.md) y deja el ADR en §6.
   - Si la API o dominio ya tiene contratos críticos estables que vayan a tocarse pronto, resume los principales en §4.
   - Ajusta las rutas de la matriz de propiedad en `AGENTS.md` §8 si la estructura de carpetas del repo difiere de la tabla genérica.

4. **Sembrar memoria y deuda técnica heredada (`BRAIN.md`)**:
   - Registra las decisiones arquitectónicas ya consolidadas en el código dentro de §6 de `GLOBAL_STATE.md` como filas `APROBADO`.
   - Documenta la topología real en `.agents/brain/system_map.md` y los términos clave de negocio en `.agents/brain/domain_glossary.md`.
   - Registra hallazgos críticos detectados en el inventario inicial (p. ej. falta de tests en módulo crítico, secretos o configs frágiles, ausencia de CI) como deuda técnica con `./.agents/scripts/task.sh debt "<descripción>" TASK-000 "<acción definitiva>" ALTA|MEDIA|BAJA`.

5. **Planificar las primeras tareas de transición**:
   - Propone al usuario entre 2 y 5 primeras tareas concretas (estabilización de pruebas/CI, cierre de deuda `ALTA` o primer entregable funcional) con especialista y criterios de aceptación verificables.
   - Tras confirmación explícita del usuario, regístralas con `/nueva-tarea`.

6. **Validar estado e integridad**:
   ```bash
   ./.agents/scripts/validate-state.sh
   ./.agents/scripts/task.sh brain doctor
   ```
   Asegura `0` errores y muestra un resumen inicial con `/estado`.

## Checklist antes de cerrar la adopción
- [ ] Entorno instalado con `init-project.sh --adopt` conservando `README.md`, `.gitignore`, `.env.example`, código y configuraciones previas intactos.
- [ ] `GLOBAL_STATE.md` §1 y §2 reflejan el proyecto y stack reales sin placeholders pendientes.
- [ ] `AGENTS.md` §8 y `.agents/brain/system_map.md` alineados con las rutas reales del repositorio.
- [ ] Deuda técnica heredada crítica (`ALTA`) registrada en `.agents/brain/tech_debt.md` y primeros `ADR` heredados anotados en §6.
- [ ] Primeras tareas reales acordadas con el usuario y registradas tras confirmación.
- [ ] `./.agents/scripts/validate-state.sh` y `./.agents/scripts/task.sh brain doctor` pasan sin errores.

## Prohibido
- Sobrescribir código fuente existente, `README.md`, `.gitignore`, `.env.example`, configuraciones de CI o hooks propios sin autorización expresa.
- Reescribir o refactorizar módulos enteros solo por estilo sin bug ni tarea aprobada.
- Dejar placeholders (`[NOMBRE_DEL_PROYECTO]`, `[Framework:...]`) ni tareas ficticias de plantilla en `GLOBAL_STATE.md`.
- Registrar tareas en el tablero sin confirmación del usuario ni criterios de aceptación verificables.

