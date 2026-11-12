# Changelog

Todos los cambios relevantes de la librería SKILL MAESTRO. El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado, [SemVer](https://semver.org/lang/es/). La versión instalada en un proyecto está en `.agents/VERSION`; `init-project.sh --update` la sincroniza.

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
