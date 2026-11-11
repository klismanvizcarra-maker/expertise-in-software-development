# Veredicto de QA: TASK-037

- **Tarea**: `TASK-037`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `0/3` (primera revisión)

---

## 1. Criterios de Aceptación Verificados

Entorno: macOS, `/bin/bash` 3.2, awk BSD. Las pruebas manuales se hicieron en proyectos temporales creados con `init-project.sh` fuera del repo (uno con espacios en la ruta), con `TMPDIR` propio. El repo no se modificó (`git status` igual antes y después).

| Criterio / Control | Resultado | Evidencia (ejecutada por QA) |
| :--- | :---: | :--- |
| Hook `brain-context.sh` registrado en la plantilla de `.claude/settings.json` | ✅ | Plantilla y `.claude/settings.json` del repo son JSON válido e idénticos; un solo grupo `Edit\|Write\|MultiEdit\|NotebookEdit` con `require-active-task.sh` primero y `brain-context.sh` después. Proyecto nuevo: `settings.json` == plantilla, script con permiso de ejecución |
| Muestra la lección cuyo Ámbito cubre el archivo editado | ✅ | Ruta relativa, `./relativa`, absoluta bajo el proyecto, subdirectorio y ámbito de directorio (`migrations/`) → lección con su antídoto. No casa `xmigrations/`, `a.sql.bak`, `myserver/db/`, ni rutas absolutas de fuera |
| Solo lecciones activas con ámbito; excluye `*` y OBSOLETAS | ✅ | LL general (`*`) nunca aparece; tras `lesson-retire` la salida es vacía |
| Una sola vez por lección y sesión | ✅ | Misma sesión: 2ª edición sin salida; otra lección de la misma sesión sí; otra sesión sí. (En paralelo estricto puede repetirse, ver observaciones) |
| Sin bloquear: nunca falla ni bloquea | ✅ | 45+ caminos de fallo con código 0 y stdout vacío o JSON válido: JSON inválido, vacío, `[]`, `null`, cadena, `tool_input` no objeto, `file_path` número/lista/null, sin ruta, 1 MB válido y 1 MB basura, ruta de 300 KB y 2 MB, rutas con espacios, comillas, salto de línea, `$(...)`, backticks, tildes, glob, `\`, `[`; `LC_ALL=C`; sin python3; `TMPDIR` inexistente, de solo lectura, o con el registro sustituido por archivo/directorio; `CLAUDE_PROJECT_DIR` sin definir, inexistente o con espacios; `stdin` = `/dev/null` |
| Nunca falla si falta BRAIN o python3 | ✅ | Sin `lessons_learned.md`, sin `BRAIN.md`, sin ambos, fuente vacía, binaria aleatoria, con filas truncadas y globs con regex rota, CRLF, sin permiso de lectura, `brain-lib.sh` ausente o con error de sintaxis: código 0, stdout vacío o JSON válido |
| El hook no escribe en el proyecto ni migra | ✅ | Hash de `BRAIN.md`, `lessons_learned.md` y `GLOBAL_STATE.md` y listado de `.agents/brain` idénticos antes y después en todos los casos, incluido el esquema antiguo de 6 columnas (no migra) y la fuente ausente (no la crea). `die` y `replace_file` están neutralizados y solo se llama a `relevant_lessons` (lectura) |
| Seguridad: `session_id` hostil e inyección | ✅ | `../..`, `../../../../pwned`, `/etc/x`, `$(touch …)`, backticks, `a b;touch …`, 100 000 caracteres, `.`, `..`, `-rf`: se reducen a `[A-Za-z0-9_-]` (máx. 80) y solo se crean archivos dentro de `$TMPDIR/maestro-brain-context`; ningún archivo `PWNED`. Lección con `"`, `\n`, `\t`, `\\`, `$(…)`, backticks, `%s`, `</x>`: JSON válido, texto literal, solo las claves `hookEventName` y `additionalContext` |
| No interfiere con "cero código sin tarea" | ✅ | Sin tarea activa: `require-active-task.sh` sale con 2 y `brain-context.sh` con 0 y sin `permissionDecision`; son procesos independientes |
| `init-project.sh` nuevo instala ambos; `--update` avisa y no toca `settings.json` | ✅ | Aviso con `brain-context.sh` y archivo idéntico byte a byte; sin aviso si ya lo registra |
| AGENTS.md §7 documenta el mecanismo y la regla para Antigravity | ✅ | §7.4, QUICKSTART, skill `aprender` y `system_map.md` leídos: describen lo que hace el código |
| `adopt_brain_lessons` (cambio colateral) | ✅ | Filas de 6, 7 y 8 columnas adoptadas con solución y estado correctos; idempotente y sin duplicados; BRAIN.md con CRLF no deja `\r` en la fuente; fuente con CRLF no duplica; fuente de 0 bytes aborta sin tocar BRAIN.md; fuente ausente o sin filas recupera las 8 lecciones; migración del esquema antiguo (6 + 7 columnas, `[OBSOLETA]`) correcta |
| Rendimiento | ✅ | Mediana por invocación: 142 ms con acierto y 108 ms sin acierto (5 lecciones); 162 ms y 132 ms con 297 lecciones; ~0,3 ms desactivado |
| Tests nuevos; suite al 100% | ✅ | `bash tests/test-scripts.sh` → 213 OK, 0 fallidas; `test-flow.sh` → 24 OK; `test-skills.sh` → 28 skills sin errores; `validate-state.sh` → sin errores |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` limpio |

**No verificado por QA**: que Claude Code entregue al agente `hookSpecificOutput.additionalContext` de un hook `PreToolUse`. No es comprobable desde esta revisión; el especialista declara haberlo comprobado en vivo en su sesión.

## 2. Observaciones y Hallazgos

- **Deuda Técnica (MEDIA, sin riesgo de seguridad)**: el hook marca la lección como vista antes de saber si la edición se ejecuta. Reproducido: sin tarea `IN_PROGRESS`, `require-active-task.sh` sale con 2 y `brain-context.sh` emite la lección; la segunda invocación de la misma sesión ya no la emite. Si Claude Code descarta el contexto adicional cuando otro hook bloquea (no verificado), la lección se pierde para esa sesión. Mitigado porque `task.sh start` muestra el resumen del cerebro.
- **Observaciones (BAJA)**:
  1. Concurrencia: 10 invocaciones en paralelo con la misma sesión mostraron la lección 2, 2 y 1 veces (comprobar y anotar no es atómico). Siempre código 0 y JSON válido.
  2. `stdin` cerrado (`<&-`): el hook se queda colgado en `INPUT=$(cat)` hasta que se le mata. Claude Code siempre entrega stdin, así que no ocurre en uso real.
  3. `. "$LIB" 2>/dev/null` no silencia stdout: un `brain-lib.sh` que imprima al cargarse contaminaría la salida con texto que no es JSON (solo con la biblioteca alterada).
  4. Ruta absoluta que llega por otro alias del mismo directorio (`/tmp/...` frente a `/private/tmp/...`) o `CLAUDE_PROJECT_DIR` con `/` final: se trata como de fuera del proyecto y no se muestra nada (silencioso, nunca bloquea).
  5. Una ruta relativa que sale del proyecto (`../otro/server/db/a.sql`) sí casa el ámbito. Claude Code envía rutas absolutas.
  6. Sin `TMPDIR`, el registro va a `/tmp/maestro-brain-context/<sesión>`, directorio predecible y compartido en Linux multiusuario (posible enlace simbólico plantado; solo se añadirían líneas `LL-NNN`). Los archivos de registro no se limpian nunca.
  7. `init-project.sh --update` no avisa ni crea nada si `.claude/settings.json` no existe; el resumen final de `init-project.sh` solo menciona el hook "cero código sin tarea".
  8. `adopt_brain_lessons` con una fila de 5 columnas genera una fila de 7 columnas (entrada ya malformada).

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-037`
