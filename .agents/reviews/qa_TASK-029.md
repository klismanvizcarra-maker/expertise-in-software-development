# Veredicto de QA: TASK-029

- **Tarea**: `TASK-029`
- **Fecha**: 2026-11-10
- **Revisor**: `qa-security-agent`
- **Especialista Asignado**: `devops-cloud-agent`
- **Resultado**: `APROBADA`
- **Iteración**: `0/3` (primera revisión, sin rechazos)

---

## 1. Criterios de Aceptación Verificados

Revisión con contexto limpio (subagente independiente). Diff revisado: `git diff main...HEAD` (6 archivos, +52/−8). Los casos límite de `task.sh commit` se probaron en un proyecto temporal creado con `init-project.sh` (hooks `commit-msg` y `pre-commit` instalados), con bash 3.2.57 de macOS.

| Criterio / Control | Resultado | Evidencia |
| :--- | :---: | :--- |
| `task.sh commit` acepta `--trailer "<linea>"` repetible | ✅ | `commit TASK-003 "dos trailers" docs --trailer "Co-Authored-By: A <a@example.com>" --trailer="Reviewed-by: B <b@example.com>"` → cuerpo con ambas líneas; `git interpret-trailers --parse` las reconoce |
| Variable `MAESTRO_COMMIT_TRAILER` | ✅ | Con la variable + `--trailer` → ambos trailers en el cuerpo (primero el de entorno). Variable vacía → commit sin cuerpo. Variable malformada (`basura`) → `Trailer inválido`, sin commit |
| El hook `commit-msg` lo admite | ✅ | Los commits con trailers pasaron el hook real instalado en el proyecto temporal (solo valida la primera línea) |
| Compatibilidad hacia atrás `commit TASK-ID "msg" [tipo]` | ✅ | Sin tipo → `feat(TASK-003): sin tipo`; con tipo → `fix(TASK-003): con tipo`; tipo inválido `foo` → error. El tipo también se acepta después de `--trailer` |
| bash 3.2 y `set -u` | ✅ | `bash -u task.sh commit ...` sin trailers funciona (expansión `${TRAILERS[@]+"${TRAILERS[@]}"}` y guarda `${#TRAILERS[@]} -gt 0`) |
| Trailers malformados | ✅ | `"sin formato"`, `"-x: y"`, `--trailer ""` y `--trailer` sin valor → error y exit ≠ 0, sin commit |
| Inyección de comandos por trailer | ✅ | `--trailer 'Co-Authored-By: $(touch PWNED) \`id\` <a@example.com>'` → texto literal en el cuerpo, no se crea `PWNED` (se pasa como argumento de `git commit -m`, sin `eval`) |
| Handoff muestra el destino sin sugerir que revisa el autor | ✅ | Ayuda: `handoff TASK-ID [revisor] ...` + «revisor: quien recibe la entrega; por defecto qa-security-agent». Salida: `revisa: <destino>` |
| Handoff avisa si el destino coincide con el asignado | ✅ | `handoff TASK-003 devops-cloud-agent` (tarea asignada a devops-cloud-agent) → aviso «el segundo argumento es quien REVISA...». Sin aviso con destino por defecto ni con `backend-agent` |
| `perf-01` acepta `nueva-tarea` en `cases.json` | ✅ | `accept: ["bugfix", "nueva-tarea"]`; `expect` y `forbid` intactos; JSON válido |
| Tests nuevos | ✅ | 3 comprobaciones nuevas en `tests/test-scripts.sh` (`--trailer`, `MAESTRO_COMMIT_TRAILER`, rechazo de trailer malformado) y 1 en `tests/test-flow.sh` (aviso de handoff) |
| Suite al 100% | ✅ | `bash tests/test-scripts.sh` → 128 OK, 0 fallidas; `bash tests/test-flow.sh` → 24 OK, 0 fallidas; `python3 tests/triggers/lint_descriptions.py` → «Sin problemas» |
| Escaneo de secretos | ✅ | `./.agents/scripts/scan-secrets.sh --branch` → sin hallazgos |
| Auditoría de seguridad | ✅ | Sin ejecución de comandos ni alteración de la línea de asunto; ver la observación MEDIA sobre trailers multilínea |

## 2. Observaciones y Hallazgos

- **MEDIA (aceptada como deuda técnica, sin riesgo de seguridad)**: la validación de trailers no rechaza saltos de línea. El patrón `^[A-Za-z][A-Za-z0-9-]*:\ .+` no está anclado al final y `.+` admite `\n`, así que un `--trailer` (o `MAESTRO_COMMIT_TRAILER`) multilínea cuya primera línea sea válida se acepta entero. Reproducción: `task.sh commit TASK-003 "multilinea" fix --trailer $'Co-Authored-By: A <a@example.com>\nfix(TASK-999): inyectado\n\nOtro: parrafo'` → el cuerpo contiene las tres líneas y `git interpret-trailers --parse` ya solo reconoce `Otro: parrafo` (el `Co-Authored-By` deja de ser un trailer). No afecta a la línea de asunto ni ejecuta nada; quien invoca el comando ya controla su propio mensaje. Tampoco hay test para este caso.
- **BAJA**: `MAESTRO_COMMIT_TRAILER` admite una sola línea; para varios trailers por entorno hay que usar `--trailer`. La ayuda no lo aclara.
- **BAJA**: `--trailer` y `MAESTRO_COMMIT_TRAILER` solo están documentados en la ayuda de `task.sh`; `AGENTS.md` §5 y `QUICKSTART.md` no los mencionan.
- **Deuda Técnica**: registrada con `task.sh debt` (rechazar trailers con saltos de línea y añadir test).

## 3. Conclusión y Veredicto Final

- **Estado**: `APROBADA`
- **Siguiente paso**: `task.sh close TASK-029`
