# Veredicto de QA: TASK-036

- **Tarea**: `TASK-036`
- **Fecha**: 2026-11-11
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `RECHAZADA`
- **Iteración**: `1/3`

---

## 1. Criterios de Aceptación Verificados

Entorno: macOS, `/bin/bash` 3.2.57, awk BSD 20200816. Pruebas manuales en proyectos temporales creados con `init-project.sh` (nunca en el repo); los proyectos "antiguos" se crearon con el `init-project.sh` de `main` (`git archive main`) y se actualizaron con `init-project.sh --update` de la rama.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `lessons_learned.md` fuente única con Ámbito y Estado; BRAIN.md se regenera (`brain sync`); `learn`/`lesson-retire` la mantienen | ✅ | Tras `learn` (con y sin `--paths`), `lesson-retire`, `brain scope`, `brain sync`: filas `LL-` idénticas (diff vacío) y resto de BRAIN.md con el mismo md5; idempotente; 300 lecciones idénticas |
| `learn --paths` | ⚠️ | Funciona (`--paths x`, `--paths=x`, en cualquier posición); pero borra todos los espacios del ámbito (BUG-3) |
| `brain search` | ✅ | Varios términos (AND), tildes/mayúsculas, sin resultados, términos con `.* [ ( \ $ ^ +` tratados como literales; incluye deuda y gotchas |
| `brain for` | ✅ | Ámbito (rutas relativas, `./`, absolutas con espacios), categoría, palabras; OBSOLETAS excluidas; deuda de la tarea y ALTA; SALDADA excluida |
| `start` usa `brain for` | ✅ | Muestra relevantes con motivo y completa con las recientes |
| Migración de las lecciones existentes con su ámbito | ❌ ALTA | Las 7 del repo migradas con ámbito; la migración 6/7→8 columnas conserva estados, `[OBSOLETA]` y filas solo-en-BRAIN, idempotente. Pero hay una ruta de pérdida total de lecciones (BUG-1) |
| init-project y plantillas actualizados | ⚠️ | Plantillas con 8 columnas; `init-project.sh` no tiene cambios (instalación nueva correcta; `--update` copia brain-lib.sh pero no crea `lessons_learned.md` si falta: ver BUG-1). `lessons_learned_template.md` l.4 conserva el comando antiguo |
| Tests nuevos; suite al 100% | ✅ | `test-scripts.sh` 182 OK / 0; `test-flow.sh` 24 OK / 0; `test-skills.sh` 28 skills sin errores; `validate-state.sh` 0 advertencias |
| Escaneo de secretos | ✅ | `scan-secrets.sh --branch` → sin hallazgos |
| Inyección con texto hostil | ✅ | `$(...)`, backticks, comillas, `&`, `\1`, `\\`, saltos de línea: sin ejecución ni corrupción; `|` → `/` (igual que en main); 8 columnas siempre |
| Portabilidad | ✅ | `LC_ALL=C`, PATH sin python3, bash 3.2: learn, duplicados, search, for, retire, scope, sync correctos. 300 lecciones (155 KB): `brain for` 0,13 s, `start` 0,24 s, `learn` 0,14 s |

## 2. Defectos

### BUG-TASK-036-1 (ALTA) — `brain sync` / `learn` borran en silencio las lecciones que solo están en BRAIN.md

- **Componente**: DevOps (`brain-lib.sh` `brain_sync`, `ensure_lessons_schema`; `task.sh learn`)
- **Pasos para reproducir** (proyecto antiguo creado con main, 4 lecciones en BRAIN.md):
  1. `rm .agents/brain/lessons_learned.md` (configuración que main toleraba: `learn` hacía `[ -f "$LL_FILE" ] && ...`).
  2. `init-project.sh . --update` (no recrea el archivo).
  3. `task.sh learn "..."` → `❌ No existe .../lessons_learned.md. Créalo desde .agents/templates/lessons_learned_template.md.` (regresión: en main registraba la lección).
  4. Seguir el consejo: `cp .agents/templates/lessons_learned_template.md .agents/brain/lessons_learned.md`.
  5. `task.sh brain sync` (o cualquier `learn`).
- **Observado**: `🧠 BRAIN.md sincronizado ... (0 lecciones)`; BRAIN.md pasa de 5 filas `LL-` a 0. Con `learn` en el paso 5: BRAIN.md queda solo con la lección nueva (LL-001..LL-004 desaparecen). Sin aviso y con código 0.
- **Causa**: la incorporación de filas solo-en-BRAIN vive en `ensure_lessons_schema`, que solo actúa si `lessons_learned.md` tiene el esquema antiguo. Si la fuente ya tiene 8 columnas (plantilla nueva, o archivo recreado), `brain_sync` reemplaza la tabla de BRAIN.md sin comprobar si contiene IDs ausentes en la fuente.
- **Esperado**: ninguna lección se pierde: `brain_sync` debe incorporar a la fuente (o abortar con mensaje) las filas `LL-` de BRAIN.md que no existan en `lessons_learned.md`, sea cual sea el esquema; y si falta `lessons_learned.md` con lecciones en BRAIN.md, crearlo desde ellas (o que `--update` lo haga).
- **Test pedido**: BRAIN.md antiguo con lecciones + `lessons_learned.md` ausente / recién copiado de la plantilla → tras `learn` y `brain sync` siguen todas.

### BUG-TASK-036-2 (MEDIA) — Un tabulador en el problema/solución hace desaparecer la lección de las activas (regresión)

- **Pasos**: `task.sh learn $'pegado con\ttab dentro' ui/ux c s`; `task.sh brain for TASK-XXX`; `task.sh start`; repetir el mismo `learn`.
- **Observado**: `all_lessons` emite 6 campos separados por TAB y `cell()` no limpia tabuladores: los campos se desplazan, el estado deja de ser `ACTIVO` y la lección no aparece en `start` ni en `brain for`, ni cuenta para el detector de duplicados; `brain search` la muestra con campos cruzados (`→ * (ámbito: tab dentro...; x)`). En main `start` sí la mostraba (truncada).
- **Esperado**: `cell()` sustituye `\t` por espacio y `all_lessons` normaliza tabuladores de filas editadas a mano.

### BUG-TASK-036-3 (MEDIA) — El ámbito pierde los espacios: rutas con espacios imposibles y globs alterados

- **Pasos**: `task.sh learn "x" be c s --paths "a b/*.ts"` → se guarda `ab/*.ts` (ídem `brain scope`). `brain scope LL-002 " , ,"` → guarda `,,` con éxito.
- **Observado**: `tr -d ' \`'` elimina todos los espacios, no solo los de alrededor de las comas; el ámbito guardado no coincide con ninguna ruta real y no se avisa. Ámbito formado solo por comas aceptado.
- **Esperado**: recortar espacios solo alrededor de cada glob, descartar globs vacíos y rechazar el ámbito si no queda ninguno.

### BUG-TASK-036-4 (BAJA) — Sin brain-lib.sh, task.sh falla con el error crudo de bash

- **Observado**: `./.agents/scripts/task.sh: line 73: .../brain-lib.sh: No such file or directory` (código 1) en cualquier comando, incluido `help`.
- **Esperado**: mensaje propio (`die`) que diga cómo recuperarlo (`init-project.sh --update`).

## 3. Observaciones (BAJA, no bloquean por sí solas)

- `brain sync` responde "BRAIN.md sincronizado" aunque BRAIN.md no exista o no tenga tabla de lecciones (no escribe nada).
- Semántica del glob sin documentar: `*` cruza `/` y el patrón casa en cualquier límite de directorio (`src/api/*.ts` casa `other/src/api/x.ts` y `src/api/sub/x.ts`); un ámbito de directorio sin `*` (`docs`, `docs/`) nunca casa archivos. Sin falsos positivos por sufijo (`*.sh` no casa `x.sh.bak`; `xsrc/api/x.ts` no casa).
- Filas editadas a mano con `\|`: el parseo `-F'|'` desplaza columnas (comportamiento previo en main para el problema; ahora además se lee mal el ámbito y no casa por rutas). `learn` no puede producirlas (`|` → `/`).
- Tamaño: con ~1 MB de lecciones (2100 filas largas) `brain for` y `brain search` fallan con `awk: Argument list too long` (ENVIRON > ARG_MAX). Irreal a corto plazo; conviene pasar los datos por stdin/archivo.
- `brain search ""` devuelve todo el cerebro.
- Ayuda de `task.sh`: líneas `brain search` y `debt-resolve` mal sangradas.
- Documentación: cabecera de brain-lib.sh cita `brain-context.sh` (aún no existe, TASK-037); skill `aprender` paso 3 sigue diciendo "busca en BRAIN.md ... actualiza su antídoto" y la línea de `start` describe el criterio anterior; `lessons_learned_template.md` l.4 mantiene `learn "<problema: solución>" [categoría]`.

## 4. Siguiente paso

`task.sh reject TASK-036` ejecutado. El especialista retoma con `task.sh start TASK-036`; obligatorio corregir BUG-1 a BUG-3 con tests; BUG-4 y las observaciones, recomendables.
