# Documento de Estado Global (Global State Document)

> **Única Fuente de Verdad (SSOT)**: Todos los agentes leen y sincronizan su estado a través del `Orchestrator` en este documento para garantizar consistencia arquitectónica, trazabilidad de tareas y evitar pérdida de contexto.

---

## 1. Metadatos del Proyecto

- **Proyecto**: `SKILL MAESTRO`
- **Descripción**: `Framework y catálogo multi-agente para Claude Code y Antigravity: directrices de gobernanza, roles especializados, scripts de ciclo de vida de tareas y batería de evals.`
- **Estado Actual**: `IN_PROGRESS`
- **Fase Actual**: `FASE 1: Evolución y Mejora de Skills`
- **Última Actualización**: `2026-10-29`
- **Iteraciones Críticas Acumuladas**: `0 / 3`

---

## 2. Stack Tecnológico y Arquitectura

- **Core**: `Markdown (Skills & Prompts) con Frontmatter YAML`
- **Automatización**: `Bash (scripts de task.sh, init-project.sh, require-active-task.sh, validate-state.sh)`
- **Hooks & CI**: `Git hooks (pre-commit, commit-msg) + GitHub Actions`
- **Evals & Testing**: `Python 3 (triggers y evals) + Bash test suite`
- **Entornos soportados**: `Claude Code CLI + Antigravity IDE / CLI`

---

## 3. Matriz de Agentes y Responsabilidades

| Agente | Rol Principal | Skill Asociada |
| :--- | :--- | :--- |
| **Orchestrator** | Coordinación, backlog y gestión de SSOT | `orchestrator-agent` |
| **Product Manager** | Alcance de producto, User Stories (Gherkin) y flujos | `product-manager-agent` |
| **Backend & Data** | APIs, lógica de negocio y seguridad server | `backend-agent` |
| **Frontend & UI** | Componentes, vistas y experiencia web | `frontend-agent` |
| **Mobile & Native** | Apps móviles (React Native/Flutter/iOS/Android) | `mobile-agent` |
| **QA & Security** | Pruebas automatizadas, OWASP y veto | `qa-security-agent` |
| **Database** | Modelado, migraciones y optimización SQL | `database-architect-agent` |
| **DevOps** | Pipelines CI/CD, builds y despliegues | `devops-cloud-agent` |
| **UI/UX** | Tokens de diseño, accesibilidad y guías de estilo | `ui-ux-agent` |
| **Domain Logic** | Reglas puras de negocio y cálculos | `domain-logic-agent` |
| **AI Integrator** | Modelos LLM (Ollama/Cloud), RAG y embeddings | `ai-integrator-agent` |
| **Docs & Architecture** | Diagramas Mermaid, OpenAPI, ADRs y contratos | `docs-architecture-agent` |

---

## 4. Contratos de Integración Activos (APIs y DTOs)

*No aplican contratos de API HTTP directos al ser un framework de desarrollo de software y catálogo de skills.*

---

## 5. Tablero de Tareas Activas

| ID Tarea | Descripción | Asignado a | Estado | Iteración QA | Criterios de Aceptación |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `TASK-001` | Auditoría y diagnóstico de las skills actuales para identificar oportunidades de mejora | Orchestrator | `DONE` | `0/3` | Reporte de diagnóstico de las 26 skills completado y priorizado |
| `TASK-002` | Implementar linter automatizado de calidad estructural de skills | qa-security-agent | `DONE` | `0/3` | Script tests/test-skills.sh audita los 5 pilares en todas las skills; integrado en test-scripts.sh pasando al 100% |
| `TASK-003` | Crear plantilla de stack tecnológico y skill stack-nextjs-tailwind-prisma | docs-architecture-agent | `DONE` | `0/3` | Plantilla .agents/templates/stack_template.md creada; skill stack-nextjs-tailwind-prisma con referencias de Next.js, Prisma, Tailwind y Auth; triggers validados |
| `TASK-004` | Incorporar gotchas de stacks y seguridad al Cerebro del proyecto | docs-architecture-agent | `DONE` | `0/3` | BRAIN.md actualizado con gotchas de Next.js/Prisma, Express 5, Angular SSR y Stripe; suites pasando al 100% |
| `TASK-005` | Estandarizar skills de flujo: nueva-tarea, aprender, release y web-performance | orchestrator-agent | `DONE` | `0/3` | Checklists y secciones Prohibido agregadas; linter estructural pasando al 100% |
| `TASK-006` | Elevar resiliencia en base de datos y DevOps (Expand/Contract, non-root, healthchecks) | database-architect-agent | `DONE` | `0/3` | Patron Expand/Contract e indices FK en database-architect; Docker non-root, healthchecks y graceful shutdown en devops; tests pasando |
| `TASK-007` | Soporte de selector de stack (--stack nextjs/angular) en init-project.sh | devops-cloud-agent | `DONE` | `0/3` | init-project.sh admite --stack nextjs y --stack angular configurando GLOBAL_STATE.md sin placeholders; test pasando |
| `TASK-008` | Fix: scan-secrets no revisa la entrega ya commiteada en QA y handoff | devops-cloud-agent | `IN_REVIEW_QA` | `0/3` | scan-secrets.sh --branch detecta un secreto commiteado en la rama respecto a main (test nuevo en tests/test-scripts.sh); qa-review, qa-security-agent, handoff y bugfix usan --branch; grep de scan-secrets.sh sin flag en .agents/skills devuelve 0 lineas; bash tests/test-scripts.sh al 100% |
| `TASK-009` | Fix: task.sh move permite saltarse el veto de QA | devops-cloud-agent | `TODO` | `0/3` | task.sh move TASK-X DONE sale con exit 1 desde cualquier estado; move solo acepta salir de BLOCKED o pasar a TODO/BACKLOG; tests nuevos en tests/test-scripts.sh; suite al 100% |
| `TASK-010` | Fix: slug de rama con tildes roto en macOS (iconv) | devops-cloud-agent | `TODO` | `0/3` | task.sh start sobre una tarea "Auditoría de diagnóstico" crea la rama feature/TASK-XXX-auditoria-de-diagnostico; test nuevo en tests/test-scripts.sh; suite al 100% en ubuntu y macos (CI) |
| `TASK-011` | Activar en la propia librería el hook de Claude Code y los git hooks | devops-cloud-agent | `TODO` | `0/3` | .claude/settings.json versionado con el hook require-active-task.sh; install-hooks.sh ejecutado y el paso documentado en QUICKSTART.md; un commit sin TASK-XXX es rechazado por commit-msg; bash tests/test-scripts.sh al 100% |
| `TASK-012` | Exigir veredicto registrado y revisor distinto del autor en task.sh close | devops-cloud-agent | `TODO` | `0/3` | task.sh close falla si no existe .agents/reviews/qa_TASK-XXX.md; close falla si el revisor declarado coincide con el agente asignado; qa-review genera el archivo de veredicto con la plantilla; tests nuevos en tests/test-scripts.sh al 100% |
| `TASK-013` | Definir fusión y limpieza de ramas tras la aprobación de QA | devops-cloud-agent | `TODO` | `0/3` | AGENTS.md §3 y §5 indican quién fusiona a main (merge --no-ff) y cuándo se borra la rama; qa-review o release incluyen el paso; task.sh close muestra el comando de fusión; git branch --merged main no lista ramas feature/TASK-001 a TASK-007; suite al 100% |
| `TASK-014` | Sanear el cerebro de la librería y separar sus módulos de las plantillas | orchestrator-agent | `TODO` | `0/3` | BRAIN.md y .agents/brain/ sin LL-001 a LL-003 ni TD-001 de ejemplo; al menos 3 lecciones reales (awk BSD sin \s, git diff -S, iconv en macOS); mapa del sistema describe skills, scripts y tests; comando learn con ruta ./.agents/scripts/task.sh; init-project instala módulos de cerebro genéricos desde .agents/templates (test en test-scripts.sh al 100%) |
| `TASK-015` | Ampliar y volver a ejecutar la batería real de activación de skills | qa-security-agent | `TODO` | `0/3` | tests/triggers/cases.json incluye al menos 2 casos de stack-nextjs-tailwind-prisma; lint_descriptions.py sin problemas; run_claude.py ejecutado tras TASK-001 a TASK-007 con al menos 55 aciertos y resultado guardado en tests/triggers/results; fallos analizados en el handoff |
| `TASK-016` | Fix: el control de tarea activa se puede esquivar | devops-cloud-agent | `TODO` | `0/3` | commit-msg rechaza commits cuya TASK-XXX no existe en el tablero de GLOBAL_STATE.md (si existe el archivo); require-active-task.sh bloquea con exit 2 si falta python3 en lugar de permitir; tests nuevos en tests/test-scripts.sh al 100% |
| `TASK-017` | Modo --update y versión en init-project.sh | devops-cloud-agent | `TODO` | `0/3` | Existe .agents/VERSION; init-project.sh --update sincroniza skills, scripts, plantillas y hooks sin tocar GLOBAL_STATE.md, BRAIN.md ni .agents/brain y elimina skills retiradas; --stack con valor desconocido sale con exit 1; nombres de proyecto con & o / se sustituyen literalmente; tareas de ejemplo de la plantilla usan nombres de skill; tests al 100% |
| `TASK-018` | Verificar el stack Next.js con un scaffold real y mapear sus rutas | docs-architecture-agent | `TODO` | `0/3` | Versiones de stack-nextjs-tailwind-prisma contrastadas con un proyecto real (create-next-app, prisma migrate, next build) y anotadas con fecha; AGENTS.md §8 mapea las rutas Next.js (app/, lib/, prisma/) a cada agente; test-skills.sh y lint_descriptions.py al 100% |
| `TASK-019` | Fijar versiones de dependencias externas (MCP y GitHub Actions) | devops-cloud-agent | `TODO` | `0/3` | @playwright/mcp con versión exacta en mcp_config_template.json, .mcp.json y maestro-mcp/mcp_config.json; actions de library.yml y ci_workflow_template.yml fijadas a SHA con comentario de versión; grep -r @latest en esos archivos devuelve 0; JSON válidos |
| `TASK-020` | Bloqueo de concurrencia en las escrituras de task.sh | devops-cloud-agent | `TODO` | `0/3` | task.sh toma un lock (mkdir atómico) en toda operación que escribe archivos; test que lanza 10 task.sh add en paralelo deja 10 tareas con IDs únicos; suite al 100% |
| `TASK-021` | Handoff con comandos de verificación y registro automático en el historial | devops-cloud-agent | `TODO` | `0/3` | task.sh handoff TASK-X --verify "<cmd>" (repetible) guarda los comandos en verification_commands del JSON y añade la fila en §7 de GLOBAL_STATE.md; handoff/SKILL.md actualizado; tests nuevos al 100% |
| `TASK-022` | Fix: robustez de los scripts de pruebas y automatización | qa-security-agent | `TODO` | `0/3` | test-skills.sh sale con exit 1 ante cualquier error (no exit con el contador); scripts de .agents/scripts y tests usan set -euo pipefail o documentan la excepción; suite al 100% en ubuntu y macos |
| `TASK-023` | Opción --ci en init-project y QUICKSTART actualizado | devops-cloud-agent | `TODO` | `0/3` | init-project.sh --ci copia ci_workflow_template.yml a .github/workflows/audit.yml sin sobrescribir; QUICKSTART.md refleja el número real de comprobaciones y las opciones nuevas; test nuevo en tests/test-scripts.sh al 100% |

> **Estados Válidos**: `BACKLOG` | `TODO` | `IN_PROGRESS` | `IN_REVIEW_QA` | `BLOCKED` | `DONE`

---

## 6. Historial de Decisiones de Arquitectura (ADR)

| Fecha | Decisión | Justificación | Estado |
| :--- | :--- | :--- | :--- |
| `2026-10-29` | Adopción de SKILL MAESTRO como autosuficiente y gobernado por sus propias reglas | Permite probar y perfeccionar el framework usando su propio ciclo de vida | `APROBADO` |

---

## 7. Registro Cronológico de Entregables e Hitos

| Fecha | Agente Emisor | Agente Receptor | Tarea | Resumen del Hito |
| :--- | :--- | :--- | :--- | :--- |
| `2026-10-29` | Orchestrator | Equipo | `TASK-001` | Inicialización de GLOBAL_STATE.md para el mantenimiento y mejora de skills |
| `2026-10-29` | Orchestrator | qa-security-agent | `TASK-001` | Estandarización de 4 skills, soporte Antigravity (subagentes/artefactos), scan de secretos en handoff y validación de suite. Comandos: `bash tests/test-scripts.sh`, `python3 tests/triggers/lint_descriptions.py`, `./.agents/scripts/scan-secrets.sh` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-001` | Aprobada por QA -> DONE |
| `2026-10-29` | qa-security-agent | qa-security-agent | `TASK-002` | Linter tests/test-skills.sh creado y validado en CI y test-scripts.sh (62 OK). Comandos: `bash tests/test-skills.sh`, `bash tests/test-scripts.sh` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-002` | Aprobada por QA -> DONE |
| `2026-10-29` | docs-architecture-agent | qa-security-agent | `TASK-003` | Plantilla stack_template.md y skill stack-nextjs-tailwind-prisma creadas con referencias tecnicas y casos de activacion. Comandos: `bash tests/test-skills.sh`, `python3 tests/triggers/lint_descriptions.py`, `bash tests/test-scripts.sh` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-003` | Aprobada por QA -> DONE |
| `2026-10-29` | docs-architecture-agent | qa-security-agent | `TASK-004` | 4 gotchas criticos incorporados a BRAIN.md (Next.js/Prisma, Express 5, Angular SSR, Stripe). Comandos: `bash tests/test-scripts.sh`, `./.agents/scripts/validate-state.sh` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-004` | Aprobada por QA -> DONE |
| `2026-10-29` | orchestrator-agent | qa-security-agent | `TASK-005` | Estandarizacion de nueva-tarea, aprender, release y web-performance con checklists y prohibiciones. Comandos: `bash tests/test-skills.sh`, `python3 tests/triggers/lint_descriptions.py` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-005` | Aprobada por QA -> DONE |
| `2026-10-29` | database-architect-agent | qa-security-agent | `TASK-006` | Patron Expand/Contract e indices FK en database-architect; Docker non-root, healthchecks y graceful shutdown en devops-cloud. Comandos: `bash tests/test-skills.sh`, `python3 tests/triggers/lint_descriptions.py` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-006` | Aprobada por QA -> DONE |
| `2026-10-29` | devops-cloud-agent | qa-security-agent | `TASK-007` | Soporte de flag --stack nextjs y --stack angular en init-project.sh sin placeholders; tests en test-scripts.sh (64 OK). Comandos: `bash tests/test-scripts.sh`, `./.agents/scripts/validate-state.sh` |
| `2026-10-29` | qa-security-agent | orchestrator-agent | `TASK-007` | Aprobada por QA -> DONE |
| `2026-10-29` | devops-cloud-agent | qa-security-agent | `TASK-008` | scan-secrets.sh --branch [base] revisa lo añadido desde el merge-base con main (commits, cambios sin commitear y archivos nuevos); qa-review, qa-security-agent, handoff, bugfix y stack-nextjs lo usan; 6 tests nuevos (70 OK). Comandos: `bash tests/test-scripts.sh`, `bash tests/test-skills.sh`, `git grep -n scan-secrets.sh -- .agents/skills`, `./.agents/scripts/scan-secrets.sh --branch` |
