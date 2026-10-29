---
name: release
description: Publica una versión de forma controlada - verifica que todas las tareas incluidas estén DONE, ejecuta la batería completa (lint, tests, build, migraciones, escaneo de secretos), actualiza CHANGELOG y versión SemVer, crea el tag, despliega, comprueba producción con una prueba de humo y deja documentado el rollback. Usar cuando el usuario quiere sacar una versión, desplegar a producción o preparar un release. Requiere confirmación explícita del usuario antes de desplegar.
---

# /release — Publicación de una Versión

Coordinas `devops-cloud-agent` (build y despliegue), `docs-architecture-agent` (CHANGELOG) y `qa-security-agent` (verificación). Carga sus skills cuando ejecutes su parte.

## Pasos

1. **Alcance**: lista las tareas `DONE` desde el último tag (`git log <último-tag>..HEAD --oneline` + tablero). Si hay tareas incluidas en `IN_PROGRESS`, `IN_REVIEW_QA` o `BLOCKED`, detente y pregunta al usuario.
   El release es una tarea más: regístrala y empiézala (el hook `commit-msg` exige un `TASK-XXX` en cada commit):
   ```bash
   ./.agents/scripts/task.sh add "Release vX.Y.Z" "devops-cloud-agent" "Batería en verde; tag vX.Y.Z publicado; prueba de humo en producción OK"
   ./.agents/scripts/task.sh start TASK-XXX
   ```
2. **Batería previa** desde la raíz, todo en verde:
   ```bash
   npm ci
   npm run lint --if-present
   npm test
   npm run build
   bash .agents/scripts/scan-secrets.sh --all
   ./.agents/scripts/validate-state.sh
   ```
   Si hay migraciones nuevas, aplícalas sobre una copia de la base de datos de staging y verifica que la app arranca contra ella.
3. **Versión SemVer**: `MAJOR` si rompe contratos de API o datos, `MINOR` si añade funcionalidad, `PATCH` si solo corrige. Actualiza `version` en los `package.json` y el `CHANGELOG.md` (*Keep a Changelog*: Added / Changed / Deprecated / Removed / Fixed / Security), agrupando por las tareas incluidas.
4. **Confirmación del usuario**: muestra versión, cambios, migraciones y plan de rollback, y **espera un sí explícito** antes de seguir.
5. **Tag y despliegue**:
   ```bash
   git add CHANGELOG.md                      # puede ser nuevo; task.sh commit solo añade archivos ya versionados
   ./.agents/scripts/task.sh commit TASK-XXX "release vX.Y.Z" chore
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin HEAD vX.Y.Z
   ```
   Si el proyecto integra por PR, abre el PR de la rama del release y crea el tag sobre el commit fusionado en la rama principal. Despliega con el procedimiento del proyecto (CI/CD o comando documentado en `README.md`). Nunca `git push --force` ni despliegues manuales que salten el pipeline.
6. **Prueba de humo en producción**: `GET /healthz` y `GET /readyz` responden 200, la página principal carga sin errores de consola y el flujo crítico (ej. login) funciona. Si falla, ejecuta el rollback de inmediato y avisa.
7. **Cerrar**: registra el hito en el historial de `GLOBAL_STATE.md` (§7), entrega la tarea del release con `/handoff` para que QA la cierre, actualiza la fase si corresponde y resume al usuario: versión, enlace o comando de despliegue, resultado de la prueba de humo y cómo volver atrás.

## Rollback
Documenta siempre el camino de vuelta antes de desplegar: redeploy del tag anterior. Si hubo migraciones sin `down`, el rollback de datos es una migración correctiva hacia delante; por eso los cambios destructivos se hacen en dos releases (expandir → migrar datos → contraer).
