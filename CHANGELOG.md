# Changelog

Todos los cambios relevantes de la librería SKILL MAESTRO. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado, [SemVer](https://semver.org/lang/es/). La versión instalada en un proyecto está en `.agents/VERSION`; `init-project.sh --update` la sincroniza.

## [Unreleased]

### Añadido
- `tests/test-skills.sh` endurecido para exigir cierre YAML `---`, palabra clave `Usar`, secciones obligatorias por tipo de skill y enlaces relativos a raíz, plantillas y referencias (TASK-040).
- `tests/evals/evals.json` ampliado de 5 a 8 evals deterministas con `handoff-verificacion`, `refactor-caracterizacion` y `security-hardening-sql-idor` (fixtures en `tests/evals/fixtures/`), cubiertos junto a los nuevos linters en `tests/test-scripts.sh` (265 comprobaciones) y alineados en `QUICKSTART.md` (TASK-040).
- `tests/evals/evals.json` pasa de 8 a 15 evals deterministas: una por cada rol que escribe código (`backend-agent`, `frontend-agent`, `database-architect-agent`, `domain-logic-agent`, `devops-cloud-agent`) y por `testing-strategy` y `async-jobs`, con sus fixtures. Todas fallan en el estado inicial y pasan con una solución de referencia; `tests/test-scripts.sh` exige al menos 14, cobertura de esos roles y fixtures con permisos `755` (TASK-048).
- `task.sh check <rutas>` y `.agents/scripts/pre-edit-check.sh`: antes de editar, aplican el control de "cero código sin tarea" (exit 2 si alguna ruta está bloqueada) y muestran las lecciones de esas rutas, reutilizando los dos hooks de Claude Code. Da a Antigravity, que no tiene hooks, el mismo control; `AGENTS.md` §2.4 y §7.4 y las skills de rol lo piden antes de editar (TASK-049).
- `run_evals.py --verify-baselines`: sin LLM ni coste, comprueba que cada eval falla tras su setup (FAIL_INIT) y que el setup funciona; lo ejecutan `tests/test-scripts.sh` y la CI (`library.yml`) (TASK-049).

### Cambiado
- `orchestrator-agent` lista también `security-hardening` y `observability` entre las skills de técnica (TASK-041).
- `qa-review` delega la verificación independiente en Antigravity con `TypeName: "self"` y documenta que citar `LL-XXX` en `task.sh reject` garantiza el registro de reincidencias (TD-004, TASK-041).
- `devops-cloud-agent` y `.agents/templates/ci_workflow_template.yml` actualizados a Node 24 LTS (TASK-041).
- Las skills de roles de código recuerdan ejecutar `./.agents/scripts/task.sh brain for TASK-XXX <rutas>` antes de editar (paridad con el hook `brain-context.sh` en Antigravity), y `e2e-testing` incorpora sección `## Prohibido` (TASK-041).

### Corregido
- Los hooks `require-active-task.sh` y `brain-context.sh` normalizan la ruta editada: `.agents/../src/app.ts` ya no esquiva "Cero Código sin Tarea", los symlinks se resuelven (`realpath`), un `file_path` que no es texto se bloquea y una ruta relativa fuera del proyecto (`../otro/x.ts`) deja de bloquearse (TASK-050).
- `install-hooks.sh` e `init-project.sh` (instalación, `--update` y `--adopt`) funcionan en worktrees y submódulos (`.git` es un archivo): los hooks se instalan en el directorio que git usa de verdad (`git rev-parse --git-path hooks`), con `core.hooksPath` (husky, lefthook) no se pisan los existentes, y desde un subdirectorio de otro repositorio no se instalan en él (TASK-050).
- `task.sh` sale con exit 1 ante un comando desconocido, en lugar de mostrar la ayuda con exit 0; `SIGINT` y `SIGTERM` terminan el script tras liberar el bloqueo (exit 130/143), en vez de continuar escribiendo sin él (TASK-050).
- `task.sh` y `tests/test-skills.sh` emiten colores ANSI solo en una terminal y respetan `NO_COLOR` y `TERM=dumb`; los errores de `task.sh` solo llevan color si stderr es una terminal (TASK-050).
- Saldadas `TD-003` (`brain-context.sh` valida `IN_PROGRESS` antes de emitir/marcar vista, usa bloqueo de sesión seguro sin robar locks y purga sesiones `>7` días) y `TD-004` (`recurrence_for` compara causa raíz y plurales simples; `task.sh close` exige emisor `qa-security-agent`) (TASK-039, TASK-041).
- `debt_sync()` integrado en `task.sh brain sync`, `debt` y `debt-resolve` con guarda de cabecera y `FILENAME` (evita borrado de `BRAIN.md` ante `tech_debt.md` vacío); `brain doctor` valida §6 de `BRAIN.md` y la tabla de `tech_debt.md` (TASK-039).
- Endurecidos `task.sh` (`next_id`, `handoff` con `-z`/`quotePath=false`, `close` con `git for-each-ref`, `Última Actualización`), `init-project.sh` (`--stack`, permisos en `strip_examples`, aviso de drift en `AGENTS.md`) y `validate-state.sh` (IDs duplicados y agentes desconocidos) (TASK-039).

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
