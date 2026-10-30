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

