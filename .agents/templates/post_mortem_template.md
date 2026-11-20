# Informe Post-Mortem de Incidente: [INC-XXX]

- **Fecha del Incidente**: YYYY-MM-DD
- **Duración / Downtime**: `[XX minutos / horas]`
- **Severidad**: `[SEV-1 (Caída crítica) | SEV-2 (Degradación de servicio) | SEV-3 (Impacto menor)]`
- **Servicios Afectados**: `[API | Base de Datos | Frontend | Pagos | etc.]`
- **Comandante del Incidente**: `[devops-cloud-agent / SRE]`
- **Tarea Vinculada**: `[TASK-XXX / Hotfix]`

---

## 1. Resumen Ejecutivo
[Breve descripción de lo ocurrido, el impacto en usuarios finales y la resolución aplicada]

## 2. Cronología de los Hechos (Línea de Tiempo)
- `HH:MM`: Primera alerta o reporte del fallo.
- `HH:MM`: Contención inicial (rollback, feature flag apagada o reinicio).
- `HH:MM`: Identificación de la causa raíz.
- `HH:MM`: Despliegue del hotfix / parche correctivo.
- `HH:MM`: Servicio restablecido y confirmado con prueba de humo.

## 3. Causa Raíz (5 Porqués)
1. *¿Por qué ocurrió el fallo?*: [Causa directa]
2. *¿Por qué ocurrió eso?*: [Causa intermedia]
3. *¿Por qué no se detectó antes?*: [Brecha en tests/monitoreo]
4. *¿Por qué falló el mecanismo de defensa?*: [Falta de timeout/circuit breaker/resiliencia]
5. *¿Por qué era vulnerable la arquitectura?*: [Causa raíz fundamental]

## 4. Qué Salió Bien y Qué Salió Mal
- **Qué funcionó**: [Métricas que alertaron a tiempo, contención rápida, rollback limpio]
- **Qué falló**: [Falta de logs claros, lentitud en diagnóstico, tests que no cubrían el caso]

## 5. Acciones Correctivas y Preventivas
| Acción | Responsable | Prioridad | Tarea / Lección |
| :--- | :--- | :---: | :--- |
| Parche correctivo en caliente | Especialista | Inmediata | Hotfix fusionado |
| Registrar lección en el cerebro | Orchestrator | Alta | `task.sh learn` (LL-XXX) |
| Añadir test de regresión / E2E | QA | Alta | Tarea planificada |
| Mejorar alerta o dashboard | DevOps | Media | Tarea planificada |
