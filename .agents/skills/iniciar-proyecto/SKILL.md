---
name: iniciar-proyecto
description: Arranca un proyecto nuevo: chequeo pre-vuelo doctor --kickoff, entrevista de arquitectura y 5 tareas fundacionales. Usar al empezar o con placeholders en GLOBAL_STATE.md. No usar en repositorios ya construidos (adoptar-proyecto).
---

# /iniciar-proyecto — Kickoff y Arranque de Desarrollo

Actúas como `orchestrator-agent` (carga su skill).

## Pasos

1. **Verificar instalación y diagnóstico pre-vuelo**:
   - Comprueba en la raíz: `.agents/skills/`, `.agents/scripts/task.sh`, `AGENTS.md`, `CLAUDE.md` y `GLOBAL_STATE.md`.
   - Si falta `GLOBAL_STATE.md`, créalo desde [GLOBAL_STATE_TEMPLATE.md](../../templates/GLOBAL_STATE_TEMPLATE.md).
   - Si falta el resto, indica ejecutar `npx skill-maestro init` o `init-project.sh` (ver `QUICKSTART.md`) y detente.
   - Ejecuta o recomienda el diagnóstico pre-vuelo local: `./.agents/scripts/task.sh doctor --kickoff` para verificar Node.js, Python, Git, Docker y puertos libres.
   - Presenta la portada de bienvenida de SKILL MAESTRO (creador: Klisman Vizcarra, versión de `.agents/VERSION`) como saludo inicial usando la plantilla visual [welcome_cover_template.html](../../templates/welcome_cover_template.html) o el banner tipográfico.

2. **Entrevista Heurística de Arquitectura**: Si los requerimientos no están cerrados, formula en un solo mensaje estructurado la **Matriz de 4 Dimensiones**:
   - **Actores y Autorización**: ¿Quiénes interactúan con el producto (roles) y qué permisos requieren (RBAC)?
   - **Persistencia y Consistencia**: ¿Relacional transaccional (PostgreSQL) o documental (MongoDB)? ¿Entidades clave?
   - **Integraciones y Servicios Críticos**: ¿Cobros (`payments-stripe`), colas/emails (`async-jobs`), almacenamiento de medios, IA (`ai-integrator-agent`)?
   - **Despliegue y Hosting**: ¿Vercel/Cloudflare, VPS con Docker Compose o nube pública (GCP/AWS)?
   Si la idea de negocio aún es difusa, propone pasar antes por `/product-manager-agent`. Si hay referentes del mercado que estudiar, propone `/research-agent`.

3. **Proponer y confirmar el stack**:
   - Define frontend, backend, base de datos, auth y despliegue con justificación en una línea por componente.
   - Si existe `docs/plan/plan-maestro.md`, parte del stack allí propuesto y pide confirmación al usuario.

4. **Completar `GLOBAL_STATE.md`**:
   - Actualiza Metadatos (§1), Stack Tecnológico (§2), la decisión de arquitectura como primer ADR (§6) y un hito en el registro (§7).
   - Retira las tareas de ejemplo `TASK-001`/`TASK-002` de la plantilla.

5. **Secuencia Canónica de Arranque (Las 5 Tareas Fundacionales)**:
   Si no hay un plan maestro previo con tareas cerradas, registra mediante `./.agents/scripts/task.sh add` el pack fundacional de la Fase 1:
   1. **`TASK-001` (Scaffolding & CI)**: asignada a `devops-cloud-agent` — Estructura base compilando, scripts dev/test, `docker-compose.yml` y workflow CI.
   2. **`TASK-002` (Persistencia Base)**: asignada a `database-architect-agent` — Esquema inicial (usuarios, auditoría), migración inicial reversible y seeds.
   3. **`TASK-003` (Seguridad y Auth)**: asignada a `backend-agent` (+ `security-hardening`) — Endpoints registro/login, hashing Argon2/Bcrypt y middleware JWT/RBAC.
   4. **`TASK-004` (Contratos de Integración)**: asignada a `backend-agent` — Especificación `contracts.json` inicial con `/health` y `/api/users/me`, validada con `task.sh contracts validate`.
   5. **`TASK-005` (UI Foundation)**: asignada a `frontend-agent` (+ `ui-ux-agent`) — Layout principal responsivo, tokens de diseño CSS (claro/oscuro) y estado reactivo.
   *(Si el usuario prefiere ver el roadmap completo de varias fases con Gantt y riesgos antes de registrar tareas, lanza `/crear-plan`).*

6. **Cierre y Lanzamiento**:
   - Ejecuta `./.agents/scripts/validate-state.sh` (debe salir limpio y sin placeholders pendientes).
   - Muestra el resumen de estado tipo `/estado` y sugiere iniciar el Live Dashboard: `./.agents/scripts/task.sh serve`.

## Prohibido
- Registrar tareas sin confirmación explícita del stack por el usuario.
- Modificar o sobreescribir código productivo directamente durante el kickoff.
- Dejar placeholders `<...>` o campos vacíos en `GLOBAL_STATE.md`.
