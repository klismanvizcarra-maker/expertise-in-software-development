# Veredicto de QA: TASK-050

- **Tarea**: `TASK-050`
- **Fecha**: 2026-11-16
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `2/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente con contexto limpio (subagente) de la rama `fix/TASK-050-endurecer-hooks-y-cli-rutas-co` (`6a1b7f9`) frente a `main` (`694f7c8`). Las pruebas manuales se hicieron en proyectos temporales (`mktemp -d`) instalados con `init-project.sh`. Entorno: macOS, `/bin/bash` 3.2.57 (el único `bash` del `PATH`) y git 2.54.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| **BUG-TASK-050-1** (iteración 1): `init-project.sh` no instalaba hooks en worktrees | ✅ | La reproducción del veredicto anterior, en un `mktemp -d`, ahora funciona. Instalación nueva en un worktree: `-> Instalando Git Hooks` y `commit-msg` y `pre-commit` en `base/.git/hooks`. `--adopt` en un worktree con espacios en el nombre: también los instala. `--update`: los reinstala tras borrarlos. Un commit `"sin formato"` desde el worktree se rechaza (rc=1). `--adopt` conserva un `pre-commit` propio. La causa raíz está corregida en `init-project.sh:131-136` (`is_git_root`, con `rev-parse --show-toplevel` y `pwd -P`) y en las líneas 212 y 417 |
| 1. `require-active-task.sh` y `brain-context.sh` normalizan la ruta | ✅ | Bloqueado (exit 2): `.agents/../src/app.ts`, `src/app.ts` relativo y absoluto con raíz `proy con  espacios`, `CLAUDE_PROJECT_DIR=.` y sin `CLAUDE_PROJECT_DIR`. Permitido (exit 0): `../otro/x.ts`, `README.md` y `docs/x.ts`. `brain-context.sh` inyecta la lección de `src/*.ts` con la raíz con espacios, con `.agents/../src` y con la raíz o el archivo vistos a través de un symlink. Ignora los archivos de fuera del proyecto |
| 2. `install-hooks.sh` funciona en worktrees y respeta `core.hooksPath` sin pisar hooks existentes | ✅ | Probado en un worktree, con `init-project.sh` y directamente. En un submódulo instala en `.git/modules/mod/hooks` y no en el repositorio padre. En un repositorio anidado instala en su propio `.git/hooks`. Con un worktree, `core.hooksPath=.husky` y `--update`, añade `commit-msg`, conserva el `.husky/pre-commit` propio (`echo propio`) y avisa de que lo conserva |
| 3. `task.sh` sale con exit 1 ante un comando desconocido | ✅ | `task.sh clsoe` → rc=1, 0 bytes en stdout y error por stderr (sin ESC en una tubería, comprobado con `od -c`). `task.sh help` → rc=0 |
| 4. SIGINT y SIGTERM terminan `task.sh` tras liberar el lock (130/143) | ✅ | Hay tests nuevos para los dos: `signal_start SIGINT` → 130 y `signal_start SIGTERM` → 143, sin `.agents/.task_lock` residual. Fallan con `main` y pasan en la rama. Los traps de `task.sh:119-121` están separados (`EXIT` limpia; `INT`/`TERM` limpian y salen) |
| 5. Colores ANSI solo en una terminal, respetando `NO_COLOR` y `TERM=dumb` | ✅ | Tests con pty en `task.sh list` y `tests/test-skills.sh`: hay ESC con `TERM=xterm` y texto plano con `NO_COLOR=1` o `TERM=dumb`. `task.sh` no tiene otra escritura en stderr con color aparte de `die()` (`task.sh:64-68`), que comprueba `-t 2` |
| 6. Hay tests nuevos en `tests/test-scripts.sh` que fallan antes del arreglo | ✅ | Copia con `git archive HEAD` y los 6 archivos de `main` (`task.sh`, `require-active-task.sh`, `brain-context.sh`, `install-hooks.sh`, `init-project.sh`, `tests/test-skills.sh`) junto al `tests/test-scripts.sh` nuevo: **290 OK, 18 fallidas**. Fallan las rutas `..` (5), el symlink, el worktree (2), `init-project` en un worktree (3), `core.hooksPath`, el comando desconocido, `NO_COLOR`, SIGTERM, SIGINT, ANSI en el log de stderr y los colores de `test-skills.sh`. Con los scripts de la iteración 1 (`382a6c1`) hay **301 OK, 7 fallidas**: los tests nuevos de la iteración 2 también distinguen su propio arreglo |
| 7. La suite pasa al 100% | ✅ | `LC_ALL=C bash tests/test-scripts.sh` → 308 OK, 0 fallidas (rc=0), en dos ejecuciones seguidas. `bash tests/test-flow.sh` → 25 OK. `bash tests/test-skills.sh` → 36 skills sin errores. `python3 tests/triggers/lint_descriptions.py` → sin problemas. `./.agents/scripts/validate-state.sh` → 0 advertencias. Todos con rc=0. `bash -n` limpio en `.agents/scripts/*.sh` y `tests/*.sh` |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` → sin hallazgos respecto a `main` (`694f7c8`), rc=0 |
| Batería de pruebas (comandos del handoff) | ✅ | Los 6 `verification_commands` de `.agents/handoffs/handoff_TASK-050.json` se ejecutaron por separado, todos con rc=0 |
| Regresiones: `.claude/skills` es un symlink a `.agents/skills` | ✅ | `realpath` resuelve `.claude/skills/qa-review/scripts/x.py` (relativo y absoluto) a `.agents/skills/...`, que se sigue permitiendo (exit 0). `brain-context.sh` inyecta ahora las lecciones con ámbito `.agents/skills/**` al editar a través de `.claude/skills`, lo que es una mejora. Ninguna lección del repositorio tiene ámbito `.claude/` (`grep -c` → 0) |
| Regresiones: `CLAUDE_PROJECT_DIR` con espacios o symlinks | ✅ | Raíz `proy con  espacios` (dos espacios, igual que este repositorio). También `/var` frente a `/private/var`, en ambos sentidos, y una raíz enlazada frente a la real, en ambos sentidos. En todos los casos `src/app.ts` se bloquea y la lección se inyecta |
| Seguridad: bypass por symlink y entradas no textuales (observaciones 3 y 5) | ✅ | Ahora se bloquean (exit 2): `.agents/evil -> ../src` con `.agents/evil/app.ts`, `docs/link.md -> ../src/app.ts`, un bucle de symlinks, `{"file_path":123}`, `["src/a.ts"]`, saltos de línea y `\u0000`. El mensaje es claro: "la ruta del archivo a editar no es válida" |
| Auditoría de seguridad | ✅ | No hay inyección: `ROOT` y la ruta llegan a Python por entorno o por JSON, sin interpolarse en código. `session_id` sigue saneado, no hay secretos y no hay comandos destructivos |

### Observaciones BAJA del veredicto anterior

| # | Observación | Resultado | Evidencia |
| :---: | :--- | :---: | :--- |
| 1 | El test de worktree pasaba también con `main` | ✅ Resuelta | Borra `.git/hooks/{commit-msg,pre-commit}` antes de instalar (`tests/test-scripts.sh:869`); los dos checks del worktree fallan con `main` |
| 2 | SIGINT y los colores de `test-skills.sh` no tenían test | ✅ Resuelta | Tests nuevos en `tests/test-scripts.sh:939` y `:943`; los dos fallan con `main` |
| 3 | Los symlinks no se resolvían | ✅ Resuelta | `os.path.realpath` en los dos lados (`require-active-task.sh:50-51`, `brain-context.sh:55-56`). El test del symlink falla con `main` y con la iteración 1 |
| 4 | Había ANSI en los logs de stderr | ✅ Resuelta | `die()` y el comando desconocido solo usan color si `-t 2`. El test pty con `2>err.log` falla con `main` y con la iteración 1 |
| 5 | Un `file_path` no textual se dejaba pasar | ✅ Resuelta | Centinela `/INVALID` → exit 2 (`require-active-task.sh:46-48`, `:58-61`). El test falla con la iteración 1 |
| 6 | `install-hooks.sh` desde un subdirectorio instalaba en el repositorio que lo contiene | ✅ Resuelta | Ahora se niega con exit 1 y lo explica (`install-hooks.sh:25-28`). `init-project.sh` en un subdirectorio de otro repositorio no toca los hooks de ese repositorio |

## 2. Observaciones y Hallazgos

- **Observaciones (BAJA, no bloqueantes)**:
  1. **`init-project.sh` en un subdirectorio de otro repositorio** omite los git hooks sin avisar. Es lo correcto, porque los hooks usan rutas `./.agents/...` relativas a la raíz, y `main` hacía lo mismo. Aun así, convendría un mensaje del tipo `(no se instalan git hooks: <dir> no es la raíz de un repositorio)` para que no pase desapercibido.
  2. **Entradas falsy o con estructura inesperada en el hook (ya pasaba en `main`)**: `{"file_path":0}`, `{"file_path":[]}`, `{"tool_input":"src/a.ts"}` y un JSON inválido salen con exit 0. `main` daba el mismo resultado, comprobado ejecutando su script. No se puede explotar, porque Claude Code valida el esquema de la herramienta antes del hook.
  3. **Symlink del proyecto que apunta fuera** (`ext -> /otro/dir`): con `realpath`, `ext/a.ts` cuenta como archivo externo y se permite. Encaja con la regla de que los archivos de fuera del proyecto no se controlan, porque la escritura real ocurre fuera. Se deja anotado.
  4. **Lección LL-015 algo desfasada**: su antídoto dice `os.path.normpath`, pero la implementación final usa `os.path.realpath` porque también resuelve symlinks. Conviene actualizar el texto en una tarea de mantenimiento del cerebro.
  5. **Cosmético**: el handoff incluye `.agents/reviews/qa_TASK-050.md` entre los entregables, pero ese archivo es de QA, no del especialista.
- **Deuda Técnica**: no se registra; ninguna observación es MEDIA o superior.
- **Lección**: `LL-016` (registrada por el especialista; su ámbito `.agents/scripts/*.sh,tests/*.sh` cubre `init-project.sh`). BUG-TASK-050-1 fue la reincidencia de LL-016 anotada en `.agents/brain/recurrences.md`, y la corrección aplica su antídoto: preguntar a git (`rev-parse --show-toplevel`) en lugar de suponer `.git/`. Se cierra con `--lesson LL-016`.

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `./.agents/scripts/task.sh close TASK-050 --lesson LL-016`. La fusión a `main` (`git checkout main && git merge --no-ff fix/TASK-050-endurecer-hooks-y-cli-rutas-co && git branch -d fix/TASK-050-endurecer-hooks-y-cli-rutas-co`) la hace el especialista o el `orchestrator-agent`, no QA.
