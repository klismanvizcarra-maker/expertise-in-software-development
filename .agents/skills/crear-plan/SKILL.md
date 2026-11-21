---
name: crear-plan
description: Plan maestro antes de programar (docs/plan/plan-maestro.md) - visión, alcance por versiones, arquitectura, fases con criterio de salida, Gantt y riesgos; registra solo la fase 1. Usar cuando piden un roadmap o planificar todo el proyecto. No usar para un requerimiento (nueva-tarea).
---

# /crear-plan — Plan Maestro del Proyecto

Lo ejecuta el `orchestrator-agent` (carga su skill). El plan es el mapa de **todo** el proyecto: une la investigación (`research-agent`), la especificación (`product-manager-agent`) y el stack en un único documento que el usuario aprueba antes de que se registre ninguna tarea. Después, `/nueva-tarea` registra la fase 1 y `/cerrar-fase` activa cada fase siguiente desde el plan.

## Pasos

1. **Reunir las entradas**:
   - `GLOBAL_STATE.md` §1-§2 (proyecto, fase, stack) y §6 (ADRs).
   - Informes aprobados en `docs/research/` y PRDs en `docs/product/`.
   - `.agents/brain/tech_debt.md` y `BRAIN.md` si el proyecto ya tiene historia (`/adoptar-proyecto`).
   Si no hay ni informe ni PRD y la idea es difusa, propone primero `/research-agent` (si hay referentes que estudiar) o `/product-manager-agent`, y detente. Si falta información para planificar, pregunta en un solo mensaje (máximo 5): plataformas, fecha objetivo o hitos fijos, tamaño del equipo (personas o agentes y dedicación), presupuesto de servicios externos y restricciones (país, regulación, integraciones obligatorias).
2. **Visión y alcance**: objetivo y métrica de éxito; qué entra en el **MVP**, en la **v1** y en la **v2**, y qué queda **fuera** explícitamente. Cada pieza del MVP enlaza la historia de usuario o la funcionalidad del informe de investigación que la justifica.
3. **Arquitectura general**: componentes (apps por actor, panel de administración, API, base de datos, colas, servicios externos como mapas, pagos o notificaciones) en un diagrama Mermaid, y el stack:
   - Si `GLOBAL_STATE.md` §2 ya lo declara, úsalo.
   - Si no, propónlo con una línea de justificación por pieza, marcado `PENDIENTE DE CONFIRMAR`; lo confirma `/iniciar-proyecto` y queda como ADR en §6.
   - Las decisiones de arquitectura significativas se listan como ADR candidatos para el `docs-architecture-agent`.
4. **Módulos y responsables**: tabla de módulos con el agente que lo construye según el enrutamiento del `orchestrator-agent` y las skills de stack y técnica que debe cargar (p. ej. cobros → `backend-agent` + `payments-stripe`; ubicación en tiempo real → `mobile-agent` + `async-jobs`).
5. **Fases**: de 3 a 6 fases (p. ej. Fundaciones, MVP núcleo, MVP completo, Beta, Lanzamiento, v1). Para cada una:
   - **Objetivo** y **criterio de salida** verificable (qué debe funcionar y cómo se comprueba).
   - **Tareas candidatas** con agente, criterios de aceptación resumidos y dependencias (`depende de`), con el mismo nivel de detalle que pide `/nueva-tarea`.
   - Deuda técnica o riesgos que se atacan en ella.
6. **Cronograma**: diagrama `gantt` en Mermaid por fases y el **camino crítico** (la cadena de dependencias que fija la fecha final). Las estimaciones son **rangos** (p. ej. 2-3 semanas) o tallas (S/M/L) con los supuestos de equipo y dedicación escritos al lado; nunca una fecha única sin supuestos.
7. **Riesgos y supuestos**: tabla con probabilidad, impacto y mitigación (técnicos, de mercado, regulatorios, de dependencias externas). Incluye los riesgos del informe de investigación.
8. **Estrategia de calidad y salida a producción**: qué cubren las pruebas (`testing-strategy`, `e2e-testing`), revisión de seguridad (`security-hardening`), observabilidad (`observability`) y el criterio para lanzar (`/release`).
9. **Plan de lanzamiento**: entornos, versiones y lo que se mide tras lanzar (métricas de producto del PRD).
10. **Redactar y validar**: escribe `docs/plan/plan-maestro.md` con la plantilla [plan_maestro_template.md](../../templates/plan_maestro_template.md) en estado `DRAFT`. Presenta al usuario el resumen (alcance, fases, rango de duración, riesgos principales y preguntas abiertas). **En Antigravity**, publícalo además como artefacto (`UserFacing: true`, `RequestFeedback: true`). Ajusta hasta que lo apruebe y márcalo `APPROVED`.
11. **Activar la fase 1**, solo con el plan aprobado. La activa **una sola** skill, para no registrar las tareas ni el hito dos veces:
    - **Si el stack está `PENDIENTE DE CONFIRMAR`** o `GLOBAL_STATE.md` aún tiene placeholders: pasa a `/iniciar-proyecto`. Esa skill confirma el stack, completa `GLOBAL_STATE.md` (Fase Actual en §1 y un hito en §7 que enlaza el plan) y registra la fase 1 del plan (sus pasos 4 y 5). `/crear-plan` termina aquí y no registra nada.
    - **Si no**, lo hace `/crear-plan`: actualiza la **Fase Actual** de `GLOBAL_STATE.md` §1 con el nombre de la fase 1, añade un hito en §7 que enlace el plan y registra **solo** las tareas de la fase 1 con el flujo de `/nueva-tarea` (`task.sh add`).
    - En ambos casos, las tareas de fases posteriores quedan como candidatas en el plan: se registran en `/cerrar-fase`.
12. **Mantener el plan vivo**: cuando cambie el alcance, actualiza el plan (nueva versión en su historial de cambios) con la confirmación del usuario; `/cerrar-fase` anota en él lo real frente a lo planificado al terminar cada fase.

## Checklist antes de dar el plan por aprobado
- [ ] Alcance por versiones (MVP, v1, v2) y lo que queda fuera, con la justificación de cada pieza del MVP.
- [ ] Arquitectura con diagrama Mermaid, stack declarado o marcado `PENDIENTE DE CONFIRMAR` y ADR candidatos.
- [ ] Cada módulo tiene agente responsable y skills de stack y técnica.
- [ ] Cada fase tiene objetivo, criterio de salida verificable, tareas candidatas con agente y dependencias.
- [ ] Cronograma Gantt con camino crítico y estimaciones en rangos con sus supuestos.
- [ ] Riesgos con mitigación, estrategia de calidad y plan de lanzamiento.
- [ ] Plan en `docs/plan/plan-maestro.md` aprobado por el usuario (`APPROVED`).
- [ ] Solo las tareas de la fase 1 registradas con `task.sh`, una sola vez (por `/crear-plan` o por `/iniciar-proyecto`, no por ambas); `validate-state.sh` en verde.

## Prohibido
- Registrar tareas o cambiar la fase en `GLOBAL_STATE.md` sin la aprobación del plan por el usuario.
- Registrar de golpe las tareas de todas las fases: solo la fase 1; las demás, en `/cerrar-fase`.
- Dar fechas o duraciones únicas sin rango ni supuestos, o presentar estimaciones como compromisos.
- Fijar el stack sin confirmación del usuario o contradecir un ADR vigente sin proponer uno nuevo.
- Incluir en el MVP funcionalidades sin justificación (historia de usuario, informe o petición del usuario), o ampliar el alcance aprobado sin su autorización.
- Escribir código: el plan es documentación.
