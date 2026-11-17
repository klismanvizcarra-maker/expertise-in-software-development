# Reincidencias (Recurrences)

> **Propósito**: rechazos de QA cuyo motivo ya estaba cubierto por una lección activa. Lo escribe `task.sh reject`; una lección con reincidencias no está llegando a tiempo al agente: revisa su ámbito (`task.sh brain scope`) o su antídoto.

| Fecha | Tarea | Lección | Motivo del rechazo |
| :---: | :---: | :---: | :--- |
| 2026-11-12 | `TASK-042` | `LL-010` | payments-stripe/references/angular-express.md:32 importa ../utils/apiResponse en lugar de ../../lib/api-response.ts con extension .ts (LL-010) |
| 2026-11-16 | `TASK-050` | `LL-016` | init-project.sh:203 y :408 siguen comprobando [ -d .git ] y en un worktree se saltan install-hooks.sh sin avisar (init, --update y --adopt no instalan commit-msg ni pre-commit); falta test de init-project sobre worktree (BUG-TASK-050-1 en .agents/reviews/qa_TASK-050.md) |
| 2026-11-17 | `TASK-048` | `LL-013` | Evals sin poder discriminante: domain acepta Math.round y exige -333 contra 'a favor del cliente'; async acepta marcar id antes de enviar; testing: check de inyeccion pasa en el estado inicial y new Date() evade; devops rechaza .env* y HEALTHCHECK multilinea y acepta ENV sin = y USER 0:0 (ver .agents/reviews/qa_TASK-048.md) |
