# SKILL MAESTRO

Sistema multi-agente para desarrollar software con asistentes de IA (**Claude Code** y **Antigravity**). Convierte al asistente en un equipo de ingeniería coordinado: cada rol es una skill, cada cambio es una tarea con criterios de aceptación, nadie aprueba su propio trabajo y lo aprendido se recuerda.

**Versión**: ver [`.agents/VERSION`](.agents/VERSION) · **Cambios**: [CHANGELOG.md](CHANGELOG.md)

## Qué incluye

| Pieza | Dónde | Para qué |
| :--- | :--- | :--- |
| Reglas del sistema | [`AGENTS.md`](AGENTS.md) (Claude Code lo importa desde [`CLAUDE.md`](CLAUDE.md)) | Ciclo de vida de las tareas, veto de QA, Git, seguridad, cerebro y propiedad del código |
| 38 skills | [`.agents/skills/`](.agents/skills) | Roles (`backend-agent`, `qa-security-agent`, `research-agent`...), flujo (`/iniciar-proyecto`, `/adoptar-proyecto`, `/crear-plan`, `/nueva-tarea`, `/bugfix`, `/refactor`, `/pr-review`, `/qa-review`, `/cerrar-fase`, `/release`...), stacks (Angular + Express, Next.js + Prisma, FastAPI) y técnicas (pagos, SEO, rendimiento, i18n, testing, E2E, colas/async, seguridad, observabilidad) |
| CLI de tareas | [`.agents/scripts/task.sh`](.agents/scripts/task.sh) | `add`, `start`, `handoff`, `reject`, `close`, `archive`, `commit`, `learn`, `brain`... Única forma de cambiar el estado de una tarea |
| Cerebro | `BRAIN.md` y [`.agents/brain/`](.agents/brain) | Lecciones con ámbito de rutas, gotchas, deuda técnica, preferencias y glosario; se muestran al agente cuando toca |
| Hooks | `.claude/settings.json`, `.agents/hooks/` | Sin tarea activa no se edita código; las lecciones aparecen al editar; commits convencionales y escaneo de secretos |
| Pruebas | [`tests/`](tests) | Scripts, flujo completo de una tarea, estructura de las skills, batería de activación y evaluaciones en `tests/evals/` |

## Empezar

Requisitos: `bash`, `git` y `python3`. Linux, macOS o Windows con WSL 2.

```bash
./.agents/scripts/init-project.sh "Mi Proyecto" ../mi-proyecto --stack angular --ci
cd ../mi-proyecto && ./.agents/scripts/install-hooks.sh
```

Luego, en el asistente: `/iniciar-proyecto`. La guía completa (opciones de instalación, catálogo de skills, flujo de trabajo y Windows) está en [QUICKSTART.md](QUICKSTART.md).

Para adoptar un proyecto existente (brownfield) sin sobrescribir código ni docs previos, o actualizar uno que ya usa la librería:

```bash
./.agents/scripts/init-project.sh --adopt ../proyecto-existente   # luego ejecuta /adoptar-proyecto
./.agents/scripts/init-project.sh --update ../mi-proyecto
```

## Cómo trabaja

```text
/nueva-tarea → task.sh start → (especialista + skills de stack y técnica) → /handoff
     → /qa-review (revisor independiente) → close → merge --no-ff a main
                 └── reject (máx. 3) ──┘          └── al 3.º rechazo: BLOCKED, decides tú
```

Las tareas rechazadas o de corrección no se cierran sin una lección en el cerebro, y esa lección se muestra al próximo agente que toque los mismos archivos.

## Desarrollar la librería

```bash
bash tests/test-scripts.sh          # scripts, hooks, cerebro e instalación
bash tests/test-flow.sh             # ciclo completo de una tarea
bash tests/test-skills.sh           # estructura de las skills
python3 tests/triggers/lint_descriptions.py
```

Este repositorio se gobierna con su propio sistema: el estado está en [`GLOBAL_STATE.md`](GLOBAL_STATE.md) y las convenciones de la librería en [`.agents/brain/preferences.md`](.agents/brain/preferences.md).
