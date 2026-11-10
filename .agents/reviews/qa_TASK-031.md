# Veredicto de QA: TASK-031

- **Tarea**: `TASK-031`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `orchestrator-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `0/3` (primera revisión, sin rechazos)

---

## 1. Criterios de Aceptación Verificados

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `preferences.md` y `domain_glossary.md` describen la librería real, sin reglas de TypeScript/UI de plantilla | ✅ | `git diff main...HEAD`: desaparecen TypeScript estricto, UI/UX y entidades Cuenta/Sesión. Contrastado con el repo: `cell` y `json_escape` existen en `task.sh` (l. 108 y 112); `tests/test-scripts.sh`, `tests/test-flow.sh`, `tests/test-skills.sh`, `tests/triggers/lint_descriptions.py` y `cases.json` existen; los tests usan `mktemp -d` + `trap`; `QUICKSTART.md` l. 21 declara `git` y `python3` y l. 191 cita 147 comprobaciones (= resultado real); `.claude/skills` es un enlace a `../.agents/skills`; `init-project.sh` l. 316-321 siembra el cerebro de los proyectos desde las plantillas, no desde la instancia; sin `mapfile`, `declare -A`, `grep -P` ni `sed -i` sin sufijo en `.agents/scripts/` y `tests/` |
| Invariantes del glosario impuestos por el código | ✅ | En copia temporal: `close` con revisor = asignado falla ("cero auto-aprobación"); `move` rechaza `DONE`/`IN_REVIEW_QA`/`BLOCKED`; `lesson-retire` marca `OBSOLETA` sin borrar; `debt-resolve` marca `SALDADA` y conserva la fila; `next_id` toma el máximo existente (LL-008 y TD-003, sin reutilizar) |
| `BRAIN.md` sin filas de relleno en gotchas, dominio y preferencias | ✅ | §3-§5 reescritas; las 7 filas de gotchas reproducidas en shell (ver §2) |
| Gotchas por stack movidas o enlazadas a las skills | ✅ | Los 6 enlaces resuelven a archivos existentes. Contienen la trampa: Express 5 `req.query` (`stack-angular-express-postgres/SKILL.md` l. 75), singleton de Prisma (`stack-nextjs-tailwind-prisma/SKILL.md` l. 61 y `references/prisma-postgres.md`), `express.raw` antes de `express.json()` (`payments-stripe/SKILL.md` l. 57), `allowedHosts` / `NG_ALLOWED_HOSTS` (`seo-web/SKILL.md` l. 61), `PRAGMA foreign_keys = ON` (`database-architect-agent/SKILL.md` l. 31) |
| Mapa del sistema con el número real de skills | ✅ (con observación 1) | El "27 skills" obsoleto se eliminó de `BRAIN.md` y `system_map.md`; hay 28 skills reales. No se escribió el número, se quitó |
| Las plantillas de `.agents/templates` siguen genéricas | ✅ | `git diff main --stat -- .agents/templates` vacío; `git status --short .agents/templates` vacío |
| Lecciones LL-001..LL-007 conservadas | ✅ | Filas `LL-` de `BRAIN.md` y `lessons_learned.md` idénticas a `main` (diff vacío), las 7 en `ACTIVO`; cabeceras de las tablas §2 y §6 iguales a `BRAIN_TEMPLATE.md` |
| `learn`, `lesson-retire`, `debt`, `debt-resolve` y `start` con el `BRAIN.md` nuevo | ✅ | En copia temporal: `learn` inserta LL-008 en la tabla §2 (l. 37, antes de §3) y en `lessons_learned.md`; detecta el duplicado; `lesson-retire LL-008` -> `OBSOLETA`; `start TASK-032` crea la rama y lista las lecciones activas; las dos tablas de §3 quedan intactas; `validate-state.sh` limpio después |
| Batería de pruebas | ✅ | `bash tests/test-scripts.sh` -> 147 OK, 0 fallidas; `bash tests/test-skills.sh` -> 28 skills sin errores; `validate-state.sh` -> 0 advertencias |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` -> sin hallazgos |
| Auditoría de seguridad | ✅ | Diff solo de Markdown; sin código, secretos ni comandos nuevos |

## 2. Observaciones y Hallazgos

**Gotchas de `BRAIN.md` §3 reproducidas** (macOS, `/bin/bash` 3.2.57, awk 20200816):

- bash 3.2: `mapfile: command not found`; `declare -A: invalid option`; `set -u; A=(); echo "${A[@]}"` -> `A[@]: unbound variable`; con `${A[@]+"${A[@]}"}` no falla.
- awk BSD: `/a\sb/` casa con `asb` y no con `a b`; `LC_ALL=C tolower("ÁRBOL Ñ")` -> `Árbol Ñ` (en UTF-8 sí baja).
- sed: `s/X/A & B/` -> `A X B`, con `\&` -> `A & B`; `sed -i 's/..' f` falla (`invalid command code f`), `sed -i.bak` funciona; `LC_ALL=C sed 'y/áé/ae/'` -> `transform strings are not the same length`.
- Git rutas: `"configuraci\303\263n.ts"` y `"co\"mi.ts"` por defecto; con `quotePath=false` sigue entrecomillada `"co\"mi.ts"`; con `-z` + `read -r -d ''` ambas se leen bien.
- Git `-S`: tres commits tocan la línea `KEY=`; `-S'KEY'` solo muestra el primero, `-G'KEY'` los tres.
- `mktemp` + `mv`: temporal `600`, archivo final `600` (original `644`).
- Locale: el entorno de esta revisión arranca con `LC_CTYPE="C"` y `LANG=""`.

No comprobado: el comportamiento en GNU/Ubuntu (solo se dispuso de macOS); "en muchos entornos de agente" de la fila Locale solo se constató en este.

**Observaciones (BAJA, no bloqueantes)**:

1. El criterio pedía "el número real de skills" y la entrega quitó el conteo en lugar de poner 28. Cumple la intención (no queda ningún número falso) y el handoff lo declara, pero no la letra.
2. La fila "SQLite, PostgreSQL, MySQL, MongoDB -> `database-architect-agent`" promete más de lo que hay: el cuerpo de esa skill solo tiene una trampa específica de motor (los `PRAGMA` de SQLite); MySQL y MongoDB solo aparecen en la `description`.
3. La gotcha anterior "Node.js fetch / cabecera `Host`" se eliminó sin moverla a ninguna skill; la de tokens CSS vive en `ui-ux-agent` pero no está enlazada.
4. La librería incumple reglas que ahora declara obligatorias (código previo, fuera del alcance de esta tarea):
   - `mktemp` + `mv`: `task.sh` (`set_task`, `append_to_table`) no restaura permisos; `GLOBAL_STATE.md` está hoy en `0600` en el árbol de trabajo.
   - `\s`: `task.sh` l. 584 usa `grep -Ei '^\s*...'`.
   - `LL-003` sigue recomendando `sed 'y/.../.../'`, que la fila de sed y `LL-007` desaconsejan.
   - "Solo `git` y `python3`": `task.sh` l. 360 usa `iconv` en la rama de respaldo sin `python3`.
5. Previo a esta tarea: `BRAIN.md` §6 está vacío aunque `TD-002` sigue pendiente en `tech_debt.md` (`task.sh debt` no escribe en `BRAIN.md`).

- **Deuda Técnica**: no se registra. Se recomienda al `orchestrator-agent` abrir una tarea para el punto 4 (permisos tras `mktemp` + `mv`).

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-031`
