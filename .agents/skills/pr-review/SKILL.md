---
name: pr-review
description: Prepara y revisa Pull Requests - descripción con plantilla, lectura crítica del diff (contratos, migraciones, pruebas), convención de commits y conflictos. Usar cuando piden revisar un PR o diff o redactar su descripción. No usar para entregar a QA (handoff) ni el veredicto (qa-review).
---

# Revisión Técnica de Pull Requests (`/pr-review`)

Complementa el ciclo del tablero: `handoff` + `qa-review` garantizan criterios de aceptación y seguridad sobre `TASK-XXX`; `/pr-review` asegura que el **diff en Git** esté limpio, comprensible para humanos, retrocompatible, libre de código muerto y listo para integrarse en la rama destino.

## Pasos

1. **Identificar el alcance del PR**:
   - Obtén la rama base (`main` por defecto) y lista archivos y commits:
     ```bash
     git log --oneline main..HEAD
     git diff --stat main...HEAD
     ```
   - Verifica higiene de commits (`tipo(TASK-XXX): ...`) y que no haya archivos ajenos a la tarea en curso (`git status -s`), secretos o configuraciones locales accidentales.
2. **Revisar el diff por riesgo técnico** (de mayor a menor impacto):
   - **Migraciones y compatibilidad (*backward compatibility*)**: cambios de esquema siguen Expand/Contract para no romper la versión en vuelo durante un despliegue gradual (`database-architect-agent`).
   - **Contratos y validación**: rutas/DTOs cambiados conservan compatibilidad o actualizan esquema + cliente + `GLOBAL_STATE.md` §4 en sincronía.
   - **Concurrencia, errores y recursos**: transacciones cerradas antes de I/O externo, locks liberados en `finally`, sin consultas N+1 ni cuerpos sin límite.
   - **Claridad y mantenibilidad**: funciones cortas, sin lógica duplicada ni flags muertos; solo se comentan los *porqués* no evidentes.
   - **Cobertura**: todo comportamiento nuevo o bug corregido incluye su test asociado; cero aserciones relajadas para hacer pasar una suite.
3. **Resolver conflictos o actualizar rama** (cuando el PR tiene conflictos con `main`):
   - Sincroniza `main` y haz `rebase` o `merge` de actualización, inspeccionando cada marcador `<<<<<<<` entendiendo la intención de ambos cambios (nunca aceptes "ours" o "theirs" a ciegas).
   - Tras resolver conflictos, vuelve a ejecutar **lint, build, pruebas y `./.agents/scripts/scan-secrets.sh --branch`** completos antes de aprobar o re-subir.
4. **Redactar resumen del PR o comentarios accionables**:
   - Para abrir/documentar un PR: completa [pull_request_template.md](../../templates/pull_request_template.md) con tarea asociada (`TASK-XXX`), cambios, comandos de verificación ejecutados y resultado.
   - Para devolver feedback como revisor: clasifica cada hallazgo en **Bloqueante** (`[blocker]`: bug, regresión, migración destructiva, falta test) vs **Sugerencia** (`[nit]`: estilo o mejora opcional) citando `archivo:línea` exactos.

## Checklist antes de aprobar/fusionar un PR
- [ ] Todos los commits cumplen `tipo(TASK-XXX): descripcion` y el diff no mezcla cambios no relacionados.
- [ ] Sin secretos, archivos `.env`, trazas de debug (`console.log`, `print`), TODOs huérfanos ni código comentado.
- [ ] Contratos API y migraciones revisados por retrocompatibilidad e idempotencia.
- [ ] Conflictos resueltos (si los hubo) seguidos de ejecución completa de lint, tests, build y `scan-secrets.sh --branch`.
- [ ] Resumen del PR documentado siguiendo `pull_request_template.md` (si aplica) y hallazgos clasificados con precisión (`archivo:línea`).

## Prohibido
- Aprobar un PR leyendo solo la descripción sin inspeccionar `git diff` ni verificar las pruebas ejecutadas tras el último cambio.
- Resolver conflictos aceptando en bloque `--ours` o `--theirs` sin revisar cada sección en conflicto.
- Emitir `task.sh close` o sustituir la revisión formal de `qa-review` / `qa-security-agent` mediante `/pr-review`.
- Mezclar refactors ajenos en el PR que dificulten revisar la funcionalidad original.
