# Changelog

Todos los cambios relevantes de la librería SKILL MAESTRO. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado, [SemVer](https://semver.org/lang/es/). La versión instalada en un proyecto está en `.agents/VERSION`; `init-project.sh --update` la sincroniza.

## [Unreleased]

### Añadido
- `lint_descriptions.py` controla el presupuesto del listado de skills de Claude Code: 300 caracteres como máximo por `description` y 15 000 en total, con opciones `--skills-dir` y `--cases` y 4 checks nuevos en `tests/test-scripts.sh` (TASK-081).

### Cambiado
- Las 56 `description` se reescriben en formato compacto (qué hace, cuándo usarla y límite con la skill vecina): de 31 840 a menos de 15 000 caracteres. Las de los stacks dejan la plantilla común para que el modelo no los confunda (TASK-081).

### Corregido
- Claude Code dejaba 18 skills sin descripción en su listado (presupuesto agotado), así que no se activaban solas; ahora las 56 aparecen con descripción (TASK-081, lección LL-020).
- Sección `[1.4.0]` de este CHANGELOG: `user-testing-agent` atribuido a TASK-066 y `/incidente` a TASK-067, y añadidas las skills omitidas `/onboarding`, `/explain-codebase` (TASK-068) y `/aprobar` (TASK-072), contrastadas con `git log v1.3.0..v1.4.0` (TASK-084).

## [1.5.0] - 2026-11-20

### Añadido
- **3 nuevos roles especialistas enterprise** (de 50 a 56 skills en el catálogo):
  - `data-engineer-agent`: pipelines ETL/ELT con dbt, arquitectura medallion (Bronze/Silver/Gold) y data warehouses (TASK-073).
  - `devsecops-agent`: automatización de seguridad en CI/CD (SAST, DAST, SCA con Trivy/Snyk, SBOM con SPDX/CycloneDX y firma Cosign) (TASK-074).
  - `compliance-legal-agent`: auditoría de licencias Open Source (detección copyleft viral), GDPR/CCPA/HIPAA y anonimización de PII (TASK-075).
- **Nueva skill técnica de optimización de infraestructura**:
  - `finops-cost-optimization`: auditoría de costes cloud, rightsizing de instancias/serverless, optimización de consultas SQL (BigQuery/Athena) y ciclo de vida de almacenamiento (TASK-076).
- **2 nuevos stacks tecnológicos especializados**:
  - `stack-fastapi-mongodb`: arquitectura backend Python 3.12 con FastAPI + MongoDB 7 + Motor + Beanie ODM para proyectos NoSQL basados en documentos (TASK-077).
  - `stack-react-native-expo`: desarrollo móvil nativo multiplataforma con React Native 0.76+ (New Architecture/Hermes), Expo SDK 52+, Expo Router v3 y MMKV/SQLite (TASK-078).
- **Protocolo formal de contratos de integración inter-agente (`contracts.json`)**:
  - Plantilla oficial `.agents/templates/contracts_template.json` con especificación estricta de endpoints, métodos, headers, DTOs y respuestas de error (TASK-079).
  - Subcomando `./task.sh contracts validate [ruta]` para validación determinista de contratos (TASK-079).
  - Protocolo documentado en `AGENTS.md` §4 e integrado en el poder de veto de QA (TASK-079).
- **Batería de pruebas y suite ampliada**:
  - 128 casos de prueba de activación en `tests/triggers/cases.json` con 0 avisos en `lint_descriptions.py`.
  - 382 checks automatizados en `tests/test-scripts.sh`.

## [1.4.0] - 2026-11-20

### Añadido
- **9 skills nuevas** (de 41 a 50 skills en el catálogo).
- **Rol y flujo de pruebas exploratorias de usuario (UAT)**:
  - `user-testing-agent`: simulación interactiva de personas de usuario reales en navegador con reporte de evidencias (TASK-066).
  - `/probar-usuario`: flujo de pruebas de usuario con loop de verificación y rechazos UAT (TASK-066).
- **Gestión operativa de incidentes y parches en caliente**:
  - `/hotfix`: flujo quirúrgico urgente derivado del tag activo de producción con test de regresión y lección obligatoria (TASK-067).
  - `/incidente`: protocolo de contención, degradación graciosa y post-mortem para caídas de servicio (TASK-067).
- **Inducción y comprensión del repositorio**:
  - `/onboarding`: genera y mantiene la guía de inducción técnica para desarrolladores humanos en `docs/onboarding/guide.md` (TASK-068).
  - `/explain-codebase`: explica en lenguaje claro la estructura, el flujo de datos y las responsabilidades de cada carpeta del repositorio (TASK-068).
- **Técnicas transversales de accesibilidad y resiliencia**:
  - `accessibility-testing`: auditoría automatizada con Axe-core y Playwright bajo WCAG 2.1 AA (TASK-069).
  - `resilience-engineering`: patrones circuit breaker, timeouts estrictos, backoff exponencial con jitter y bulkheads (TASK-070).
- **Visor interactivo y control humano (Human-in-the-loop)**:
  - `task.sh dashboard`: visor HTML autónomo para visualización gráfica del estado, métricas, tablero Kanban y salud del cerebro (TASK-071).
  - Estado `AWAITING_HUMAN_APPROVAL` y subcomandos `task.sh hold` y `task.sh approve` para puntos de control formales (TASK-072).
  - `/aprobar`: flujo de punto de control humano que pausa la tarea con `task.sh hold` y la reanuda con `task.sh approve` (TASK-072).

## [1.3.0] - 2026-11-19

### Añadido
- **3 nuevos stacks tecnológicos preconfigurados** (de 38 a 41 skills en el catálogo):
  - `stack-vue-nuxt-postgres`: convenciones de Vue 3 + Nuxt 3 (SSR/Nitro) + Pinia + Tailwind + PostgreSQL con Drizzle ORM (TASK-054).
  - `stack-react-vite-node`: convenciones SPA con React 19 + Vite + Tailwind + Node.js (Express) + PostgreSQL y TanStack Query (TASK-055).
  - `stack-nestjs-postgres`: arquitectura modular backend con NestJS + Prisma/TypeORM + PostgreSQL, validación DTO y Guards (TASK-056).
  - Soporte multi-stack en `init-project.sh` (`--stack nuxt`, `--stack react-vite`, `--stack nestjs`) y mapeo de rutas por rol en `AGENTS.md` §8 (TASK-057).
  - Recetas operativas en `references/` para Nuxt, React-Vite y NestJS en las 4 skills técnicas (`payments-stripe`, `seo-web`, `web-performance` e `i18n`) (TASK-061).
- **Herramientas de diagnóstico y control de versiones en `task.sh`**:
  - `task.sh doctor`: diagnóstico semafórico unificado de 5 etapas (`validate-state`, `brain doctor`, `brain lint`, `scan-secrets`, `test-skills`) con salida 0/1 (TASK-058).
  - `task.sh diff [TASK-XXX] [--stat]`: visualización de estadísticas y diff contra `main` (`merge-base`) de la tarea activa o especificada (TASK-058).
- **Evolución del Cerebro y memoria persistente**:
  - `task.sh brain lint`: linter activo de código contra antipatrones aprendidos con antídotos deterministas (`LL-001`, `LL-007`, `LL-012`, `LL-016`) integrado en `task.sh doctor` (TASK-063).
  - `task.sh brain hotspots`: mapa de calor de riesgo en el código basado en acumulación de lecciones y reincidencias (TASK-062).
  - `task.sh prefer "<categoría>" "<regla>"`: registro instantáneo y sin duplicados de preferencias en `.agents/brain/preferences.md` (TASK-062).
  - Alertas visuales reforzadas ante lecciones reincidentes (`🚨 REINCIDENTE xN`) en `task.sh start`, `task.sh brain for` y `task.sh check` (TASK-062).
  - Filtrado dinámico de lecciones según el stack activo declarado en `GLOBAL_STATE.md` (TASK-062).
- **Ampliación de evals deterministas**:
  - 3 nuevas evals deterministas en `tests/evals/` para `research-agent`, `crear-plan` y `adoptar-proyecto`, totalizando 18 evals verificadas (TASK-059).
  - Batería de activación ampliada a 98 casos en `tests/triggers/cases.json` (TASK-057).

### Cambiado
- Catálogo general sincronizado a **41 skills** y **6 stacks tecnológicos** en `README.md`, `QUICKSTART.md` y `.agents/brain/system_map.md` (TASK-060).
- Suite de pruebas de scripts ampliada a 344 checks automatizados (TASK-057, TASK-064).

## [1.2.0] - 2026-11-18

### Añadido
- **6 skills nuevas** (de 32 a 38 skills):
  - `research-agent` (investigador): benchmark de productos de referencia en 12 dimensiones y propuesta para el proyecto en `docs/research/` (TASK-052).
  - `/crear-plan`: plan maestro completo en `docs/plan/plan-maestro.md` con alcance MVP/v1/v2, arquitectura Mermaid, fases y cronograma Gantt (TASK-053).
  - `testing-strategy`: pirámide de pruebas, fakes reales vs mocks acoplados y relojes deterministas (TASK-044).
  - `async-jobs`: colas en segundo plano, Transactional Outbox, consumidores idempotentes y DLQ (TASK-044).
  - `pr-review`: revisiones estructuradas de pull requests y resolución limpia de conflictos (TASK-044).
  - `/adoptar-proyecto`: adopción de proyectos brownfield sin sobreescribir código ni documentación previa (TASK-046).
- **Modo adopción brownfield y archivado**:
  - `init-project.sh --adopt`: inicialización segura sobre código existente conservando hooks y configuraciones previas (TASK-046).
  - `task.sh archive [--keep N] [--phase "<fase>"]`: archivado de tareas `DONE` en `.agents/archive/` preservando `next_id`, métricas y validación (TASK-046).
- **Desacople multi-stack y referencias operativas**:
  - `references/` con recetas para Angular+Express, Next.js y FastAPI en `i18n`, `payments-stripe`, `seo-web` y `web-performance` (TASK-042).
  - `references/` operativas verificables en las 6 skills base (`backend-agent`, `frontend-agent`, `database-architect-agent`, `domain-logic-agent`, `mobile-agent`, `docs-architecture-agent`) (TASK-045).
  - CI multi-stack Python 3.12 y Node 24 LTS en `.agents/templates/ci_workflow_template.yml` (TASK-043).
- **Paridad Antigravity y arnés de pruebas**:
  - `task.sh check <rutas>` y `.agents/scripts/pre-edit-check.sh`: control de "cero código sin tarea" e inyección de lecciones aplicable en Antigravity (TASK-049).
  - Evals deterministas ampliadas de 5 a 15 casos en `tests/evals/evals.json` cubriendo todos los roles de código (TASK-040, TASK-048).
  - `run_evals.py --verify-baselines`: verificación de línea base sin coste ni LLM integrada en CI y `test-scripts.sh` (TASK-049).
  - Batería de activación ampliada a 92 casos en `tests/triggers/cases.json` con `lint_descriptions.py` en verde (TASK-047, TASK-052, TASK-053).
- `tests/test-skills.sh` endurecido para exigir cierre YAML `---`, palabra clave `Usar`, secciones obligatorias por tipo de skill y enlaces relativos (TASK-040).

### Cambiado
- `orchestrator-agent` lista también `security-hardening` y `observability` entre las skills de técnica (TASK-041).
- `qa-review` delega la verificación independiente en Antigravity con `TypeName: "self"` y documenta que citar `LL-XXX` en `task.sh reject` garantiza el registro de reincidencias (TD-004, TASK-041).
- `devops-cloud-agent` y `.agents/templates/ci_workflow_template.yml` actualizados a Node 24 LTS (TASK-041).
- Las skills de roles de código recuerdan ejecutar `./.agents/scripts/task.sh brain for TASK-XXX <rutas>` antes de editar (TASK-041).
- `e2e-testing` incorpora sección `## Prohibido` (TASK-041).

### Corregido
- Evals sin falsos negativos (TD-005): `testing-reloj-determinista` acepta fechas fijas `new Date('…')` en tests y mutante con módulos de `src/`; `devops-docker-no-root` ignora comentarios con `JWT_SECRET`; `async-worker-idempotente` clasifica transitorios con `err.code` (TASK-051).
- `run_evals.py` no deja temporales `skill-eval-*` si falla el setup y trata `127`/`126` como error de entorno; `task.sh check` bloquea si el directorio actual se ha borrado (TD-006, TASK-051).
- Normalización estricta de rutas en `require-active-task.sh` y `brain-context.sh` contra evasión con `..` y symlinks (TASK-050).
- `install-hooks.sh` e `init-project.sh` compatibles con worktrees, submódulos y `core.hooksPath` (TASK-050).
- `task.sh` sale con exit 1 ante comandos desconocidos, maneja traps de `SIGINT`/`SIGTERM` liberando el lock y emite colores ANSI solo en terminales respetando `NO_COLOR` (TASK-050).
- Saldadas `TD-003` (sesión segura en `brain-context.sh`) y `TD-004` (reincidencias por causa raíz y filtro de `close`) (TASK-039, TASK-041).
- Endurecidos `task.sh`, `init-project.sh` y `validate-state.sh` (TASK-039).

## [1.1.0] - 2026-11-11

### Añadido
- **Cerebro dirigido** (TASK-036 a TASK-038):
  - `.agents/brain/lessons_learned.md` es la fuente única de lecciones, con columnas **Ámbito** (globs de rutas) y **Estado**. La tabla de `BRAIN.md` se regenera desde ella (`task.sh brain sync`).
  - `task.sh learn --paths "<globs>"`, `task.sh brain scope`, `brain search <términos>` y `brain for TASK-XXX [rutas]`.
  - Hook de Claude Code `.agents/scripts/brain-context.sh`: muestra al agente las lecciones cuyo ámbito cubre el archivo que va a editar, una vez por sesión y sin bloquear nunca.
  - `task.sh close` exige `--lesson LL-XXX` o `--no-lesson "<motivo>"` si la tarea tuvo rechazos o corrige un defecto.
  - `task.sh reject` anota **reincidencias** de lecciones activas en `.agents/brain/recurrences.md`.
  - `task.sh brain doctor` (integrado en `validate-state.sh`) y `task.sh brain stats`.
  - `task.sh debt-resolve TD-XXX` (marca `SALDADA`) y `task.sh lesson-retire LL-XXX` (marca `OBSOLETA`); `learn` rechaza duplicados salvo `--force`.
- **Skills nuevas** (de 27 a 32):
  - `stack-fastapi-postgres` (TASK-028) y la opción `init-project.sh --stack fastapi`.
  - `refactor` y `cerrar-fase`, skills de flujo (TASK-032).
  - `security-hardening` y `observability`, skills de técnica (TASK-033).
- `task.sh commit --trailer "Clave: valor"` y la variable `MAESTRO_COMMIT_TRAILER` para líneas de autoría (TASK-029).
- `tests/test-flow.sh`: ciclo completo de una tarea de punta a punta, también en la CI (TASK-025).
- Documentación de uso en Windows con WSL 2 (TASK-026).

### Cambiado
- `BRAIN.md`, `preferences.md` y `domain_glossary.md` de la librería describen la librería real; las trampas de cada stack se enlazan a su skill (TASK-031).
- Lecciones y deuda: los IDs no se reutilizan; la deuda saldada queda marcada en vez de borrarse.
- `task.sh handoff` avisa si el revisor indicado es el propio agente asignado.
- La plantilla `lessons_learned_template.md` y `BRAIN_TEMPLATE.md` usan el esquema de 8 columnas. Los proyectos instalados con 1.0.0 se migran solos en la primera escritura del cerebro, sin perder lecciones.
- `.claude/settings.json` (plantilla) registra el hook del cerebro junto al de "cero código sin tarea". `init-project.sh --update` avisa si falta en un proyecto existente, sin tocar su `settings.json`.

### Corregido
- `scan-secrets.sh` no veía rutas con comillas o barra invertida, `.env` creados por rename ni líneas añadidas que empiezan por `++ ` (TASK-024).
- `init-project.sh --stack` corrompía la línea de infraestructura de `GLOBAL_STATE.md` por un `&` sin escapar en `sed`, en los tres stacks (TASK-028).
- `task.sh` (TASK-035):
  - Ya no deja los archivos en `0600`.
  - Imprime literal el texto del usuario, sin interpretar secuencias de escape.
  - Funciona sin `python3` y en locale C.
- `init-project.sh` con un solo argumento fallaba en bash 3.2 (TASK-035).

### Actualizar desde 1.0.0
```bash
./.agents/scripts/init-project.sh --update /ruta/al/proyecto
```
Después, en el proyecto: `./.agents/scripts/task.sh brain sync` (migra las lecciones al esquema nuevo) y `./.agents/scripts/task.sh brain doctor`. Si su `.claude/settings.json` no registra `brain-context.sh`, añade la entrada desde `.agents/templates/claude_settings_template.json`.

## [1.0.0] - 2026-10-29

Primera versión: 27 skills (roles, flujo, stack y técnica), `task.sh` con el ciclo de vida y el veto de QA, hooks de git y de Claude Code, `scan-secrets.sh`, `validate-state.sh`, `init-project.sh` (`--stack`, `--ci`, `--update`) y la batería de activación de skills (TASK-001 a TASK-023).
