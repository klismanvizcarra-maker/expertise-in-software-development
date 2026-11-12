# Reglas Globales del Sistema Multi-Agente (Master Agent Governance)

> **Regla de Oro**: Este archivo rige el comportamiento de todos los agentes de inteligencia artificial en este proyecto. Todo agente debe acatar estas directrices de forma obligatoria e incondicional.

---

## 1. Protocolo de Inicio de Sesión (Lectura Obligatoria)

Al recibir cualquier requerimiento que vaya a **modificar archivos**, el primer paso obligatorio del agente es:
1. Leer `GLOBAL_STATE.md` en la raíz: metadatos, fase actual, contratos activos y tablero de tareas (`TASK-XXX`).
2. Si `GLOBAL_STATE.md` no existe, cargar la skill `orchestrator-agent` y crearlo a partir de `.agents/templates/GLOBAL_STATE_TEMPLATE.md`.
3. Antes de diseñar, refactorizar o corregir un bug, revisar `BRAIN.md` (lecciones `LL-XXX`, *gotchas* y preferencias) para no repetir antipatrones.

> Las preguntas, explicaciones y lecturas que no modifican archivos no requieren tarea ni lectura previa del estado.

---

## 2. Roles, Skills y Punto de Entrada

1. **Un agente = una skill**: cada rol (`orchestrator-agent`, `backend-agent`, etc.) es una skill en `.agents/skills/`. Se activa automáticamente cuando el requerimiento coincide con su descripción, o explícitamente con `/<nombre-de-la-skill>`. Funciona igual en Claude Code y en Antigravity.
2. **Cambio de rol explícito**: si un mismo asistente encadena roles, debe anunciar el cambio (`→ Actuando como qa-security-agent`) y cargar la skill correspondiente antes de continuar.
3. **Punto de Entrada**: todo requerimiento nuevo o cambio de alcance pasa por el `orchestrator-agent`. Si la idea aún es difusa (sin usuarios, flujos ni criterios), primero va al `product-manager-agent`.
4. **Cero Código sin Tarea**: ningún agente crea o modifica código sin una `TASK-XXX` registrada con Criterios de Aceptación verificables en `GLOBAL_STATE.md`. En Claude Code lo impone el hook `.agents/scripts/require-active-task.sh` (`.claude/settings.json`): sin una tarea `IN_PROGRESS` bloquea las ediciones de archivos que no sean Markdown, `docs/`, `specs/`, `.agents/` o `.claude/`. En Antigravity depende de esta regla.
5. **Skills de flujo**: los pasos recurrentes del ciclo tienen su propia skill invocable con `/`: `/iniciar-proyecto`, `/estado`, `/nueva-tarea`, `/bugfix`, `/refactor`, `/handoff`, `/qa-review`, `/aprender`, `/cerrar-fase` y `/release`. Úsalas en lugar de improvisar el procedimiento.
6. **Skills de stack**: si el stack declarado en `GLOBAL_STATE.md` §2 tiene una skill `stack-*` (ej. `stack-angular-express-postgres`), todo agente que escriba código la carga **junto con** la skill de su rol. La skill de stack manda en convenciones concretas (estructura, librerías, comandos); la del rol, en el proceso.
7. **Skills de técnica**: cuando una tarea toca pagos (`payments-stripe`), SEO y SSR (`seo-web`), rendimiento (`web-performance`), varios idiomas (`i18n`), pruebas end-to-end (`e2e-testing`), autenticación, permisos, datos de usuarios, subidas o llamadas a URLs externas (`security-hardening`) o logs, métricas, alertas y salida a producción (`observability`), el agente asignado carga también esa skill. El Orchestrator lo indica en los criterios de la tarea. `payments-stripe`, `seo-web`, `web-performance` e `i18n` están escritas para Angular + Express (`security-hardening` y `observability` son independientes del stack); con otro stack sirven como guía de principios y sus comandos se adaptan (registrándolo como ADR).

---

## 3. Ciclo de Vida de una Tarea (Fuente Única)

Toda transición de estado se hace **exclusivamente** con `./.agents/scripts/task.sh`, y cada rol ejecuta solo los comandos de su fila:

| Transición | Comando | Lo ejecuta |
| :--- | :--- | :--- |
| Crear tarea (`TODO`) | `task.sh add "<desc>" "<agente>" "<criterios>"` | `orchestrator-agent` |
| `TODO` → `IN_PROGRESS` (+ rama Git) | `task.sh start TASK-XXX` | Especialista asignado |
| `IN_PROGRESS` → `IN_REVIEW_QA` | `task.sh handoff TASK-XXX` | Especialista asignado |
| `IN_REVIEW_QA` → `IN_PROGRESS` (rechazo, +1 iteración) | `task.sh reject TASK-XXX "<motivo>"` | `qa-security-agent` |
| Retomar tras rechazo (vuelve a su rama) | `task.sh start TASK-XXX` | Especialista asignado |
| `IN_REVIEW_QA` → `DONE` | `task.sh close TASK-XXX [--lesson LL-XXX \| --no-lesson "<motivo>"]` | `qa-security-agent` (solo tras aprobar) |
| Salir de `BLOCKED` (→ `TODO`, `BACKLOG` o `IN_PROGRESS`, reinicia a 0/3) | `task.sh move TASK-XXX <ESTADO>` | `orchestrator-agent` (solo tras decisión humana) |
| Replanificar (→ `TODO` o `BACKLOG`) | `task.sh move TASK-XXX <ESTADO>` | `orchestrator-agent` |

```text
TODO ──start──> IN_PROGRESS ──handoff──> IN_REVIEW_QA ──close──> DONE
                     ▲                        │
                     └────── reject (n/3) ────┘   reject a 3/3 ──> BLOCKED ──> ESCALAMIENTO AL HUMANO
```

`move` nunca lleva a `DONE`, `IN_REVIEW_QA` ni `BLOCKED`, ni a `IN_PROGRESS` salvo desde `BLOCKED`: esas transiciones solo existen con `close`, `handoff`, `reject` y `start`, que aplican sus controles.

**Traspaso formal (*hand-off*)**: el especialista nunca marca su propia tarea como terminada. Antes de `task.sh handoff` debe cumplir el checklist de su skill y dejar en el historial de `GLOBAL_STATE.md` los entregables y los comandos exactos para verificarlos (formato: `.agents/templates/handoff_template.json`).

**Fusión a `main` y Limpieza de Ramas**: Tras la aprobación de QA (`task.sh close TASK-XXX`), el especialista asignado o el `orchestrator-agent` fusiona la rama a `main` ejecutando `git checkout main && git merge --no-ff <rama>` para preservar el historial completo de commits de la tarea, seguido inmediatamente de `git branch -d <rama>` para eliminar la rama local y mantener el repositorio limpio. Ninguna tarea se considera completamente integrada sin esta fusión.

---

## 4. Poder de Veto de QA y Regla Anti-Deadlocks (Límite de 3 Iteraciones)

1. **Poder de Veto**: el `qa-security-agent` rechaza todo entregable que falle al menos 1 Criterio de Aceptación, tenga pruebas rotas o contenga vulnerabilidades OWASP o secretos expuestos.
2. **Verificación independiente**: QA ejecuta por sí mismo los tests y comandos de verificación; nunca aprueba basándose solo en el reporte del especialista. Revisa con contexto limpio: un subagente en Claude Code o una conversación nueva en Antigravity, nunca con la memoria de quien implementó (ver `/qa-review`).
3. **Límite de 3 Iteraciones**: cada rechazo suma +1 al contador (`n/3`). Al llegar a **3/3** la tarea pasa a `BLOCKED`, se prohíbe seguir iterando y el `orchestrator-agent` emite el informe de **ESCALAMIENTO AL USUARIO (HUMANO)** con opciones de solución.

---

## 5. Convenciones de Control de Versiones (Git)

1. **Ramas por Tarea**:
   - Cada tarea debe trabajarse en su propia rama: `feature/TASK-XXX-descripcion-corta`, `fix/TASK-XXX-...` o `refactor/TASK-XXX-...`. `task.sh start` elige el prefijo según la descripción: `Bug:`/`Fix:`/`Hotfix:` → `fix/`, `Refactor:` → `refactor/`, el resto → `feature/`.
2. **Mensajes de Commit Convencionales**:
   - Formato obligatorio: `tipo(TASK-XXX): descripción en imperativo`. Usa `./.agents/scripts/task.sh commit TASK-XXX "<descripción>" [tipo]`, que lo aplica (el hook `commit-msg` rechaza el resto). Las líneas de autoría (ej. `Co-Authored-By: ...`) se añaden con `--trailer "<línea>"` o con la variable `MAESTRO_COMMIT_TRAILER`.
   - Ejemplos:
     - `feat(TASK-001): implementar autenticacion jwt y middleware rbac`
     - `test(TASK-002): anadir pruebas de integracion para endpoints de usuario`
     - `fix(TASK-003): corregir calculo de prorrateo en servicio de facturacion`
3. **Fusión y Limpieza de Ramas**:
   - Toda tarea aprobada por QA se fusiona a `main` con `--no-ff` (`git merge --no-ff <rama>`), nunca con fast-forward directo, asegurando trazabilidad por tarea.
   - Tras la fusión a `main`, se elimina la rama local (`git branch -d <rama>`) para prevenir ramas huérfanas o acumuladas.

---

## 6. Seguridad y Protección de Datos

1. **Cero Secretos en el Repositorio**: Toda clave de API, token JWT, contraseña de base de datos o llave criptográfica debe cargarse mediante variables de entorno (`.env`).
2. **Comandos Destructivos Prohibidos**: Ningún agente tiene permiso para ejecutar comandos destructivos (`rm -rf`, `DROP TABLE`, `DROP DATABASE`, `git push --force`) sin autorización explícita del usuario.
3. **Manejo Seguro de Errores**: Prohibido exponer trazas internas de stack o detalles del motor de base de datos en respuestas de error al cliente.

---

## 7. Protocolo del Cerebro y Memoria Persistente (Long-Term Brain)

1. **Consulta Previa al Cerebro**: Antes de abordar cualquier refactorización compleja, solución de bugs o diseño de módulos, el agente debe inspeccionar `BRAIN.md` o `.agents/brain/lessons_learned.md` para verificar si ya existe una solución previa o un antipatrón prohibido. La forma dirigida es `./.agents/scripts/task.sh brain for TASK-XXX [ruta...]` (lecciones y deuda relevantes para la tarea y los archivos que se van a tocar) y `task.sh brain search <términos>`; `task.sh start` muestra ese resumen al iniciar la tarea.
2. **Registro Obligatorio de Aprendizajes**: toda tarea que tuvo algún rechazo de QA o que corrige un defecto deja una lección **antes** de cerrarse. Se registra con `task.sh learn` (skill `/aprender`), indicando con `--paths` las rutas a las que aplica, y `task.sh close` lo impone: sin `--lesson LL-XXX` (una lección activa) o `--no-lesson "<motivo>"` no cierra la tarea. Cuenta como corrección la tarea cuya descripción empieza por `Bug:`, `Fix:` o `Hotfix:` (el mismo criterio que crea su rama `fix/`), y los rechazos se cuentan en el historial, de modo que reabrir una tarea `BLOCKED` con `move` no borra la obligación. Si el motivo de un `task.sh reject` ya estaba cubierto por una lección activa, se anota como **reincidencia** en `.agents/brain/recurrences.md`. La fuente única de lecciones es `.agents/brain/lessons_learned.md`; la tabla de `BRAIN.md` se genera desde ella y no se edita a mano.
3. **Respeto a las Preferencias del Usuario**: El archivo `.agents/brain/preferences.md` es vinculante para todos los agentes; se deben respetar las convenciones de tipado, estilo de código y UX allí indicadas.
4. **El Cerebro va al Agente**: cada lección declara su **ámbito** (globs de rutas). En Claude Code, el hook `.agents/scripts/brain-context.sh` (`.claude/settings.json`) muestra al agente, una vez por sesión, las lecciones activas cuyo ámbito cubre el archivo que va a editar; es informativo y nunca bloquea. En Antigravity no hay hooks: antes de editar, el agente ejecuta `./.agents/scripts/task.sh brain for TASK-XXX <rutas que va a tocar>`.

---

## 8. Matriz de Propiedad de Código y Límites de Archivos (Code Ownership)

Para prevenir colisiones o sobreescrituras accidentales entre especialistas, cada agente tiene jurisdicción sobre áreas específicas del código:

| Agente | Directorios y Archivos Permitidos | Zonas Prohibidas |
| :--- | :--- | :--- |
| **`orchestrator-agent`** | `GLOBAL_STATE.md`, `BRAIN.md`, documentación de alto nivel | Modificación directa de lógica de código productivo |
| **`product-manager-agent`** | `docs/product/`, `specs/`, historias de usuario, user journeys, PRDs | Modificación de código fuente funcional en `src/`, `server/`, `mobile/` |
| **`backend-agent`** | `server/`, `src/api/`, `src/controllers/`, `src/services/`, `src/models/` | Componentes visuales UI, vistas HTML, hojas de estilo CSS |
| **`frontend-agent`** | `src/app/`, `src/components/`, `src/views/`, `public/`, estilos visuales | Esquemas de base de datos, consultas SQL/ORM de servidor |
| **`mobile-agent`** | `mobile/`, `src/screens/`, `src/navigation/`, `ios/`, `android/`, vistas móviles nativas | Esquemas de base de datos, endpoints o controladores backend de servidor |
| **`database-architect-agent`** | `database/`, `migrations/`, `schemas/`, scripts de seed/purge | Componentes visuales, endpoints de transporte HTTP |
| **`qa-security-agent`** | `tests/`, `*.spec.ts`, `*.test.ts`, reportes de defectos | Código productivo sin revisión previa |
| **`devops-cloud-agent`** | `Dockerfile`, `docker-compose.yml`, `.github/`, configs de build (`vite`, `next`, `angular`) | Reglas de negocio puras |
| **`ui-ux-agent`** | Archivos de tokens de diseño, `variables.css`, temas, iconografía | Controladores backend, lógica de persistencia |
| **`domain-logic-agent`** | `src/domain/`, funciones puras de cálculo matemático, máquinas de estado | Detalles de infraestructura o transporte HTTP |
| **`ai-integrator-agent`** | `src/ai/`, prompts, clientes Ollama/Cloud, pipelines RAG/embeddings | Tablas de base de datos no vectoriales sin aprobación |
| **`docs-architecture-agent`** | `README.md`, `docs/`, diagramas Mermaid, OpenAPI specs | Modificación de código fuente funcional |

> **Rutas según el stack**: las rutas de la tabla son genéricas. Si el proyecto tiene una skill `stack-*`, sus rutas mandan:
> - **Monorepo Angular + Express (`stack-angular-express-postgres`)**: `apps/web/` = frontend, `apps/api/` = backend, `apps/api/drizzle/` y `apps/api/src/db/` = base de datos, `packages/shared/src/domain/` = dominio, `e2e/` = QA.
> - **API Python (`stack-fastapi-postgres`)**:
>   - **`backend-agent`**: `app/api/` (routers y `deps.py`), `app/services/`, `app/schemas/`, `app/core/`, `app/main.py`.
>   - **`database-architect-agent`**: `app/models/`, `app/db/`, `alembic/` (`env.py` y `versions/`), scripts de seed.
>   - **`domain-logic-agent`**: `app/domain/` (funciones puras sin FastAPI ni base de datos).
>   - **`qa-security-agent`**: `tests/` (pytest) y `e2e/` si hay interfaz.
>   - **`devops-cloud-agent`**: `Dockerfile`, `docker-compose.yml`, `.github/workflows/`, `pyproject.toml` (herramientas de build), `.env.example`.
>   - **Frontend**: independiente; si lo hay, rige su propio stack y consume el contrato OpenAPI de `/openapi.json`.
> - **Next.js + Prisma (`stack-nextjs-tailwind-prisma`)**:
>   - **`frontend-agent`**: `app/(auth)/`, `app/(dashboard)/`, `app/page.tsx`, `app/layout.tsx`, `components/ui/`, `components/forms/`, `app/globals.css` (vistas, componentes interactivos y estado reactivo).
>   - **`backend-agent`**: `app/api/` (Route Handlers), Server Actions en `app/actions/` o `lib/actions/`, `lib/auth.ts`, `lib/schemas/` (validaciones Zod).
>   - **`database-architect-agent`**: `prisma/schema.prisma`, `prisma/migrations/`, `lib/prisma.ts` (singleton de PrismaClient), scripts de seed y fixtures.
>   - **`ui-ux-agent`**: `app/globals.css`, directivas `@theme` de Tailwind 4 o `tailwind.config.ts`, variables CSS y temas visuales.
>   - **`domain-logic-agent`**: `lib/domain/`, funciones puras de cálculo matemático, tipos compartidos y máquinas de estado en `lib/`.
>   - **`qa-security-agent`**: `e2e/`, `*.test.ts`, `*.spec.tsx` (tests unitarios/integración con Vitest y E2E con Playwright).
>   - **`devops-cloud-agent`**: `next.config.ts`, `docker-compose.yml`, `Dockerfile`, `.github/workflows/`, presupuestos de build y `.env.example`.

> **Regla de Coordinación**: Si una tarea requiere cambios cruzados (ej. nuevo endpoint + nueva pantalla), el Orchestrator debe asignar subtareas independientes a cada especialista.


