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
5. **Skills de flujo**: los pasos recurrentes del ciclo tienen su propia skill invocable con `/`: `/iniciar-proyecto`, `/estado`, `/nueva-tarea`, `/bugfix`, `/handoff`, `/qa-review`, `/release` y `/aprender`. Úsalas en lugar de improvisar el procedimiento.
6. **Skills de stack**: si el stack declarado en `GLOBAL_STATE.md` §2 tiene una skill `stack-*` (ej. `stack-angular-express-postgres`), todo agente que escriba código la carga **junto con** la skill de su rol. La skill de stack manda en convenciones concretas (estructura, librerías, comandos); la del rol, en el proceso.
7. **Skills de técnica**: cuando una tarea toca pagos (`payments-stripe`), SEO y SSR (`seo-web`), rendimiento (`web-performance`), varios idiomas (`i18n`) o pruebas end-to-end (`e2e-testing`), el agente asignado carga también esa skill. El Orchestrator lo indica en los criterios de la tarea. `payments-stripe`, `seo-web`, `web-performance` e `i18n` están escritas para Angular + Express; con otro stack sirven como guía de principios y sus comandos se adaptan (registrándolo como ADR).

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
| `IN_REVIEW_QA` → `DONE` | `task.sh close TASK-XXX` | `qa-security-agent` (solo tras aprobar) |
| Salir de `BLOCKED` (→ `TODO`, `BACKLOG` o `IN_PROGRESS`, reinicia a 0/3) | `task.sh move TASK-XXX <ESTADO>` | `orchestrator-agent` (solo tras decisión humana) |
| Replanificar (→ `TODO` o `BACKLOG`) | `task.sh move TASK-XXX <ESTADO>` | `orchestrator-agent` |

```text
TODO ──start──> IN_PROGRESS ──handoff──> IN_REVIEW_QA ──close──> DONE
                     ▲                        │
                     └────── reject (n/3) ────┘   reject a 3/3 ──> BLOCKED ──> ESCALAMIENTO AL HUMANO
```

`move` nunca lleva a `DONE`, `IN_REVIEW_QA` ni `BLOCKED`, ni a `IN_PROGRESS` salvo desde `BLOCKED`: esas transiciones solo existen con `close`, `handoff`, `reject` y `start`, que aplican sus controles.

**Traspaso formal (*hand-off*)**: el especialista nunca marca su propia tarea como terminada. Antes de `task.sh handoff` debe cumplir el checklist de su skill y dejar en el historial de `GLOBAL_STATE.md` los entregables y los comandos exactos para verificarlos (formato: `.agents/templates/handoff_template.json`).

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
   - Formato obligatorio: `tipo(TASK-XXX): descripción en imperativo`. Usa `./.agents/scripts/task.sh commit TASK-XXX "<descripción>" [tipo]`, que lo aplica (el hook `commit-msg` rechaza el resto).
   - Ejemplos:
     - `feat(TASK-001): implementar autenticacion jwt y middleware rbac`
     - `test(TASK-002): anadir pruebas de integracion para endpoints de usuario`
     - `fix(TASK-003): corregir calculo de prorrateo en servicio de facturacion`

---

## 6. Seguridad y Protección de Datos

1. **Cero Secretos en el Repositorio**: Toda clave de API, token JWT, contraseña de base de datos o llave criptográfica debe cargarse mediante variables de entorno (`.env`).
2. **Comandos Destructivos Prohibidos**: Ningún agente tiene permiso para ejecutar comandos destructivos (`rm -rf`, `DROP TABLE`, `DROP DATABASE`, `git push --force`) sin autorización explícita del usuario.
3. **Manejo Seguro de Errores**: Prohibido exponer trazas internas de stack o detalles del motor de base de datos en respuestas de error al cliente.

---

## 7. Protocolo del Cerebro y Memoria Persistente (Long-Term Brain)

1. **Consulta Previa al Cerebro**: Antes de abordar cualquier refactorización compleja, solución de bugs o diseño de módulos, el agente debe inspeccionar `BRAIN.md` o `.agents/brain/lessons_learned.md` para verificar si ya existe una solución previa o un antipatrón prohibido.
2. **Registro Obligatorio de Aprendizajes**: Cuando el `qa-security-agent` apruebe la resolución de un defecto no trivial o se adopte una regla crítica, el `orchestrator-agent` debe registrar de inmediato el aprendizaje en la sección de Lecciones Aprendidas de `BRAIN.md`.
3. **Respeto a las Preferencias del Usuario**: El archivo `.agents/brain/preferences.md` es vinculante para todos los agentes; se deben respetar las convenciones de tipado, estilo de código y UX allí indicadas.

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

> **Rutas según el stack**: las rutas de la tabla son genéricas. Si el proyecto tiene una skill `stack-*`, sus rutas mandan (ej. en el monorepo Angular + Express: `apps/web/` = frontend, `apps/api/` = backend, `apps/api/drizzle/` y `apps/api/src/db/` = base de datos, `packages/shared/src/domain/` = dominio, `e2e/` = QA).

> **Regla de Coordinación**: Si una tarea requiere cambios cruzados (ej. nuevo endpoint + nueva pantalla), el Orchestrator debe asignar subtareas independientes a cada especialista.


