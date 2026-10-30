---
name: release
description: Publica una versión de forma controlada - verifica que todas las tareas incluidas estén DONE, ejecuta la batería completa (lint, tests, build, migraciones, escaneo de secretos), actualiza CHANGELOG y versión SemVer, crea el tag, despliega, comprueba producción con una prueba de humo y deja documentado el rollback. Usar cuando el usuario quiere sacar una versión, desplegar a producción o preparar un release. Requiere confirmación explícita del usuario antes de desplegar.
---

# /release — Publicación de una Versión

Coordinas `devops-cloud-agent` (build y despliegue), `docs-architecture-agent` (CHANGELOG) y `qa-security-agent` (verificación de pre-vuelo). Carga sus skills cuando ejecutes su parte.

## Pasos

1. **Auditoría de Alcance**:
   - Lista las tareas terminadas desde el último tag (`git log <último-tag>..HEAD --oneline` + tablero de `GLOBAL_STATE.md`).
   - *Si existen tareas incluidas en `IN_PROGRESS`, `IN_REVIEW_QA` o `BLOCKED`, detén el proceso y solicita decisión al usuario.*
   - Registra e inicia la tarea del release en el tablero:
     ```bash
     ./.agents/scripts/task.sh add "Release vX.Y.Z" "devops-cloud-agent" "Batería en verde; tag vX.Y.Z publicado; prueba de humo en producción OK"
     ./.agents/scripts/task.sh start TASK-XXX
     ```
2. **Batería de Verificación Previa (Pre-flight)** desde la raíz:
   ```bash
   npm ci
   npm run lint --if-present
   npm test
   npm run build
   bash .agents/scripts/scan-secrets.sh --all
   ./.agents/scripts/validate-state.sh
   ```
   *Si existen migraciones pendientes, aplícalas sobre una copia de base de datos de staging y comprueba que la aplicación inicia sin errores.*
3. **Versión SemVer y Changelog**:
   - `MAJOR` si rompe contratos de API o estructuras de datos irreversibles.
   - `MINOR` si añade funcionalidades retrocompatibles.
   - `PATCH` si contiene correcciones de errores.
   - Actualiza `version` en los archivos de proyecto (`package.json`) y el `CHANGELOG.md` siguiendo el formato *Keep a Changelog* (Added, Changed, Deprecated, Removed, Fixed, Security).
4. **Confirmación del Usuario**: presenta la versión, lista de cambios, migraciones aplicadas y el procedimiento exacto de rollback. **Espera una confirmación explícita antes de continuar.**
5. **Tag y Despliegue**:
   ```bash
   git add CHANGELOG.md package.json
   ./.agents/scripts/task.sh commit TASK-XXX "release vX.Y.Z" chore
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin HEAD vX.Y.Z
   ```
   *Despliega mediante el pipeline de CI/CD configurado o comando oficial documentado. Prohibido saltarse las comprobaciones de CI.*
6. **Prueba de Humo en Producción**:
   - `GET /healthz` y `GET /readyz` responden 200 OK.
   - La pantalla principal carga sin errores de consola ni advertencias críticas.
   - El flujo crítico de usuario (ej. login o navegación base) opera correctamente.
   - *Si la prueba de humo falla, activa el procedimiento de rollback inmediatamente.*
7. **Cierre de Tarea**: registra el hito en el historial de `GLOBAL_STATE.md` (§7), entrega la tarea con `/handoff` para cierre por QA y notifica el resumen al usuario.

## Rollback
Documenta siempre el plan de reversión antes de desplegar: re-despliegue del tag anterior (`git checkout vX.Y.(Z-1)` o rollback en plataforma cloud). Si hubo migraciones sin marcha atrás (`down`), el rollback de datos se realiza con una migración correctiva hacia adelante; por ello, los cambios destructivos se segregan en dos versiones (expandir primero, contraer después).

## Checklist antes de desplegar
- [ ] Todas las tareas contempladas en el release en estado `DONE`.
- [ ] Batería completa en verde (`npm test`, `npm run build`, `scan-secrets.sh --all`, `validate-state.sh`).
- [ ] Versión SemVer calculada y `CHANGELOG.md` actualizado con notas estructuradas.
- [ ] Plan y comandos de rollback documentados y comprobados.
- [ ] Aprobación explícita del usuario recibida antes del despliegue.
- [ ] Prueba de humo post-despliegue (`/healthz`, `/readyz`, login) ejecutada con éxito.

## Prohibido
- Desplegar a producción con tareas pendientes en `IN_PROGRESS` o `IN_REVIEW_QA`.
- Desplegar sin confirmación explícita del usuario.
- Ejecutar `git push --force` o saltarse las verificaciones de CI/CD.
- Publicar un release sin haber definido y verificado el procedimiento de rollback.
