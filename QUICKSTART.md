# Guía Rápida de Uso (Multi-Agent System Quickstart)

¡Bienvenido al sistema multi-agente para desarrollo de software! Este catálogo de skills y reglas está diseñado para transformar a cualquier asistente de IA en un **equipo autónomo de ingeniería de software** coordinado y de nivel profesional.

---

## 1. Cómo Iniciar un Proyecto Nuevo en 10 Segundos

El sistema funciona igual en **Claude Code** y en **Antigravity**: las skills viven una sola vez en `.agents/skills/` y cada herramienta las descubre por su propia ruta.

| Pieza | Antigravity | Claude Code |
| :--- | :--- | :--- |
| Reglas globales | `AGENTS.md` | `CLAUDE.md` (importa `@AGENTS.md`) |
| Skills | `.agents/skills/<nombre>/SKILL.md` | `.claude/skills` → enlace a `.agents/skills` |
| Servidores MCP | `.agents/plugins/maestro-mcp/mcp_config.json` | `.mcp.json` |
| Hook "cero código sin tarea" | — (regla de `AGENTS.md`) | `.claude/settings.json` → `.agents/scripts/require-active-task.sh` |
| Invocar una skill | `/<nombre>` o activación automática | `/<nombre>` o activación automática |

### Requisitos y uso en Windows

Los scripts (`task.sh`, `init-project.sh`, hooks) son **bash** y requieren `git` y `python3`. Se prueban en CI en Ubuntu y macOS.

| Entorno | Estado |
| :--- | :--- |
| Linux y macOS | Soportado y probado en CI |
| Windows con **WSL 2** (Ubuntu) | Recomendado: es Linux real. Clona el proyecto **dentro** del sistema de archivos de WSL (`~/proyectos`, no `/mnt/c/...`) para tener enlaces simbólicos, permisos y rendimiento correctos |
| Windows con Git Bash | No probado en CI. Puede funcionar con `--copy` (sin enlaces simbólicos), pero no está garantizado |
| PowerShell o `cmd` | No soportado: los scripts no se ejecutan fuera de bash |

En WSL instala las dependencias una vez: `sudo apt update && sudo apt install -y git python3`. Si usas Claude Code o Antigravity en Windows, abre el proyecto desde WSL para que los hooks y `./.agents/scripts/task.sh` se ejecuten con bash.

### Opción A: Usando el script automático
En tu terminal, ejecuta:
```bash
# Sintaxis: ./.agents/scripts/init-project.sh "Nombre" "/ruta/al/proyecto" [--copy] [--stack nextjs|angular|fastapi] [--ci]
./.agents/scripts/init-project.sh "Mi Plataforma SaaS" "../MI-NUEVO-PROYECTO" --stack nextjs --ci
cd ../MI-NUEVO-PROYECTO && ./.agents/scripts/install-hooks.sh
```
El script nunca sobrescribe `AGENTS.md`, `CLAUDE.md`, `GLOBAL_STATE.md`, `BRAIN.md`, `.mcp.json`, `.claude/settings.json`, `.gitignore` ni workflows existentes si ya existen.
- Usa `--copy` si tu entorno no admite enlaces simbólicos (ej. Windows).
- Usa `--stack nextjs`, `--stack angular` o `--stack fastapi` para preconfigurar la arquitectura sin placeholders.
- Usa `--ci` para instalar automáticamente el pipeline de GitHub Actions (`.github/workflows/audit.yml`) desde la plantilla.
- Usa `--update` (o `-u`) en proyectos existentes para sincronizar scripts, plantillas, hooks y skills retirando obsoletas, sin tocar `GLOBAL_STATE.md`, `BRAIN.md` ni `.agents/brain/`.
Luego ejecuta `install-hooks.sh` para activar la validación de commits y escaneo de secretos.

### Opción B: Copia manual
1. Copia la carpeta [`.agents/`](.agents), [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md) y [`.mcp.json`](.mcp.json) a la raíz de tu nuevo repositorio.
2. Crea la configuración de Claude Code: `mkdir -p .claude && ln -s ../.agents/skills .claude/skills && cp .agents/templates/claude_settings_template.json .claude/settings.json`.
3. Instala los Git hooks para blindar commits y secretos: `./.agents/scripts/install-hooks.sh`.
4. Copia [`.agents/templates/GLOBAL_STATE_TEMPLATE.md`](.agents/templates/GLOBAL_STATE_TEMPLATE.md) como `GLOBAL_STATE.md` en la raíz de tu proyecto.
5. Abre el proyecto en tu editor y dile a la IA:
   > *"Inicia el proyecto configurando el stack en GLOBAL_STATE.md y planifica las primeras tareas."*

---

## 2. Catálogo Completo de Agentes y Skills

| Agente | Skill (`/nombre`) | Especialidad |
| :--- | :--- | :--- |
| **Orchestrator** | [`orchestrator-agent`](.agents/skills/orchestrator-agent/SKILL.md) | Líder de proyecto, descomposición (`TASK-XXX`), SSOT y prevención de bucles. |
| **Product Manager** | [`product-manager-agent`](.agents/skills/product-manager-agent/SKILL.md) | Discovery, Historias de Usuario Gherkin, User Journeys, estados UI y analítica. |
| **Backend & Data** | [`backend-agent`](.agents/skills/backend-agent/SKILL.md) | APIs REST/GraphQL, arquitectura en capas, esquemas Zod/DTOs, auth JWT/RBAC. |
| **Frontend & UI** | [`frontend-agent`](.agents/skills/frontend-agent/SKILL.md) | Vistas reactivas, componentes desacoplados, PWA offline, accesibilidad WCAG. |
| **Mobile & Native** | [`mobile-agent`](.agents/skills/mobile-agent/SKILL.md) | Apps React Native, Flutter, Swift/Kotlin, hardware, offline y Store compliance. |
| **QA & Security** | [`qa-security-agent`](.agents/skills/qa-security-agent/SKILL.md) | Tests automatizados, OWASP Top 10, escaneo de secretos y **Poder de Veto**. |
| **Database** | [`database-architect-agent`](.agents/skills/database-architect-agent/SKILL.md) | Modelado relacional/NoSQL, migraciones reversibles, índices y transacciones ACID. |
| **DevOps & Cloud** | [`devops-cloud-agent`](.agents/skills/devops-cloud-agent/SKILL.md) | Presupuestos de bundle, Docker multi-etapa, CI/CD y despliegues en la nube. |
| **UI/UX Craft** | [`ui-ux-agent`](.agents/skills/ui-ux-agent/SKILL.md) | Tokens de diseño, sistemas de color, micro-interacciones y consistencia visual. |
| **Domain Logic** | [`domain-logic-agent`](.agents/skills/domain-logic-agent/SKILL.md) | Domain-Driven Design (DDD), máquinas de estado finitas y fórmulas de negocio. |
| **AI & LLM** | [`ai-integrator-agent`](.agents/skills/ai-integrator-agent/SKILL.md) | Modelos locales (Ollama), APIs Cloud (Gemini/OpenAI), RAG, vectores y streaming. |
| **Docs & Arch** | [`docs-architecture-agent`](.agents/skills/docs-architecture-agent/SKILL.md) | Diagramas Mermaid, especificaciones OpenAPI/Swagger, ADRs y Changelogs. |

### Skills de Flujo (atajos del ciclo de vida)

| Comando | Qué hace | Rol que asume |
| :--- | :--- | :--- |
| [`/iniciar-proyecto`](.agents/skills/iniciar-proyecto/SKILL.md) | Acuerda el stack, completa `GLOBAL_STATE.md` y planifica la fase 1 | Orchestrator |
| [`/estado`](.agents/skills/estado/SKILL.md) | Resumen: progreso, bloqueos, pendientes de QA y siguiente paso (solo lectura) | — |
| [`/nueva-tarea`](.agents/skills/nueva-tarea/SKILL.md) | Descompone un requerimiento y registra las `TASK-XXX` tras tu confirmación | Orchestrator |
| [`/bugfix`](.agents/skills/bugfix/SKILL.md) | Reproduce, escribe un test que falle, corrige la causa raíz y entrega a QA | Especialista |
| [`/handoff`](.agents/skills/handoff/SKILL.md) | Verifica el checklist y los tests, y pasa la tarea a `IN_REVIEW_QA` | Especialista |
| [`/qa-review`](.agents/skills/qa-review/SKILL.md) | Verificación independiente y veredicto: `close` o `reject` con bug report | QA & Security |
| [`/aprender`](.agents/skills/aprender/SKILL.md) | Registra problema, causa y solución en el cerebro (o deuda técnica) | — |
| [`/release`](.agents/skills/release/SKILL.md) | Batería completa, CHANGELOG, versión, tag, despliegue (con tu confirmación) y prueba de humo | DevOps + Docs + QA |

Flujo típico: `/iniciar-proyecto` → `/nueva-tarea` → *(especialista trabaja)* → `/handoff` → `/qa-review` → `/release`. Para errores: `/bugfix` → `/handoff` → `/qa-review` → `/aprender`. Usa `/estado` en cualquier momento.

### Skills de Stack y de Técnica

| Skill | Qué aporta |
| :--- | :--- |
| [`stack-angular-express-postgres`](.agents/skills/stack-angular-express-postgres/SKILL.md) | Convenciones verificadas de Angular 22 + Node 24/Express 5 + PostgreSQL 18 con Drizzle, JWT propio y monorepo npm. Se carga junto a la skill del rol. |
| [`stack-nextjs-tailwind-prisma`](.agents/skills/stack-nextjs-tailwind-prisma/SKILL.md) | Convenciones verificadas de React 19 + Next.js 15 (App Router, Server Components y Actions) + Tailwind CSS + PostgreSQL con Prisma ORM y Zod. |
| [`e2e-testing`](.agents/skills/e2e-testing/SKILL.md) | Pruebas end-to-end con Playwright a partir de los escenarios Gherkin del PRD. |
| [`payments-stripe`](.agents/skills/payments-stripe/SKILL.md) | Suscripciones y pagos con Stripe Checkout, portal de cliente y webhooks idempotentes (Stripe 23). |
| [`seo-web`](.agents/skills/seo-web/SKILL.md) | SSR y prerender por ruta, metadatos, canonical/hreflang, JSON-LD, sitemap y hosts permitidos. |
| [`web-performance`](.agents/skills/web-performance/SKILL.md) | Core Web Vitals, presupuestos, análisis del bundle, imágenes, caché y latencia de la API. |
| [`i18n`](.agents/skills/i18n/SKILL.md) | Varios idiomas con `@angular/localize`, builds por idioma y comprobación de traducciones. |

---

## 3. Las 5 Reglas de Oro del Flujo

1. **`AGENTS.md` es la Ley**: Está siempre activo. Obliga a la IA a leer `GLOBAL_STATE.md` antes de responder o ejecutar cualquier acción.
2. **Cero Código sin Tarea**: Nadie programa sin un `TASK-XXX` registrado con Criterios de Aceptación (DoD).
3. **Contrato Primero**: Antes de codificar el backend, se publica el esquema de datos (DTO) para que el frontend pueda avanzar en paralelo con mocks tipados.
4. **Poder de Veto de QA**: Una tarea no pasa a `DONE` sin la aprobación del `qa-security-agent`.
5. **Regla de 3 Iteraciones**: Si una tarea acumula 3 rechazos consecutivos de QA, se detiene el bucle automático y el Orchestrator te escala el caso inmediatamente para que tomes la decisión final.

---

## 4. Prompts Útiles para el Usuario

* **Para conceptualizar y aterrizar una nueva idea o pantalla**:
  > *"/product-manager-agent Quiero crear una app de reservas. Define el User Flow, las Historias de Usuario con criterios Gherkin y los 4 estados de pantalla en docs/product/reservas.md."*

* **Para iniciar la descomposición técnica de una funcionalidad**:
  > *"/orchestrator-agent Descompón el requerimiento 'Sistema de autenticación con doble factor' en tareas y actualiza GLOBAL_STATE.md."*

* **Para auditar la calidad antes de desplegar**:
  > *"/qa-security-agent Ejecuta la auditoría completa de seguridad, prueba los endpoints y emite tu veredicto."*

* **Para documentar la arquitectura**:
  > *"/docs-architecture-agent Genera un diagrama de secuencia en Mermaid para el flujo de pago y documenta el ADR correspondiente."*

* **Para integrar IA local o en la nube**:
  > *"/ai-integrator-agent Configura la conexión con Ollama en local para procesar resúmenes con streaming estructurado."*

---

## 5. El Sistema de Cerebro (Memoria Permanente contra la Amnesia)

Para evitar que los agentes olviden decisiones pasadas al compactar el chat o abrir nuevas sesiones, el sistema opera con **3 niveles de memoria**:

1. **Memoria Inmediata (Chat)**: La conversación activa en la ventana de contexto.
2. **Memoria Operativa ([`GLOBAL_STATE.md`](.agents/templates/GLOBAL_STATE_TEMPLATE.md))**: Tablero Kanban de tareas vivas y contratos activos.
3. **Memoria a Largo Plazo ([`BRAIN.md`](BRAIN.md) / [`.agents/brain/`](.agents/brain))**:
   - `lessons_learned.md`: Errores superados para que ningún agente vuelva a cometerlos.
   - `system_map.md`: Mapa mental del flujo de datos del proyecto.
   - `domain_glossary.md`: Invariantes y términos exactos del negocio.
   - `preferences.md`: Tus preferencias personales de estilo y código.

---

## 6. CLI de Tareas (`task.sh`)

Manipula el tablero de `GLOBAL_STATE.md`, crea ramas Git y genera traspasos desde la terminal. Cada transición valida el estado de origen (por ejemplo, no se puede cerrar una tarea que no pasó por QA) y `reject`/`close` quedan registrados en el historial automáticamente.

| Comando | Transición | Lo ejecuta |
| :--- | :--- | :--- |
| `task.sh add "<desc>" "<agente>" "<criterios>"` | → `TODO` | Orchestrator |
| `task.sh start TASK-001` | `TODO`/rechazada → `IN_PROGRESS` + rama `feature/` (o `fix/`, `refactor/` según la descripción) | Especialista |
| `task.sh handoff TASK-001 [--verify "<cmd>"]...` | `IN_PROGRESS` → `IN_REVIEW_QA` + `.agents/handoffs/handoff_TASK-001.json` + registro automático en §7 | Especialista |
| `task.sh reject TASK-001 "<motivo>"` | `IN_REVIEW_QA` → `IN_PROGRESS` (n/3); a 3/3 → `BLOCKED` | QA |
| `task.sh close TASK-001` | `IN_REVIEW_QA` → `DONE` | QA |
| `task.sh move TASK-001 TODO` | Desbloqueo tras decisión humana (reinicia el contador a 0/3) o replanificar a `TODO`/`BACKLOG`. Nunca lleva a `DONE`, `IN_REVIEW_QA` ni `BLOCKED` | Orchestrator |

Todas las operaciones de escritura emplean bloqueo atómico (`mkdir .agents/.task_lock`) con liberación garantizada por `trap`, previniendo colisiones de concurrencia.

```bash
./.agents/scripts/task.sh list       # Tablero
./.agents/scripts/task.sh metrics    # Progreso y salud de QA

# Commit con formato tipo(TASK-ID): mensaje. Si no hay nada preparado añade solo
# archivos ya versionados; los archivos nuevos se listan para que los añadas tú.
./.agents/scripts/task.sh commit TASK-001 "implementar endpoints de suscripcion" feat

# Lección aprendida (auto LL-XXX en BRAIN.md y .agents/brain/lessons_learned.md)
./.agents/scripts/task.sh learn "Formulario no reacciona a cambios" frontend "ngModel mezclado con Signals en Angular 19" "Usar formularios reactivos o Signals puros, nunca ambos"

# Deuda técnica aceptada (auto TD-XXX en .agents/brain/tech_debt.md)
./.agents/scripts/task.sh debt "Paginación en memoria temporal" TASK-001 "Paginación SQL" MEDIA
```

---

## 7. Blindaje de Git con Hooks Automáticos

Instala los hooks con un solo comando:
```bash
./.agents/scripts/install-hooks.sh
```
* **`commit-msg`**: Bloquea cualquier commit que no siga `tipo(TASK-XXX): descripción` (se permiten `Merge`, `Revert`, `fixup!` y `squash!`).
* **`pre-commit`**: Ejecuta [`scan-secrets.sh`](.agents/scripts/scan-secrets.sh) sobre las líneas añadidas (claves `sk-…`, tokens de GitHub, AWS, Google y Slack, claves privadas y archivos `.env`) y audita `GLOBAL_STATE.md` con `validate-state.sh`. Para un falso positivo, añade `secret-scan:allow` en esa línea. En handoff y QA se usa `scan-secrets.sh --branch`, que revisa todo lo que la rama añade respecto a `main` (commiteado o no, archivos nuevos y cada commit de la rama, porque un secreto borrado después sigue en el historial); `--all` revisa el repositorio completo (CI).
* **CI**: el workflow de plantilla usa el mismo escáner en modo `--all`, así las reglas son idénticas en local y en GitHub.

### Pruebas de los scripts (solo en este repositorio de skills)
```bash
bash tests/test-scripts.sh
```
Instala el sistema en proyectos temporales y verifica el ciclo completo de `task.sh`, los hooks, concurrencia y la instalación (123 comprobaciones).

---

## 8. Integración MCP y CI/CD en la Nube

* **Servidores MCP** — una sola plantilla ([`.agents/templates/mcp_config_template.json`](.agents/templates/mcp_config_template.json)) copiada a [`.mcp.json`](.mcp.json) (Claude Code) y a [`.agents/plugins/maestro-mcp/mcp_config.json`](.agents/plugins/maestro-mcp/mcp_config.json) (Antigravity):
  - `web-tester-playwright` (`npx @playwright/mcp`): Frontend y QA interactúan con la UI en un navegador real.
  - Base de datos, HTTP y Git se usan desde la terminal (`psql`/`sqlite3`, `curl`/supertest, `git`/`gh`): no requieren servidores MCP ni `uvx`. Si quieres uno más, añádelo a la plantilla y vuelve a copiarla a los dos destinos.
* **Pipeline GitHub Actions ([`.agents/templates/ci_workflow_template.yml`](.agents/templates/ci_workflow_template.yml))**:
  Se instala automáticamente indicando la opción `--ci` en `init-project.sh` como `.github/workflows/audit.yml` (o copiando manualmente la plantilla) para validar commits convencionales, escaneo de secretos y consistencia del estado en cada Pull Request.

---

## 9. Kit de Diseño UI/UX y Sistema de Tokens

Para construir interfaces profesionales en minutos sin dependencias pesadas:
* [**`tokens_template.css`**](.agents/templates/tokens_template.css): Variables CSS con modo claro/oscuro, grilla de 4px/8px, escala tipográfica y sombras suaves.
* [**`components_template.css`**](.agents/templates/components_template.css): Botones con área táctil accesible de 44px (Ley de Fitts), tarjetas con elevación interactiva, inputs con validación accesible, loading skeletons y modales difuminados.
* [**`ux_audit_template.md`**](.agents/templates/ux_audit_template.md): Lista de verificación heurística para auditar pantallas antes de aprobar entregas.

---

## 10. Arquitectura Backend y Envoltorio Universal de APIs

Para que todas las rutas del servidor retornen respuestas semánticas y errores estructurados:
* [**`api_response_template.ts`**](.agents/templates/api_response_template.ts): Envoltorio TypeScript listo para usar con:
  - `ApiResponse.success(data, meta?)`: Respuestas 200/201 con fecha ISO.
  - `ApiResponse.paginated(data, page, limit, total)`: Paginación calculada.
  - Excepciones tipadas (`BadRequestException`, `UnauthorizedException`, `NotFoundException`, etc.).
  - Middleware de captura global que previene la fuga de *stack traces* en producción.
* **Protocolos Obligatorios**: Claves de idempotencia (`Idempotency-Key`), rate limiting en autenticación y endpoints de salud (`/healthz` y `/readyz`).




