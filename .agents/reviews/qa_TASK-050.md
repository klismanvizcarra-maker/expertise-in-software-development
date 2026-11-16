# Veredicto de QA: TASK-050

- **Tarea**: `TASK-050`
- **Fecha**: 2026-11-16
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Revisión independiente (subagente con contexto limpio) sobre la rama `fix/TASK-050-endurecer-hooks-y-cli-rutas-co` (`4088c60`) frente a `main` (`694f7c8`). Las pruebas manuales se hicieron en proyectos temporales (`mktemp -d`) instalados con `init-project.sh`, en macOS con `/bin/bash` 3.2.57 y git 2.54.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| 1. `require-active-task.sh` y `brain-context.sh` normalizan la ruta | ✅ | Bloqueados (exit 2): `.agents/../src/app.ts`, `$P//.agents//..//src//app.ts`, `//$P/...`, `./.agents/../src/app.ts`, `docs/../src/app.ts`, `src/x.md/../app.ts`, `.agents/../src/a.ts`, raíz con barra final, raíz `.` / `./` / `p/../p`, raíz con espacios. Permitidos (exit 0): `../otro/x.ts`, `$P/../otro/x.ts`, prefijo hermano `${P}2/src/x.ts`. `brain-context.sh` inyecta la lección de `src/*.ts` con `.agents/../src/app.ts`, `//`, `./` y raíz con barra final; ignora `../otro/...`; no emite sin `IN_PROGRESS`; JSON inválido o `file_path` no string → exit 0 |
| 2. `install-hooks.sh` funciona en worktrees y respeta `core.hooksPath` sin pisar hooks existentes | ⚠️ | `install-hooks.sh` sí: worktree con espacios en el nombre (instala en `<común>/.git/hooks`), submódulo (`.git/modules/lib/hooks`, un commit sin formato se rechaza), `core.hooksPath` relativo, absoluto inexistente y desde un subdirectorio; un `pre-commit` propio en `.husky`/`.hk` se conserva. **Pero** el instalador oficial no lo usa en worktrees: ver `BUG-TASK-050-1` |
| 3. `task.sh` sale con exit 1 ante un comando desconocido | ✅ | `clsoe`, `HELP` y `--version` → exit 1, mensaje por stderr y stdout vacío (0 bytes); `help`, `-h`, `--help`, sin argumentos y `""` → exit 0; también con `/bin/bash` 3.2 |
| 4. SIGINT y SIGTERM terminan `task.sh` tras liberar el lock (130/143) | ✅ | `start` con un `git` falso que se detiene en `checkout`, señal enviada desde Python (para que SIGINT no llegue ignorado como en `&`): SIGINT → 130 y SIGTERM → 143, sin `.agents/.task_lock` residual, con `bash` 5 y con `/bin/bash` 3.2 |
| 5. Colores ANSI solo en una terminal, respetando `NO_COLOR` y `TERM=dumb` | ✅ | Con un pty: `task.sh list` y `tests/test-skills.sh` usan ESC con `TERM=xterm`; texto plano con `NO_COLOR=1` y `TERM=dumb`; `NO_COLOR=` vacío mantiene los colores (como dice no-color.org); en una tubería, 0 secuencias ESC |
| 6. Hay tests nuevos en `tests/test-scripts.sh` que fallan antes del arreglo | ✅ | `git archive HEAD` en un directorio temporal, con los 5 scripts de `main` y el `tests/test-scripts.sh` nuevo: **288 OK, 10 fallidas**. Fallan los 10 tests de criterios 1–5 (rutas `..`, worktree, `core.hooksPath`, comando desconocido, `NO_COLOR`, SIGTERM). Los otros 6 son de guarda y ya pasaban en `main` |
| 7. La suite pasa al 100% | ✅ | `LC_ALL=C bash tests/test-scripts.sh` → 298 OK, 0 fallidas (exit 0); `test-flow.sh` → 25 OK; `test-skills.sh` → 36 skills sin errores; `lint_descriptions.py` → sin problemas; `validate-state.sh` → 0 errores y 0 avisos (todos con exit 0) |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` → sin hallazgos (respecto a `main` `694f7c8`) |
| Regresiones en `task.sh` e `init-project.sh` (`--adopt`, `--update`) | ✅ | Suite completa en verde, incluidas las secciones `--adopt` (conserva hooks propios en `.git/hooks`) y el ciclo `add/start/handoff/reject/close/archive`; `bash -n` limpio en los 6 scripts modificados; ninguna skill ni documento depende de que `task.sh <desconocido>` salga con exit 0 (todas las llamadas usan subcomandos válidos) |
| Auditoría de seguridad | ✅ | Sin inyección: `ROOT` y la ruta llegan a Python por entorno o JSON, no se interpolan; `session_id` sigue saneado; sin secretos |

## 2. Observaciones y Hallazgos

### BUG-TASK-050-1 (MEDIA): `init-project.sh` sigue suponiendo que `.git` es un directorio y no instala los git hooks en worktrees

- **Componente**: DevOps (`.agents/scripts/init-project.sh:203` y `.agents/scripts/init-project.sh:408`).
- **Descripción**: la corrección hace que `install-hooks.sh` funcione en worktrees, pero el instalador que lo llama solo lo hace si se cumple `[ -d "$TARGET_DIR/.git" ]`. En un worktree `.git` es un archivo, así que `init-project.sh`, `--update` y `--adopt` se saltan los git hooks sin avisar: no se instalan ni `commit-msg` ni el `pre-commit` que escanea secretos. Es la misma causa raíz que esta tarea corrige y que la lección LL-016 de la entrega prohíbe ("preguntar a git por sus rutas en lugar de suponer `.git/`").
- **Reproducción**:
  ```bash
  W=$(mktemp -d); cd "$W" && git init -q -b main base && cd base
  git -c user.email=a@b -c user.name=a commit -q --allow-empty -m init
  git worktree add -q "$W/wt" -b wt && git worktree add -q "$W/wt2" -b wt2
  bash "<repo>/.agents/scripts/init-project.sh" "P" "$W/wt"   # sin "-> Instalando Git Hooks"
  bash "<repo>/.agents/scripts/init-project.sh" --adopt "$W/wt2"
  ls .git/hooks | grep -v sample   # vacío: ningún hook instalado
  ```
- **Observado**: exit 0 y ningún hook en `git rev-parse --git-path hooks`. **Esperado**: igual que en un repositorio normal, se instalan (con `--preserve-existing` en `--adopt`).
- **Recomendación**: en las dos líneas, sustituir `[ -d "$TARGET_DIR/.git" ]` por `git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1`, o mejor comprobar que `git -C "$TARGET_DIR" rev-parse --show-toplevel` es `$TARGET_DIR`, para no instalar en un repositorio padre cuando el destino es un subdirectorio sin repositorio propio. Añadir un test en `tests/test-scripts.sh` que ejecute `init-project.sh` y `--adopt` sobre un worktree de un repositorio **sin** hooks previos y compruebe `commit-msg` y `pre-commit` en `$(git rev-parse --git-path hooks)`.

### Observaciones (BAJA, no bloqueantes; se pueden resolver en la misma iteración)

1. **Test que no discrimina**: el check `con los hooks del worktree, un commit sin TASK-XXX se rechaza` (`tests/test-scripts.sh:868`) también pasa en `main`, porque `new_project` ya instaló los hooks en el `.git/hooks` común antes de crear el worktree. Lo mismo ocurre con `[ -x .git/hooks/commit-msg ]` en el check anterior: solo discrimina el exit code. Conviene borrar `.git/hooks/{commit-msg,pre-commit}` antes de ejecutar `install-hooks.sh` desde el worktree.
2. **Faltan tests de dos casos del criterio**: SIGINT (exit 130), que verifiqué a mano, y los colores de `tests/test-skills.sh` con pty, `NO_COLOR` y `TERM=dumb`.
3. **Symlinks y realpath (ya pasaba en `main`)**: la normalización es solo léxica (`normpath`). Si `CLAUDE_PROJECT_DIR` y `file_path` difieren por un symlink (`/var` frente a `/private/var` en macOS, o una raíz enlazada), el archivo se considera externo y se permite: `/private$P/src/app.ts` con raíz `$P` en `/var/...` → exit 0. `main` hacía lo mismo. Se resolvería con `os.path.realpath` en los dos lados.
4. **ANSI en stderr redirigido**: el color se decide con `[ -t 1 ]`. Con stdout en una terminal y stderr redirigido a un archivo (`task.sh clsoe 2>log`, `task.sh start TASK-999 2>log`), el archivo recibe secuencias ESC. `die()` ya lo hacía en `main`.
5. **`file_path` que no es string**: ahora se permite (`{"file_path":123}` → exit 0) y `main` lo bloqueaba. No se puede explotar porque la herramienta rechaza esa entrada, pero el cambio va de fallar cerrado a fallar abierto.
6. **`install-hooks.sh` desde un subdirectorio sin repositorio propio**: si ese subdirectorio está dentro de otro repositorio, ahora instala los hooks en el repositorio padre; antes se negaba. Puede ser lo deseado en un monorepo, pero conviene documentarlo.

- **Deuda Técnica**: no registrada; corresponde al especialista resolver `BUG-TASK-050-1` en la iteración 2/3.
- **Lección**: LL-015 y LL-016 ya registradas por el especialista. `BUG-TASK-050-1` es un caso del antídoto de LL-016 que no se aplicó a `init-project.sh`; al cerrar, usar `--lesson LL-016` o `--lesson LL-015`. `task.sh reject` lo anotó como reincidencia de LL-016 en `.agents/brain/recurrences.md`: el ámbito (`.agents/scripts/*.sh`) ya cubría `init-project.sh`, pero el antídoto solo se aplicó a `install-hooks.sh`.

## 3. Conclusión y Veredicto Final

- **Estado**: `RECHAZADA`
- **Siguiente paso**: `task.sh reject TASK-050` (iteración 1/3). El especialista retoma con `./.agents/scripts/task.sh start TASK-050`, corrige `BUG-TASK-050-1` con su test, y, si quiere, las observaciones 1 y 2, y vuelve a entregar con `task.sh handoff TASK-050`.
