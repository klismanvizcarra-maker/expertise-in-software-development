---
name: hotfix
description: Aplica un parche de emergencia urgente directamente sobre el código de producción - crea una rama hotfix/ a partir del último tag de producción o main, aplica el cambio mínimo para contener la falla sin alterar contratos, ejecuta verificaciones estrictas y fusiona con --no-ff registrando la lección y redactando el post-mortem. Usar cuando ocurre un fallo crítico o bloqueo en producción que no puede esperar al ciclo normal de sprint. No usar para bugs normales detectados en desarrollo o QA (usar bugfix) ni para refactorizaciones o nuevas funcionalidades (usar refactor o nueva-tarea).
---

# /hotfix — Parche de Emergencia en Producción

El flujo `/hotfix` está diseñado para responder a incidentes críticos en producción donde la velocidad y la contención del riesgo son prioritarias. A diferencia de `/bugfix`, este flujo se deriva del último tag o commit productivo y concluye con un post-mortem.

---

## Protocolo

1. **Declaración del Hotfix**:
   - Registra la tarea con prefijo `Hotfix:` mediante `./.agents/scripts/task.sh add "Hotfix: <descripción de la emergencia>" "<especialista>" "<criterio de contención y verificación>"`.
   - Inicia la tarea con `./.agents/scripts/task.sh start TASK-XXX` (crea automáticamente la rama `fix/TASK-XXX-...`).

2. **Aislamiento y Reproducción Rápida**:
   - Localiza la causa raíz del incidente sin conjeturas (revisando logs, trazas de error o métricas de producción).
   - Escribe un test específico que reproduzca exactamente el fallo en caliente.

3. **Corrección Mínima Quirúrgica**:
   - Aplica el parche estrictamente necesario para mitigar la emergencia.
   - **Regla no negociable**: Prohibido alterar contratos de API, esquemas de BD irreversibles o introducir cambios cosméticos no relacionados.
   - Verifica que el test previo ahora pasa y que la batería existente no sufre regresiones.

4. **Entrega a QA y Aprobación Express**:
   - Entrega con `./.agents/scripts/task.sh handoff TASK-XXX --deliverable "Parche hotfix y test de contención" --verify "bash tests/test-scripts.sh"`.
   - `qa-security-agent` valida la corrección con prioridad máxima y verifica que no introduce vulnerabilidades OWASP ni secretos.
   - Se aprueba y cierra con `./.agents/scripts/task.sh close TASK-XXX --lesson LL-XXX` (todo hotfix exige registrar lección aprendida en el cerebro con `task.sh learn`).

5. **Fusión y Post-Mortem**:
   - Fusiona a `main` con `git merge --no-ff`.
   - Si el proyecto mantiene ramas de release, aplica `git cherry-pick` hacia la rama de soporte correspondiente.
   - Completa el informe post-mortem usando la plantilla `.agents/templates/post_mortem_template.md` y archívalo en `docs/incidents/`.

---

## Checklist

- [ ] Tarea registrada con prefijo `Hotfix:` e iniciada con `task.sh start`.
- [ ] Test mínimo de reproducción escrito y fallando antes del arreglo.
- [ ] Corrección quirúrgica aplicada sin cambios de formato ni código ajeno.
- [ ] Lección aprendida registrada obligatoriamente con `task.sh learn` antes del cierre.
- [ ] Veredicto independiente emitido por `qa-security-agent`.
- [ ] Fusión completada con `--no-ff` y rama local eliminada.
- [ ] Documento post-mortem completado en `docs/incidents/` con los 5 porqués.

---

## Prohibido

- Prohibido incluir refactorizaciones, formateos masivos o dependencias innecesarias en un hotfix.
- Prohibido cerrar un hotfix sin registrar su lección correspondiente en el cerebro (`task.sh learn`).
- Prohibido saltarse la ejecución de pruebas de seguridad y escaneo de secretos por motivos de prisa.
- Prohibido modificar contratos públicos de API que rompan clientes existentes.
